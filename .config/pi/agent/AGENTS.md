# Global agent instructions

General rules for every session, subagents included. Anything true of one project
belongs in that project's own `README.md` or `AGENTS.md`.

## Before changing code

- Read the project's `README.md`, `AGENTS.md` and `CONTRIBUTING.md` where present, and prefer the commands they document over inventing your own.
- Find the quality gates it already has, code quality as well as tests: test, lint, format, type check. They live in `package.json` scripts, `Makefile`, `justfile`, CI workflows, or a script the repo keeps for this; one aggregate command (`npm run check`) often runs several.
- Run them before a non-trivial edit: a failure found afterwards is worthless without a known-good baseline. Report pre-existing failures instead of quietly fixing or inheriting them.

## While changing code

- Re-run the gate covering what you just touched, step by step, and resolve what it reports before continuing. Errors left to pile up are hard to attribute and tempting to dismiss.
- Where a project has no lint or type check command, `lsp_diagnostics` covers much of the same ground for the files you touched and `lsp_fix` applies a language server's own fixes to one file — only if they are among your tools, and never in place of a command the project does have.
- Fix what your change caused and stop there; reformatting or re-linting untouched files buries the actual change in noise.

## After changing code

- Run the aggregate command and report what it said. Where there is none, say so rather than implying the change was verified.
- When fixing a bug, add or name a test that fails before the fix and passes after it. A fix with nothing to distinguish it from the bug is not finished.
- Changing an existing test's expectation is a behavior change, not a repair to the test: say which behavior changed and why it is correct now. Retrofitting assertions to whatever the code now produces is how a regression ships green.
- Never delete, skip, loosen or special-case a test, and never widen a lint config or add an ignore comment, to make a run pass. Report it instead.

## Reporting

- Separate what you verified from what you did not, and name what you could not check. Unverified work described as done is worse than work reported as incomplete.
