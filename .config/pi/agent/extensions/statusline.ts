/**
 * statusline.ts - Claude Code style statusline (footer) for pi
 *
 * Ports the layout/colors of ~/.config/claude/statusline.sh to pi's footer:
 *
 *   [session] user@host 📂dir (branch*) (+12/-3)
 *   model • thinking • [1.3%/1.0M] (auto) 💰0.158 • ↑14 ↓2.5k CR43k CW12k CH99.3% • ⏱1m02s/12m30s
 *   <status texts published by other extensions via ctx.ui.setStatus()>
 *
 * Colors are the claude ones: user=blue, host=bright red, dir=dim green,
 * branch=cyan, dirty=red, +added/-removed=green/red, stats=dim,
 * context=green/yellow/red by usage.
 *
 * Command: /statusline    toggles between the built-in footer and this one.
 */

import { execFile } from "node:child_process";
import { readFileSync } from "node:fs";
import { hostname, userInfo } from "node:os";
import { join, relative, resolve, sep } from "node:path";
import type { ContextUsage, ExtensionAPI, ExtensionContext, SessionEntry } from "@earendil-works/pi-coding-agent";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import type { TUI } from "@earendil-works/pi-tui";
import { truncateToWidth } from "@earendil-works/pi-tui";

// ---------------------------------------------------------------- config

const CONFIG = {
	/** Install the custom statusline automatically on session start. */
	enabledByDefault: true,
	/** Icons - set any of them to "" if the terminal font lacks the glyph. */
	icons: { dir: "📂", cost: "💰", time: "⏱", branch: "" },
	/** Interval between `git status --porcelain` checks, in ms. 0 disables the check. */
	gitDirtyIntervalMs: 5000,
	/**
	 * How to label the model:
	 *   "auto"   - use the configured name when the model id is an ARN
	 *   "always" - always prefer the configured name
	 *   "never"  - always show the raw model id
	 */
	modelLabel: "auto" as "auto" | "always" | "never",
	/** Show token/cache statistics (↑ ↓ CR CW CH). */
	showTokens: true,
	/** Show the "(auto)" auto-compaction indicator. */
	showAutoCompact: true,
	/** Show api/wall-clock durations. */
	showDuration: true,
	/** Show added/removed line counts (+N/-M). */
	showLineDiff: true,
	/** Context usage percentages that switch the color to yellow / red. */
	contextWarnPercent: 70,
	contextErrorPercent: 90,
};

// ---------------------------------------------------------------- colors

const RESET = "\x1b[0m";
const ansi = (code: string, text: string) => `\x1b[${code}m${text}${RESET}`;
const blue = (text: string) => ansi("34", text);
const brightRed = (text: string) => ansi("91", text);
const cyan = (text: string) => ansi("36", text);
const dim = (text: string) => ansi("2", text);
const dimGreen = (text: string) => ansi("2;32", text);
const green = (text: string) => ansi("32", text);
const red = (text: string) => ansi("31", text);
const yellow = (text: string) => ansi("33", text);

const ELLIPSIS = dim("…");

// ---------------------------------------------------------------- formatting

/** Compact token counts, matching pi's built-in footer (`14`, `2.5k`, `43k`, `1.0M`). */
function formatTokens(count: number): string {
	if (count < 1000) return `${count}`;
	if (count < 10_000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1_000_000) return `${Math.round(count / 1000)}k`;
	if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
	return `${Math.round(count / 1_000_000)}M`;
}

/** `42s`, `1m02s`, `2h05m`. */
function formatDuration(ms: number): string {
	const seconds = Math.floor(ms / 1000);
	if (seconds >= 3600) {
		return `${Math.floor(seconds / 3600)}h${String(Math.floor((seconds % 3600) / 60)).padStart(2, "0")}m`;
	}
	if (seconds >= 60) return `${Math.floor(seconds / 60)}m${String(seconds % 60).padStart(2, "0")}s`;
	return `${seconds}s`;
}

/** Replace the home prefix with `~`, leaving paths outside of home untouched. */
function shortenPath(path: string): string {
	const home = process.env.HOME || process.env.USERPROFILE;
	if (!home) return path;
	const rel = relative(resolve(home), resolve(path));
	if (rel === "") return "~";
	if (rel.startsWith("..")) return path;
	return `~${sep}${rel}`;
}

