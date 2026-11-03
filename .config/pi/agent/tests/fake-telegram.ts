/**
 * pi-telegram as guard.ts and prompt-notify.ts see it through extensions/lib/telegram.ts:
 * records what was sent and edited, and taps a sent button the way the paired user's
 * phone would. `failure` is the reason every send fails with; target-unavailable is
 * every case where this pi has no Telegram chat to send to.
 */

import type {
	TelegramHandle,
	TelegramPort,
	TelegramUpdateHandler,
	TelegramView,
} from "../extensions/lib/telegram.ts";

export function fakeTelegram(failure?: string) {
	const sent: TelegramView[] = [];
	const edits: TelegramView[] = [];
	let handler: TelegramUpdateHandler | undefined;
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
	return { port, sent, edits, tap, registered: () => handler !== undefined };
}
