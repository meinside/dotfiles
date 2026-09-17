/**
 * `extensions/magpi-render.ts` drives a browser, so most of it cannot be unit tested.
 * What can be, and is here, are the decisions that made the difference between a run
 * that returned the catalogue page's 11 tables and one that returned a 2,767-character fragment
 * while reporting success:
 *
 *   - the settle rule (all five conditions, and the cap)
 *   - which extractor wins for a frame, given coverage and tables
 *   - the coverage yardstick, which cannot exceed 1 by construction
 *   - why an empty render is empty (login wall / bot check / nothing)
 *   - the same-site heuristic that decides whether a response resets the idle timer
 *   - browser discovery, and that a machine without Firefox registers nothing at all
 *   - the hand-rolled WebSocket framing, because a proxy-honouring global WebSocket
 *     could not reach a loopback BiDi socket on this machine
 *
 * No browser is launched and no network is touched.
 */

import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import * as renderModule from "../extensions/magpi-render.ts";

const {
	TUNING,
	registrableDomain,
	isContentBearing,
	shouldSettle,
	coverageOf,
	chooseExtractor,
	toFrameResult,
	assembleMarkdown,
	classifyEmpty,
	findBrowser,
	browserLookup,
	learnedStorePath,
	loadLearned,
	saveLearned,
	learnHost,
	hostMatchesPattern,
	shouldRenderHost,
	isThinFetch,
	thinNote,
	configPaths,
	loadConfig,
	readabilityPath,
	renderArtifactPath,
	RawWebSocket,
} = renderModule as typeof import("../extensions/magpi-render.ts");

/** Type stripping leaves the CJS default nested one level deeper (as in guard.test.ts). */
const entry = (renderModule as { default?: unknown }).default;
const activate = (typeof entry === "function" ? entry : (entry as { default?: unknown })?.default) as (pi: unknown) => Promise<void>;

const frame = (over: Partial<Parameters<typeof chooseExtractor>[0]> = {}) => ({
	url: "https://example.com/",
	depth: 0,
	markdown: "# Title\n\nbody",
	plainLen: 100,
	visibleLen: 100,
	tables: 0,
	structured: [],
	og: {},
	...over,
});

// ---------------------------------------------------------------- tuning invariants

test("the tuning block holds together", () => {
	const s = TUNING.settle;
	assert.ok(s.minWaitMs < s.maxWaitMs, "a minimum longer than the cap can never settle");
	assert.ok(s.pollMs > 0 && s.stableRounds >= 2, "one stable poll is not a plateau check");
	assert.ok(
		s.stableRounds * s.pollMs >= 1_400,
		"the stability window must exceed the 1.4 s mid-load pause measured on the catalogue page",
	);
	assert.ok(s.confirmMs > 0, "the confirm pass is the guard against a missed pause");
	assert.equal(s.contentBearing.sameSiteOnly, false, "same-site-only must stay opt-in; see the comment");
	assert.ok(TUNING.extract.weakCoverage > 0 && TUNING.extract.weakCoverage < 1);
	assert.ok(TUNING.empty.minChars > 0);
	assert.ok(TUNING.browser.candidates.length > 0);
});

// ---------------------------------------------------------------- same-site heuristic

test("registrable domain folds subdomains and known two-part suffixes", () => {
	const cases: Array<[string, string]> = [
		["kr.example.com", "example.com"],
		["api.kr.example.com", "example.com"], // the case sameSiteOnly exists for
		["shop.example.co.kr", "example.co.kr"],
		["example.co.kr", "example.co.kr"],
		["a.b.c.example.co.jp", "example.co.jp"],
		["example.com", "example.com"],
		["localhost", "localhost"],
	];
	for (const [host, expected] of cases) assert.equal(registrableDomain(host), expected, host);
});

test("only a response that could carry content resets the idle timer", () => {
	const opts = { sameSiteOnly: false, pageDomain: "example.com" };
	// A GA beacon: 204 with an empty body. Counting these, the network is never quiet.
	assert.equal(isContentBearing({ status: 204, bodySize: 0, mimeType: "text/plain" }, opts), true);
	assert.equal(isContentBearing({ status: 302, bodySize: 0, mimeType: "" }, opts), false);
	assert.equal(isContentBearing({ status: 200, bodySize: 0, mimeType: "image/png" }, opts), false);
	assert.equal(isContentBearing({ status: 200, bodySize: 3286, mimeType: "application/json" }, opts), true);
	assert.equal(isContentBearing(undefined, opts), false);
});