/** Model ids can be ARNs (e.g. Bedrock inference profiles) - prefer the configured name then. */
function formatModel(model: { id: string; name?: string } | undefined): string {
	if (!model) return "no-model";
	if (CONFIG.modelLabel === "never" || !model.name) return model.id;
	if (CONFIG.modelLabel === "always") return model.name;
	return model.id.startsWith("arn:") ? model.name : model.id;
}

/** Sanitize a single-line status: no newlines/tabs, no repeated spaces. */
function sanitizeStatus(text: string): string {
	return text.replace(/[\r\n\t]/g, " ").replace(/ {2,}/g, " ").trim();
}

// ---------------------------------------------------------------- session totals

type UsageLike = {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: { total: number };
};

interface SessionTotals {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	/** Cache hit rate of the most recent assistant response, not a session average. */
	cacheHitRate?: number;
}

/** Pick the usage record an entry contributes to the session totals, if any. */
function entryUsage(entry: SessionEntry): UsageLike | undefined {
	if (entry.type === "message") {
		const role = entry.message.role;
		if (role === "assistant" || role === "toolResult") return (entry.message as { usage?: UsageLike }).usage;
		return undefined;
	}
	if (entry.type === "branch_summary" || entry.type === "compaction") return entry.usage as UsageLike | undefined;
	return undefined;
}

/**
 * Same accounting as pi's built-in footer: assistant responses, usage reported by
 * tools, plus compaction/branch-summary generation, across the whole session.
 */
function sumSessionUsage(entries: readonly SessionEntry[]): SessionTotals {
	const totals: SessionTotals = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0 };
	for (const entry of entries) {
		const usage = entryUsage(entry);
		if (!usage) continue;
		totals.input += usage.input;
		totals.output += usage.output;
		totals.cacheRead += usage.cacheRead;
		totals.cacheWrite += usage.cacheWrite;
		totals.cost += usage.cost.total;

		if (entry.type === "message" && entry.message.role === "assistant") {
			const prompt = usage.input + usage.cacheRead + usage.cacheWrite;
			totals.cacheHitRate = prompt > 0 ? (usage.cacheRead / prompt) * 100 : undefined;
		}
	}
	return totals;
}

// ---------------------------------------------------------------- line diff counter

/**
 * Counts lines added/removed by the edit/write tools, like claude's
 * total_lines_added / total_lines_removed.
 *
 * Session entries are append-only, so the scan is incremental: each entry is
 * inspected exactly once no matter how often the footer re-renders.
 *
 * Caveats: `write` over an existing file counts the whole file as added (the
 * previous content is not in the session log), and edits made through `bash`
 * (sed, heredoc, ...) are not counted.
 */
class LineDiffCounter {
	added = 0;
	removed = 0;
	private index = 0;
	/** toolCallId -> tool call arguments, needed because write results carry no details. */
	private callArgs = new Map<string, Record<string, unknown>>();

	reset(): void {
		this.added = 0;
		this.removed = 0;
		this.index = 0;
		this.callArgs.clear();
	}

	get hasChanges(): boolean {
		return this.added > 0 || this.removed > 0;
	}

	scan(entries: readonly SessionEntry[]): void {
		for (; this.index < entries.length; this.index++) {
			const entry = entries[this.index];
			if (entry.type !== "message") continue;
			const message = entry.message as Record<string, any>;

			if (message.role === "assistant") {
				this.rememberToolCalls(message);
			} else if (message.role === "toolResult") {
				this.countToolResult(message);
			}
		}
	}

	private rememberToolCalls(message: Record<string, any>): void {
		for (const block of message.content ?? []) {
			if (block?.type === "toolCall" && typeof block.id === "string") {
				this.callArgs.set(block.id, block.arguments ?? {});
			}
		}
	}

	private countToolResult(message: Record<string, any>): void {
		const args = this.callArgs.get(message.toolCallId);
		this.callArgs.delete(message.toolCallId);
		if (message.isError) return;

		if (message.toolName === "edit") {
			const patch: string | undefined = message.details?.patch;
			if (!patch) return;
			for (const line of patch.split("\n")) {
				if (line.startsWith("+") && !line.startsWith("+++")) this.added++;
				else if (line.startsWith("-") && !line.startsWith("---")) this.removed++;
			}
		} else if (message.toolName === "write") {
			const content = args?.content;
			if (typeof content === "string") this.added += content.split("\n").length;
		}
	}
}

