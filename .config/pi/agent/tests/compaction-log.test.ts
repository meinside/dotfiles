/**
 * compaction-log.ts's arithmetic and formatting.
 *
 * The extension exists to tell a "threshold" failure apart from an "overflow" one and
 * to say how much compression was being asked for, so the cases here are the ones that
 * would send a reader to the wrong fix: a budget capped by the model rather than by
 * reserveTokens, a summary that only just fit, an aborted attempt that proves nothing,
 * and an outcome that arrives with no attempt remembered. No compaction is triggered.
 */

import assert from "node:assert/strict";
import test from "node:test";
import {
	type Attempt,
	budgetOf,
	contentChars,
	deriveRecord,
	formatLog,
	parseExtensionFailure,
	parseLog,
	type Record_,
	summaryBudget,
	withAnnouncements,
} from "../extensions/compaction-log.ts";

const attempt = (over: Partial<Attempt> = {}): Attempt => ({
	startedAt: "2026-01-01T00:00:00.000Z",
	reason: "threshold",
	willRetry: false,
	isSplitTurn: false,
	tokensBefore: 200_000,
	reserveTokens: 16_384,
	keepRecentTokens: 20_000,
	enabled: true,
	spanMessages: 120,
	spanChars: 400_000,
	prefixMessages: 0,
	prefixChars: 0,
	hadCustomInstructions: false,
	model: { id: "m", name: "model", contextWindow: 1_000_000, maxTokens: 128_000, reasoning: true },
	...over,
});

test("the summary budget is the smaller of the reserve fraction and the model's own cap", () => {
	// 0.8 * 16384 = 13107, well under a 128k output cap: the reserve binds.
	assert.equal(summaryBudget(16_384, 128_000), 13_107);
	// A small free model's output cap binds instead, so raising reserveTokens buys nothing.
	assert.equal(summaryBudget(100_000, 8_192), 8_192);
	// A model that declares no cap leaves the reserve fraction alone.
	assert.equal(summaryBudget(24_576, 0), 19_660);
	assert.equal(summaryBudget(24_576, undefined), 19_660);
});

test("a threshold failure reports the compression that was asked for", () => {
	const r = deriveRecord(attempt(), { kind: "failed", errorMessage: "token cap", fromExtension: false }, "t1");
	// 400,000 chars / 4 = 100,000 est tokens against a 13,107 budget.
	assert.equal(r.spanTokensEst, 100_000);
	assert.equal(r.summaryBudget, 13_107);
	assert.equal(r.compressionRatio, 7.63);
	assert.equal(r.outcome, "failed");
	assert.equal(r.errorMessage, "token cap");
	assert.equal(r.budgetUsed, undefined, "a failure has no summary to measure");
});

test("an overflow failure is named as one, because it implies a different fix", () => {
	const r = deriveRecord(
		attempt({ reason: "overflow", willRetry: true, spanChars: 4_000_000 }),
		{ kind: "failed", fromExtension: false },
		"t1",
	);
	assert.match(r.verdict, /overflow recovery/);
	assert.match(r.verdict, /never fit/);
	assert.match(r.verdict, /1,?000,?000|1000000/, "the declared window belongs in the verdict");
});

test("a high ratio on a threshold failure points at the budget, not at the model", () => {
	const r = deriveRecord(attempt({ spanChars: 4_000_000 }), { kind: "failed", fromExtension: false }, "t1");
	assert.ok(r.compressionRatio > 12, `expected a high ratio, got ${r.compressionRatio}`);
	assert.match(r.verdict, /budget or the window/);
});

test("a rewritten earlier summary is called out, since updating grows it", () => {
	const r = deriveRecord(
		attempt({ spanChars: 100_000, previousSummaryChars: 48_000 }),
		{ kind: "failed", fromExtension: false },
		"t1",
	);
	assert.ok(r.compressionRatio <= 12, "this case is only reached below the high-ratio rule");
	assert.match(r.verdict, /earlier summary of 48000 chars/);
});