test("same-site mode ignores third parties and keeps the site's own api host", () => {
	const opts = { sameSiteOnly: true, pageDomain: "example.com" };
	const json = { status: 200, bodySize: 3286, mimeType: "application/json" };
	assert.equal(isContentBearing({ ...json, url: "https://api.kr.example.com/api/v1/series/search" }, opts), true);
	assert.equal(isContentBearing({ ...json, url: "https://beacon.analytics.example.net/api/v2/rum" }, opts), false);
	assert.equal(isContentBearing({ ...json, url: "https://sync.ads.example.org/syncframe" }, opts), false);
	// An unparseable url is not silently dropped: losing a real signal is the worse failure.
	assert.equal(isContentBearing({ ...json, url: "not a url" }, opts), true);
});

// ---------------------------------------------------------------- settle rule

test("settling needs every condition, not any of them", () => {
	const ok = { elapsedMs: 5_000, stableRounds: 4, quietForMs: 2_000, inflight: 0, totalText: 14_296 };
	assert.equal(shouldSettle(ok), true);
	assert.equal(shouldSettle({ ...ok, elapsedMs: 1_000 }), false, "before the minimum wait");
	assert.equal(shouldSettle({ ...ok, stableRounds: 1 }), false, "a single stable poll is a plateau, not the end");
	assert.equal(shouldSettle({ ...ok, quietForMs: 200 }), false, "still fetching");
	assert.equal(shouldSettle({ ...ok, inflight: 1 }), false, "a request is on the wire");
	assert.equal(shouldSettle({ ...ok, totalText: 0 }), false, "nothing rendered yet");
});

test("the cap settles regardless, so a hung page cannot hold the turn", () => {
	const stuck = { elapsedMs: 30_000, stableRounds: 0, quietForMs: 0, inflight: 3, totalText: 0 };
	assert.equal(shouldSettle(stuck), true);
	assert.equal(shouldSettle({ ...stuck, elapsedMs: 10_000 }), false);
});

test("the measured v4 failure would not settle under this rule", () => {
	// the catalogue page at 2.9 s: text had held 2,767 chars for two polls, but requests were still
	// in flight and the minimum wait had not passed. v4 settled here and lost 11 tables.
	assert.equal(
		shouldSettle({ elapsedMs: 2_900, stableRounds: 2, quietForMs: 900, inflight: 2, totalText: 2_767 }),
		false,
	);
});

// ---------------------------------------------------------------- extractor choice

test("coverage is a ratio against the rendered text and cannot exceed 1", () => {
	assert.equal(coverageOf({ plainLen: 9_360, visibleLen: 13_926 }).toFixed(2), "0.67");
	assert.equal(coverageOf({ plainLen: 0, visibleLen: 0 }), 0);
	assert.ok(coverageOf({ plainLen: 40_540, visibleLen: 40_819 }) <= 1);
});

test("a table in the output beats Readability outright", () => {
	// Measured on the catalogue page: layout 0.97 with 11 tables, Readability 0.08 with none.
	const catalogue = frame({
		plainLen: 9_360,
		visibleLen: 13_926,
		tables: 11,
		readableMarkdown: "x".repeat(1_060),
		readablePlainLen: 1_060,
	});
	assert.equal(chooseExtractor(catalogue).chosen, "layout");
});

test("Readability wins only when it actually covers more of a table-less page", () => {
	const thinLayout = frame({ plainLen: 100, visibleLen: 1_000, tables: 0, readableMarkdown: "## Title\n\nbody", readablePlainLen: 900 });
	assert.equal(chooseExtractor(thinLayout).chosen, "readability");
	const layoutBetter = frame({ plainLen: 800, visibleLen: 1_000, tables: 0, readableMarkdown: "## Title", readablePlainLen: 100 });
	assert.equal(chooseExtractor(layoutBetter).chosen, "layout");
	const noCandidate = frame({ plainLen: 100, visibleLen: 1_000, tables: 0 });
	assert.equal(chooseExtractor(noCandidate).chosen, "layout", "no candidate means the layout pass stands");
});

// ---------------------------------------------------------------- assembly