// ---------------------------------------------------------------- git dirty tracker

/** Polls `git status --porcelain` in the background and caches the result. */
class GitDirtyTracker {
	private dirty = false;
	private checkedAt = 0;
	private running = false;
	/** Called when the dirty flag flips, to request a re-render. */
	private readonly onChange: () => void;

	constructor(onChange: () => void) {
		this.onChange = onChange;
	}

	isDirty(): boolean {
		return this.dirty;
	}

	/** Force the next refresh() call to actually run git. */
	invalidate(): void {
		this.checkedAt = 0;
	}

	/** Kick off a check if the cached value is stale. Never blocks rendering. */
	refresh(cwd: string): void {
		if (CONFIG.gitDirtyIntervalMs <= 0 || this.running) return;
		if (Date.now() - this.checkedAt < CONFIG.gitDirtyIntervalMs) return;
		this.running = true;
		this.checkedAt = Date.now();
		const args = ["-C", cwd, "--no-optional-locks", "status", "--porcelain"];
		execFile("git", args, { timeout: 2000 }, (error, stdout) => {
			this.running = false;
			const dirty = !error && stdout.trim().length > 0;
			if (dirty === this.dirty) return;
			this.dirty = dirty;
			this.onChange();
		});
	}
}

// ---------------------------------------------------------------- duration tracker

/**
 * Per-session timing state.
 *
 * Kept on globalThis so it survives `/reload`: reloading re-imports this module
 * and re-fires `session_start`, which would otherwise restart both timers.
 */
interface DurationState {
	sessionId?: string;
	/** Wall-clock start: the first session entry's timestamp when known. */
	sessionStart: number;
	/** Accumulated time spent inside agent turns. */
	apiMs: number;
}

const DURATION_STATE_KEY = "__piStatuslineDurations";

function loadDurationState(): DurationState {
	const globals = globalThis as Record<string, unknown>;
	let state = globals[DURATION_STATE_KEY] as DurationState | undefined;
	if (!state) {
		state = { sessionStart: Date.now(), apiMs: 0 };
		globals[DURATION_STATE_KEY] = state;
	}
	return state;
}

/** Tracks api time (sum of turns) and wall-clock time (since session start). */
class DurationTracker {
	private state = loadDurationState();
	private turnStart?: number;
	private ticker?: ReturnType<typeof setInterval>;

	/**
	 * Bind to a session. Timers restart only when the session actually changes,
	 * not on `/reload`.
	 *
	 * @param sessionId    current session id
	 * @param startedAt    epoch ms of the session's first entry, if any
	 */
	attach(sessionId: string, startedAt?: number): void {
		if (this.state.sessionId === sessionId) {
			// Same session (e.g. after /reload): keep the accumulated api time and
			// only correct the wall-clock start if the log knows an earlier one.
			if (startedAt) this.state.sessionStart = Math.min(this.state.sessionStart, startedAt);
			return;
		}
		this.state.sessionId = sessionId;
		this.state.sessionStart = startedAt ?? Date.now();
		this.state.apiMs = 0;
		this.turnStart = undefined;
	}

	/** @param onTick called once per second so the running duration stays live */
	startTurn(onTick: () => void): void {
		this.turnStart = Date.now();
		if (!CONFIG.showDuration || this.ticker) return;
		this.ticker = setInterval(onTick, 1000);
		this.ticker.unref?.();
	}

	endTurn(): void {
		if (this.turnStart) this.state.apiMs += Date.now() - this.turnStart;
		this.turnStart = undefined;
		if (!this.ticker) return;
		clearInterval(this.ticker);
		this.ticker = undefined;
	}

	/** Stop the ticker (called when the extension is unloaded). */
	dispose(): void {
		if (!this.ticker) return;
		clearInterval(this.ticker);
		this.ticker = undefined;
	}

	/** `api/wall`, with the in-flight turn included in the api part. */
	format(): string {
		const running = this.turnStart ? Date.now() - this.turnStart : 0;
		return `${formatDuration(this.state.apiMs + running)}/${formatDuration(Date.now() - this.state.sessionStart)}`;
	}
}

