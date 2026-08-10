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

type Handler = (event: unknown, ctx: unknown) => Promise<unknown>;
type ToolCallResult = { block?: boolean; reason?: string } | undefined;
type ToolResultPatch = { content: Array<{ type: string; text?: string }> } | undefined;

/** Type stripping leaves the CJS default nested one level deeper. */
const entry = (guardModule as { default?: unknown }).default;
const guard = (typeof entry === "function" ? entry : (entry as { default?: unknown })?.default) as (
	pi: { on: (name: string, handler: Handler) => void },
) => void;

const handlers: Record<string, Handler> = {};
guard({
	on: (name, handler) => {
		handlers[name] = handler;
	},
});

const CWD = join(homedir(), ".config/pi/agent");
const ctx = { cwd: CWD, hasUI: false, ui: { notify: () => {}, select: async () => "Block" } };

const call = (toolName: string, path: string) =>
	handlers.tool_call({ toolName, input: { path } }, ctx) as Promise<ToolCallResult>;

test("guard registers the handlers it needs", () => {
	assert.deepEqual(Object.keys(handlers).sort(), ["tool_call", "tool_result", "user_bash"]);
});

test("credential paths are not writable", async () => {
	for (const path of [
		"~/.ssh/authorized_keys",
		"~/.gnupg/pubring.kbx",
		"~/.aws/config",
		"~/.aws/sso/cache/x.json",
		"~/.config/gcloud/x.json",
		"~/.config/rclone/rclone.conf",
		"~/.netrc",
		"~/.npmrc",
		"~/.ollama/id_ed25519",
		"~/.claude/settings.json",
		"~/.config/claude/settings.json",
		"~/.config/pi/agent/auth.json",
		"~/.pi/agent/auth.json",
		"auth.json", // relative to cwd
	]) {
		assert.equal((await call("write", path))?.block, true, `write ${path} should be blocked`);
		assert.equal((await call("edit", path))?.block, true, `edit ${path} should be blocked`);
	}
});

test("secret paths are not readable", async () => {
	for (const path of [
		"~/.ssh/id_ed25519",
		"~/.aws/credentials",
		"~/.aws/sso/cache/x.json",
		"~/.aws/cli/cache/session.db",
		"~/.config/gcloud/credentials.db",
		"~/.config/rclone/rclone.conf",
		"~/.ollama/id_ed25519",
		"~/.config/pi/agent/auth.json",
		"auth.json",
		"~/.config/pi/agent/sessions/x.jsonl",
		"~/.claude/sessions/x.jsonl",
		"~/.config/claude/history.jsonl",
		"~/.zsh_history",
		"~/.bash_history",
		"~/.python_history",
	]) {
		assert.equal((await call("read", path))?.block, true, `read ${path} should be blocked`);
	}
	assert.equal((await call("grep", "~/.gnupg"))?.block, true, "grep inside a secret dir should be blocked");
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
