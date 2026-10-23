/**
 * extensions/section-order.ts makes pi's prompt builder render custom sections in the
 * order the transcript replay holds them, which is what pi-claude-bridge's exact-match
 * prompt capture needs (upstream elidickinson/pi-claude-bridge#153).
 *
 * The cases run pi's own builder, section diff and pi-ai's replay, not a model of them:
 * the first pins the failure itself, so a pi or bridge release that changes either side
 * shows up here rather than as a failed turn.
 *
 * The last case runs the installed bridge's own replay on the same failure and fails
 * once the bridge orders custom sections itself: that is the signal to delete the
 * extension, this file and its README row.
 */

import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { stripTypeScriptTypes } from "node:module";
import { join } from "node:path";
import test from "node:test";
import { CONFIG_DIR, piPackageDir, redirectPiImports } from "./lib.ts";

redirectPiImports(["@earendil-works/pi-ai"]);

const { getCurrentSystemMessage, getSystemMessageText } = await import("@earendil-works/pi-ai");
const { buildSystemPrompt, buildSystemPromptSections, diffSystemPromptSections, normalizeBuildSystemPromptOptions } =
	await import(join(piPackageDir(), "dist/core/system-prompt.js"));
const { alignSections, replayedSectionOrder } = await import("../extensions/section-order.ts");

type Sections = Record<string, string>;
const mcp = "MCP servers whose tools are not declared to you.";
const telegram = "Telegram session connected.";

/** The transcript after a first run whose handlers left `first` in the sections. */
function transcriptWith(first: Sections) {
	const options = normalizeBuildSystemPromptOptions({ cwd: "/work", sections: first });
	return [{ role: "system", content: "", sections: buildSystemPromptSections(options), timestamp: 1 }];
}

/** One later run: returns what the bridge keys on and what the provider replays. */
function nextRun(messages: object[], sections: Sections) {
	const options = normalizeBuildSystemPromptOptions({ cwd: "/work", sections });
	const current = getCurrentSystemMessage(messages)?.sections ?? {};
	const patch = diffSystemPromptSections(current, buildSystemPromptSections(options));
	const next = patch ? [...messages, { role: "system", content: "", sections: patch, timestamp: 2 }] : messages;
	return { built: buildSystemPrompt(options), replayed: getSystemMessageText(getCurrentSystemMessage(next)) };
}

test("without alignment: a section added before an existing one replays after it", () => {
	const messages = transcriptWith({ mcp_servers: mcp });
	// pi-telegram's handler runs before pi's built-in MCP one.
	const { built, replayed } = nextRun(messages, { telegram, mcp_servers: mcp });
	assert.equal(built.length, replayed.length);
	assert.notEqual(built, replayed);
});

test("aligned after pi-telegram: the new section follows, the prompts agree", () => {
	const messages = transcriptWith({ mcp_servers: mcp });
	const sections: Sections = { telegram };
	alignSections(sections, replayedSectionOrder(messages));
	sections.mcp_servers = mcp; // pi's MCP extension, always last
	const { built, replayed } = nextRun(messages, sections);
	assert.equal(built, replayed);
});

test("aligned before every handler: placeholders hold the replay positions", () => {
	const messages = transcriptWith({ telegram, mcp_servers: mcp });
	const sections: Sections = {};
	alignSections(sections, replayedSectionOrder(messages));
	sections.mcp_servers = mcp;
	sections.telegram = telegram;
	const { built, replayed } = nextRun(messages, sections);
	assert.equal(built, replayed);
});

test("a section that went away leaves an empty placeholder, which renders nothing", () => {
	const messages = transcriptWith({ mcp_servers: mcp, telegram });
	const sections: Sections = {}; // pi-telegram disconnected and deleted its section
	alignSections(sections, replayedSectionOrder(messages));
	sections.mcp_servers = mcp;
	assert.deepEqual(sections, { mcp_servers: mcp, telegram: "" });
	const { built, replayed } = nextRun(messages, sections);
	assert.equal(built, replayed);
	assert.ok(!built.includes("<telegram>"));
});

test("replay order: built-ins are skipped, a removal drops the name, a re-add goes last", () => {
	const order = replayedSectionOrder([
		{ role: "system", sections: { preamble: "p", cwd: "c", a: "1", b: "2" } },
		{ role: "user" },
		{ role: "system", sections: { a: null } },
		{ role: "system", sections: { a: "1", b: "3" } },
	]);
	assert.deepEqual(order, ["b", "a"]);
});

test("pi-claude-bridge still misorders custom sections (#153), so the workaround is needed", async (t) => {
	const bridge = join(CONFIG_DIR, "npm/node_modules/pi-claude-bridge");
	if (!existsSync(bridge)) return t.skip("pi-claude-bridge not installed");
	const { version } = JSON.parse(readFileSync(join(bridge, "package.json"), "utf8"));
	const source = join(bridge, "src/transcript.ts");
	assert.ok(
		existsSync(source),
		`pi-claude-bridge ${version} has no src/transcript.ts: re-check elidickinson/pi-claude-bridge#153 and this test`,
	);
	// Node refuses to strip types under node_modules; strip here and import the result.
	const js = stripTypeScriptTypes(readFileSync(source, "utf8"));
	const { toBridgeContext } = await import(`data:text/javascript,${encodeURIComponent(js)}`);

	const messages = transcriptWith({ mcp_servers: mcp });
	const sections: Sections = { telegram, mcp_servers: mcp };
	const options = normalizeBuildSystemPromptOptions({ cwd: "/work", sections });
	const patch = diffSystemPromptSections(getCurrentSystemMessage(messages)?.sections ?? {}, buildSystemPromptSections(options));
	const replayed = toBridgeContext({ messages: [...messages, { role: "system", content: "", sections: patch, timestamp: 2 }] })
		.systemPrompt;
	assert.notEqual(
		replayed,
		buildSystemPrompt(options),
		`pi-claude-bridge ${version} now replays custom sections in builder order: elidickinson/pi-claude-bridge#153 looks fixed. ` +
			"Try /reload in a session with Telegram connected; if it works, delete extensions/section-order.ts, " +
			"tests/section-order.test.ts and their README row.",
	);
});
