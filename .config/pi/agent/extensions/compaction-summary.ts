/**
 * compaction-summary.ts - let the summary have room without shrinking the context window
 *
 * pi sizes the compaction summary as `min(0.8 * reserveTokens, model.maxTokens)`, and it
 * uses the same `reserveTokens` to decide when compaction starts (`contextWindow -
 * reserveTokens`). One number therefore answers two questions that pull apart on a
 * large-window model: it has to be small for the window to be usable and large for the
 * summary to fit. Measured on this machine, with the default 16,384:
 *
 *   576,801 token context, 427 messages to summarize
 *   budget 13,107 -> "generation hit the token cap and the summary is incomplete"
 *   budget 32,768 -> succeeded, and the summary came to 7,689 tokens (23% of it)
 *
 * The same input succeeded once it had headroom, and the summary it produced would have
 * fit in the original budget. The failure was overshoot, not a task that needed more
 * room, so headroom is the whole fix.
 *
 * `session_before_compact` may return a summary of its own, which is where the two
 * questions come apart: this calls pi's own summarizer, with pi's own prompt, its own
 * conversation serialization and its own length-stop detection, and passes it a larger
 * `reserveTokens` for that one call. Nothing else changes, so no setting has to trade
 * the window against the summary:
 *
 *   settings.json    untouched; reserveTokens stays 16,384 and the window stays usable
 *   models.json      untouched; every model keeps its native contextWindow
 *
 * On any failure it returns nothing and pi runs its normal compaction, so the worst case
 * is the behaviour without this file. compaction-log.ts records which path ran
 * (`fromExtension`) and how much of the budget the summary used (`budgetUsed`).
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { generateSummaryWithUsage } from "@earendil-works/pi-coding-agent";

// ---------------------------------------------------------------- config

const CONFIG = {
	/**
	 * The `reserveTokens` handed to the summarizer, which turns into a budget of
	 * `0.8 * this`, capped by the model's own output limit. 32,768 -> 26,214 tokens,
	 * about 3.4x the 7,689 a real summary of a 577k-token session needed.
	 *
	 * The first cut asked for 65,536 and that was a mistake in the other direction: a
	 * larger cap also licenses a longer answer, and generation is the slow half. A
	 * measured compaction of this session took 282 s under pi's own 32,768 budget, and an
	 * attempt under 65,536 was still running at 206 s when it was cancelled. Headroom
	 * against overshoot is the goal; room for an essay is not.
	 */
	reserveTokens: 32_768,
	/**
	 * Thinking level for the summarization call. Reasoning tokens are drawn from the
	 * same budget as the text, and the measured failure above already had thinking
	 * `off`, so reasoning was not what saved or sank it: "off" keeps the budget for the
	 * summary itself.
	 */
	thinkingLevel: "off" as const,
	/**
	 * Summarize with a different model, as `{ provider, id }`. Left unset the session's
	 * own model is used, which needs no configuration and cannot disagree with the
	 * conversation it is summarizing. A cheaper model is the reason to set it: the
	 * summarization request sends the whole span with `cacheRetention: "none"`, so on a
	 * large context it is the most expensive single call pi makes.
	 *
	 * Set it in `compaction-summary.json` rather than here when the id is an ARN, which
	 * carries an account number this directory is shared without.
	 */
	summarizerModel: undefined as { provider: string; id: string } | undefined,
	/**
	 * How often the footer's elapsed-time status updates, in ms. Summarizing a large span
	 * takes minutes with nothing on screen, which reads as a hang: one attempt was cancelled
	 * at 206 s for that reason. A visible clock is the difference between waiting and giving
	 * up.
	 */
	progressIntervalMs: 1_000,
	/**
	 * Tell compaction-log.ts which budget this attempt really had. Without it that log
	 * divides the summary by pi's settings-derived cap and reports a percentage of a
	 * request nobody made. Same bus magpi-handlers.ts uses; a missing listener is not an
	 * error, so this stays a one-way announcement.
	 */
	announceBudget: true,
	/**
	 * Say in the UI which path ran. Compaction is otherwise invisible until it fails,
	 * and "which summarizer produced this" is the first question when a summary looks
	 * wrong.
	 */
	notify: true,
} as const;

