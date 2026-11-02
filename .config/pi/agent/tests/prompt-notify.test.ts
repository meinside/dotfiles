/**
 * extensions/prompt-notify.ts is what tells the user on Telegram that pi stopped at
 * a terminal prompt. Pinned here: nothing is sent for a prompt answered within the
 * wait, a claimed (guard) prompt is left to its owner, only a shortened first line
 * of the title leaves the machine, and the message is settled once the prompt closes.
 */

import assert from "node:assert/strict";
import test from "node:test";
import { claimPrompt, type TelegramHandle, type TelegramPort, type TelegramView } from "../extensions/lib/telegram.ts";
import * as notifyModule from "../extensions/prompt-notify.ts";

type Handler = (event: unknown, ctx: unknown) => Promise<unknown>;

/** Type stripping leaves the CJS default nested one level deeper. */
const entry = (notifyModule as { default?: unknown }).default;
const notify = (typeof entry === "function" ? entry : (entry as { default?: unknown })?.default) as (
	pi: { on: (name: string, handler: Handler) => void },
	loadTelegram?: () => Promise<TelegramPort | undefined>,
	notifyAfterMs?: number,
) => void;
const { summarizeTitle } = notifyModule;

function fakeTelegram(failure?: string) {
	const sent: TelegramView[] = [];
	const edits: TelegramView[] = [];
	const handle: TelegramHandle = { target: { chatId: 42, threadId: 7 }, messageIds: [100], generation: "g1" };
	const port: TelegramPort = {
		send: async (view) => {
			sent.push(view);
			return failure ? { ok: false, reason: failure, message: "boom" } : { ok: true, value: handle };
		},
		edit: async (_handle, view) => {
			edits.push(view);
			return { ok: true, value: handle };
		},
		isTelegramTurn: async () => !failure,
		onUpdate: () => () => {},
	};
	return { port, sent, edits };
}

function notifierWith(telegram: TelegramPort | undefined, notifyAfterMs = 0) {
	const on: Record<string, Handler> = {};
	const register = (name: string, handler: Handler) => {
		on[name] = handler;
	};
	notify({ on: register }, async () => telegram, notifyAfterMs);
	const notices: string[] = [];
	const ctx = { cwd: "/work/conjecture-go", ui: { notify: (text: string) => void notices.push(text) } };
	return {
		on,
		notices,
		start: (kind: string, title?: string) => on.ui_prompt_start({ type: "ui_prompt_start", reason: "ui_prompt", kind, title }, ctx),
		end: (kind: string, title?: string) => on.ui_prompt_end({ type: "ui_prompt_end", reason: "ui_prompt", kind, title }, ctx),
	};
}

const wait = (ms = 5) => new Promise((resolve) => setTimeout(resolve, ms));

test("a prompt left open is announced with its directory and title, then settled when it closes", async () => {
	const telegram = fakeTelegram();
	const notifier = notifierWith(telegram.port);
	await notifier.start("confirm", "Run project-local agents?");
	await wait();
	assert.equal(telegram.sent.length, 1);
	assert.equal(telegram.sent[0].text, "⏳ pi (conjecture-go) is waiting for an answer in the terminal:\nRun project-local agents?");
	assert.equal(telegram.sent[0].replyMarkup, undefined, "answering stays in the terminal");
	await notifier.end("confirm", "Run project-local agents?");
	await wait();
	assert.deepEqual(telegram.edits, [{ text: "☑️ No longer waiting: Run project-local agents?" }]);
});

test("a prompt answered within the wait sends nothing", async () => {
	const telegram = fakeTelegram();
	const notifier = notifierWith(telegram.port, 60_000);
	await notifier.start("select", "Restore code state?");
	await notifier.end("select", "Restore code state?");
	await wait();
	assert.deepEqual(telegram.sent, []);
});

test("a claimed prompt is left to the extension that claimed it", async () => {
	const telegram = fakeTelegram();
	const notifier = notifierWith(telegram.port);
	const release = claimPrompt();
	await notifier.start("select", "Allow this sudo?\n\n  sudo cat /tmp/s3cret");
	await wait();
	await notifier.end("select");
	release();
	assert.deepEqual(telegram.sent, []);
});

test("ask_user's untitled dialog is announced by its question", async () => {
	const telegram = fakeTelegram();
	const notifier = notifierWith(telegram.port);
	await notifier.on.tool_call({ toolName: "ask_user", input: { question: "Which approach?\nlong context" } }, {});
	await notifier.start("custom");
	await wait();
	assert.match(telegram.sent[0]?.text ?? "", /:\nWhich approach\?$/);
	await notifier.end("custom");
	await notifier.on.tool_result({ toolName: "ask_user" }, {});

	await notifier.on.tool_call({ toolName: "ask_user", input: { questions: [{ question: "First?" }, { question: "Second?" }] } }, {});
	await notifier.start("custom");
	await wait();
	assert.match(telegram.sent[1]?.text ?? "", /:\nFirst\?$/);
	await notifier.end("custom");
	await notifier.on.tool_result({ toolName: "ask_user" }, {});

	await notifier.start("custom");
	await wait();
	assert.match(telegram.sent[2]?.text ?? "", /:\na custom dialog$/, "no question once ask_user is over");
});

test("no Telegram to reach stays quiet; any other failure is reported in the terminal", async () => {
	for (const failure of ["target-unavailable", "runtime-unavailable"]) {
		const notifier = notifierWith(fakeTelegram(failure).port);
		await notifier.start("input", "magpi");
		await wait();
		assert.deepEqual(notifier.notices, [], failure);
	}
	const notifier = notifierWith(undefined);
	await notifier.start("input", "magpi");
	await wait();
	assert.deepEqual(notifier.notices, []);

	const failing = notifierWith(fakeTelegram("transport-failed").port);
	await failing.start("input", "magpi");
	await wait();
	assert.equal(failing.notices.length, 1);
	assert.match(failing.notices[0], /Telegram not reached \(transport-failed\): boom/);
});

test("only the first non-empty line of a title is sent, shortened", () => {
	assert.equal(summarizeTitle(undefined), undefined);
	assert.equal(summarizeTitle("\n  \n"), undefined);
	assert.equal(summarizeTitle("\n🐦 magpi: every search source failed\n\nLook up: secret query"), "🐦 magpi: every search source failed");
	assert.equal(summarizeTitle("a\tb\u0007c"), "a b c");
	const long = summarizeTitle("x".repeat(200)) ?? "";
	assert.equal([...long].length, 80);
	assert.ok(long.endsWith("…"));
});

test("a session ending drops a pending announcement", async () => {
	const telegram = fakeTelegram();
	const notifier = notifierWith(telegram.port, 20);
	await notifier.start("select", "Switched to google/gemini");
	await notifier.on.session_shutdown({}, {});
	await wait(40);
	assert.deepEqual(telegram.sent, []);
});
