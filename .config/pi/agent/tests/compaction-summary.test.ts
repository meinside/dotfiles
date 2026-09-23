/**
 * compaction-summary.ts decides whether to take over a compaction and what to hand back.
 *
 * The measured failure it exists for came from `min(0.8 * reserveTokens, maxTokens)`
 * being 13,107 while the model overshot it, so the cases pinned here are the ones where
 * taking over would be wrong or harmful: a model whose own output cap makes the larger
 * reserve meaningless (identical request, new way to fail), an empty summary (a
 * checkpoint that discards the conversation for nothing), and a split turn whose prefix
 * must end up inside the one summary rather than under pi's smaller separate cap.
 *
 * Like statusline.ts, this extension imports pi's package at *runtime*, so the module is
 * loaded behind tests/lib.ts's `redirectPiImports()`. No compaction and no provider call
 * happens here.
 */

import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { redirectPiImports } from "./lib.ts";

redirectPiImports();

// Dynamic, so the hook above is installed before the module's own imports run.
const mod = await import(join(dirname(import.meta.dirname), "extensions/compaction-summary.ts"));

const { budgetFor, improvesBudget, messagesFor, compactionFrom, describeAttempt, progressText, readFileConfig, triggerAt, shouldTriggerEarly, failureAnnouncement } =
	mod as {
		failureAnnouncement: (message: string, elapsedMs?: number) => { message: string; elapsedMs?: number };
		budgetFor: (reserveTokens: number, modelMaxTokens: number | undefined) => number;
		improvesBudget: (
			model: { id: string; maxTokens: number } | undefined,
			reserveTokens: number,
			defaultReserve: number,
		) => boolean;
		messagesFor: <T>(prep: { messagesToSummarize: T[]; turnPrefixMessages: T[] }) => T[];
		compactionFrom: <U>(
			prep: { firstKeptEntryId: string; tokensBefore: number },
			summary: string,
			usage: U,
		) => { compaction: { summary: string; firstKeptEntryId: string; tokensBefore: number; usage: U } } | undefined;
		describeAttempt: (
			model: { id: string; name?: string; maxTokens: number },
			count: number,
			budget: number,
		) => string;
		progressText: (elapsedMs: number, messageCount: number) => string;
		readFileConfig: (path: string) => { reserveTokens?: number; summarizerModel?: { provider: string; id: string }; triggerRatio?: number };
		triggerAt: (contextWindow: number, reserveTokens: number, ratio: number) => number;
		shouldTriggerEarly: (
			usage: { tokens: number | null; contextWindow: number } | undefined,
			reserveTokens: number,
			ratio: number,
		) => boolean;
	};

test("the budget mirrors pi's own sizing, including the model's cap", () => {
	// The measured failure: pi's default reserve against a 128k output cap.
	assert.equal(budgetFor(16_384, 128_000), 13_107);
	// What this extension asks for instead: 3.4x the 7,689 a real summary needed, not the
	// 8.5x of the first cut, because a larger cap also licenses a slower answer.
	assert.equal(budgetFor(32_768, 128_000), 26_214);
	// A small free model's output cap binds, and no reserve can lift it.
	assert.equal(budgetFor(32_768, 8_192), 8_192);
	// A model declaring no cap keeps the fraction.
	assert.equal(budgetFor(32_768, 0), 26_214);
	assert.equal(budgetFor(32_768, undefined), 26_214);
});

test("a model whose output cap already binds is left to pi", () => {
	// 0.8 * 16384 = 13107 > 8192, so pi and this file would send the same maxTokens.
	// Taking over would add a second way to fail and no extra room.
	assert.equal(improvesBudget({ id: "small", maxTokens: 8_192 }, 32_768, 16_384), false);
	assert.equal(improvesBudget({ id: "exact", maxTokens: 13_107 }, 32_768, 16_384), false);
	assert.equal(improvesBudget({ id: "big", maxTokens: 128_000 }, 32_768, 16_384), true);
	assert.equal(improvesBudget({ id: "mid", maxTokens: 20_000 }, 32_768, 16_384), true);
	assert.equal(improvesBudget(undefined, 32_768, 16_384), false, "no model means nothing to improve");
});

test("the progress line answers the question that cancelled a working call", () => {
	// A compaction was aborted at 206 s because nothing on screen distinguished a long call
	// from a hung one. What it needed was the live facts and a warning, not a duration: see
	// `progressText` for why no figure is predicted here.
	const line = progressText(206_000, 205);
	assert.match(line, /205 msg/);
	assert.match(line, /206s/);
	assert.match(line, /takes minutes/, "a qualitative warning survives a model change; a measured figure would not");
	assert.deepEqual(line.match(/\d+s\b/g), ["206s"], "the only duration shown is the live clock");
	assert.match(progressText(0, 1), /0s/, "the clock starts before the first tick");
});

