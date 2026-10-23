// Turns `ask_user` away during a Telegram-originated turn.
//
// pi-ask-user draws its question in the terminal (`ctx.ui.custom`), which the user on
// Telegram never sees, so the turn would sit there until someone answers at the
// machine. pi-telegram's own way to ask is to end the reply with `telegram_button`
// choices: a tapped button arrives as the next prompt. The block reason says so, and
// the model asks again that way.
//
// Outside a Telegram turn, and wherever pi-telegram is missing or not connected,
// `ask_user` runs untouched (extensions/lib/telegram.ts decides which is which).
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { loadTelegramPort, type TelegramPort } from "./lib/telegram.ts";

export const REASON =
	"ask_user cannot be answered in this turn: it came from Telegram, where the user sees only your reply, " +
	"not the terminal prompt. Ask by ending your reply with the question and telegram_button choices " +
	"(telegram-bridge skill), then stop; the user's tap arrives as the next message.";

/** `loadTelegram` is a parameter so tests can stand in for pi-telegram; pi passes only `pi`. */
export default function (pi: ExtensionAPI, loadTelegram: () => Promise<TelegramPort | undefined> = loadTelegramPort) {
	let telegram: Promise<TelegramPort | undefined> | undefined;

	pi.on("tool_call", async (event) => {
		if (event.toolName !== "ask_user") return undefined;
		telegram ??= loadTelegram();
		const found = await telegram;
		if (!found || !(await found.isTelegramTurn())) return undefined;
		return { block: true, reason: REASON };
	});
}
