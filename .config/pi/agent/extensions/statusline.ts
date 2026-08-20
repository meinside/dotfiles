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
	/**
	 * Install the custom statusline automatically on session start. Once
	 * `/statusline` has been used, that decision wins for the rest of the process.
	 */
	enabledByDefault: true,
	/** Icons - set any of them to "" if the terminal font lacks the glyph. */
	icons: { dir: "📂", cost: "💰", time: "⏱️", branch: "" },
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
export function formatTokens(count: number): string {
	if (count < 1000) return `${count}`;
	if (count < 10_000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1_000_000) return `${Math.round(count / 1000)}k`;
	if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
	return `${Math.round(count / 1_000_000)}M`;
}

/** `42s`, `1m02s`, `2h05m`. */
export function formatDuration(ms: number): string {
	const seconds = Math.floor(ms / 1000);
	if (seconds >= 3600) {
		return `${Math.floor(seconds / 3600)}h${String(Math.floor((seconds % 3600) / 60)).padStart(2, "0")}m`;
	}
	if (seconds >= 60) return `${Math.floor(seconds / 60)}m${String(seconds % 60).padStart(2, "0")}s`;
	return `${seconds}s`;
}

/** Replace the home prefix with `~`, leaving paths outside of home untouched. */
export function shortenPath(path: string): string {
	const home = process.env.HOME || process.env.USERPROFILE;
	if (!home) return path;
	const rel = relative(resolve(home), resolve(path));
	if (rel === "") return "~";
	if (rel.startsWith("..")) return path;
	return `~${sep}${rel}`;
}

/** Model ids can be ARNs (e.g. Bedrock inference profiles) - prefer the configured name then. */
export function formatModel(model: { id: string; name?: string } | undefined): string {
	if (!model) return "no-model";
	if (CONFIG.modelLabel === "never" || !model.name) return model.id;
	if (CONFIG.modelLabel === "always") return model.name;
	return model.id.startsWith("arn:") ? model.name : model.id;
}

/** Sanitize a single-line status: no newlines/tabs, no repeated spaces. */
export function sanitizeStatus(text: string): string {
	return text.replace(/[\r\n\t]/g, " ").replace(/ {2,}/g, " ").trim();
}

// ---------------------------------------------------------------- session scan

/** The fields of pi-ai's `Usage` this footer reads. */
interface UsageLike {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: { total: number };
}

export interface SessionTotals {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	/** Cache hit rate of the most recent assistant response, not a session average. */
	cacheHitRate?: number;
}

/**
 * Structural views of the two message shapes that carry footer data. Narrower
 * than `any` but not the full pi-ai `Message` union, whose optional fields this
 * footer must tolerate missing in older session files.
 */
interface AssistantLike {
	role: "assistant";
	content?: readonly unknown[];
	usage?: UsageLike;
}
interface ToolResultLike {
	role: "toolResult";
	toolCallId: string;
	toolName: string;
	isError?: boolean;
	details?: { patch?: string };
	usage?: UsageLike;
}
interface ToolCallLike {
	type: "toolCall";
	id: string;
	arguments?: Record<string, unknown>;
}

function asRole(message: unknown): string | undefined {
	return (message as { role?: unknown } | null)?.role as string | undefined;
}

/** Lines a `write` call adds: content lines, not split() elements. */
function countLines(content: string): number {
	if (content.length === 0) return 0;
	const lines = content.split("\n").length;
	return content.endsWith("\n") ? lines - 1 : lines;
}

/**
 * Single incremental pass over the session log, producing both the usage totals
 * and the added/removed line counts.
 *
 * Usage accounting matches pi's built-in footer exactly: assistant responses,
 * usage reported by tools, plus compaction/branch-summary generation, across the
 * whole session tree. That includes branches abandoned by a rewind or `/fork`,
 * since the tokens were really spent - and, for the line counts, it means edits
 * made on a since-abandoned branch keep counting too.
 *
 * Line counts follow claude's total_lines_added / total_lines_removed. Caveats:
 * `write` over an existing file counts the whole file as added (the previous
 * content is not in the session log), and edits made through `bash` (sed,
 * heredoc, ...) are not counted.
 *
 * The log is append-only, so each entry is inspected exactly once no matter how
 * often the footer re-renders - which matters here, because a running turn
 * re-renders every second and after every tool result. A shorter array than the
 * cursor means the session file was swapped underneath us, and the scan restarts.
 */