test("an unreadable or malformed config file leaves the defaults in place", () => {
	// An optional file's typo must not disable compaction.
	assert.deepEqual(readFileConfig(join(tmpdir(), "compaction-summary-does-not-exist.json")), {});

	const dir = mkdtempSync(join(tmpdir(), "compaction-summary-"));
	const write = (body: string) => {
		const path = join(dir, `${Math.random().toString(36).slice(2)}.json`);
		writeFileSync(path, body, "utf8");
		return path;
	};
	assert.deepEqual(readFileConfig(write("{ not json")), {});
	assert.deepEqual(readFileConfig(write('{"reserveTokens": "lots"}')), {}, "a wrong type is not a value");
	assert.deepEqual(readFileConfig(write('{"reserveTokens": -5}')), {});
	assert.deepEqual(readFileConfig(write('{"summarizerModel": {"provider": "p"}}')), {}, "half a model is none");
	assert.deepEqual(readFileConfig(write('{"triggerRatio": 0}')), {}, "a ratio of zero is not a way to disable");
	assert.deepEqual(readFileConfig(write('{"triggerRatio": 1}')), { triggerRatio: 1 }, "1 disables the ceiling");
	assert.deepEqual(readFileConfig(write('{"reserveTokens": 49152, "summarizerModel": {"provider": "p", "id": "i"}}')), {
		reserveTokens: 49_152,
		summarizerModel: { provider: "p", id: "i" },
	});
});

test("a split turn's prefix goes into the same summary, in order", () => {
	// pi summarizes the prefix separately under half the budget; folding it in means that
	// smaller cap never applies.
	const out = messagesFor({ messagesToSummarize: ["a", "b"], turnPrefixMessages: ["c"] });
	assert.deepEqual(out, ["a", "b", "c"]);
	assert.deepEqual(messagesFor({ messagesToSummarize: [], turnPrefixMessages: [] }), []);
});

test("the ratio ceiling is a ceiling, and only binds where pi's absolute margin is thin", () => {
	const R = 16_384;
	// Above the crossover the ratio wins: a 1M window stops at 92% instead of 98.4%, which
	// is 80,000 tokens of headroom instead of 16,384.
	assert.equal(triggerAt(1_000_000, R, 0.92), 920_000);
	assert.equal(triggerAt(1_048_576, R, 0.92), 964_689);
	// The crossover, `reserveTokens / (1 - ratio)`: both rules give the same point, so no
	// window is affected twice.
	assert.equal(triggerAt(204_800, R, 0.92), 188_416);
	assert.equal(204_800 - R, Math.floor(0.92 * 204_800));
	// Below it pi's margin is already the earlier of the two and nothing changes. A flat
	// 92% here would be a regression: 0.92 * 65,536 leaves 5,243 tokens, under one turn.
	assert.equal(triggerAt(200_000, R, 0.92), 183_616);
	assert.equal(triggerAt(131_072, R, 0.92), 114_688);
	assert.equal(triggerAt(65_536, R, 0.92), 49_152);
	// A ratio of 1 or more disables the ceiling; so does a nonsensical one.
	assert.equal(triggerAt(1_000_000, R, 1), 983_616);
	assert.equal(triggerAt(1_000_000, R, 0), 983_616);
	assert.equal(triggerAt(1_000_000, R, Number.NaN), 983_616);
});

test("an unmeasured context is not an over-full one", () => {
	const over = { tokens: 950_000, contextWindow: 1_000_000 };
	assert.equal(shouldTriggerEarly(over, 16_384, 0.92), true);
	assert.equal(shouldTriggerEarly({ tokens: 900_000, contextWindow: 1_000_000 }, 16_384, 0.92), false);
	// Right after a compaction pi reports null until the next response measures the window.
	// Treating that as over would compact again immediately, on nothing.
	assert.equal(shouldTriggerEarly({ tokens: null, contextWindow: 1_000_000 }, 16_384, 0.92), false);
	assert.equal(shouldTriggerEarly(undefined, 16_384, 0.92), false);
	assert.equal(shouldTriggerEarly({ tokens: 950_000, contextWindow: 0 }, 16_384, 0.92), false, "no window, no ratio");
	assert.equal(shouldTriggerEarly(over, 16_384, 1), false, "disabled leaves the decision to pi");
});

test("an empty summary never becomes a checkpoint", () => {
	const prep = { firstKeptEntryId: "entry-9", tokensBefore: 576_801 };
	assert.equal(compactionFrom(prep, "", { in: 1 }), undefined);
	assert.equal(compactionFrom(prep, "   \n\t ", { in: 1 }), undefined);
});

test("a real summary is handed back with the cut point and the count pi asked for", () => {
	const prep = { firstKeptEntryId: "entry-9", tokensBefore: 576_801 };
	const usage = { input: 181_000, output: 7_689 };
	const result = compactionFrom(prep, "## Goal\n...", usage);
	assert.deepEqual(result, {
		compaction: {
			summary: "## Goal\n...",
			firstKeptEntryId: "entry-9",
			tokensBefore: 576_801,
			usage,
		},
	});
});

test("the notice names the model and the budget, which is what a wrong summary raises", () => {
	const line = describeAttempt({ id: "arn:aws:...:profile/x", name: "tier:strong", maxTokens: 128_000 }, 427, 65_536);
	assert.match(line, /427 messages/);
	assert.match(line, /tier:strong/);
	assert.match(line, /budget 65536 tokens/);
	assert.ok(!line.includes("arn:"), "the configured name is what a reader recognises");
});

test("a failed attempt is announced in the shape compaction-log.ts accepts", async () => {
	// The two files only share a bus, so a renamed field would drop the reason silently.
	const { parseExtensionFailure } = await import(join(dirname(import.meta.dirname), "extensions/compaction-log.ts"));
	assert.deepEqual(parseExtensionFailure(failureAnnouncement("token cap", 312_400)), { message: "token cap", elapsedMs: 312_400 });
	assert.deepEqual(parseExtensionFailure(failureAnnouncement("no key")), { message: "no key" });
});
