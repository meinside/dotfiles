/**
 * The vendored files must stay byte-identical to upstream except their `model:`
 * lines, because that clean diff is how an upstream change gets noticed. See
 * README.md, "Updating the vendored files".
 */

import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";
import { CONFIG_DIR, upstreamExamples } from "./lib.ts";

/** local path -> path under examples/extensions */
const PAIRS: Array<[string, string]> = [
	["extensions/subagent/index.ts", "subagent/index.ts"],
	["extensions/subagent/agents.ts", "subagent/agents.ts"],
	["extensions/git-checkpoint.ts", "git-checkpoint.ts"],
	["prompts/implement.md", "subagent/prompts/implement.md"],
	["prompts/scout-and-plan.md", "subagent/prompts/scout-and-plan.md"],
	["prompts/implement-and-review.md", "subagent/prompts/implement-and-review.md"],
	["agents/scout.md", "subagent/agents/scout.md"],
	["agents/planner.md", "subagent/agents/planner.md"],
	["agents/reviewer.md", "subagent/agents/reviewer.md"],
	["agents/worker.md", "subagent/agents/worker.md"],
];

const withoutModelLine = (text: string): string =>
	text
		.split("\n")
		.filter((line) => !line.startsWith("model:"))
		.join("\n");

test("upstream examples are installed", () => {
	assert.ok(
		existsSync(join(upstreamExamples(), "subagent")),
		`upstream examples not found in ${upstreamExamples()}`,
	);
});

for (const [rel, upstreamRel] of PAIRS) {
	test(`${rel} matches upstream`, (t) => {
		const local = join(CONFIG_DIR, rel);
		const upstream = join(upstreamExamples(), upstreamRel);
		assert.ok(existsSync(local), `${rel} missing locally`);
		assert.ok(existsSync(upstream), `${rel} missing upstream`);

		const mine = withoutModelLine(readFileSync(local, "utf8"));
		const theirs = withoutModelLine(readFileSync(upstream, "utf8"));
		if (mine !== theirs && process.env.PI_CHECK_VERBOSE === "1") {
			// diff's exit code is 1 for "differs", which execFileSync throws on
			try {
				execFileSync("diff", ["-u", local, upstream], { encoding: "utf8" });
			} catch (error) {
				const { stdout } = error as { stdout?: string };
				t.diagnostic(`\n${stdout ?? ""}`);
			}
		}
		assert.equal(mine, theirs, `${rel} drifted from upstream (-v prints the diff)`);
	});
}