/** Mirrors pi's own sizing, so this file can tell whether it is an improvement at all. */
const BUDGET_FRACTION = 0.8;
/** pi's default, from DEFAULT_COMPACTION_SETTINGS. Only used to compare against. */
const DEFAULT_RESERVE_TOKENS = 16_384;

// ---------------------------------------------------------------- pure helpers

export interface ModelLike {
	id: string;
	name?: string;
	provider?: string;
	maxTokens: number;
	reasoning?: boolean;
}

/** `min(0.8 * reserveTokens, model.maxTokens)`; a model declaring no cap keeps the fraction. */
export function budgetFor(reserveTokens: number, modelMaxTokens: number | undefined): number {
	const fromReserve = Math.floor(BUDGET_FRACTION * reserveTokens);
	if (!modelMaxTokens || modelMaxTokens <= 0) return fromReserve;
	return Math.min(fromReserve, modelMaxTokens);
}

/**
 * Whether taking over buys anything. When the model's own output cap is at or below
 * what pi would have allowed anyway, this file would send the identical request and add
 * only a way to fail differently, so it steps aside and lets pi do it.
 */
export function improvesBudget(model: ModelLike | undefined, reserveTokens: number, defaultReserve: number): boolean {
	if (!model) return false;
	return budgetFor(reserveTokens, model.maxTokens) > budgetFor(defaultReserve, model.maxTokens);
}

/**
 * Everything the compaction is about to discard, in order. pi summarizes a split turn's
 * prefix separately and under half the budget; one summary over both spans is both
 * simpler and never subject to that smaller cap.
 */
export function messagesFor<T>(prep: { messagesToSummarize: T[]; turnPrefixMessages: T[] }): T[] {
	return [...prep.messagesToSummarize, ...prep.turnPrefixMessages];
}

/**
 * The compaction entry pi expects, or undefined when there is nothing worth keeping.
 * An empty or whitespace summary must not become a checkpoint: that is the same mistake
 * as persisting a truncated one.
 */
export function compactionFrom<U>(
	prep: { firstKeptEntryId: string; tokensBefore: number },
	summary: string,
	usage: U,
): { compaction: { summary: string; firstKeptEntryId: string; tokensBefore: number; usage: U } } | undefined {
	if (!summary.trim()) return undefined;
	return {
		compaction: {
			summary,
			firstKeptEntryId: prep.firstKeptEntryId,
			tokensBefore: prep.tokensBefore,
			usage,
		},
	};
}

/** One line for the UI, naming the budget this attempt got and the model that got it. */
export function describeAttempt(model: ModelLike, messageCount: number, budget: number): string {
	return `Summarizing ${messageCount} messages with ${model.name ?? model.id} (budget ${budget} tokens)`;
}

/**
 * Footer text while the call is in flight. The count and the clock are what tell a reader
 * that a multi-minute wait is progress rather than a hang. It says "minutes" and no number:
 * the two completions measured here took 190 s and 282 s on different inputs, which is not
 * a basis for predicting a third, and a hardcoded figure would go quietly wrong the moment
 * the model or the summarizer changed.
 */
export function progressText(elapsedMs: number, messageCount: number): string {
	const seconds = Math.floor(elapsedMs / 1000);
	return `\u{1F5DC} compacting ${messageCount} msg - ${seconds}s (takes minutes)`;
}

/** Local overrides, so an ARN or a machine-specific choice stays out of the repo. */
export interface FileConfig {
	reserveTokens?: number;
	summarizerModel?: { provider: string; id: string };
}

/**
 * `compaction-summary.json` beside this extension, merged over CONFIG. Unreadable or
 * malformed is not an error: the defaults are the documented behaviour, and a typo in an
 * optional file must not disable compaction.
 */