test("a success records how much of the budget it used", () => {
	const r = deriveRecord(attempt(), { kind: "ok", summaryChars: 50_000, fromExtension: false }, "t1");
	// 50,000 chars / 4 = 12,500 tokens of a 13,107 budget.
	assert.equal(r.budgetUsed, 0.95);
	assert.match(r.verdict, /used 95%/, "a summary that only just fit is the warning before the failure");

	const roomy = deriveRecord(attempt(), { kind: "ok", summaryChars: 8_000, fromExtension: false }, "t1");
	assert.equal(roomy.budgetUsed, 0.15);
	assert.match(roomy.verdict, /fit in 15%/);
});

test("a split turn's prefix runs under half the reserve, so it is measured separately", () => {
	// The measured failure that prompted this: a manual compaction at 576,801 tokens with
	// isSplitTurn true, where only the main summary was instrumented and the prefix was
	// invisible. Half the reserve is the tighter cap, so it can fail while the main ratio
	// still looks survivable.
	assert.equal(budgetOf(0.5, 16_384, 128_000), 8_192);
	assert.equal(summaryBudget(16_384, 128_000), 13_107);

	const r = deriveRecord(
		attempt({ isSplitTurn: true, spanChars: 100_000, prefixMessages: 40, prefixChars: 600_000 }),
		{ kind: "failed", fromExtension: false },
		"t1",
	);
	assert.equal(r.prefixBudget, 8_192);
	assert.equal(r.prefixTokensEst, 150_000);
	assert.equal(r.compressionRatio, 1.91, "the main summary looks comfortable on its own");
	assert.ok(r.prefixRatio > r.compressionRatio);
	assert.match(r.verdict, /split turn: its prefix asks/);
	assert.match(formatLog([r]), /split turn prefix ~150000 tok in 40 msg -> budget 8192/);
});

test("a turn boundary cut has no prefix and is not described as a split", () => {
	const r = deriveRecord(attempt({ spanChars: 4_000_000 }), { kind: "failed", fromExtension: false }, "t1");
	assert.equal(r.prefixTokensEst, 0);
	assert.equal(r.prefixRatio, 0);
	assert.ok(!r.verdict.includes("split turn"));
	assert.ok(!formatLog([r]).includes("split turn prefix"));
});

test("what the estimate cannot see is reported instead of being absorbed into the ratio", () => {
	// pi counted 576,801 tokens where this file could account for far less. The remainder
	// is the system prompt, the tool schemas, images and charsPerToken error; hiding it
	// would make the ratios look authoritative.
	const r = deriveRecord(
		attempt({ tokensBefore: 576_801, spanChars: 725_522, keepRecentTokens: 20_000 }),
		{ kind: "failed", fromExtension: false },
		"t1",
	);
	assert.equal(r.spanTokensEst, 181_381);
	assert.equal(r.unaccountedTokensEst, 576_801 - 181_381 - 20_000);
	assert.match(formatLog([r]), /unaccounted ~375420 tok/);
});

test("an over-accounted context cannot report a negative remainder", () => {
	const r = deriveRecord(
		attempt({ tokensBefore: 1_000, spanChars: 400_000, keepRecentTokens: 20_000 }),
		{ kind: "failed", fromExtension: false },
		"t1",
	);
	assert.equal(r.unaccountedTokensEst, 0);
});

test("an aborted attempt concludes nothing", () => {
	const r = deriveRecord(attempt(), { kind: "aborted", fromExtension: false }, "t1");
	assert.equal(r.outcome, "aborted");
	assert.match(r.verdict, /nothing to conclude/);
});

test("a zero budget cannot become a division by zero", () => {
	const r = deriveRecord(
		attempt({ reserveTokens: 0, model: { id: "m", name: "m", contextWindow: 1000, maxTokens: 0, reasoning: false } }),
		{ kind: "failed", fromExtension: false },
		"t1",
	);
	assert.equal(r.summaryBudget, 0);
	assert.equal(r.compressionRatio, 0);
	assert.ok(Number.isFinite(r.compressionRatio));
});

