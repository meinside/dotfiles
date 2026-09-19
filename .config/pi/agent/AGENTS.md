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

## Fetching web content

- A fetched page that comes back suspiciously empty or all boilerplate — a few bytes, a login/consent/bot-check wall, navigation with no article — is a failure, not the answer: say so instead of reasoning from it, never let it stand as a cached success, and name which source did answer. When one site fails that way twice, propose a durable fix instead of working around it again.

## Writing docs and comments

- A README answers what something is, where it lives and where to change it. The
  experiment that settled a value, the alternatives measured and rejected, and the
  statistics behind them are not that: they push the answer further down the page. Keep
  only what a reader needs to act.
- Where a reason is worth keeping because the mistake would otherwise repeat, put it next
  to the thing it constrains — a comment on the tunable, the config key, the test — not in
  a document a page away. A comment beside the value is read when the value is edited; a
  document is not, and drifts unnoticed.
- Do not state the same thing in two places. If the source already explains it, the README
  points at the source instead of restating it: two copies diverge, and there is no way to
  tell which one is current.

## Before committing

- Read the diff of what is staged before committing, not just the file list. `git add`
  taken earlier does not describe what the file says now.
- Look for what must not leave the machine: credentials and tokens, account and project
  ids, absolute home paths, internal hostnames, and personal identifiers belonging to
  anyone — including third parties whose account name, post id or address arrived as a
  test fixture, a sample URL or an error message copied from a real run. A neutral value
  of the same shape tests the same code.
- Point the check at every staged file, not the ones that look risky. A secrets scanner
  and a sample-file check cover the files they were written for; the leak arrives in the
  one nobody classified as sensitive.
- When something is found, say what it was and where, rather than quietly rewriting it:
  a value already committed needs history rewritten and the credential rotated, which is
  the owner's decision, not a cleanup.

## Reporting

- Separate what you verified from what you did not, and name what you could not check. Unverified work described as done is worse than work reported as incomplete.
