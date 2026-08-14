/**
 * extensions/git-checkpoint.ts and extensions/statusline.ts both shell out to
 * `git` directly (`pi.exec`/`execFile`), not through pi's own read/write/edit
 * tool layer, so a machine without git on PATH doesn't get a friendly error
 * from either one at the point of use \u2014 checkpointing silently no-ops
 * (git-checkpoint.ts already treats a failed `git stash create` as "nothing to
 * stash") and the footer's branch/status segment just goes blank. Same
 * go/no-go framing as sandbox-deps.test.ts, split into its own file since it
 * has nothing to do with pi-sandbox specifically \u2014 these two extensions need
 * git regardless of whether sandboxing is even installed.
 */

import assert from "node:assert/strict";
import test from "node:test";
import { resolveCommand } from "./lib.ts";

test("git is installed (git-checkpoint.ts and statusline.ts require it)", () => {
	assert.ok(resolveCommand("git"), "git not found on PATH");
});
