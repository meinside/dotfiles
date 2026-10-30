/**
 * extensions/claude-usage.ts turns the anthropic-ratelimit-unified-* headers into the
 * plan usage shown in the status line. The header names are not a documented API
 * (pi-claude-bridge rebuilds them from Claude Code's rate_limit_event), so what the
 * parser accepts and how each window is labelled are pinned here.
 */

import assert from "node:assert/strict";
import { homedir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { cacheFile, format, parseHeaders } from "../extensions/claude-usage.ts";

test("the cache lives in XDG cache, outside the agent dir", (t) => {
	const saved = process.env.XDG_CACHE_HOME;
	t.after(() => {
		if (saved === undefined) delete process.env.XDG_CACHE_HOME;
		else process.env.XDG_CACHE_HOME = saved;
	});
	process.env.XDG_CACHE_HOME = "/xdg/cache";
	assert.equal(cacheFile(), "/xdg/cache/pi/claude-usage.json");
	delete process.env.XDG_CACHE_HOME;
	assert.equal(cacheFile(), join(homedir(), ".cache/pi/claude-usage.json"));
});

/** Marks each painted piece as <color:text>, so the test sees which colour got what. */
const tag = (color: string, text: string) => `<${color}:${text}>`;

const hour = 3600;
const now = () => Math.floor(Date.now() / 1000);

test("headers become windows; ones without utilization and unrelated ones are dropped", () => {
	const windows = Object.fromEntries(
		parseHeaders({
			"Anthropic-Ratelimit-Unified-5h-Utilization": "0.35",
			"anthropic-ratelimit-unified-5h-reset": "1792490400",
			"anthropic-ratelimit-unified-7d_oi-utilization": "0.17",
			"anthropic-ratelimit-unified-7d-reset": "1792663200",
			"anthropic-ratelimit-unified-status": "allowed",
			"anthropic-ratelimit-unified-reset": "1792490400",
			"anthropic-ratelimit-unified-overage-utilization": "n/a",
			"content-type": "application/json",
		}),
	);
	assert.deepEqual(windows, {
		"5h": { utilization: 0.35, resetsAt: 1792490400 },
		"7d_oi": { utilization: 0.17 },
	});
});

test("labels: the model window takes its model's name, seven_day_ is shortened", () => {
	const text = format({
		windows: {
			"5h": { utilization: 0.354 },
			"7d_oi": { utilization: 0.17, model: "fable" },
			seven_day_opus: { utilization: 0.1 },
		},
	});
	assert.equal(text, "📊 5h 35% · fable 17% · opus 10%");
	assert.equal(format({ windows: {} }), "", "no windows, no lone icon");
});

test("only the percentage is coloured: warning above 40, error above 70, by the shown value", () => {
	const colorOf = (utilization: number) =>
		/<(\w+):\d+%>/.exec(format({ windows: { "5h": { utilization } } }, tag))?.[1];
	assert.equal(colorOf(0.404), "text"); // shown as 40%
	assert.equal(colorOf(0.41), "warning");
	assert.equal(colorOf(0.7), "warning");
	assert.equal(colorOf(0.705), "error"); // shown as 71%
	assert.equal(colorOf(1), "error");

	const text = format({ windows: { "5h": { utilization: 0.92, resetsAt: now() + hour }, "7d": { utilization: 0.2 } } }, tag);
	assert.match(text, /^📊 <text:5h ><error:92%><text: ~[^>]+><text: · ><text:7d ><text:20%>$/);
	// A window past its reset is plain 0%, whatever it read before.
	assert.equal(format({ windows: { "5h": { utilization: 0.92, resetsAt: now() - hour } } }, tag), "📊 <text:5h 0%>");
});

test("a window past its reset reads 0% until the next response; a future one shows its reset", () => {
	assert.equal(format({ windows: { "5h": { utilization: 0.92, resetsAt: now() - hour } } }), "📊 5h 0%");
	assert.match(format({ windows: { "5h": { utilization: 0.92, resetsAt: now() + hour } } }), /^📊 5h 92% ~\S/);
});
