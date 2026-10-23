/**
 * extensions/lib/telegram.ts is how guard.ts and ask-user-telegram.ts reach
 * pi-telegram, which is optional. Every way of it not being there has to come back
 * as "no Telegram", or a missing package would break confirmations and ask_user
 * instead of leaving them to the terminal. Fake packages in a temp dir stand in for
 * the cases this machine does not have; the last case reads the installed package,
 * so an update that moves or renames the API fails here rather than silently turning
 * the Telegram path off.
 */

import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import * as askModule from "../extensions/ask-user-telegram.ts";
import { loadTelegramPort, type TelegramPort } from "../extensions/lib/telegram.ts";
import { CONFIG_DIR } from "./lib.ts";

const DELIVERY = `
export async function sendTelegramView(view, options) { return globalThis.__fakeSend(view, options); }
export async function editTelegramView() { return { ok: true, value: {} }; }
export async function sendTelegramChatAction(action, options) { return globalThis.__fakeSend({ action }, options); }
`;
const UPDATES = `export function registerTelegramUpdateHandler() { return globalThis.__fakeRegister(); }`;

const made: string[] = [];
test.after(() => {
	for (const dir of made) rmSync(dir, { recursive: true, force: true });
});

/** A pi-telegram package dir holding the given dist/api files. */
function fakePackage(files: Record<string, string>): string {
	const dir = mkdtempSync(join(tmpdir(), "fake-pi-telegram-"));
	made.push(dir);
	mkdirSync(join(dir, "dist/api"), { recursive: true });
	writeFileSync(join(dir, "package.json"), '{"type":"module"}');
	for (const [name, text] of Object.entries(files)) writeFileSync(join(dir, "dist/api", name), text);
	return dir;
}

const fakes = globalThis as { __fakeSend?: (...args: unknown[]) => unknown; __fakeRegister?: () => unknown };

test("no package, or one missing a function, is no Telegram", async () => {
	assert.equal(await loadTelegramPort(join(tmpdir(), "no-such-pi-telegram")), undefined);
	assert.equal(await loadTelegramPort(fakePackage({ "delivery.js": DELIVERY })), undefined);
	const noEdit = DELIVERY.replace("editTelegramView", "renamedEditView");
	assert.equal(await loadTelegramPort(fakePackage({ "delivery.js": noEdit, "updates.js": UPDATES })), undefined);
});

test("sends go to the active turn; throws and odd results become failures", async () => {
	const port = await loadTelegramPort(fakePackage({ "delivery.js": DELIVERY, "updates.js": UPDATES }));
	assert.ok(port);
	const scopes: unknown[] = [];
	fakes.__fakeSend = (_view, options) => {
		scopes.push(options);
		return { ok: true, value: { target: { chatId: 1 }, messageIds: [1], generation: "g" } };
	};
	assert.equal((await port.send({ text: "x" })).ok, true);
	assert.equal(await port.isTelegramTurn(), true);
	assert.deepEqual(scopes, [{ scope: { kind: "active-turn" } }, { scope: { kind: "active-turn" } }]);

	for (const send of [
		() => ({ ok: false, reason: "target-unavailable", message: "" }), // local turn, Guest Mode, not connected
		() => ({ ok: false, reason: "runtime-unavailable", message: "" }), // installed, not loaded
		() => {
			throw new Error("boom");
		},
		() => "something else", // an API that changed shape
	]) {
		fakes.__fakeSend = send;
		assert.equal((await port.send({ text: "x" })).ok, false);
		assert.equal(await port.isTelegramTurn(), false);
	}
});

test("a failing update registration leaves a harmless unregister", async () => {
	const port = await loadTelegramPort(fakePackage({ "delivery.js": DELIVERY, "updates.js": UPDATES }));
	assert.ok(port);
	fakes.__fakeRegister = () => {
		throw new Error("boom");
	};
	assert.doesNotThrow(() => port.onUpdate(() => "pass")());
	fakes.__fakeRegister = () => undefined;
	assert.doesNotThrow(() => port.onUpdate(() => "pass")());
});

type ToolCall = (event: { toolName: string }) => Promise<{ block?: boolean; reason?: string } | undefined>;

async function askWith(telegram: TelegramPort | undefined): Promise<ToolCall> {
	let handler: ToolCall | undefined;
	const extension = askModule.default as unknown as (
		pi: { on: (name: string, h: ToolCall) => void },
		load: () => Promise<TelegramPort | undefined>,
	) => void;
	const on = (_name: string, h: ToolCall) => {
		handler = h;
	};
	extension({ on }, async () => telegram);
	assert.ok(handler);
	return handler;
}

const turn = (isTelegram: boolean): TelegramPort => ({
	send: async () => ({ ok: false, reason: "unused", message: "" }),
	edit: async () => ({ ok: false, reason: "unused", message: "" }),
	isTelegramTurn: async () => isTelegram,
	onUpdate: () => () => {},
});

test("ask_user is turned to telegram_button only in a Telegram turn", async () => {
	const inTelegram = await askWith(turn(true));
	assert.deepEqual(await inTelegram({ toolName: "ask_user" }), { block: true, reason: askModule.REASON });
	assert.match(askModule.REASON, /telegram_button/);
	assert.equal(await inTelegram({ toolName: "bash" }), undefined);
	assert.equal(await (await askWith(turn(false)))({ toolName: "ask_user" }), undefined);
	assert.equal(await (await askWith(undefined))({ toolName: "ask_user" }), undefined);
});

test("the installed pi-telegram still exports what extensions/lib/telegram.ts calls", (t) => {
	const dir = join(CONFIG_DIR, "npm/node_modules/@llblab/pi-telegram");
	if (!existsSync(dir)) return t.skip("pi-telegram not installed; guard and ask_user stay terminal-only");
	const { version } = JSON.parse(readFileSync(join(dir, "package.json"), "utf8"));
	// Read, not imported: its modules import pi's packages, which only pi's loader resolves.
	const api = (name: string) => readFileSync(join(dir, "dist/api", name), "utf8");
	for (const [file, names] of [
		["delivery.js", ["sendTelegramView", "editTelegramView", "sendTelegramChatAction"]],
		["updates.js", ["registerTelegramUpdateHandler"]],
	] as const) {
		assert.ok(existsSync(join(dir, "dist/api", file)), `pi-telegram ${version} has no dist/api/${file}`);
		for (const name of names) {
			assert.match(api(file), new RegExp(`\\b${name}\\b`), `pi-telegram ${version}: ${file} no longer exports ${name}`);
		}
	}
});
