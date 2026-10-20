/**
 * extensions/claude-usage.ts turns the anthropic-ratelimit-unified-* headers into the
 * plan usage shown in the status line. The header names are not a documented API
 * (pi-claude-bridge rebuilds them from Claude Code's rate_limit_event), so what the
 * parser accepts and how each window is labelled are pinned here.
 *
 * The module imports `getAgentDir` from pi at runtime, so it is loaded behind
 * tests/lib.ts's `redirectPiImports()` like statusline.test.ts.
 */

import assert from "node:assert/strict";
import { dirname, join } from "node:path";
import test from "node:test";
import { redirectPiImports } from "./lib.ts";

redirectPiImports();

const claudeUsage = await import(join(dirname(import.meta.dirname), "extensions/claude-usage.ts"));

type Window = { utilization: number; resetsAt?: number; model?: string };
const { parseHeaders, format } = claudeUsage as {
	parseHeaders: (headers: Record<string, string>) => [string, Window][];
	format: (cache: { windows: Record<string, Window> }) => string;
};

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
	assert.equal(text, "5h 35% · fable 17% · opus 10%");
});

test("a window past its reset reads 0% until the next response; a future one shows its reset", () => {
	assert.equal(format({ windows: { "5h": { utilization: 0.92, resetsAt: now() - hour } } }), "5h 0%");
	assert.match(format({ windows: { "5h": { utilization: 0.92, resetsAt: now() + hour } } }), /^5h 92% ~\S/);
});
