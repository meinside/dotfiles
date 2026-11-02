// Tells Telegram when pi has been waiting on a terminal prompt for a while.
//
// Any extension's ctx.ui dialog (select, confirm, input, editor, custom) stops the
// agent until someone answers at the machine, which the user on Telegram cannot see.
// pi reports every such wait as ui_prompt_start / ui_prompt_end, so one listener
// covers them all: left open for NOTIFY_AFTER_MS, the prompt is announced to the
// Telegram turn's chat or this instance's Thread, and the message is updated once
// the prompt closes. Answering still happens in the terminal.
//
// Only the prompt title's first line is sent, shortened: the rest can be a command
// or arguments, and a message on Telegram stays on Telegram's servers. guard.ts
// claims its own prompts and sends them as buttons, so they are skipped here.
import { basename } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
	isPromptClaimed,
	isUnreachable,
	loadTelegramPort,
	NOTIFY_AFTER_MS,
	type TelegramHandle,
	type TelegramPort,
} from "./lib/telegram.ts";

const TITLE_MAX = 80;

/** The first non-empty line, without control characters, at most TITLE_MAX characters. */
export function summarizeTitle(title: string | undefined): string | undefined {
	const line = title
		?.split("\n")
		.map((text) => text.replace(/\p{Cc}/gu, " ").trim())
		.find(Boolean);
	if (!line) return undefined;
	const chars = [...line];
	return chars.length > TITLE_MAX ? `${chars.slice(0, TITLE_MAX - 1).join("")}…` : line;
}

/** pi-ask-user's question: `question`, or the first of `questions`. */
function askUserQuestion(input: unknown): string | undefined {
	const { question, questions } = (input ?? {}) as { question?: unknown; questions?: Array<{ question?: unknown }> };
	const text = typeof question === "string" ? question : questions?.[0]?.question;
	return typeof text === "string" ? text : undefined;
}

type Waiting = { what: string; timer: ReturnType<typeof setTimeout>; sent?: Promise<TelegramHandle | undefined> };

/** `loadTelegram` and `notifyAfterMs` are parameters so tests can stand in for them; pi passes only `pi`. */
export default function (
	pi: ExtensionAPI,
	loadTelegram: () => Promise<TelegramPort | undefined> = loadTelegramPort,
	notifyAfterMs = NOTIFY_AFTER_MS,
) {
	let telegram: Promise<TelegramPort | undefined> | undefined;
	const port = () => (telegram ??= loadTelegram());
	let waiting: Waiting | undefined;
	// ask_user draws a `custom` dialog, which has no title; its question stands in.
	let question: string | undefined;

	function close(entry: Waiting | undefined): void {
		if (!entry) return;
		clearTimeout(entry.timer);
		// Not awaited: closing a prompt should not wait on Telegram.
		void entry.sent?.then(async (handle) => {
			if (handle) await (await port())?.edit(handle, { text: `☑️ No longer waiting: ${entry.what}` });
		});
	}

	pi.on("tool_call", async (event) => {
		if (event.toolName === "ask_user") question = askUserQuestion(event.input);
		return undefined;
	});
	pi.on("tool_result", async (event) => {
		if (event.toolName === "ask_user") question = undefined;
		return undefined;
	});

	pi.on("ui_prompt_start", async (event, ctx: ExtensionContext) => {
		close(waiting);
		waiting = undefined;
		if (isPromptClaimed()) return;
		const title = summarizeTitle(event.title ?? (event.kind === "custom" ? question : undefined));
		const what = title ?? `a ${event.kind} dialog`;
		const entry: Waiting = {
			what,
			timer: setTimeout(() => {
				entry.sent = port().then(async (found) => {
					if (!found || waiting !== entry) return undefined;
					const result = await found.send({
						text: `⏳ pi (${basename(ctx.cwd)}) is waiting for an answer in the terminal:\n${what}`,
					});
					if (result.ok) return result.value;
					if (!isUnreachable(result)) {
						ctx.ui.notify(`prompt-notify: Telegram not reached (${result.reason}): ${result.message}`, "warning");
					}
					return undefined;
				});
			}, notifyAfterMs),
		};
		waiting = entry;
	});

	pi.on("ui_prompt_end", async () => {
		close(waiting);
		waiting = undefined;
	});

	pi.on("session_shutdown", async () => {
		if (waiting) clearTimeout(waiting.timer);
		waiting = undefined;
	});
}