export class SessionScanner {
	readonly totals: SessionTotals = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0 };
	added = 0;
	removed = 0;
	private index = 0;
	/**
	 * toolCallId -> lines the pending `write` would add, because write results
	 * carry no details and the arguments live on the assistant message. Only the
	 * count is kept, never the arguments: a call whose result never arrives (an
	 * aborted turn) would otherwise pin its whole payload until session end.
	 * Not cleared at turn end either, since a scan may still be behind the log.
	 */
	private pendingWrites = new Map<string, number>();

	reset(): void {
		this.totals.input = 0;
		this.totals.output = 0;
		this.totals.cacheRead = 0;
		this.totals.cacheWrite = 0;
		this.totals.cost = 0;
		this.totals.cacheHitRate = undefined;
		this.added = 0;
		this.removed = 0;
		this.index = 0;
		this.pendingWrites.clear();
	}

	get hasChanges(): boolean {
		return this.added > 0 || this.removed > 0;
	}

	scan(entries: readonly SessionEntry[]): void {
		if (entries.length < this.index) this.reset();
		for (; this.index < entries.length; this.index++) {
			const entry = entries[this.index];

			if (entry.type === "compaction" || entry.type === "branch_summary") {
				this.addUsage(entry.usage);
				continue;
			}
			if (entry.type !== "message") continue;

			const role = asRole(entry.message);
			if (role === "assistant") {
				const message = entry.message as unknown as AssistantLike;
				this.addUsage(message.usage);
				this.noteCacheHitRate(message.usage);
				if (CONFIG.showLineDiff) this.rememberWrites(message);
			} else if (role === "toolResult") {
				const message = entry.message as unknown as ToolResultLike;
				this.addUsage(message.usage);
				if (CONFIG.showLineDiff) this.countToolResult(message);
			}
		}
	}

	private addUsage(usage: UsageLike | undefined): void {
		if (!usage) return;
		this.totals.input += usage.input;
		this.totals.output += usage.output;
		this.totals.cacheRead += usage.cacheRead;
		this.totals.cacheWrite += usage.cacheWrite;
		this.totals.cost += usage.cost.total;
	}

	/** Last assistant response wins, like the built-in footer's latestCacheHitRate. */
	private noteCacheHitRate(usage: UsageLike | undefined): void {
		if (!usage) return;
		const prompt = usage.input + usage.cacheRead + usage.cacheWrite;
		this.totals.cacheHitRate = prompt > 0 ? (usage.cacheRead / prompt) * 100 : undefined;
	}

	private rememberWrites(message: AssistantLike): void {
		for (const block of message.content ?? []) {
			const call = block as ToolCallLike | null;
			if (call?.type !== "toolCall" || typeof call.id !== "string") continue;
			const content = call.arguments?.content;
			if (typeof content === "string") this.pendingWrites.set(call.id, countLines(content));
		}
	}

	private countToolResult(message: ToolResultLike): void {
		const pendingLines = this.pendingWrites.get(message.toolCallId);
		this.pendingWrites.delete(message.toolCallId);
		if (message.isError) return;

		if (message.toolName === "edit") {
			const patch = message.details?.patch;
			if (!patch) return;
			for (const line of patch.split("\n")) {
				if (line.startsWith("+") && !line.startsWith("+++")) this.added++;
				else if (line.startsWith("-") && !line.startsWith("---")) this.removed++;
			}
		} else if (message.toolName === "write" && pendingLines !== undefined) {
			this.added += pendingLines;
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
		// A repository dirty enough to overflow the default 1 MB maxBuffer yields both
		// output and an error, so the output decides: an error with nothing on stdout
		// is "not a repository" (or git missing) and reads as clean, an error after a
		// truncated listing still means dirty.
		execFile("git", args, { timeout: 2000, maxBuffer: 4 * 1024 * 1024 }, (_error, stdout) => {
			this.running = false;
			const dirty = stdout.trim().length > 0;
			if (dirty === this.dirty) return;
			this.dirty = dirty;
			this.onChange();
		});
	}
}

// ---------------------------------------------------------------- persisted state

/**
 * State that must outlive a single extension instance.
 *
 * Kept on globalThis because pi re-imports this module and re-fires
 * `session_start` on `/reload`, and again on every session switch, fork or
 * `/new`. Without it both timers would restart and a footer the user turned off
 * would come back.
 */