test("content chars counts text and thinking, and does not skip unknown blocks", () => {
	assert.equal(contentChars([{ content: "abcd" }]), 4);
	assert.equal(contentChars([{ content: [{ type: "text", text: "abc" }, { type: "thinking", thinking: "de" }] }]), 5);
	// A tool call has no text field; counting its JSON keeps a tool-heavy span from
	// looking empty, which would understate the ratio.
	assert.ok(contentChars([{ content: [{ type: "toolCall", name: "read" }] }]) > 0);
	assert.equal(contentChars([{}, { content: undefined }]), 0);
});

test("a truncated log line does not cost the readable ones", () => {
	const good = JSON.stringify({ outcome: "ok", reason: "threshold" });
	const records = parseLog(`${good}\n{"outcome":"fai\n${good}\n\n`);
	assert.equal(records.length, 2);
});

test("an entry written before a field existed prints what it has, not undefined", () => {
	// The append-only log outlives its schema: the first recorded failure predates the
	// prefix and unaccounted fields, and printing `undefined` for them read like a fault in
	// the run being diagnosed. Substituting 0 would be worse - a measurement nobody took.
	const old = {
		startedAt: "2026-09-19T02:45:43.875Z",
		reason: "manual",
		willRetry: false,
		isSplitTurn: true,
		tokensBefore: 576_801,
		reserveTokens: 16_384,
		keepRecentTokens: 20_000,
		enabled: true,
		spanMessages: 427,
		spanChars: 725_522,
		hadCustomInstructions: false,
		model: { id: "m", name: "m", contextWindow: 1_000_000, maxTokens: 128_000, reasoning: true },
		finishedAt: "x",
		outcome: "failed",
		fromExtension: false,
		summaryBudget: 13_107,
		spanTokensEst: 181_381,
		compressionRatio: 13.84,
		verdict: "13.8:1 compression asked of a 13107 token budget",
	} as unknown as Record_;

	const out = formatLog([old]);
	assert.ok(!out.includes("undefined"), `no field may print as undefined:\n${out}`);
	assert.match(out, /split turn, prefix not recorded \(entry predates that field\)/);
	assert.ok(!out.includes("unaccounted"), "a number nobody recorded gets no line at all");
	assert.match(out, /span ~181381 tok in 427 msg -> budget 13107/, "what it does have still prints");
});

test("a budget announced by a handler replaces the one derived from settings", () => {
	// compaction-summary.ts hands pi's summarizer a larger reserve for one call, so the
	// settings-derived 13107 describes a request that was never made: reporting a summary
	// as 95% of it would be wrong by the factor the handler chose.
	const r = deriveRecord(
		attempt({ suppliedBudget: 65_536 }),
		{ kind: "ok", summaryChars: 30_758, fromExtension: true },
		"t1",
	);
	assert.equal(r.summaryBudget, 65_536, "not the 13107 that settings imply");
	assert.equal(r.budgetUsed, 0.12, "7,689 tokens of 65,536");
	assert.equal(r.compressionRatio, 1.53);
	assert.match(formatLog([r]), /budget 65536 \(supplied by an extension\)/);

	// Without the announcement the settings-derived cap is still the honest answer.
	const own = deriveRecord(attempt(), { kind: "ok", summaryChars: 30_758, fromExtension: false }, "t1");
	assert.equal(own.summaryBudget, 13_107);
	assert.ok(!formatLog([own]).includes("supplied by an extension"));
});

