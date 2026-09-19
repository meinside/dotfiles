/**
 * extensions/statusline.ts is the one extension here with real logic of its own:
 * it re-derives, from the raw session log, what pi's built-in footer computes
 * internally (token totals, cost, cache hit rate) plus counters pi does not have
 * (added/removed lines, api/wall durations). None of that is covered by pi's own
 * tests, and a wrong number in a footer is the kind of thing one reads for weeks
 * without noticing, so the accounting and the formatters are pinned here.
 *
 * Unlike guard.ts, this extension has *runtime* imports of pi's packages
 * (`getAgentDir`, `truncateToWidth`), which do not resolve from this config
 * directory — pi resolves them against its own installation. So the module is
 * imported dynamically behind tests/lib.ts's `redirectPiImports()`, which points those
 * specifiers at the pi installation the other checks already locate.
 */

import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { redirectPiImports } from "./lib.ts";

redirectPiImports();

// Dynamic, so the hook above is installed before the module's own imports run.
const statusline = await import(join(dirname(import.meta.dirname), "extensions/statusline.ts"));

const {
	formatTokens,
	formatDuration,
	shortenPath,
	formatModel,
	sanitizeStatus,
	SessionScanner,
	readAutoCompactEnabled,
} = statusline as {
	formatTokens: (count: number) => string;
	formatDuration: (ms: number) => string;
	shortenPath: (path: string) => string;
	formatModel: (model: { id: string; name?: string } | undefined) => string;
	sanitizeStatus: (text: string) => string;
	SessionScanner: new () => {
		readonly totals: {
			input: number;
			output: number;
			cacheRead: number;
			cacheWrite: number;
			cost: number;
			cacheHitRate?: number;
		};
		added: number;
		removed: number;
		readonly hasChanges: boolean;
		reset(): void;
		scan(entries: readonly unknown[]): void;
	};
	readAutoCompactEnabled: (cwd: string, trusted: boolean) => boolean;
};

// ---------------------------------------------------------------- formatters

test("token counts use the same thresholds as pi's own footer", () => {
	assert.equal(formatTokens(0), "0");
	assert.equal(formatTokens(999), "999");
	assert.equal(formatTokens(2500), "2.5k");
	assert.equal(formatTokens(43_210), "43k");
	assert.equal(formatTokens(1_040_000), "1.0M");
	assert.equal(formatTokens(12_400_000), "12M");
});

test("durations stay two-component and zero-padded", () => {
	assert.equal(formatDuration(42_000), "42s");
	assert.equal(formatDuration(62_000), "1m02s");
	assert.equal(formatDuration(7_500_000), "2h05m");
});

test("paths under home are abbreviated, paths outside are not", () => {
	const home = process.env.HOME as string;
	assert.equal(shortenPath(home), "~");
	assert.equal(shortenPath(join(home, "src/pi")), "~/src/pi");
	assert.equal(shortenPath("/usr/local/lib"), "/usr/local/lib");
});

test("ARN model ids fall back to the configured name", () => {
	assert.equal(formatModel({ id: "claude-sonnet-4-5" }), "claude-sonnet-4-5");
	assert.equal(formatModel({ id: "claude-sonnet-4-5", name: "Sonnet" }), "claude-sonnet-4-5");
	assert.equal(formatModel({ id: "arn:aws:bedrock:eu-north-1:1234:x", name: "Sonnet" }), "Sonnet");
	assert.equal(formatModel(undefined), "no-model");
});

test("extension statuses are collapsed to a single line", () => {
	assert.equal(sanitizeStatus("  two\nlines\tand   gaps "), "two lines and gaps");
});

// ---------------------------------------------------------------- session scan

const usage = (over: Partial<Record<"input" | "output" | "cacheRead" | "cacheWrite" | "cost", number>> = {}) => ({
	input: over.input ?? 0,
	output: over.output ?? 0,
	cacheRead: over.cacheRead ?? 0,
	cacheWrite: over.cacheWrite ?? 0,
	cost: { total: over.cost ?? 0 },
});

const assistant = (over: Record<string, unknown> = {}) => ({
	type: "message" as const,
	message: { role: "assistant", content: [], usage: usage(), ...over },
});

const toolResult = (over: Record<string, unknown>) => ({
	type: "message" as const,
	message: { role: "toolResult", isError: false, ...over },
});

const writeCall = (id: string, content: string) =>
	assistant({ content: [{ type: "toolCall", id, name: "write", arguments: { path: "f.txt", content } }] });

test("totals cover assistant, tool and compaction usage", () => {
	const scanner = new SessionScanner();
	scanner.scan([
		assistant({ usage: usage({ input: 10, output: 5, cacheRead: 90, cacheWrite: 0, cost: 0.1 }) }),
		toolResult({ toolName: "task", toolCallId: "t1", usage: usage({ input: 3, output: 1, cost: 0.02 }) }),
		{ type: "compaction", usage: usage({ input: 7, output: 2, cost: 0.03 }) },
		{ type: "user_message_placeholder" },
	]);

	assert.equal(scanner.totals.input, 20);
	assert.equal(scanner.totals.output, 8);
	assert.equal(scanner.totals.cacheRead, 90);
	assert.equal(scanner.totals.cost.toFixed(2), "0.15");
});