export function readFileConfig(path: string): FileConfig {
	try {
		const raw = JSON.parse(readFileSync(path, "utf8")) as FileConfig;
		const out: FileConfig = {};
		if (typeof raw.reserveTokens === "number" && raw.reserveTokens > 0) out.reserveTokens = raw.reserveTokens;
		if (raw.summarizerModel && typeof raw.summarizerModel.provider === "string" && typeof raw.summarizerModel.id === "string") {
			out.summarizerModel = { provider: raw.summarizerModel.provider, id: raw.summarizerModel.id };
		}
		return out;
	} catch {
		return {};
	}
}

// ---------------------------------------------------------------- extension

export default function (pi: ExtensionAPI) {
	const fileConfig = readFileConfig(join(homedir(), ".pi", "agent", "compaction-summary.json"));
	const reserveTokens = fileConfig.reserveTokens ?? CONFIG.reserveTokens;

	const pickModel = (ctx: ExtensionContext) => {
		const wanted = fileConfig.summarizerModel ?? CONFIG.summarizerModel;
		if (wanted) {
			const found = ctx.modelRegistry.find(wanted.provider, wanted.id);
			if (found) return found;
			if (ctx.hasUI) {
				ctx.ui.notify(
					`compaction-summary: ${wanted.provider}/${wanted.id} not found; using the session model`,
					"warning",
				);
			}
		}
		return ctx.model;
	};

	pi.on("session_before_compact", async (event, ctx) => {
		const { preparation: prep, customInstructions, signal } = event;
		const model = pickModel(ctx);
		if (!improvesBudget(model, reserveTokens, DEFAULT_RESERVE_TOKENS)) return undefined;
		if (!model) return undefined;

		const messages = messagesFor(prep);
		if (messages.length === 0) return undefined;

		const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
		if (!auth.ok) {
			if (ctx.hasUI) ctx.ui.notify(`compaction-summary: ${auth.error}; using pi's compaction`, "warning");
			return undefined;
		}

		const budget = budgetFor(reserveTokens, model.maxTokens);
		if (CONFIG.announceBudget) pi.events.emit("compaction-log:budget", budget);
		if (CONFIG.notify && ctx.hasUI) ctx.ui.notify(describeAttempt(model, messages.length, budget), "info");

		// A multi-minute wait with an empty screen is indistinguishable from a hang, and was
		// cancelled as one. The clock stops in `finally` whichever way the call ends.
		const startedAt = Date.now();
		const ticker =
			ctx.hasUI && CONFIG.progressIntervalMs > 0
				? setInterval(() => {
						ctx.ui.setStatus("compaction-summary", progressText(Date.now() - startedAt, messages.length));
					}, CONFIG.progressIntervalMs)
				: undefined;
		ticker?.unref?.();
		if (ctx.hasUI) ctx.ui.setStatus("compaction-summary", progressText(0, messages.length));

		try {
			// pi's summarizer: its prompt (or its update prompt when a previous summary
			// exists), its serialization, and its refusal to return a length-stopped
			// answer. The only argument that differs from the default path is the reserve.
			const { text, usage } = await generateSummaryWithUsage(
				messages,
				model,
				reserveTokens,
				auth.apiKey,
				auth.headers,
				signal,
				customInstructions,
				prep.previousSummary,
				CONFIG.thinkingLevel,
				undefined,
				auth.env,
			);
			const result = compactionFrom(prep, text, usage);
			if (!result) {
				if (ctx.hasUI && !signal.aborted) {
					ctx.ui.notify("compaction-summary: the summary came back empty; using pi's compaction", "warning");
				}
				return undefined;
			}
			return result;
		} catch (err) {
			// Including the length stop this file exists to avoid: pi's own path runs next,
			// and compaction-log.ts records which one produced the entry.
			if (ctx.hasUI && !signal.aborted) {
				const message = err instanceof Error ? err.message : String(err);
				ctx.ui.notify(`compaction-summary: ${message}; using pi's compaction`, "warning");
			}
			return undefined;
		} finally {
			if (ticker) clearInterval(ticker);
			if (ctx.hasUI) ctx.ui.setStatus("compaction-summary", undefined);
		}
	});
}
