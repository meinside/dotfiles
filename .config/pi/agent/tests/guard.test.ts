/**
 * guard.ts is the only thing standing between a tool call and the credential
 * files in this home directory, so its policy is pinned here rather than tried by
 * hand. The `tool_result` cases are the ones that matter most: `grep` given an
 * ancestor directory is not blocked at call time by design, so the filter is all
 * that keeps `grep ~/.config` from returning lines out of `auth.json`.
 */

import assert from "node:assert/strict";
import { homedir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import * as guardModule from "../extensions/guard.ts";
import type { TelegramHandle, TelegramPort, TelegramUpdateHandler, TelegramView } from "../extensions/lib/telegram.ts";
import { readText } from "./lib.ts";

type Handler = (event: unknown, ctx: unknown) => Promise<unknown>;
type ToolCallResult = { block?: boolean; reason?: string } | undefined;
type ToolResultPatch = { content: Array<{ type: string; text?: string }> } | undefined;

/** Type stripping leaves the CJS default nested one level deeper. */
const entry = (guardModule as { default?: unknown }).default;
const guard = (typeof entry === "function" ? entry : (entry as { default?: unknown })?.default) as (
	pi: { on: (name: string, handler: Handler) => void; getAllTools: () => unknown[] },
	loadTelegram?: () => Promise<TelegramPort | undefined>,
) => void;
const { answerCallback } = guardModule;

/**
 * MCP tools as `pi.getAllTools()` reports them, one per combination of hints the
 * approval rule distinguishes. Server and tool names are neutral on purpose.
 */
const MCP_TOOLS: Array<{ name: string; annotations?: Record<string, boolean> }> = [
	{ name: "mcp__srv__no_hints" },
	{ name: "mcp__srv__read", annotations: { readOnlyHint: true } },
	{ name: "mcp__srv__read_but_destructive", annotations: { readOnlyHint: true, destructiveHint: true } },
	{ name: "mcp__srv__additive_closed", annotations: { destructiveHint: false, openWorldHint: false } },
	{ name: "mcp__srv__additive_open", annotations: { destructiveHint: false } },
	{ name: "mcp__srv__destructive", annotations: { destructiveHint: true } },
];

const handlers: Record<string, Handler> = {};
guard({
	on: (name, handler) => {
		handlers[name] = handler;
	},
	getAllTools: () => MCP_TOOLS,
});

const CWD = join(homedir(), ".config/pi/agent");
const ctx = { cwd: CWD, hasUI: false, ui: { notify: () => {}, select: async () => "Block" } };

const call = (toolName: string, path: string) =>
	handlers.tool_call({ toolName, input: { path } }, ctx) as Promise<ToolCallResult>;

test("guard registers the handlers it needs", () => {
	assert.deepEqual(Object.keys(handlers).sort(), [
		"session_shutdown",
		"session_start",
		"tool_call",
		"tool_result",
		"user_bash",
	]);
});

test("credential paths are not writable", async () => {
	// sorted, like the list in guard.ts, so an addition has one obvious place to go
	for (const path of [
		"auth.json", // relative to cwd
		"mcp-auth.json",
		"telegram.json",
		"~/.aws/config",
		"~/.aws/sso/cache/x.json",
		"~/.claude/settings.json",
		"~/.config/claude/settings.json",
		"~/.config/gcloud/x.json",
		"~/.config/pi/agent/auth.json",
		"~/.config/pi/agent/mcp-auth.json",
		"~/.config/pi/agent/telegram.json",
		"~/.config/rclone/rclone.conf",
		"~/.custom_env",
		"~/.gnupg/pubring.kbx",
		"~/.netrc",
		"~/.npmrc",
		"~/.ollama/id_ed25519",
		"~/.pi/agent/auth.json",
		"~/.pi/agent/mcp-auth.json",
		"~/.pi/agent/telegram.json",
		"~/.ssh/authorized_keys",
	]) {
		assert.equal((await call("write", path))?.block, true, `write ${path} should be blocked`);
		assert.equal((await call("edit", path))?.block, true, `edit ${path} should be blocked`);
	}
});

test("secret paths are not readable", async () => {
	for (const path of [
		"auth.json",
		"mcp-auth.json",
		"telegram.json",
		"~/.aws/cli/cache/session.db",
		"~/.aws/credentials",
		"~/.aws/sso/cache/x.json",
		"~/.bash_history",
		"~/.claude/sessions/x.jsonl",
		"~/.config/claude/history.jsonl",
		"~/.config/gcloud/credentials.db",
		"~/.config/pi/agent/auth.json",
		"~/.config/pi/agent/mcp-auth.json",
		"~/.config/pi/agent/sessions/x.jsonl",
		"~/.config/pi/agent/telegram.json",
		"~/.config/rclone/rclone.conf",
		"~/.custom_env",
		"~/.ollama/id_ed25519",
		"~/.python_history",
		"~/.ssh/id_ed25519",
		"~/.zsh_history",
	]) {
		assert.equal((await call("read", path))?.block, true, `read ${path} should be blocked`);
	}
	assert.equal((await call("grep", "~/.gnupg"))?.block, true, "grep inside a secret dir should be blocked");
});

/**
 * The lists in guard.ts are long enough that an unsorted addition hides a
 * duplicate or a near-miss (`~/.aws` next to `~/.aws/sso`). Read from the source
 * rather than imported: the exported arrays carry the derived `~/.pi` twins, which
 * are not in sorted position.
 */
test("guard.ts policy lists stay alphabetically sorted", () => {
	const source = readText("extensions/guard.ts");
	assert.ok(source, "extensions/guard.ts should be readable");
	for (const name of ["PROTECTED_PATHS", "SECRET_PATHS"]) {
		const block = new RegExp(`const ${name} = withPiTwin\\(\\[([^\\]]*)\\]`).exec(source);
		assert.ok(block, `${name} not found in extensions/guard.ts`);
		const entries = [...block[1].matchAll(/"([^"]+)"/g)].map((m) => m[1]);
		assert.ok(entries.length > 5, `${name} parsed as only ${entries.length} entries — did the literal change shape?`);
		assert.deepEqual(entries, [...entries].sort(), `${name} should be sorted alphabetically`);
		assert.equal(new Set(entries).size, entries.length, `${name} has a duplicate entry`);
	}
});

test("the two lists differ where they are meant to", async () => {
	// profiles and regions, no secrets: writing is the risk, reading is useful
	assert.equal(await call("read", "~/.aws/config"), undefined);
	// hooks run commands, so it is write-blocked, but it holds no credentials
	assert.equal(await call("read", "~/.claude/settings.json"), undefined);
	// transcripts are read-blocked without being write-blocked
	assert.equal(await call("write", "~/.zsh_history"), undefined);
	// checked and found to hold no secrets on this machine
	assert.equal(await call("read", "~/.config/gh/hosts.yml"), undefined);
	assert.equal(await call("read", "~/.docker/config.json"), undefined);
	assert.equal(await call("read", "~/.config/git/config"), undefined);
	assert.equal(await call("read", "~/.ollama/id_ed25519.pub"), undefined);
	// ordinary files
	assert.equal(await call("read", "README.md"), undefined);
	assert.equal(await call("write", "README.md"), undefined);
	assert.equal(await call("grep", "~/.config/pi/agent"), undefined);
});

test("machine-changing commands need a confirmation that headless cannot give", async () => {
	const blocked = await handlers.tool_call({ toolName: "bash", input: { command: "sudo rm -rf /" } }, ctx);
	assert.equal(blocked?.block, true);
	assert.equal(await handlers.tool_call({ toolName: "bash", input: { command: "ls -la" } }, ctx), undefined);
	// documented hole: bash is not gated on credential paths
	assert.equal(
		await handlers.tool_call({ toolName: "bash", input: { command: "cat ~/.aws/credentials" } }, ctx),
		undefined,
	);
});

const mcpCall = (toolName: string, context: unknown = ctx) =>
	handlers.tool_call({ toolName, input: { id: 1 } }, context) as Promise<ToolCallResult>;

test("MCP calls follow pi's documented approval rule on server annotations", async () => {
	// headless: anything needing approval is blocked, the rest passes untouched
	const expected: Record<string, boolean> = {
		mcp__srv__no_hints: true, // MCP defaults: not read-only, may be destructive, open world
		mcp__srv__read: false,
		mcp__srv__read_but_destructive: true, // an explicit destructive hint wins
		mcp__srv__additive_closed: false,
		mcp__srv__additive_open: true, // openWorldHint defaults to true
		mcp__srv__destructive: true,
		mcp__srv__not_listed: true, // a tool pi does not report has no hints at all
	};
	for (const [name, blocked] of Object.entries(expected)) {
		const result = await mcpCall(name);
		assert.equal(result?.block === true, blocked, name);
	}
});

test("an MCP call needing approval runs once the user allows it", async () => {
	let asked = "";
	const withUI = {
		...ctx,
		hasUI: true,
		ui: {
			...ctx.ui,
			select: async (title: string) => {
				asked = title;
				return "Allow once";
			},
		},
	};
	assert.equal(await mcpCall("mcp__srv__destructive", withUI), undefined);
	assert.match(asked, /mcp__srv__destructive \{"id":1\}/);
});

test("the MCP rule leaves non-MCP tools alone, hints or not", async () => {
	assert.equal(await mcpCall("magpi_fetch"), undefined);
	assert.equal(await mcpCall("codemode"), undefined);
});

const grepResult = (path: string | undefined, text: string) =>
	handlers.tool_result(
		{ toolName: "grep", input: { pattern: "x", ...(path ? { path } : {}) }, content: [{ type: "text", text }] },
		ctx,
	) as Promise<ToolResultPatch>;

test("grep matches inside secret paths are removed from the result", async () => {
	const result = await grepResult(
		"~/.config",
		[
			"pi/agent/auth.json:3:     \"key\": \"<<<fake-secret-for-this-test>>>\"",
			"pi/agent/auth.json-4-     \"type\": \"aws\"",
			"gcloud/credentials.db:1: binary",
			"rclone/rclone.conf:2: RCLONE_ENCRYPT_V0",
			"pi/agent/README.md:12: a normal match",
		].join("\n"),
	);
	assert.ok(result, "the result should have been rewritten");
	const text = result.content[0].text ?? "";
	assert.ok(!text.includes("<<<fake-secret-for-this-test>>>"), "the credential line survived");
	assert.ok(!text.includes("auth.json-4-"), "the context line around it survived");
	assert.ok(!text.includes("credentials.db"), "the gcloud line survived");
	assert.ok(!text.includes("rclone.conf"), "the rclone line survived");
	assert.ok(text.includes("a normal match"), "an unrelated match was dropped");
	assert.match(text, /guard\.ts removed 4 line\(s\)/, "the model was not told the result is partial");
});

test("grep with a secret search root is filtered by relative path too", async () => {
	const result = await grepResult("~/.aws", ["credentials:2: aws_secret_access_key = x", "config:1: region = x"].join("\n"));
	const text = result?.content[0].text ?? "";
	assert.ok(!text.includes("aws_secret_access_key"), "the credentials line survived");
	assert.ok(text.includes("region = x"), "~/.aws/config should stay readable");
});

test("results with nothing to hide are left untouched", async () => {
	assert.equal(await grepResult(undefined, "README.md:1: hello"), undefined);
	assert.equal(await grepResult("~/.config", "No matches found"), undefined);
	assert.equal(
		await handlers.tool_result({ toolName: "read", input: {}, content: [{ type: "text", text: "x" }] }, ctx),
		undefined,
	);
	assert.equal(
		await handlers.tool_result(
			{ toolName: "grep", input: { path: "~/.config" }, isError: true, content: [{ type: "text", text: "pi/agent/auth.json:1: x" }] },
			ctx,
		),
		undefined,
	);
});

// ---------------------------------------------------------------- telegram

/**
 * pi-telegram as guard sees it through extensions/lib/telegram.ts: records what was
 * sent and edited, and taps a sent button the way the paired user's phone would.
 * `turn: false` is every case where there is no Telegram turn to send to.
 */
function fakeTelegram(turn = true) {
	const sent: TelegramView[] = [];
	const edits: TelegramView[] = [];
	let handler: TelegramUpdateHandler | undefined;
	const handle: TelegramHandle = { target: { chatId: 42, threadId: 7 }, messageIds: [100], generation: "g1" };
	const port: TelegramPort = {
		send: async (view) => {
			sent.push(view);
			return turn ? { ok: true, value: handle } : { ok: false, reason: "target-unavailable", message: "" };
		},
		edit: async (_handle, view) => {
			edits.push(view);
			return { ok: true, value: handle };
		},
		isTelegramTurn: async () => turn,
		onUpdate: (h) => {
			handler = h;
			return () => {
				handler = undefined;
			};
		},
	};
	const buttonData = (answer: "y" | "n") =>
		sent.at(-1)?.replyMarkup?.inline_keyboard[0].find((b) => b.callback_data.endsWith(`:${answer}`))?.callback_data;
	const tap = (answer: "y" | "n") =>
		handler?.({ callback_query: { data: buttonData(answer), from: { id: 42 }, message: { message_id: 100, chat: { id: 42 } } } });
	return { port, sent, edits, tap, buttonData, registered: () => handler !== undefined };
}

/** A terminal whose select stays open until answered or aborted, like pi's. */
function terminal() {
	let answer: (choice: string | undefined) => void = () => {};
	let signal: AbortSignal | undefined;
	const ui = {
		notify: () => {},
		select: (_title: string, _options: string[], opts?: { signal?: AbortSignal }) => {
			signal = opts?.signal;
			return new Promise<string | undefined>((resolve) => {
				answer = resolve;
				signal?.addEventListener("abort", () => resolve(undefined));
			});
		},
	};
	return { ctx: { cwd: CWD, hasUI: true, ui }, answer: (choice: string) => answer(choice), closed: () => signal?.aborted === true };
}

async function guardWith(telegram: TelegramPort | undefined) {
	const own: Record<string, Handler> = {};
	const on = (name: string, handler: Handler) => {
		own[name] = handler;
	};
	guard({ on, getAllTools: () => MCP_TOOLS }, async () => telegram);
	await own.session_start({}, {});
	return own;
}

/** Lets the send that follows the terminal dialog happen. */
const tick = () => new Promise((resolve) => setImmediate(resolve));

test("in a Telegram turn a tap there decides, and the terminal dialog closes", async () => {
	for (const [answer, blocked] of [["y", false], ["n", true]] as const) {
		const telegram = fakeTelegram();
		const own = await guardWith(telegram.port);
		const local = terminal();
		const result = own.tool_call({ toolName: "mcp__srv__destructive", input: { id: 1 } }, local.ctx) as Promise<ToolCallResult>;
		await tick();
		assert.equal(telegram.tap(answer), "consume");
		assert.equal((await result)?.block === true, blocked, answer);
		assert.ok(local.closed(), "the terminal dialog should close");
		await tick();
		assert.match(telegram.edits[0]?.text ?? "", blocked ? /blocked from Telegram/ : /allowed from Telegram/);
	}
});

test("Telegram gets the label and tool name, never the command or its arguments", async () => {
	const telegram = fakeTelegram();
	const own = await guardWith(telegram.port);
	const local = terminal();
	const mcp = own.tool_call({ toolName: "mcp__srv__destructive", input: { token: "s3cret" } }, local.ctx);
	await tick();
	local.answer("Block");
	await mcp;
	const bash = own.tool_call({ toolName: "bash", input: { command: "sudo cat /tmp/s3cret" } }, local.ctx);
	await tick();
	local.answer("Block");
	await bash;
	assert.equal(telegram.sent.length, 2);
	assert.match(telegram.sent[0].text, /MCP call mcp__srv__destructive/);
	assert.match(telegram.sent[1].text, /allow this sudo\?/);
	for (const view of [...telegram.sent, ...telegram.edits]) assert.ok(!view.text.includes("s3cret"), view.text);
});

test("an answer in the terminal settles the Telegram message, and a later tap does nothing", async () => {
	const telegram = fakeTelegram();
	const own = await guardWith(telegram.port);
	const local = terminal();
	const result = own.tool_call({ toolName: "bash", input: { command: "sudo true" } }, local.ctx) as Promise<ToolCallResult>;
	await tick();
	local.answer("Allow once");
	assert.equal(await result, undefined);
	await tick();
	assert.match(telegram.edits[0]?.text ?? "", /allowed locally/);
	assert.equal(telegram.tap("n"), "consume", "a stale guard button must not reach the model as [callback]");
});

test("outside a Telegram turn, or without pi-telegram, only the terminal is asked", async () => {
	for (const telegram of [fakeTelegram(false), undefined]) {
		const own = await guardWith(telegram?.port);
		const local = terminal();
		const result = own.tool_call({ toolName: "bash", input: { command: "sudo true" } }, local.ctx) as Promise<ToolCallResult>;
		await tick();
		local.answer("Allow once");
		assert.equal(await result, undefined);
		assert.deepEqual(telegram?.edits ?? [], []);
	}
});

test("a session ending blocks a confirmation still waiting and stops listening", async () => {
	const telegram = fakeTelegram();
	const own = await guardWith(telegram.port);
	assert.ok(telegram.registered());
	const result = own.tool_call({ toolName: "bash", input: { command: "sudo true" } }, terminal().ctx) as Promise<ToolCallResult>;
	await tick();
	await own.session_shutdown({}, {});
	assert.equal((await result)?.block, true);
	assert.ok(!telegram.registered());
});

test("a guard button settles only for the paired chat's tap on the message it was sent in", () => {
	let settled: boolean | undefined;
	const pending = new Map([
		[
			"ab12",
			{
				handle: { target: { chatId: 42 }, messageIds: [100], generation: "g" },
				settle: (allowed: boolean) => {
					settled = allowed;
				},
			},
		],
	]);
	const query = (data: string, from = 42, chat = 42, message = 100) => ({
		callback_query: { data, from: { id: from }, message: { message_id: message, chat: { id: chat } } },
	});
	assert.equal(answerCallback(query("tgbtn:x"), pending, 7), "pass", "not ours");
	assert.equal(answerCallback(query("guard:8:ab12:y"), pending, 7), "pass", "another pi instance's, routed on by the leader");
	assert.equal(answerCallback(query("guard:7:ffff:y"), pending, 7), "consume", "answered already or from before /reload");
	for (const [from, chat, message] of [[99, 42, 100], [42, 99, 100], [42, 42, 101]]) {
		assert.equal(answerCallback(query("guard:7:ab12:y", from, chat, message), pending, 7), "consume");
		assert.equal(settled, undefined, `${from}/${chat}/${message} must not settle`);
	}
	assert.equal(answerCallback(query("guard:7:ab12:n"), pending, 7), "consume");
	assert.equal(settled, false);
});
