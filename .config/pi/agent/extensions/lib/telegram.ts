// pi-telegram's public delivery and update-handler APIs, for extensions that tell the
// user on Telegram that pi is waiting for them. Not an extension itself: pi only loads
// `index.ts` from a subdirectory, and this directory has none.
//
// pi-telegram is optional. Not installed, installed but not loaded, not connected, a
// Guest Mode turn, an API that changed shape, a failed send: every one of them comes
// back as "no Telegram", and the caller keeps asking in the TUI alone.
//
// The package is imported by path because nothing above `extensions/` has it in a
// node_modules. Inside pi the import goes through the extension loader's jiti, which
// resolves pi-telegram's own imports of pi's packages; plain node cannot, so under
// `node --test` the load fails and reports no Telegram, as it should.
import { fileURLToPath } from "node:url";

export type TelegramButton = { text: string; callback_data: string };
export type TelegramView = { text: string; parseMode?: "plain"; replyMarkup?: { inline_keyboard: TelegramButton[][] } };
export type TelegramHandle = {
	readonly target: { chatId: number; threadId?: number };
	readonly messageIds: readonly number[];
	readonly generation: string;
};
export type TelegramResult<T> = { ok: true; value: T } | { ok: false; reason: string; message: string };
export type TelegramUpdateHandler = (update: unknown) => "consume" | "pass" | Promise<"consume" | "pass">;

/** What the callers use, already narrowed to this pi instance's chat. */
export interface TelegramPort {
	/**
	 * Sends to the chat or Thread of the Telegram turn in progress, else to this
	 * instance's own Thread (the paired chat in Classic Mode): a prompt left waiting
	 * by work started at the terminal is as stuck as one from a Telegram turn.
	 */
	send(view: TelegramView): Promise<TelegramResult<TelegramHandle>>;
	edit(handle: TelegramHandle, view: TelegramView): Promise<TelegramResult<TelegramHandle>>;
	/** Whether a Telegram-owned turn is in progress, probed with a typing action. */
	isTelegramTurn(): Promise<boolean>;
	/** Sees every update before pi-telegram routes it; returns the unregister function. */
	onUpdate(handler: TelegramUpdateHandler): () => void;
}

const PACKAGE_DIR = fileURLToPath(new URL("../../npm/node_modules/@llblab/pi-telegram", import.meta.url));
const ACTIVE_TURN = { scope: { kind: "active-turn" } } as const;
const INSTANCE = { scope: { kind: "instance" } } as const;

const failed = (message: string) => ({ ok: false, reason: "transport-failed", message }) as const;

/**
 * How long a terminal prompt waits before Telegram hears of it. Someone at the
 * terminal answers well within this, so only a prompt left unattended pings the
 * phone; immediate sends turned every confirmation into a notification.
 */
export const NOTIFY_AFTER_MS = 30_000;

/**
 * Failures that only mean this pi has no Telegram to reach (not connected, no
 * Thread assigned, pi-telegram not loaded); any other one is worth reporting.
 */
export const isUnreachable = (result: TelegramResult<unknown>): boolean =>
	!result.ok && (result.reason === "target-unavailable" || result.reason === "runtime-unavailable");

// A prompt whose extension sends its own Telegram message (guard.ts, with buttons)
// is claimed for its lifetime, so prompt-notify.ts does not announce it a second
// time. On globalThis because pi loads each extension, and what it imports, apart.
const CLAIMS = Symbol.for("pi-agent.telegram-prompt-claims");
const claims = globalThis as { [CLAIMS]?: number };

/** Marks the terminal prompt about to open as announced by its caller; call the result once it closes. */
export function claimPrompt(): () => void {
	claims[CLAIMS] = (claims[CLAIMS] ?? 0) + 1;
	let released = false;
	return () => {
		if (released) return;
		released = true;
		claims[CLAIMS] = Math.max(0, (claims[CLAIMS] ?? 1) - 1);
	};
}

export const isPromptClaimed = (): boolean => (claims[CLAIMS] ?? 0) > 0;

/** `undefined` when the package or any function used here is missing. */
export async function loadTelegramPort(packageDir = PACKAGE_DIR): Promise<TelegramPort | undefined> {
	try {
		const delivery = await import(`${packageDir}/dist/api/delivery.js`);
		const updates = await import(`${packageDir}/dist/api/updates.js`);
		const { sendTelegramView, editTelegramView, sendTelegramChatAction } = delivery;
		const { registerTelegramUpdateHandler } = updates;
		const used = [sendTelegramView, editTelegramView, sendTelegramChatAction, registerTelegramUpdateHandler];
		if (used.some((fn) => typeof fn !== "function")) return undefined;
		// A throw or a result of another shape is a pi-telegram that changed: no Telegram.
		const guarded = async <T>(run: () => Promise<TelegramResult<T>>): Promise<TelegramResult<T>> => {
			try {
				const result = await run();
				return typeof result?.ok === "boolean" ? result : failed("unexpected result");
			} catch (error) {
				return failed(String(error));
			}
		};
		return {
			send: async (view) => {
				const result = await guarded(() => sendTelegramView(view, ACTIVE_TURN));
				return !result.ok && result.reason === "target-unavailable"
					? guarded(() => sendTelegramView(view, INSTANCE))
					: result;
			},
			edit: (handle, view) => guarded(() => editTelegramView(handle, view)),
			isTelegramTurn: async () => (await guarded(() => sendTelegramChatAction("typing", ACTIVE_TURN))).ok,
			onUpdate: (handler) => {
				try {
					const off = registerTelegramUpdateHandler(handler);
					return typeof off === "function" ? off : () => {};
				} catch {
					return () => {};
				}
			},
		};
	} catch {
		return undefined;
	}
}