interface StatuslineState {
	sessionId?: string;
	/** Wall-clock start: the first session entry's timestamp when known. */
	sessionStart: number;
	/** Accumulated time spent inside agent turns. */
	apiMs: number;
	/**
	 * Last explicit `/statusline` decision, or undefined while the user has made
	 * none. Not session-scoped: it is a preference, so it survives session
	 * switches (but not a pi restart).
	 */
	footerEnabled?: boolean;
}

const STATE_KEY = "__piStatuslineState";

function loadState(): StatuslineState {
	const globals = globalThis as Record<string, unknown>;
	let state = globals[STATE_KEY] as StatuslineState | undefined;
	if (!state) {
		state = { sessionStart: Date.now(), apiMs: 0 };
		globals[STATE_KEY] = state;
	}
	return state;
}

// ---------------------------------------------------------------- duration tracker

/** Tracks api time (sum of turns) and wall-clock time (since session start). */
class DurationTracker {
	private state = loadState();
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

/**
 * Auto-compaction flag, read straight from settings.json (project settings win).
 *
 * `trusted` mirrors pi's own gating: `SettingsManager` ignores project settings
 * entirely for an untrusted project, so honoring `.pi/settings.json` here would
 * show `(auto)` for a setting pi is not applying.
 */
export function readAutoCompactEnabled(cwd: string, trusted: boolean): boolean {
	const globalPath = join(getAgentDir(), "settings.json");
	const paths = trusted ? [join(cwd, ".pi", "settings.json"), globalPath] : [globalPath];
	for (const path of paths) {
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
		// A warn threshold above the error one would otherwise hide red entirely.
		const error = CONFIG.contextErrorPercent;
		const warn = Math.min(CONFIG.contextWarnPercent, error);
		const paint = level > error ? red : level > warn ? yellow : green;
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
	const state = loadState();

	const requestRender = () => tui?.requestRender();
	const scanner = new SessionScanner();
	const gitDirty = new GitDirtyTracker(requestRender);
	const durations = new DurationTracker();

	// Cached compaction.enabled, refreshed on session start / turn end.
	let autoCompact = true;
	/** Whether our footer is currently installed. */
	let installed = false;

	/** Replace pi's footer with ours. */
	function install(ctx: ExtensionContext): void {
		ctx.ui.setFooter((footerTui, _theme, footerData) => {
			tui = footerTui;
			const unsubscribe = footerData.onBranchChange(() => {
				gitDirty.invalidate();
				footerTui.requestRender();
			});

			return {
				dispose() {
					unsubscribe();
					if (tui === footerTui) tui = undefined;
				},
				invalidate() {},
				render(width: number): string[] {
					const entries = ctx.sessionManager.getEntries();
					scanner.scan(entries);

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
							diff: { added: scanner.added, removed: scanner.removed, hasChanges: scanner.hasChanges },
						}),
						buildStatsLine({
							model: ctx.model,
							thinkingLevel: ctx.thinkingLevel,
							totals: scanner.totals,
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
		// Nothing left to redraw once a second; api time keeps accruing regardless,
		// since it is measured from turn_start/turn_end rather than from the ticker.
		durations.dispose();
	}

	// ---------------------------------------------------------------- events

	pi.on("session_start", async (_event, ctx) => {
		const entries = ctx.sessionManager.getEntries();
		const firstTimestamp = entries[0]?.timestamp;
		// Resumed sessions keep their original wall-clock start; /reload keeps everything.
		durations.attach(ctx.sessionManager.getSessionId(), firstTimestamp ? Date.parse(firstTimestamp) : undefined);
		scanner.reset();
		gitDirty.invalidate();
		autoCompact = readAutoCompactEnabled(ctx.cwd, ctx.isProjectTrusted());
		// A session switch, fork or /reload rebinds this extension, so the user's last
		// explicit toggle decides here - falling back to the configured default.
		if ((state.footerEnabled ?? CONFIG.enabledByDefault) && ctx.mode === "tui") install(ctx);
	});

	pi.on("turn_start", async () => {
		durations.startTurn(requestRender);
	});

	pi.on("turn_end", async (_event, ctx) => {
		durations.endTurn();
		gitDirty.invalidate(); // files likely changed during the turn
		autoCompact = readAutoCompactEnabled(ctx.cwd, ctx.isProjectTrusted());
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
				state.footerEnabled = false;
				ctx.ui.notify("Built-in footer restored", "info");
				return;
			}
			autoCompact = readAutoCompactEnabled(ctx.cwd, ctx.isProjectTrusted());
			install(ctx);
			state.footerEnabled = true;
			ctx.ui.notify("Custom statusline enabled", "info");
		},
	});
}
