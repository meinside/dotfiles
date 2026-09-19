/**
 * compaction-log.ts - record what happened at every compaction attempt
 *
 * `Compaction failed: Summarization failed: generation hit the token cap and the
 * summary is incomplete` names the symptom and hides the cause. The message does not
 * say what triggered the attempt, how large the context was, or how much room the
 * summarizer had, and those three decide which fix is the right one:
 *
 *   reason "threshold"  the window filled up normally. The summary budget
 *                       (0.8 * reserveTokens, capped by the model's maxTokens) is too
 *                       small for the span being summarized -> raise reserveTokens or
 *                       lower the model's declared contextWindow.
 *   reason "overflow"   the provider already rejected the context, so compaction is
 *                       running as recovery on a context that never fit. With a
 *                       rotating model chain this is what a mid-session switch to a
 *                       smaller-window model looks like -> the chain's smallest window
 *                       is the real ceiling, not the current model's.
 *   reason "manual"     /compact, so the numbers are whatever the session had.
 *
 * `session_compact_failed` carries neither the preparation nor the settings, so an
 * attempt is remembered from `session_before_compact` and paired with its outcome.
 * One JSONL line per completed attempt; nothing is written when nothing is attempted.
 *
 * This extension only observes. It never cancels a compaction and never supplies a
 * summary, so a bug here cannot cost a session its history.
 *
 * Command: /compaction-log    show the recorded attempts, newest last.
 */