test("a budget from an extension that failed is not the budget pi's fallback had", () => {
	// The 2026-09-22 failures: compaction-summary.ts announced 26,214, gave up, and pi's
	// own compaction then hit its 13,107 cap. Logging 26,214 put the ratio at 14.4:1 against
	// a request that never produced the error, and dropped the extension's own reason.
	const ann = { budget: 26_214, extensionFailure: { message: "generation hit the token cap", elapsedMs: 312_400 } };
	const failed = { kind: "failed", errorMessage: "token cap", fromExtension: false } as const;
	const r = deriveRecord(withAnnouncements(attempt({ spanChars: 1_508_017 }), ann, false), failed, "t1");
	assert.equal(r.suppliedBudget, undefined);
	assert.equal(r.summaryBudget, 13_107, "pi's own cap, the one the logged error came from");
	assert.equal(r.compressionRatio, 28.76);
	assert.equal(r.extensionBudget, 26_214);
	assert.match(r.verdict, /28\.8:1 .* 13107 .*; the extension's 26214 token attempt had failed first$/);
	assert.doesNotMatch(r.verdict, /generation hit/, "the reason has its own line; the verdict does not repeat it");
	assert.match(formatLog([r]), /extension failed after 312s under a 26214 token budget: .*; pi's compaction ran/);

	// When the extension's summary is the one kept, its budget is the summary's budget.
	const ok = deriveRecord(
		withAnnouncements(attempt(), { budget: 26_214 }, true),
		{ kind: "ok", summaryChars: 20_000, fromExtension: true },
		"t1",
	);
	assert.equal(ok.summaryBudget, 26_214);
	assert.equal(ok.extensionBudget, undefined);
	assert.ok(!formatLog([ok]).includes("pi's compaction ran"));

	// A fallback that succeeded keeps the extension's reason, and its verdict stays about the fit.
	const rescued = deriveRecord(
		withAnnouncements(attempt(), ann, false),
		{ kind: "ok", summaryChars: 20_000, fromExtension: false },
		"t1",
	);
	assert.equal(rescued.summaryBudget, 13_107);
	assert.match(rescued.verdict, /^fit in/);
	assert.match(formatLog([rescued]), /extension failed after 312s/);
});

test("an extension failure announcement is validated, not trusted", () => {
	assert.deepEqual(parseExtensionFailure({ message: " boom ", elapsedMs: 1234.6 }), { message: "boom", elapsedMs: 1235 });
	assert.deepEqual(parseExtensionFailure({ message: "no clock" }), { message: "no clock" });
	assert.deepEqual(parseExtensionFailure({ message: "bad clock", elapsedMs: -1 }), { message: "bad clock" });
	for (const junk of [undefined, null, "text", 3, {}, { message: "" }, { message: "  " }, { message: 7 }]) {
		assert.equal(parseExtensionFailure(junk), undefined, `accepted ${JSON.stringify(junk)}`);
	}
	assert.equal(parseExtensionFailure({ message: "x".repeat(1000) })?.message.length, 300);
});

test("an early trigger says so instead of reading as a /compact nobody typed", () => {
	// compaction-summary.ts enters through the manual path when the ratio ceiling fires, so
	// `reason` is "manual" and the log would misattribute it to the user.
	const early = deriveRecord(
		attempt({ reason: "manual", triggeredBy: "ratio ceiling 92%" }),
		{ kind: "ok", summaryChars: 30_758, fromExtension: true },
		"t1",
	);
	assert.match(formatLog([early]), /manual \(ratio ceiling 92%\)/);

	// A real /compact carries no label, and gets no parenthesis.
	const typed = deriveRecord(attempt({ reason: "manual" }), { kind: "ok", summaryChars: 10, fromExtension: false }, "t1");
	assert.doesNotMatch(formatLog([typed]), /manual \(/);
});

test("an empty log says so instead of printing an empty table", () => {
	assert.match(formatLog([]), /No compaction has been attempted/);
});

test("the listing shows the fields a fix depends on", () => {
	const r = deriveRecord(attempt({ reason: "overflow" }), { kind: "failed", fromExtension: false }, "t1");
	const out = formatLog([r]);
	assert.match(out, /FAIL/);
	assert.match(out, /overflow/);
	assert.match(out, /context 200000 \/ window 1000000/);
	assert.match(out, /reserve 16384/);
	assert.match(out, /budget 13107/);
});

test("only the last N attempts are shown, newest last", () => {
	const many: Record_[] = Array.from({ length: 5 }, (_, i) =>
		deriveRecord(attempt({ startedAt: `t${i}` }), { kind: "ok", summaryChars: 100, fromExtension: false }, "x"),
	);
	const out = formatLog(many, 2);
	assert.match(out, /5 attempt\(s\) recorded/);
	assert.ok(!out.includes("t2"), "older attempts stay in the file, not in the listing");
	assert.ok(out.includes("t3") && out.includes("t4"));
});