test("cache hit rate reflects the latest assistant response only", () => {
	const scanner = new SessionScanner();
	scanner.scan([
		assistant({ usage: usage({ input: 100, cacheRead: 0 }) }),
		assistant({ usage: usage({ input: 10, cacheRead: 90 }) }),
	]);
	assert.equal(scanner.totals.cacheHitRate?.toFixed(1), "90.0");
});

test("scanning incrementally matches scanning everything at once", () => {
	const entries = [
		assistant({ usage: usage({ input: 5, cacheRead: 5, cost: 0.01 }) }),
		writeCall("w1", "a\nb\n"),
		toolResult({ toolName: "write", toolCallId: "w1" }),
		assistant({ usage: usage({ input: 1, output: 2, cost: 0.02 }) }),
	];

	const incremental = new SessionScanner();
	for (let i = 1; i <= entries.length; i++) incremental.scan(entries.slice(0, i));
	const once = new SessionScanner();
	once.scan(entries);

	assert.deepEqual(incremental.totals, once.totals);
	assert.equal(incremental.added, once.added);
	assert.equal(incremental.removed, once.removed);
});

test("a shorter log than the cursor restarts the scan instead of skipping it", () => {
	const scanner = new SessionScanner();
	scanner.scan([assistant({ usage: usage({ input: 10, cost: 0.5 }) }), assistant({ usage: usage({ input: 10 }) })]);
	assert.equal(scanner.totals.input, 20);

	// A different, shorter session file (a switch or a fork) replaces the log.
	scanner.scan([assistant({ usage: usage({ input: 3, cost: 0.1 }) })]);
	assert.equal(scanner.totals.input, 3);
	assert.equal(scanner.totals.cost, 0.1);
});

test("write counts content lines, not split() elements", () => {
	const trailing = new SessionScanner();
	trailing.scan([writeCall("w1", "a\nb\n"), toolResult({ toolName: "write", toolCallId: "w1" })]);
	assert.equal(trailing.added, 2);

	const noTrailing = new SessionScanner();
	noTrailing.scan([writeCall("w2", "a\nb"), toolResult({ toolName: "write", toolCallId: "w2" })]);
	assert.equal(noTrailing.added, 2);

	const empty = new SessionScanner();
	empty.scan([writeCall("w3", ""), toolResult({ toolName: "write", toolCallId: "w3" })]);
	assert.equal(empty.added, 0);
	assert.equal(empty.hasChanges, false);
});

test("edit counts patch lines and ignores the file headers", () => {
	const patch = ["--- a/f.txt", "+++ b/f.txt", "@@ -1,2 +1,3 @@", " keep", "-old", "+new", "+extra"].join("\n");
	const scanner = new SessionScanner();
	scanner.scan([
		assistant({ content: [{ type: "toolCall", id: "e1", name: "edit", arguments: {} }] }),
		toolResult({ toolName: "edit", toolCallId: "e1", details: { patch } }),
	]);
	assert.equal(scanner.added, 2);
	assert.equal(scanner.removed, 1);
});

test("failed edits and writes change no counters", () => {
	const scanner = new SessionScanner();
	scanner.scan([
		writeCall("w1", "a\nb\n"),
		toolResult({ toolName: "write", toolCallId: "w1", isError: true }),
		toolResult({ toolName: "edit", toolCallId: "e1", isError: true, details: { patch: "+x\n-y" } }),
	]);
	assert.equal(scanner.hasChanges, false);
});

test("reset clears totals, counters and pending write calls", () => {
	const scanner = new SessionScanner();
	scanner.scan([writeCall("w1", "a\n"), toolResult({ toolName: "write", toolCallId: "w1" })]);
	scanner.reset();
	assert.equal(scanner.added, 0);
	assert.equal(scanner.totals.cacheHitRate, undefined);

	// The pending map is empty too, so a stale result counts nothing.
	scanner.scan([toolResult({ toolName: "write", toolCallId: "w1" })]);
	assert.equal(scanner.added, 0);
});

// ---------------------------------------------------------------- settings

test("project settings are honoured only for a trusted project", () => {
	// $TMPDIR can name a directory that nothing has created yet — a session inheriting
	// TMPDIR=/tmp/<something> from whatever launched it makes mkdtemp fail with ENOENT
	// and this check die for a reason that has nothing to do with what it asserts.
	mkdirSync(tmpdir(), { recursive: true });
	const cwd = mkdtempSync(join(tmpdir(), "pi-statusline-"));
	mkdirSync(join(cwd, ".pi"));
	writeFileSync(join(cwd, ".pi", "settings.json"), JSON.stringify({ compaction: { enabled: false } }));
	const bare = mkdtempSync(join(tmpdir(), "pi-statusline-bare-"));

	// Trusted: the project file wins, exactly as SettingsManager would apply it.
	assert.equal(readAutoCompactEnabled(cwd, true), false);
	// Untrusted: pi ignores project settings entirely, so the footer must too and
	// fall back to whatever the global settings say for a project without a file.
	assert.equal(readAutoCompactEnabled(cwd, false), readAutoCompactEnabled(bare, true));
});