test("frames are assembled in order, labelled, and empty ones dropped", () => {
	const out = assembleMarkdown("https://shop.example/goods", [
		frame({ depth: 0, markdown: "main body", plainLen: 90, visibleLen: 100, tables: 1 }),
		frame({ depth: 1, url: "https://shop.example/review_catalog", markdown: "| 번호 | 후기 |", plainLen: 90, visibleLen: 100, tables: 1 }),
		frame({ depth: 1, url: "https://shop.example/blank", markdown: "   ", plainLen: 0, visibleLen: 0 }),
	]);
	assert.match(out, /^# https:\/\/shop\.example\/goods/);
	assert.match(out, /rendered: main document \| layout \| coverage 0\.90 \| 1 tables/);
	assert.match(out, /rendered: frame https:\/\/shop\.example\/review_catalog/);
	assert.equal(out.includes("blank"), false, "a frame with no text contributes nothing");
	assert.ok(out.indexOf("main body") < out.indexOf("| 번호 | 후기 |"), "tree order is preserved");
});

test("structured data survives the trip from the page to the document", () => {
	// The first cut spread `{ blocks, og }` into a shape whose field is `structured`, so
	// every block became undefined and the document ended in `[null, null]` where
	// the catalogue page's Product and FAQPage data should have been.
	const result = toFrameResult(
		{ url: "https://shop.example/product/1", depth: 0 },
		{ markdown: "body", plainLen: 4, visibleLen: 4, tables: 11 },
		{ blocks: [{ "@type": "Product", name: "Widget A1" }], og: { "og:title": "Widget A1" } },
	);
	assert.deepEqual(result.structured, [{ "@type": "Product", name: "Widget A1" }]);
	assert.deepEqual(result.og, { "og:title": "Widget A1" });
	assert.equal(result.tables, 11);

	const out = assembleMarkdown("https://shop.example/product/1", [result]);
	assert.match(out, /structured data \(schema\.org\)/);
	assert.match(out, /"@type": "Product"/);
	assert.equal(out.includes("null"), false, "a dropped block must never serialise as null");
	assert.match(out, /\| og:title \| Widget A1 \|/, "OpenGraph is what a page without ld+json still declares");
});

test("a missing structured-data payload degrades to nothing, not to null", () => {
	const bare = toFrameResult(
		{ url: "https://example.com/", depth: 0 },
		{ markdown: "body", plainLen: 4, visibleLen: 4, tables: 0 },
		{ blocks: undefined as unknown as unknown[], og: undefined as unknown as Record<string, string> },
	);
	assert.deepEqual(bare.structured, []);
	assert.deepEqual(bare.og, {});
	const out = assembleMarkdown("https://example.com/", [bare]);
	assert.equal(out.includes("schema.org"), false);
	assert.equal(out.includes("opengraph"), false);
});

test("a chosen Readability article keeps its structure and stays markdown", () => {
	// Measured on example.com: `textContent` had no block boundaries at all, so "Message
	// Assistant" and the next sentence merged into the token `AssistantAn`, which broke
	// both reading and full-text search. Its HTML now goes through the same converter.
	const article = frame({
		depth: 0,
		markdown: "thin",
		plainLen: 4,
		visibleLen: 1_000,
		tables: 0,
		readableMarkdown: "## Message Assistant\n\nAn message editor with AI improves sentences.\n\n- 15 languages",
		readablePlainLen: 700,
	});
	const out = assembleMarkdown("https://www.example.com/", [article]);
	assert.match(out, /rendered: main document \| readability/);
	assert.match(out, /^## Message Assistant$/m, "headings survive");
	assert.match(out, /^- 15 languages$/m, "list items survive");
	assert.equal(/<div|<svg|<path|<p>/.test(out), false, "no HTML may reach a markdown document");
});

test("a frame below the furniture threshold is not worth including", () => {
	// The chat widget renders 22 characters; the shop page's smallest content frame has 1,499.
	assert.ok(TUNING.empty.frameMinChars > 22);
	assert.ok(TUNING.empty.frameMinChars < 1_499);
});

// ---------------------------------------------------------------- empty diagnosis

test("an empty render is diagnosed rather than returned", () => {
	assert.equal(classifyEmpty("잠시만 기다려 주세요 Just a moment... Cloudflare"), "botcheck");
	assert.equal(classifyEmpty("계속하려면 로그인이 필요합니다"), "login");
	assert.equal(classifyEmpty("Please sign in to continue"), "login");
	assert.equal(classifyEmpty("TEL 02-551-3611 사업자등록번호"), "empty");
	// A bot check that also mentions signing in is a bot check: retrying a login does not help.
	assert.equal(classifyEmpty("Access denied. Please log in."), "botcheck");
});

// ---------------------------------------------------------------- browser discovery

test("the configured binary wins, then fixed paths, then PATH", () => {
	const onlyFirefoxApp = (path: string) => path === "/Applications/Firefox.app/Contents/MacOS/firefox";
	assert.equal(findBrowser(undefined, onlyFirefoxApp, ""), "/Applications/Firefox.app/Contents/MacOS/firefox");
	assert.equal(
		findBrowser("/opt/custom/firefox", (p) => p === "/opt/custom/firefox" || onlyFirefoxApp(p), ""),
		"/opt/custom/firefox",
		"an explicit browserBinary is not second-guessed",
	);
	// A Homebrew formula, Nix or Flatpak install sits where no fixed list predicts.
	assert.equal(
		findBrowser(undefined, (p) => p === "/home/me/.nix-profile/bin/firefox", "/usr/bin:/home/me/.nix-profile/bin"),
		"/home/me/.nix-profile/bin/firefox",
	);
	assert.equal(findBrowser(undefined, () => false, "/usr/bin:/bin"), undefined);
});

test("this machine's Firefox is found by the real lookup", (t) => {
	// A note rather than a failure: the checks run on machines that may not have one.
	const found = findBrowser(undefined);
	t.diagnostic(found ? `firefox: ${found}` : "no firefox on this machine; magpi-render registers nothing");
});

// ---------------------------------------------------------------- config

test("config paths sit beside MagPi's own, and defaults are safe", () => {
	const paths = configPaths("/tmp/project");
	assert.match(paths.global, /\.pi\/agent\/magpi-render\.json$/);
	assert.equal(paths.project, "/tmp/project/.pi/magpi-render.json");
	const config = loadConfig("/tmp/definitely-not-a-project", false);
	assert.equal(typeof config.enabled, "boolean");
	assert.ok(Array.isArray(config.sameSiteOnlyHosts));
});

test("Readability is looked up in the agent's own package tree", () => {
	assert.match(readabilityPath(), /npm\/node_modules\/@mozilla\/readability\/Readability\.js$/);
});

test("the command writes to a stable per-url path instead of a custom message", () => {
	// A custom message needs a registered renderer; the first cut returned one without
	// and the whole rendered document vanished, leaving only the summary notification.
	const first = renderArtifactPath("https://kr.example.com/catalogue/detail/12345/?variant=A1-2020-500");
	assert.match(first, /tmp\/magpi-render\/kr\.example\.com-[0-9a-f]{8}\.md$/);
	assert.equal(
		renderArtifactPath("https://kr.example.com/catalogue/detail/12345/?variant=A1-2020-500"),
		first,
		"re-rendering the same url overwrites rather than accumulating",
	);
	assert.notEqual(renderArtifactPath("https://kr.example.com/other"), first);
	assert.match(renderArtifactPath("not a url"), /magpi-render\/page-[0-9a-f]{8}\.md$/);
});

// ---------------------------------------------------------------- websocket framing

test("text frames round-trip, including the 16- and 64-bit length forms", () => {
	for (const size of [5, 125, 126, 1_000, 70_000]) {
		const text = "a".repeat(size);
		const decoded = RawWebSocket.decodeFrame(RawWebSocket.encodeText(text));
		assert.ok(decoded, `frame of ${size} bytes should decode`);
		assert.equal(decoded.opcode, 0x1);
		assert.equal(decoded.fin, true);
		assert.equal(decoded.payload.toString("utf8"), text);
		assert.equal(decoded.rest.length, 0);
	}
});

test("multibyte payloads survive masking", () => {
	// A BiDi reply carries whatever the page held, so the framing has to be byte-exact for
	// non-ASCII: a spec table cell and a price are the shape that actually travels.
	const text = JSON.stringify({ 항목: "상품 사양 A1-2020", 단가: "12,345원" });
	const decoded = RawWebSocket.decodeFrame(RawWebSocket.encodeText(text));
	assert.equal(decoded?.payload.toString("utf8"), text);
});

test("a partial frame decodes to nothing rather than to garbage", () => {
	const full = RawWebSocket.encodeText("x".repeat(300));
	for (const cut of [1, 2, 3, 10, full.length - 1]) {
		assert.equal(RawWebSocket.decodeFrame(full.subarray(0, cut)), undefined, `truncated at ${cut}`);
	}
});

test("frames are decoded one at a time, leaving the remainder", () => {
	const joined = Buffer.concat([RawWebSocket.encodeText("first"), RawWebSocket.encodeText("second")]);
	const one = RawWebSocket.decodeFrame(joined);
	assert.equal(one?.payload.toString("utf8"), "first");
	const two = RawWebSocket.decodeFrame(one?.rest ?? Buffer.alloc(0));
	assert.equal(two?.payload.toString("utf8"), "second");
	assert.equal(two?.rest.length, 0);
});

test("a server ping is recognised as a control frame, not as a message", () => {
	// Server frames are unmasked: 0x89 = FIN + ping, zero length.
	const decoded = RawWebSocket.decodeFrame(Buffer.from([0x89, 0x00]));
	assert.equal(decoded?.opcode, 0x9);
	assert.equal(decoded?.payload.length, 0);
});

// ---------------------------------------------------------------- learned hosts

const thin = (over: Record<string, unknown> = {}) => ({
	url: "https://www.example.com/",
	handler: "webpage",
	kind: "article",
	contentBytes: 0,
	...over,
});

test("a shell is recognised from MagPi's own details, and nothing else is", () => {
	// The two measured shells: example.com cached 0 bytes under a healthy title, the catalogue page 315.
	assert.equal(isThinFetch(thin()), true, "0 bytes with a title is the worst case");
	assert.equal(isThinFetch(thin({ url: "https://kr.example.com/x", contentBytes: 315 })), true);
	// A real page.
	assert.equal(isThinFetch(thin({ contentBytes: 13_377 })), false);
	// A specialised handler's thin answer is a different failure a browser cannot fix.
	for (const handler of ["reddit", "discourse", "naver-blog", "github", "registry"]) {
		assert.equal(isThinFetch(thin({ handler })), false, handler);
	}
	// The renderer must never re-trigger itself.
	assert.equal(isThinFetch(thin({ handler: "render" })), false);
	// Not page-shaped: a pdf, a json document, a cloned repo.
	assert.equal(isThinFetch(thin({ kind: "pdf" })), false);
	assert.equal(isThinFetch(thin({ kind: "json" })), false);
	assert.equal(isThinFetch(thin({ kind: "repo", treePath: "/tmp/tree" })), false);
	// Errors are already loud; only silent success is worth intercepting.
	assert.equal(isThinFetch(thin(), true), false);
	assert.equal(isThinFetch(undefined), false);
	assert.equal(isThinFetch(thin({ url: "file:///etc/passwd" })), false);
});

test("host patterns match exactly, or a wildcard including its own base", () => {
	assert.equal(hostMatchesPattern("kr.example.com", "kr.example.com"), true);
	assert.equal(hostMatchesPattern("KR.Example.com", "kr.example.com"), true, "case is not a distinction");
	assert.equal(hostMatchesPattern("www.example.com", "kr.example.com"), false);
	assert.equal(hostMatchesPattern("kr.example.com", "*.example.com"), true);
	assert.equal(hostMatchesPattern("example.com", "*.example.com"), true, "the base is part of the wildcard");
	assert.equal(hostMatchesPattern("example.com.evil.test", "*.example.com"), false);
	assert.equal(hostMatchesPattern("anything", ""), false);
});

test("configured patterns and learned hosts both route to the browser", () => {
	const learned = { hosts: { "www.example.com": { learnedAt: "2026-09-17T00:00:00Z", bytes: 0, kind: "article" } } };
	assert.equal(shouldRenderHost("www.example.com", [], learned), true, "learned");
	assert.equal(shouldRenderHost("kr.example.com", ["*.example.com"], learned), true, "configured");
	assert.equal(shouldRenderHost("example.com", [], learned), false);
	assert.equal(shouldRenderHost("WWW.EXAMPLE.COM", [], learned), true, "host case must not decide it");
});

test("the learned store round-trips and keeps the first sighting", (t) => {
	const path = join(mkdtempSync(join(tmpdir(), "magpi-learn-")), "nested", "learned.json");
	t.after(() => rmSync(join(path, "..", ".."), { recursive: true, force: true }));

	assert.deepEqual(loadLearned(path), { hosts: {} }, "an absent store is empty, not an error");
	const first = learnHost({ hosts: {} }, "www.example.com", { learnedAt: "2026-09-17T01:00:00Z", bytes: 0, kind: "article" });
	saveLearned(first, path);
	assert.deepEqual(loadLearned(path), first, "a missing directory is created");

	// The original evidence is the interesting one, so a second sighting does not overwrite it.
	const again = learnHost(first, "www.example.com", { learnedAt: "2026-09-18T01:00:00Z", bytes: 12, kind: "text" });
	assert.equal(again.hosts["www.example.com"]?.learnedAt, "2026-09-17T01:00:00Z");
	assert.equal(again, first, "an unchanged store is returned as-is");
	assert.equal(learnHost(first, "", { learnedAt: "x", bytes: 0, kind: "" }), first, "an empty host is not learned");

	writeFileSync(path, "{ not json", "utf8");
	assert.deepEqual(loadLearned(path), { hosts: {} }, "a corrupt store costs one repeated discovery");
	assert.match(learnedStorePath(), /tmp\/magpi-render\/learned\.json$/);
});

test("the note tells the caller what changed and what to do next", () => {
	const note = thinNote("https://www.example.com/", 0);
	assert.match(note, /0 bytes/);
	assert.match(note, /refresh: true/, "the shell is cached, so a plain refetch would return it again");
	assert.match(note, /magpi_fetch_rendered/, "the one-off escape hatch is named too");
	assert.match(note, /^\n\n<!--[\s\S]*-->$/, "a comment, so it cannot be mistaken for page content");
});

// ---------------------------------------------------------------- registration gate

/** Collects what activation registered, with browser discovery stubbed either way. */
async function activateWith(found: string | undefined): Promise<{
	tools: string[];
	commands: string[];
	events: string[];
	hemitted: Array<{ name: string; payload: unknown }>;
}> {
	const original = browserLookup.find;
	browserLookup.find = () => found;
	const tools: string[] = [];
	const commands: string[] = [];
	const events: string[] = [];
	const emitted: Array<{ name: string; payload: unknown }> = [];
	try {
		await activate({
			registerTool: (definition: { name: string }) => tools.push(definition.name),
			registerCommand: (name: string) => commands.push(name),
			on: (name: string) => events.push(name),
			events: { on: () => {}, emit: (name: string, payload: unknown) => emitted.push({ name, payload }) },
		});
	} finally {
		browserLookup.find = original;
	}
	return { tools, commands, events, emitted };
}

test("with a browser present, the tool and command are registered", async () => {
	const { tools, commands } = await activateWith("/Applications/Firefox.app/Contents/MacOS/firefox");
	assert.deepEqual(tools, ["magpi_fetch_rendered"], "the tool sorts directly under magpi_fetch");
	assert.deepEqual(commands, ["magpi-render"]);
});

test("the render handler is registered through MagPi, so MagPi does the caching", async () => {
	const { emitted, events } = await activateWith("/Applications/Firefox.app/Contents/MacOS/firefox");
	const registrations = emitted.filter((entry) => entry.name === "magpi:register-handler");
	assert.equal(registrations.length, 1, "emitted at load; session_start repeats it idempotently");
	const handler = registrations[0]?.payload as { name: string; match: (url: URL) => boolean; fetch: unknown };
	assert.equal(handler.name, "render");
	assert.equal(typeof handler.match, "function");
	assert.equal(typeof handler.fetch, "function");
	assert.equal(handler.match(new URL("https://example.com/nothing-special")), false, "only listed hosts render");
	// Detection and re-registration both need their hooks.
	assert.ok(events.includes("tool_result"), "detection runs on magpi_fetch results");
	assert.ok(events.includes("session_start"), "registration survives a session replacement");
});

test("without a browser, nothing is registered at all", async () => {
	// This directory travels between machines through dotfiles. A tool that can only
	// fail when called still costs prompt tokens in every session, so it must not exist.
	const { tools, commands, events, emitted } = await activateWith(undefined);
	assert.deepEqual(tools, []);
	assert.deepEqual(commands, []);
	assert.deepEqual(events, [], "no detection either: there is nothing to escalate to");
	assert.deepEqual(emitted, [], "and no handler for MagPi to route into");
});