// ---------------------------------------------------------------- settings

/** Auto-compaction flag, read straight from settings.json (project settings win). */
function readAutoCompactEnabled(cwd: string): boolean {
	for (const path of [join(cwd, ".pi", "settings.json"), join(getAgentDir(), "settings.json")]) {
		try {
			const settings = JSON.parse(readFileSync(path, "utf8")) as { compaction?: { enabled?: boolean } };
			if (typeof settings.compaction?.enabled === "boolean") return settings.compaction.enabled;
		} catch {
			// missing or unreadable settings file - try the next one
		}
	}
	return true; // pi's default
}

// ---------------------------------------------------------------- line builders

interface LocationLine {
	user: string;
	host: string;
	cwd: string;
	sessionName?: string;
	branch: string | null;
	dirty: boolean;
	diff: { added: number; removed: number; hasChanges: boolean };
}

/** `[session] user@host 📂dir (branch*) (+12/-3)` */
function buildLocationLine(data: LocationLine): string {
	const parts: string[] = [];

	if (data.sessionName) parts.push(dim(`[${data.sessionName}]`));
	parts.push(`${blue(data.user)}@${brightRed(data.host)}`);
	parts.push(dimGreen(`${CONFIG.icons.dir}${shortenPath(data.cwd)}`));
	if (data.branch) {
		parts.push(cyan(`${CONFIG.icons.branch}${data.branch}`) + (data.dirty ? red("*") : ""));
	}
	if (CONFIG.showLineDiff && data.diff.hasChanges) {
		parts.push(`(${green(`+${data.diff.added}`)}/${red(`-${data.diff.removed}`)})`);
	}

	return parts.join(" ");
}

interface StatsLine {
	model: { id: string; name?: string; reasoning?: boolean; contextWindow?: number } | undefined;
	thinkingLevel?: string;
	totals: SessionTotals;
	context: ContextUsage | undefined;
	autoCompact: boolean;
	duration: string;
}

/** `model • thinking • [1.3%/1.0M] (auto) 💰0.158 • ↑14 ↓2.5k CR43k CW12k CH99.3% • ⏱1m02s/12m30s` */
function buildStatsLine(data: StatsLine): string {
	/** Space-joined segments, themselves joined by ` • ` below. */
	const groups: string[] = [];
	const { totals } = data;

	// model, plus thinking level when the model supports reasoning
	const thinking = data.model?.reasoning ? ` • ${data.thinkingLevel || "off"}` : "";
	groups.push(dim(formatModel(data.model) + thinking));

	// context usage, auto-compaction indicator and session cost
	const usage: string[] = [];

	// `?` while unknown (right after compaction, before the next response)
	const window = data.context?.contextWindow ?? data.model?.contextWindow ?? 0;
	if (window > 0) {
		const used = data.context?.percent ?? null;
		const body = `[${used === null ? "?" : `${used.toFixed(1)}%`}/${formatTokens(window)}]`;
		const level = used ?? 0;
		const paint = level > CONFIG.contextErrorPercent ? red : level > CONFIG.contextWarnPercent ? yellow : green;
		usage.push(paint(body));
	}
	if (CONFIG.showAutoCompact && data.autoCompact) usage.push(dim("(auto)"));
	if (totals.cost > 0) usage.push(`${CONFIG.icons.cost}${totals.cost.toFixed(3)}`);
	if (usage.length > 0) groups.push(usage.join(" "));

	// token and cache usage
	if (CONFIG.showTokens) {
		const stats: string[] = [];
		if (totals.input) stats.push(`↑${formatTokens(totals.input)}`);
		if (totals.output) stats.push(`↓${formatTokens(totals.output)}`);
		if (totals.cacheRead) stats.push(`CR${formatTokens(totals.cacheRead)}`);
		if (totals.cacheWrite) stats.push(`CW${formatTokens(totals.cacheWrite)}`);
		const cached = totals.cacheRead || totals.cacheWrite;
		if (cached && totals.cacheHitRate !== undefined) stats.push(`CH${totals.cacheHitRate.toFixed(1)}%`);
		if (stats.length > 0) groups.push(dim(stats.join(" ")));
	}

	// api/wall durations
	if (CONFIG.showDuration) groups.push(dim(`${CONFIG.icons.time}${data.duration}`));

	return groups.join(dim(" • "));
}