import { appendFileSync, mkdirSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// ---------------------------------------------------------------- tuning

const TUNING = {
	/**
	 * How pi sizes the summary budget, mirrored here so the log can say how close a
	 * summary came to it: `min(summaryBudgetFraction * reserveTokens, model.maxTokens)`
	 * (dist/core/compaction/compaction.js, generateSummaryWithUsage). Turn prefix
	 * summaries use 0.5 and are not logged separately.
	 */
	summaryBudgetFraction: 0.8,
	/**
	 * A split turn produces a second, separate summary of the turn's prefix, and pi gives
	 * that one half the reserve (same file, generateTurnPrefixSummary). It is the tighter
	 * of the two caps, so it is logged on its own rather than folded into the main
	 * numbers: a failure can come from either.
	 */
	prefixBudgetFraction: 0.5,
	/**
	 * Characters per token for the span estimate. The exact count needs the
	 * provider's tokenizer, which an extension has no access to; 4 is the usual
	 * English-heavy approximation and is only used for `spanTokensEst`, never for a
	 * decision. `tokensBefore` next to it is pi's own count, so a wildly different
	 * ratio is visible rather than hidden.
	 */
	charsPerToken: 4,
	/** Attempts shown by /compaction-log. Older lines stay in the file. */
	showLast: 20,
	/**
	 * Notify on failure. The built-in error text omits the reason, which is the one
	 * field that changes the fix, so it is worth one line in the UI.
	 */
	notifyOnFailure: true,
} as const;

// ---------------------------------------------------------------- types

/** What `session_before_compact` told us, kept until the outcome arrives. */
export interface Attempt {
	startedAt: string;
	reason: "manual" | "threshold" | "overflow";
	willRetry: boolean;
	isSplitTurn: boolean;
	tokensBefore: number;
	reserveTokens: number;
	keepRecentTokens: number;
	enabled: boolean;
	/** Messages that would be summarized and dropped. */
	spanMessages: number;
	spanChars: number;
	/**
	 * The prefix of a split turn, summarized separately and under a smaller cap. Zero
	 * when the cut point fell on a turn boundary.
	 */
	prefixMessages: number;
	prefixChars: number;
	/** Present when this compaction rewrites an earlier summary, which grows it. */
	previousSummaryChars?: number;
	hadCustomInstructions: boolean;
	/**
	 * The budget the summary actually had, when a `session_before_compact` handler supplied
	 * it. pi's own cap comes from `reserveTokens`, but a handler picks its own, so a
	 * `budgetUsed` computed from settings would be wrong by whatever factor the handler
	 * chose. Announced on the event bus by compaction-summary.ts; absent when pi's own
	 * summarizer ran.
	 */
	suppliedBudget?: number;
	model?: { id: string; name: string; contextWindow: number; maxTokens: number; reasoning: boolean };
	thinkingLevel?: string;
}

export type Outcome =
	| { kind: "ok"; summaryChars: number; fromExtension: boolean }
	| { kind: "failed"; errorMessage?: string; fromExtension: boolean }
	| { kind: "aborted"; fromExtension: boolean };

export interface Record_ extends Attempt {
	finishedAt: string;
	outcome: Outcome["kind"];
	fromExtension: boolean;
	errorMessage?: string;
	summaryChars?: number;
	/** min(0.8 * reserveTokens, model.maxTokens) - the cap the summary had to fit. */
	summaryBudget: number;
	/** min(0.5 * reserveTokens, model.maxTokens) - the cap a split turn's prefix had. */
	prefixBudget: number;
	/** spanChars / charsPerToken. An estimate; see TUNING.charsPerToken. */
	spanTokensEst: number;
	prefixTokensEst: number;
	/** spanTokensEst / summaryBudget. How much compression was being asked for. */
	compressionRatio: number;
	/** prefixTokensEst / prefixBudget. Often the worse of the two on a split turn. */
	prefixRatio: number;
	/**
	 * tokensBefore minus what this file can see and estimate (span + prefix + the recent
	 * tokens kept verbatim). What is left is the system prompt, the tool schemas, images
	 * and the error in charsPerToken. A large value means the ratios above were computed
	 * from a small part of the context, which is worth knowing before trusting them.
	 */
	unaccountedTokensEst: number;
	/** On success: how much of the budget the summary used. 1.0 means it only just fit. */
	budgetUsed?: number;
	verdict: string;
}

// ---------------------------------------------------------------- pure helpers

/**
 * The cap pi gives a summarizer: a fraction of the reserve, never above the model's own
 * output limit. `maxTokens <= 0` means the model declares none.
 */
export function budgetOf(fraction: number, reserveTokens: number, modelMaxTokens: number | undefined): number {
	const fromReserve = Math.floor(fraction * reserveTokens);
	if (!modelMaxTokens || modelMaxTokens <= 0) return fromReserve;
	return Math.min(fromReserve, modelMaxTokens);
}

/** The main summary's cap. */
export function summaryBudget(reserveTokens: number, modelMaxTokens: number | undefined): number {
	return budgetOf(TUNING.summaryBudgetFraction, reserveTokens, modelMaxTokens);
}

/**
 * One sentence naming the cause, so the log is readable without recomputing anything.
 * Ordered by which fix it implies, not by severity.
 */
export function verdictOf(r: Omit<Record_, "verdict">): string {
	const win = r.model?.contextWindow;
	const ratio = r.compressionRatio.toFixed(1);
	if (r.outcome === "aborted") return "aborted before an answer arrived; nothing to conclude";
	if (r.outcome === "ok") {
		const used = r.budgetUsed ?? 0;
		if (used >= 0.9) return `fit, but used ${(used * 100).toFixed(0)}% of the ${r.summaryBudget} token budget`;
		return `fit in ${(used * 100).toFixed(0)}% of the ${r.summaryBudget} token budget`;
	}
	if (r.reason === "overflow") {
		return `overflow recovery: the provider had already rejected this context${
			win ? ` against a declared window of ${win}` : ""
		}, so the summary ran on a context that never fit (${ratio}:1)`;
	}
	// A split turn's prefix runs under half the cap, so it can be the binding constraint
	// even when the main ratio looks survivable. Name whichever is worse.
	if (r.isSplitTurn && r.prefixRatio > r.compressionRatio) {
		return `split turn: its prefix asks ${r.prefixRatio.toFixed(1)}:1 of a ${r.prefixBudget} token budget, tighter than the main ${ratio}:1`;
	}
	if (r.compressionRatio > 12) {
		return `${ratio}:1 compression asked of a ${r.summaryBudget} token budget; the budget or the window is the problem`;
	}
	if (r.previousSummaryChars) {
		return `${ratio}:1 with an earlier summary of ${r.previousSummaryChars} chars being rewritten, which grows it`;
	}
	return `${ratio}:1 compression failed inside a ${r.summaryBudget} token budget`;
}

export function deriveRecord(attempt: Attempt, outcome: Outcome, finishedAt: string): Record_ {
	// A handler that supplies the summary chooses its own cap, so the settings-derived
	// budget would describe a request that was never made.
	const budget = attempt.suppliedBudget ?? summaryBudget(attempt.reserveTokens, attempt.model?.maxTokens);
	const prefixBudget = budgetOf(TUNING.prefixBudgetFraction, attempt.reserveTokens, attempt.model?.maxTokens);
	const spanTokensEst = Math.round(attempt.spanChars / TUNING.charsPerToken);
	const prefixTokensEst = Math.round(attempt.prefixChars / TUNING.charsPerToken);
	const base: Omit<Record_, "verdict"> = {
		...attempt,
		finishedAt,
		outcome: outcome.kind,
		fromExtension: outcome.fromExtension,
		errorMessage: outcome.kind === "failed" ? outcome.errorMessage : undefined,
		summaryChars: outcome.kind === "ok" ? outcome.summaryChars : undefined,
		summaryBudget: budget,
		prefixBudget,
		spanTokensEst,
		prefixTokensEst,
		unaccountedTokensEst: Math.max(
			0,
			attempt.tokensBefore - spanTokensEst - prefixTokensEst - attempt.keepRecentTokens,
		),
		compressionRatio: budget > 0 ? Number((spanTokensEst / budget).toFixed(2)) : 0,
		prefixRatio: prefixBudget > 0 ? Number((prefixTokensEst / prefixBudget).toFixed(2)) : 0,
		budgetUsed:
			outcome.kind === "ok" && budget > 0
				? Number((outcome.summaryChars / TUNING.charsPerToken / budget).toFixed(2))
				: undefined,
	};
	return { ...base, verdict: verdictOf(base) };
}

/**
 * Same place magpi-render.ts keeps its artifacts, for the same reason: a path that can
 * be read, grepped and diffed outside pi. `getAgentDir()` would be more correct but it
 * is a runtime import of pi's package, which would stop the tests from loading this
 * file at all.
 */
export function logPath(): string {
	return join(homedir(), ".pi", "agent", "tmp", "compaction", "log.jsonl");
}

/** Newest last, malformed lines skipped rather than throwing away the readable ones. */
export function parseLog(raw: string): Record_[] {
	const out: Record_[] = [];
	for (const line of raw.split("\n")) {
		const trimmed = line.trim();
		if (!trimmed) continue;
		try {
			out.push(JSON.parse(trimmed) as Record_);
		} catch {
			// a truncated tail line is not a reason to lose the rest
		}
	}
	return out;
}

/**
 * A number this file may not have recorded when the line was written. The log is
 * append-only, so entries outlive the schema that produced them: printing `undefined`
 * (the first cut did) reads like a bug in the run being diagnosed, and substituting 0
 * would claim a measurement nobody took.
 */
function told(value: number | undefined): string | undefined {
	return typeof value === "number" && Number.isFinite(value) ? String(value) : undefined;
}

export function formatLog(records: Record_[], limit = TUNING.showLast): string {
	if (records.length === 0) {
		return "No compaction has been attempted while this extension was loaded.";
	}
	const shown = records.slice(-limit);
	const lines = [
		`${records.length} attempt(s) recorded, newest last. Log: ${logPath()}`,
		"",
		...shown.map((r) => {
			const mark = r.outcome === "ok" ? "ok  " : r.outcome === "failed" ? "FAIL" : "abrt";
			const win = r.model?.contextWindow ?? 0;
			const prefixTok = told(r.prefixTokensEst);
			const unaccounted = told(r.unaccountedTokensEst);
			const budgetSource = r.suppliedBudget ? " (supplied by an extension)" : "";
			return [
				`${mark} ${r.startedAt}  ${r.reason}${r.willRetry ? " (retry)" : ""}`,
				`     context ${r.tokensBefore} / window ${win}   reserve ${r.reserveTokens}  keep ${r.keepRecentTokens}`,
				`     span ~${r.spanTokensEst} tok in ${r.spanMessages} msg -> budget ${r.summaryBudget}${budgetSource}  ratio ${r.compressionRatio}:1`,
				...(r.isSplitTurn
					? [
							prefixTok === undefined
								? "     split turn, prefix not recorded (entry predates that field)"
								: `     split turn prefix ~${prefixTok} tok in ${r.prefixMessages} msg -> budget ${r.prefixBudget}  ratio ${r.prefixRatio}:1`,
						]
					: []),
				...(unaccounted === undefined
					? []
					: [`     unaccounted ~${unaccounted} tok (system prompt, tool schemas, estimate error)`]),
				`     ${r.verdict}`,
				...(r.errorMessage ? [`     error: ${r.errorMessage}`] : []),
			].join("\n");
		}),
	];
	return lines.join("\n");
}

/** Total chars of every text or thinking block, which is what the summarizer reads. */
export function contentChars(messages: readonly unknown[]): number {
	let chars = 0;
	for (const msg of messages) {
		const content = (msg as { content?: unknown }).content;
		if (typeof content === "string") {
			chars += content.length;
			continue;
		}
		if (!Array.isArray(content)) continue;
		for (const block of content) {
			const b = block as { type?: string; text?: string; thinking?: string };
			if (typeof b.text === "string") chars += b.text.length;
			else if (typeof b.thinking === "string") chars += b.thinking.length;
			else chars += JSON.stringify(block ?? null).length;
		}
	}
	return chars;
}

// ---------------------------------------------------------------- extension

export default function (pi: ExtensionAPI) {
	let pending: Attempt | undefined;
	/**
	 * Budget announced by a `session_before_compact` handler for the attempt in flight.
	 * Without it this file would report pi's settings-derived cap for a request that used a
	 * different one. Cleared with the attempt so a later compaction cannot inherit it.
	 */
	let announcedBudget: number | undefined;

	pi.events.on("compaction-log:budget", (budget: unknown) => {
		if (typeof budget === "number" && Number.isFinite(budget) && budget > 0) announcedBudget = budget;
	});

	const modelOf = (ctx: ExtensionContext) => {
		const m = ctx.model;
		if (!m) return undefined;
		return {
			id: m.id,
			name: m.name,
			contextWindow: m.contextWindow,
			maxTokens: m.maxTokens,
			reasoning: m.reasoning,
		};
	};

	const finish = (outcome: Outcome, ctx: ExtensionContext) => {
		const attempt = pending;
		pending = undefined;
		announcedBudget = undefined;
		if (!attempt) return undefined;
		const record = deriveRecord(attempt, outcome, new Date().toISOString());
		try {
			const path = logPath();
			mkdirSync(dirname(path), { recursive: true });
			appendFileSync(path, `${JSON.stringify(record)}\n`, "utf8");
		} catch (err) {
			// Losing a diagnostic must not disturb the session it is describing.
			if (ctx.hasUI) ctx.ui.notify(`compaction-log: could not write the log (${String(err)})`, "warning");
		}
		return record;
	};

	pi.on("session_before_compact", async (event, ctx) => {
		const prep = event.preparation;
		pending = {
			startedAt: new Date().toISOString(),
			reason: event.reason,
			willRetry: event.willRetry,
			isSplitTurn: prep.isSplitTurn,
			tokensBefore: prep.tokensBefore,
			reserveTokens: prep.settings.reserveTokens,
			keepRecentTokens: prep.settings.keepRecentTokens,
			enabled: prep.settings.enabled,
			spanMessages: prep.messagesToSummarize.length,
			spanChars: contentChars(prep.messagesToSummarize),
			prefixMessages: prep.turnPrefixMessages.length,
			prefixChars: contentChars(prep.turnPrefixMessages),
			previousSummaryChars: prep.previousSummary?.length,
			hadCustomInstructions: Boolean(event.customInstructions),
			model: modelOf(ctx),
			thinkingLevel: ctx.thinkingLevel,
		};
		// Observing only: no cancel, no summary. A handler that supplies one announces its
		// budget on the bus; handler order is not guaranteed, so the value is read at the
		// outcome rather than here.
		return undefined;
	});

	pi.on("session_compact", async (event, ctx) => {
		if (pending && announcedBudget) pending.suppliedBudget = announcedBudget;
		finish(
			{
				kind: "ok",
				summaryChars: event.compactionEntry.summary?.length ?? 0,
				fromExtension: event.fromExtension,
			},
			ctx,
		);
	});

	pi.on("session_compact_failed", async (event, ctx) => {
		if (pending && announcedBudget) pending.suppliedBudget = announcedBudget;
		const record = finish(
			event.aborted
				? { kind: "aborted", fromExtension: event.fromExtension }
				: { kind: "failed", errorMessage: event.errorMessage, fromExtension: event.fromExtension },
			ctx,
		);
		if (!TUNING.notifyOnFailure || event.aborted || !ctx.hasUI) return;
		const detail = record
			? `${record.reason}, ratio ${record.compressionRatio}:1, budget ${record.summaryBudget} tok`
			: `${event.reason} (no preparation was seen)`;
		ctx.ui.notify(`Compaction failed: ${detail}. /compaction-log for the numbers`, "error");
	});

	pi.registerCommand("compaction-log", {
		description: "📉 Show what happened at each compaction attempt",
		async handler(_args, ctx) {
			let raw = "";
			try {
				raw = readFileSync(logPath(), "utf8");
			} catch {
				raw = "";
			}
			const records = parseLog(raw);
			if (pending) {
				ctx.ui.notify(`A ${pending.reason} compaction is in flight (context ${pending.tokensBefore})`, "info");
			}
			ctx.ui.notify(formatLog(records), "info");
		},
	});
}