/** Statuses other extensions published via ctx.ui.setStatus(), sorted by key. */
function buildExtensionStatusLine(statuses: ReadonlyMap<string, string>): string | undefined {
	if (statuses.size === 0) return undefined;
	return Array.from(statuses.entries())
		.sort(([a], [b]) => a.localeCompare(b))
		.map(([, text]) => sanitizeStatus(text))
		.join(" ");
}

// ---------------------------------------------------------------- extension

export default function (pi: ExtensionAPI) {
	const user = userInfo().username;
	const host = hostname().split(".")[0];

	let tui: TUI | undefined;
	let installed = false;

	const requestRender = () => tui?.requestRender();
	const lineDiff = new LineDiffCounter();
	const gitDirty = new GitDirtyTracker(requestRender);
	const durations = new DurationTracker();

	// Cached compaction.enabled, refreshed on session start / turn end.
	let autoCompact = true;

	/** Replace pi's footer with ours. */
	function install(ctx: ExtensionContext): void {
		ctx.ui.setFooter((footerTui, _theme, footerData) => {
			tui = footerTui;
			const unsubscribe = footerData.onBranchChange(() => {
				gitDirty.invalidate();
				footerTui.requestRender();
			});

			return {
				dispose: unsubscribe,
				invalidate() {},
				render(width: number): string[] {
					const entries = ctx.sessionManager.getEntries();
					if (CONFIG.showLineDiff) lineDiff.scan(entries);

					const cwd = ctx.sessionManager.getCwd();
					gitDirty.refresh(cwd);

					const lines = [
						buildLocationLine({
							user,
							host,
							cwd,
							sessionName: ctx.sessionManager.getSessionName(),
							branch: footerData.getGitBranch(),
							dirty: gitDirty.isDirty(),
							diff: { added: lineDiff.added, removed: lineDiff.removed, hasChanges: lineDiff.hasChanges },
						}),
						buildStatsLine({
							model: ctx.model,
							thinkingLevel: ctx.thinkingLevel,
							totals: sumSessionUsage(entries),
							context: ctx.getContextUsage(),
							autoCompact,
							duration: durations.format(),
						}),
					];

					const statusLine = buildExtensionStatusLine(footerData.getExtensionStatuses());
					if (statusLine) lines.push(statusLine);

					return lines.map((line) => truncateToWidth(line, width, ELLIPSIS));
				},
			};
		});
		installed = true;
	}

	/** Restore pi's built-in footer. */
	function uninstall(ctx: ExtensionContext): void {
		ctx.ui.setFooter(undefined);
		installed = false;
	}

	// ---------------------------------------------------------------- events

	pi.on("session_start", async (_event, ctx) => {
		const entries = ctx.sessionManager.getEntries();
		const firstTimestamp = entries[0]?.timestamp;
		// Resumed sessions keep their original wall-clock start; /reload keeps everything.
		durations.attach(ctx.sessionManager.getSessionId(), firstTimestamp ? Date.parse(firstTimestamp) : undefined);
		lineDiff.reset();
		gitDirty.invalidate();
		autoCompact = readAutoCompactEnabled(ctx.cwd);
		if (CONFIG.enabledByDefault && ctx.mode === "tui") install(ctx);
	});

	pi.on("turn_start", async () => {
		durations.startTurn(requestRender);
	});

	pi.on("turn_end", async (_event, ctx) => {
		durations.endTurn();
		gitDirty.invalidate(); // files likely changed during the turn
		autoCompact = readAutoCompactEnabled(ctx.cwd);
	});

	// Nudge a re-render so edits show up in the +/- counters right away.
	pi.on("tool_result", async () => {
		requestRender();
	});

	pi.on("session_shutdown", async () => {
		durations.dispose();
	});

	// ---------------------------------------------------------------- command

	pi.registerCommand("statusline", {
		description: "Toggle the Claude Code style statusline",
		handler: async (_args, ctx) => {
			if (installed) {
				uninstall(ctx);
				ctx.ui.notify("Built-in footer restored", "info");
				return;
			}
			autoCompact = readAutoCompactEnabled(ctx.cwd);
			install(ctx);
			ctx.ui.notify("Custom statusline enabled", "info");
		},
	});
}
