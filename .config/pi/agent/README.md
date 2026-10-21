# pi coding agent config

Config directory for [pi](https://github.com/earendil-works/pi-mono) (`pi-coding-agent`).

**pi does not support XDG paths.** `getAgentDir()` returns `$PI_CODING_AGENT_DIR`,
else `~/.pi/agent`. `~/.zshrc` exports the variable and a committed
`~/.pi -> .config/pi` symlink covers the fallback, so packages that build their own
`~/.pi/agent` path land here too. Read `~/.pi/agent` in upstream docs as "this
directory".

## Files

| Path | Tracked in dotfiles | Purpose |
|------|---------------------|---------|
| `settings.json` | `.sample` mirror | Theme, default model, `enabledModels` for `Ctrl+P` cycling, `defaultTools` (`+codemode`, so scripts can call classifier and image models through `models`) |
| `models.json` | `.sample` only | Providers, models, tier aliases. Holds the AWS account ID whenever it carries Bedrock ARNs |
| `claude-bridge.json` | `.sample` mirror | `pi-claude-bridge` config: `provider.plan` (`max` unlocks 1M-context Opus), `askClaude.enabled: false` |
| `auth.json` | `.sample` template | Credentials. Never commit the real file. The sample is a template, not a mirror |
| `models-store.json` | no | Generated model catalog cache. Do not edit or commit; `check.sh` reads it to cross-check prices |
| `pi-lsp.json` | yes | Language server routes ([notes](#language-servers-pi-lsp)) |
| `magpi.json` | yes | MagPi config: 100 MB cache budget, `allowPrivateNetwork: false` |
| `magpi-render.json` | no | Optional `extensions/magpi-render.ts` overrides: `enabled`, `browserBinary`, `renderHosts`, `learnHosts`, `sameSiteOnlyHosts`, `maxWaitMs`. Absent means defaults, which is the state here ([notes](#magpi-renderer)) |
| `mcp.json` | `.sample` mirror | Servers for pi's built-in MCP client, reached from `codemode` scripts. Tokens go in as `${VAR}` from `~/.custom_env`, never literally: unlike `auth.json` the file is readable by the agent (`samples.test.ts` enforces it) |
| `mcp-auth.json` | no | Built-in MCP OAuth tokens, written by `/mcp login`. Write- and read-blocked like `auth.json` |
| `telegram.json` | no | `@llblab/pi-telegram` config, written by `/telegram-setup`. The bot token should be the `$TELEGRAM_BOT_TOKEN` reference, not the value ([setup](#new-machine-setup)); write- and read-blocked like `auth.json` either way |
| `sandbox.json` | yes | `pi-sandbox` policy ([notes](#sandbox-extension)). Mutated live by `/sandbox-allow ... for all projects`, so tracking turns that prompt into a `git diff` |
| `quota-rotate.json` | `.sample` mirror | `pi-quota-rotate`'s fallback chain of `provider/modelId` entries, plus `maxRotationsPerRun`. Real file is local; `quota-rotate.test.ts` checks that it and the sample still resolve |
| `quota-rotate/` | no | `pi-quota-rotate`'s rotation state |
| `magpi-cache/` | no | MagPi's fetch cache. `~/.pi/agent/magpi-cache` in MagPi's docs is this same directory through the `~/.pi` symlink |
| `../cost-tracker/` | no | Cost ledger, one JSONL per day under `YYYY/MM/`. Outside this directory: `~/.pi/cost-tracker` through the symlink. Entries from the Bedrock era contain ARNs |
| `npm/`, `git/` | no | `pi install` targets for `npm:` and `git:` packages. Each ships its own `.gitignore` with `*` |
| `cache/` | no | `claude-usage.json`: the last plan usage seen, shared by every running pi session |
| `tmp/` | no | Extension state: `magpi-render/` (learned hosts), `pi-telegram/` (bridge runtime, inbox, logs) |
| `install/`, `bin/pi` | no | pi itself, from `pi.dev/install.sh`: `bin/pi` runs `install/releases/<install/current-version>/`. Managed by `pi update`; do not edit |
| `extensions/subagent/` | yes | Vendored subagent extension ([notes](#vendored-subagent-extension)) |
| `extensions/guard.ts` | yes | Blocks writes to credential files, confirms installs, irreversible commands and MCP calls not marked safe |
| `extensions/git-checkpoint.ts` | yes | Vendored upstream example: per-turn git stash checkpoints for `/fork` |
| `extensions/statusline.ts` | yes | Claude Code style footer ([notes](#statusline-extension)) |
| `extensions/claude-usage.ts` | yes | Claude plan usage (`5h`, `7d`, and the active model's weekly window) with reset times, at the end of the statusline ([notes](#statusline-extension)) |
| `extensions/compaction-summary.ts` | yes | Gives the compaction summary room without shrinking the context window ([notes](#compaction-extensions)) |
| `compaction-summary.json` | no | Optional `extensions/compaction-summary.ts` overrides: `reserveTokens`, `summarizerModel`, `triggerRatio`. Absent means defaults; a Bedrock id belongs here, not in the tracked extension |
| `extensions/magpi-render.ts` | yes | Reads JavaScript-rendered pages through Firefox over WebDriver BiDi ([notes](#magpi-renderer)) |
| `extensions/magpi-handlers.ts` | yes | Local MagPi fetch handlers: reddit, Discourse, naver blog ([notes](#magpi-handlers)) |
| `AGENTS.md` | yes | [Global instructions](#global-instructions-agentsmd) for every session and subagent |
| `agents/*.md` | yes | Subagent definitions |
| `prompts/*.md` | yes | Prompt templates, invoked as `/name` |
| `check.sh` | yes | Entry point for the checks |
| `tests/*.ts` | yes | The checks. `lib.ts` is shared helpers, the rest run standalone under `node --test` |
| `../../llama.cpp/config.ini` | yes | Router-level llama.cpp config, auto-loaded by every llama.cpp binary ([notes](#llamacpp-provider)) |
| `../../llama.cpp/models.ini` | yes | Router model presets, pointed at by `$LLAMA_ARG_MODELS_PRESET` |

`~/.gitignore` ignores `.config/` wholesale, so tracked files here were added with
`git add -f`. Files holding secrets or machine-specific values are committed as
`<name>.sample` with `<<<placeholder>>>` markers. `claude-bridge.json` has no
placeholder but is a `.sample` too: `provider.plan` depends on whose Claude account the
machine uses. Files with nothing to placeholder (`pi-lsp.json`, `sandbox.json`, both
`llama.cpp/*.ini`) are tracked directly.

## Global instructions (AGENTS.md)

pi's *global* context file: `loadProjectContextFiles` reads the agent directory first,
then `AGENTS.md` / `CLAUDE.md` from cwd and every ancestor. It reaches subagents too.

- **General rules only** — per-project rules belong in that project's own `AGENTS.md`,
  notes about this directory in this README.
- **Short and publishable**: billed on every turn of every session and subagent.
- **Keep it in *this* directory.** The ancestor walk stops at the filesystem root, so an
  `AGENTS.md` at `~` would load into every session under the home directory.

## Vendored subagent extension

pi ships no built-in sub-agents, so tiered model usage comes from the upstream
`subagent` example extension, vendored here.

- **Upstream repo:** <https://github.com/earendil-works/pi-mono>
- **Upstream path:** `packages/coding-agent/examples/extensions/subagent/`
- **Local copy of upstream:** resolved by `tests/lib.ts`'s `piPackageDir()` — `brew --prefix pi-coding-agent`, else the real path of the `pi` binary on `PATH` (npm installs), else that binary's managed-install release (`pi.dev/install.sh`)
- **Vendored from:** pi 1.3.0

Each delegation spawns a separate `pi` process with its own context window. Agents
come from `agents/*.md`.

### Agents

| Agent | `model:` | Upstream model | Tools | Role |
|-------|----------|----------------|-------|------|
| `scout` | `tier:fast:low` | `claude-haiku-4-5` | read, grep, find, ls, bash | Fast recon, returns compressed context |
| `planner` | `tier:strong:high` | `claude-sonnet-4-5` | read, grep, find, ls | Implementation plan, makes no changes |
| `reviewer` | `tier:strong:high` | `claude-sonnet-4-5` | read, grep, find, ls, bash | Code review, read-only bash |
| `worker` | `tier:mid:medium` | `claude-sonnet-4-5` | all | The actual implementation |

The `model:` line is the only local edit in these files; the `Upstream model`
column is what to re-apply after an upstream update.

Every agent must pin a tier **and** a thinking level:

- No `model:` line means the agent inherits the dispatching session's model *and*
  thinking level, so "fast recon" follows whatever `/model` is on.
- With a `model:` pin, `--thinking` is deliberately not passed, so
  `settings.json`'s `defaultThinkingLevel` would apply instead.
- `tier:fast:low` still resolves the pattern `tier:fast`, because a trailing
  level is consumed first ([rules](#rules-the-tokens-must-obey)).

Do not "upgrade" `worker` to the top tier — upgrade `planner` so `worker` needs
less rework.

### Workflow prompt templates

| Command | Chain |
|---------|-------|
| `/implement <task>` | scout → planner → worker |
| `/scout-and-plan <task>` | scout → planner (no implementation) |
| `/implement-and-review <task>` | worker → reviewer → worker |

Ad-hoc delegation works too (`Run 2 scouts in parallel: ...`; max 8 tasks, 4
concurrent, `Ctrl+O` expands output and per-step cost).

### Updating the vendored files

The vendored files are byte-identical to upstream except the `model:` lines, which the
comparison ignores. Run after every `pi update` and before committing:

```bash
~/.config/pi/agent/check.sh      # -v to print the diffs
```

When it reports drift:

```bash
U="$(./check.sh 2>&1 | head -1 | sed -E 's/.*upstream: //')"
C=~/.config/pi/agent

diff -u $C/extensions/subagent/index.ts $U/subagent/index.ts   # inspect first

cp $U/subagent/index.ts $U/subagent/agents.ts $C/extensions/subagent/
cp $U/git-checkpoint.ts $C/extensions/
cp $U/subagent/prompts/*.md $C/prompts/
cp $U/subagent/agents/*.md $C/agents/     # then re-apply the tiers from the
                                          # Agents table
~/.config/pi/agent/check.sh                # then bump "Vendored from" above
```

## Guard extension

pi has no tool permission system: built-in tools run with the permissions of the pi
process. `extensions/guard.ts` is the narrow middle ground — patterns live in the file:

- **Blocked, never confirmed (writes):** `~/.ssh`, `~/.gnupg`, `~/.aws`,
  `~/.config/gcloud`, `~/.config/rclone`, `~/.netrc`, `~/.npmrc`,
  `~/.ollama/id_ed25519`, `~/.custom_env`, `auth.json`, `mcp-auth.json`,
  `telegram.json`, Claude's `settings.json`.
- **Also unreadable** through `read`/`grep`: most of the above plus transcript stores
  (`sessions/`, `history.jsonl`, shell histories). `~/.aws/config` and Claude's
  `settings.json` stay readable; transcripts are read-blocked but not write-blocked.
- **Ask once:** package managers, irreversible git/filesystem operations. Read-only and
  reversible forms are excluded.
- **Ask once, MCP:** every `mcp__*` call, `codemode` scripts included, unless its
  server's annotations mark it safe. The rule is pi's own (`needsApproval` in the file);
  a server that prompts too often needs `readOnlyHint` on its tools, not an exception
  here.
- **No UI (`-p`, `--mode json`): a match is blocked**, so headless runs fail loudly. `!`
  commands go through `user_bash` and enforce only that rule.

Two limits: the read block is **not a boundary** (`bash` can `cat` anything — that is
what `pi-sandbox` is for), and command matching is substring-based over the whole
command, so it also trips on a pattern quoted inside an unrelated script. `grep` at an
ancestor is allowed, with offending lines stripped from the result.

## Sandbox extension

[`pi-sandbox`](https://github.com/carderne/pi-sandbox) gives `bash` a real OS
boundary (Seatbelt on macOS, bubblewrap + seccomp on Linux via
`@carderne/sandbox-runtime`); `read`/`write`/`edit` get the same filesystem policy
applied in-process. Policy is `sandbox.json`.

Commands: `/sandbox` shows the active policy and session allowances, `Alt+S`
toggles for the session, `/sandbox-allow {read,write,domain} <path>` extends
`allowRead`/`allowWrite`/`allowedDomains` — once, for the session, for this project
(`.pi/sandbox.json`), or for all projects (this file).

Rules that decide how entries are written:

- **`allowWrite` also grants read**, so a cache directory holding a credential at its root
  is scoped to the subdirectory (`cargo/registry`, `gem/specs`), with the credential files
  in `denyWrite` on top. `denyWrite` always wins and is never prompted.
- **A wildcard does not cover the bare domain at the enforcing layer**, so a domain
  present only as `*.example.com` is hard-blocked *without a prompt*. Every apex host a
  tool hits is listed literally next to its wildcard (`BARE_DOMAINS_TOOLS_NEED`).
- **`allowRead: "."` re-opens this directory when pi runs in it**, credentials included.
  `mcp-auth.json` and `telegram.json` are `denyRead` on top; `auth.json` is not, because
  the checks read it (`AGENT_DIR_SECRETS` in `tests/sandbox.test.ts`).
- **Execute is a read**, so every `PATH` directory must be readable or `command -v`
  reports installed tools as missing.
- **A package's data directory can sit outside the workspace**: `~/.pi/cost-tracker`, its
  symlink twin under `~/.config`, and `~/.pi/agent/magpi-cache` are listed read-only —
  tools write them in-process.
- **A `~/.pi/...` entry only helps the in-process tools, not `bash`**, which gets `EPERM`
  on that spelling because the home root is `denyRead`. Use `~/.config/pi/...` in
  commands; the paths `magpi_fetch` returns must be rewritten.
- **`~/.config/llama.cpp` is `allowRead`** so `tests/llama.test.ts` checks instead of
  skipping; not `allowWrite`, because `edit`/`write` leave a reviewable diff.
- **`allowBrowserProcess` stays `false`** — it would make Chrome's cookie and login-data
  stores bash-readable.
- **`~/.tool-versions` must be readable** even though the home root is `denyRead`, or asdf
  silently resolves a different version. Toolchains are XDG-relocated
  (`~/.local/share/{asdf,cargo,rustup,npm,pipx,uv}`).
- **`$TMPDIR` is `/tmp/claude`**, created by `sandbox-runtime`. Only `/tmp` (and
  `/private/tmp`) is writable, and the variable outlives the directory when the sandbox is
  switched off mid-session — anything calling `os.tmpdir()` must `mkdirSync` it first.

**When a `sandbox.json` edit takes effect:** at `session_start`, on `/sandbox-enable`
after a disable, and — the surprising one — on granting *any* permission prompt.

**Probing the policy honestly:** a granted domain prompt whitelists that host for the
session and is invisible to the agent, so a `200` proves nothing. Read domain results
only from a session where `/sandbox` lists no allowances, or from outside pi:

```bash
# expands ~ and folds allowWrite into allowRead the way buildRuntimeConfig() does
node .../@carderne/sandbox-runtime/dist/cli.js -s <that file> -c '<command>'
```

`tests/sandbox.test.ts` pins the committed JSON, not the live effect;
`tests/sandbox-deps.test.ts` checks the OS helpers (`rg`; `bwrap`/`socat` on Linux).

### Troubleshooting: `apply-seccomp: ... nested userns ... CAP_SYS_ADMIN` on Ubuntu 24.04+

Every `bash` command inside pi fails while a bare `bwrap --unshare-all ... echo ok` works:
`apply-seccomp` needs a *nested* unprivileged userns, which Ubuntu's
`bwrap-userns-restrict` AppArmor profiles block regardless of the
`kernel.apparmor_restrict_unprivileged_userns` sysctl. Confirm with `sudo aa-status` and
`sudo dmesg | grep -i apparmor` (`capname="sys_admin"`). macOS is unaffected.

```bash
sudo aa-complain bwrap unpriv_bwrap unprivileged_userns      # does NOT survive reboot

# persistent:
sudo sed -i 's/flags=(attach_disconnected, mediate_deleted)/flags=(attach_disconnected, mediate_deleted, complain)/' /etc/apparmor.d/bwrap-userns-restrict
sudo apparmor_parser -r /etc/apparmor.d/bwrap-userns-restrict

# revert:
sudo aa-enforce bwrap unpriv_bwrap unprivileged_userns
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=1
```

A scoped override that keeps the profiles enforcing does not work: the blanket `audit deny
capability,` wins, and `no_new_privs` blocks exec transitions to another profile.

## Statusline extension

`extensions/statusline.ts` replaces pi's footer with a three-line layout (`user@host
📂dir (branch*)`, then model/context/cost/tokens/durations, then other extensions'
`ctx.ui.setStatus()`). `/statusline` toggles back; the choice lives on `globalThis`, so
`/fork` and `/reload` keep it.

The numbers are re-derived from the session log, so:

- **Session-wide, including abandoned branches** — `+N/-M` answers "how much editing has
  this session done", not "what is in the working tree", and only sees `edit`/`write`.
- **`CH` is the latest response's cache hit rate**, not a session average.
- The cost group is omitted when cost is zero, and there is no `(sub)` marker.

`extensions/claude-usage.ts` adds the plan usage to the end of the second line (its key is
in `CONFIG.inlineStatusKeys`), only while a `claude-bridge` or `anthropic` model is
selected. It reads the rate-limit headers of each response and fetches nothing, so the
numbers are as of the last response from any pi session; a window past its reset reads
`0%`.

## Compaction extensions

pi sizes a compaction summary as `min(0.8 * compaction.reserveTokens, model.maxTokens)`
and starts compacting at `contextWindow - reserveTokens`. One number for both means a 1 M
window cannot have a workable summary budget: at the default 16,384 the budget is 13,107.

`extensions/compaction-summary.ts` answers `session_before_compact` by calling pi's own
`generateSummaryWithUsage()` with a larger reserve for that one call — same prompt, same
retry policy, only the budget differs — so **`settings.json` keeps the default 16,384 and
every model keeps its native context window**. It steps aside (pi's own compaction runs)
when the model's `maxTokens` already binds, when the summary is empty, and on any error.
On `claude-bridge` models it takes no part: pi-claude-bridge compacts those itself, at
pi's default budget (`BRIDGE_API` in the source says why).

- **Tune it in the `CONFIG` block at the top of the file**, which carries the measurement
  behind each value. `compaction-summary.json` overrides `reserveTokens`,
  `summarizerModel` and `triggerRatio` per machine.
- **`CONFIG.triggerRatio` (0.92) caps how full the window may get**, since pi's trigger
  is a fixed margin. Only windows above 204,800 are affected; `1` leaves the trigger to pi.

## MagPi handlers

`extensions/magpi-handlers.ts` — local `pi-magpi` handlers, one file, one test file
beside it. How each one works and the criteria for a new one are in its header.

| Handler | Fixes |
|---------|-------|
| `reddit` (shadows the built-in) | MagPi turns the login page into a 20-byte document and reports success. Live JSON, else the Arctic Shift archive, else an error |
| `discourse` | MagPi reads the server HTML: 18 of 169 posts, silently. `/t/<id>.json?print=true` reads the whole stream |
| `naver-blog` | The desktop page wraps the post in an iframe, so readability returns 0 bytes. Reads the mobile host |

- **Discourse is detected by URL shape, not a host list**, so a forum on an unusual host
  (`someforum.example/t/12345`) falls back to MagPi's default handler.
- **No `sandbox.json` entry**: these run in-process, and `pi-sandbox` only replaces the
  `bash` tool. Which is why `curl` to the archive host is blocked while the handler's own
  request is not.
- **Naver depends on markup** (`se-main-container`, `postViewArea`, `post_ct`). A
  redesign surfaces as "could not find the post container".
- Searching reddit is still `magpi_search` with `site:reddit.com`.

## MagPi renderer

`extensions/magpi-render.ts` reads pages whose content only exists after JavaScript
runs: it registers the `magpi_fetch_rendered` tool and `/magpi-render <url>`, drives the
installed Firefox over WebDriver BiDi, and returns markdown. Every tunable is in one
`TUNING` block at the top of the file, each with the measurement that set it — change
values there, not here.

Config is `magpi-render.json` (absent means defaults):

```json
{
  "enabled": true,
  "browserBinary": "/Applications/Firefox.app/Contents/MacOS/firefox",
  "sameSiteOnlyHosts": ["kr.example.com"],
  "renderHosts": ["*.example.com", "shop.example.co.kr"],
  "learnHosts": true,
  "maxWaitMs": 25000
}
```

- **Nothing is registered on a machine without Firefox** — a tool that can only fail still
  costs prompt tokens. Discovery tries `browserBinary`, absolute paths, then `PATH`; a
  browser installed later needs a `/reload`.
- **No `sandbox.json` change is needed**: the browser is a child process, and `pi-sandbox`
  enforces at the `bash` tool. `allowBrowserProcess` stays `false`.
- **A throwaway profile per render**, so the real Firefox profile is never touched.
- **6–15 s per page** against 0.3 s for a handler, and `navigator.webdriver` stays `true`,
  so a site can tell this is automation.

**Automatic escalation.** A `magpi_fetch` result under 600 bytes from the `webpage`
handler with a page-shaped `kind` is treated as a shell: the host is recorded in
`tmp/magpi-render/learned.json` and the result annotated. Thereafter that host is rendered
through a handler registered on MagPi's own extension point, so MagPi does the caching and
indexing. `learnHosts: false` turns the automatic half off, leaving `renderHosts`.

The first visit cannot be repaired automatically (nothing here can re-run MagPi's tool),
and `refresh: true` is needed because the shell is already cached. **A partial loss is not
detectable at all** — a page returning real bytes with empty iframes inside needs
`renderHosts` or the explicit tool.

## Model tiers

Agents and `settings.json` never name a concrete model; they reference role tokens
embedded in the `name` of a `models.json` entry:

| Token | Meaning |
|-------|---------|
| `tier:fast` | Cheap, mechanical lookup and recon |
| `tier:mid` | Default implementation model |
| `tier:strong` | Architecture, review, adversarial verification |
| `tier:fable` | Experimental top-end model. No agent uses it; reached through `Ctrl+P` only |
| `tier:local-fast` | Local Ollama model, zero cost, answers in seconds ([notes](#ollama-provider)) |
| `tier:local-strong` | Local llama.cpp model, zero cost but slow — for delegated work, not conversation ([notes](#llamacpp-provider)) |
| `tier:local-coder` | Local llama.cpp model tuned for coding/agentic work — smaller and faster than `tier:local-strong` ([notes](#llamacpp-provider)) |

Only `models.json` knows what a tier resolves to, so a machine with different
providers needs no changes elsewhere. `./check.sh` prints the current mapping.

Claude subscription through `pi-claude-bridge` (current) — the bridge registers the
`claude-bridge` provider from pi's Anthropic catalog, and `modelOverrides` names it
(pi applies overrides to extension providers too):

```json
{ "providers": { "claude-bridge": { "modelOverrides": {
    "claude-opus-5-5":  { "name": "tier:strong (claude-opus-5-5)" },
    "claude-sonnet-5-5":  { "name": "tier:mid (claude-sonnet-5-5)" },
    "claude-haiku-5-5": { "name": "tier:fast (claude-haiku-5-5)" }
} } } }
```

The same shape works for an Anthropic API key under `"anthropic"`. Do not use it with a
Claude login through pi's `/login`: pi then calls the API with the subscription token,
which Anthropic bills as extra usage, not against the plan.

Bedrock:

```json
{ "id": "arn:aws:bedrock:...:application-inference-profile/...",
  "name": "tier:strong (claude-opus-5-5)" }
```

Local-only machine:

```json
{ "id": "qwen3-coder:30b", "name": "tier:strong (qwen3-coder-30b)" },
{ "id": "gemma4:e4b",      "name": "tier:mid (gemma4-e4b)" }
```

### Pricing

Applies to entries that carry their own `cost`, which today is none of the tiers:
`pi-claude-bridge` registers its models at zero cost, since the plan, not tokens, is
what is paid. For Bedrock entries, when present:

`cost` is **USD per 1M tokens**, `cacheWrite` the 5-minute cache write price,
`cacheRead` the cache hit price. Basis: the AWS Bedrock pricing page for **us-east-1,
on-demand** — an application inference profile hides which region it resolves to, so the
file needs one fixed basis. `us.`/`global.` profiles match us-east-1; `eu.`/`au.` run
~10% higher and are not chased.

Update whenever a tier points at a new model: these drive the footer's cost readout, so a
stale value is silently wrong rather than broken. `check.sh` cross-checks against
`models-store.json` and reports differences without failing.

### Rules the tokens must obey

From pi's resolver (`dist/core/model-resolver.js`); `check.sh` enforces the first two:

- **Unique.** `--model` falls back to a case-insensitive substring match over id and
  name. An ambiguous substring is **not** an error: pi sorts matches by id and silently
  takes the highest.
- **Never a thinking level.** A trailing `:<suffix>` is consumed as a level when it is
  one of `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`. So `tier:fast:low`
  works and **`tier:high` is a trap** — the pattern becomes `tier`, which matches
  everything.
- **A shared prefix is ambiguous too**, even one nobody defined: `tier:local` is a
  substring of both `tier:local-fast` and `tier:local-strong`. Never pin a prefix;
  `check.sh` reports every shared prefix it can derive.
- **A bare, non-glob pattern resolves to exactly one model — even in `enabledModels`.**
  Use a real glob (`"ollama/*"`, matched on `provider/id`) to cover several models.
- **`*` does not cross a `/`.** `llama.cpp/*` matches **nothing**, because those ids are
  `llama.cpp/<hf-user>/<repo>:<quant>`; it needs `llama.cpp/**`. `llama.test.ts` asserts
  this through pi's own resolver.

A wrong token behaves differently depending on where it is used:

| Path | Unmatched `tier:typo` |
|------|----------------------|
| `--model` (agents, CLI) | Hard error, no fallback |
| `enabledModels` / `--models` | Warns `Invalid thinking level "typo"`, then matches the `tier` prefix and scopes the wrong model |
| `defaultModel` | Silently ignored — looked up as an exact id, so **a tier name never matches** and pi falls through to `enabledModels[0]`. Must be a raw id |

`settings.json` patterns are not validated by the checks; pi warns about unmatched scope
patterns at startup.

## Sample files

A fresh clone starts from the committed `.sample` files. `check.sh` enforces that
they parse, that every tier an agent asks for resolves exactly once in
`models.json.sample`, and that no sample carries an ARN, an AWS account id or a
value taken from the real `auth.json`.

Samples are **not** required to mirror the real config: an entry present on only one
side is a note, not a failure. Treat those notes as a reminder to sync when the
difference was not intentional.

- `models.json.sample`: generated from the real file, replacing any Bedrock ARN
  with its `<<<...>>>` placeholder, keyed on the tier name. Regenerate whenever a
  model is added or a tier renamed. It also keeps an `amazon-bedrock` block the real
  file no longer has, as a template: its names carry no `tier:`, since a tier may
  resolve only once. To switch back, move the tier names from `claude-bridge` onto it.
- `settings.json.sample`: the real file minus the two keys pi rewrites at runtime
  (`lastChangelogVersion`, `defaultThinkingLevel` — the sample holds the intended
  starting level). `defaultProvider` and `defaultModel` are placeholders and only
  work as a pair; `defaultModel` must be a raw id, **not** a tier. `check.sh` fails
  a half-filled pair.
- `auth.json.sample`: maintained by hand as a template.

## Packages

`settings.json` `packages`, installed into `npm/` on first launch (unless
`PI_OFFLINE`). The list stays short: every entry also loads in each subagent
process, and a package runs with full system access.

| Package | Why |
|---------|-----|
| `git:github.com/meinside/pi-quota-rotate` | Rotates to the next model in `quota-rotate.json`'s chain when the current one runs out of quota, then continues the interrupted turn |
| `@ctogg/pi-cost-counter` | Appends every message's `usage` to `~/.pi/cost-tracker/YYYY/MM/DD.jsonl`, adds `/cost [Nd]`. The only cross-session ledger (the statusline is session-only) |
| `@llblab/pi-telegram` | Turns arrive from and are answered on Telegram; concurrent sessions share one bot, one forum topic each. Configured by `telegram.json` |
| `@narumitw/pi-lsp` | Language server tools ([notes](#language-servers-pi-lsp)) |
| `pi-claude-bridge` | The `claude-bridge` provider: Claude models through Claude Code (Agent SDK), so turns draw on the Claude subscription. Authenticates with Claude Code's own login (`claude`), not pi's `/login`. Every agent tier points here |
| `@narumitw/pi-retry` | Marks empty-detail and stalled provider streams retryable, hands them to pi's backoff |
| `pi-ask-user` | `ask_user` tool with a structured form, plus an `ask-user` skill. Needs a UI, so subagents do not get it |
| `pi-env` | Exports `settings.json`'s `env` block into the process environment. That is the only route by which `PI_RETRY_STALL_TIMEOUT_MS` reaches `@narumitw/pi-retry`, which reads it from the environment and not from settings |
| `pi-magpi` | `magpi_fetch` / `magpi_search` / `magpi_cached`: pages as markdown behind a 24 h cache, official-API handlers for the big registries. SSRF-guarded. Its reddit handler is replaced locally, and Discourse/naver get their own ([notes](#magpi-handlers)) |
| `pi-rewind` | Per-tool-call snapshots, restored through `/rewind` or `Esc Esc`. Complements `extensions/git-checkpoint.ts`, which stashes once per turn for `/fork` |
| `pi-sandbox` | OS-level sandboxing ([notes](#sandbox-extension)) |

The bar is small, dependency-free, auditable code. `pi-sandbox` is a **documented
exception** (prebuilt native binaries, large dependency chain) kept for capability, and
so is `pi-claude-bridge` (bundles Anthropic's Agent SDK and its `claude` binary).
MCP needs no package: pi's built-in client reads `mcp.json`, so an MCP bridge such as
`pi-mcporter` would only duplicate it. `pi-smart-fetch` is rejected on the same criteria.

- **`/cost` prints the AWS account ID** for Bedrock turns: cost-counter records
  `message.model`, the full inference profile ARN under Bedrock. The ledger holds the
  same ARNs, so it is never committed.
- MagPi and cost-counter build paths from `homedir()` + a hardcoded `.pi/...` instead of
  `getAgentDir()`; the `~/.pi -> .config/pi` symlink is what lands them here.

## Language servers (pi-lsp)

Adds `lsp_diagnostics`, `lsp_fix` and `/lsp`. `pi-lsp.json` **replaces** pi-lsp's
built-in catalog and is deliberately a superset of what any one machine has: the file
stays identical everywhere, servers come from mason (shared with neovim), and `check.sh`
reports what is missing.

An entry whose command is absent stays inert until a call includes a matching file — and
then aborts that whole call, losing the other servers' results. So the risk is a language
used here whose server was never installed.

- **`check.sh` separates two states.** Missing from `PATH` is a note. On `PATH` but
  unable to exec *is* a failure: mason wrappers hardcode the asdf interpreter present at
  install time (`ruby-lsp`, `fennel-ls`), so an asdf upgrade leaves them dead with exit
  126, in neovim too. Reinstall through mason.
- **`pushDiagnosticsGraceMs`** on push-only servers stops a clean file from waiting out
  the full `timeout`.
- **Ruby needs both servers** (`ruby-lsp` parse errors, `rubocop --lsp` style); Python is
  split the same way (`ruff`, `ty`). `clojure-lsp` needs no companion.
- **biome lints but does not typecheck** — add `vtsls` if `.ts` type errors ever matter.
  Its extension list omits `.json`, so JSON routes through
  `vscode-json-language-server`.
- **`lsp_fix` only really works for gopls** (`source.organizeImports`). Use `rubocop -a`
  and `biome check --write` instead.

## Ollama provider

A hand-written `models.json` provider, backing `tier:local-fast`. Which tag the tier
points at is `models.json`'s business; `check.sh` prints it.

- `apiKey` is a dummy string: Ollama ignores it, but pi hides models with no configured
  auth. `compat.supportsDeveloperRole: false` — Ollama rejects that role.
- **Prefer GGUF tags over `-mlx`.** The MLX runner is text-only despite advertising
  vision, and slows down as context grows.

## llama.cpp provider

Not a hand-written provider: pi ships a hidden built-in extension registering the
`llama.cpp` provider and `/llama`, discovering models from a running router server. Only
*loaded* (or idle-`sleeping`) models reach `/model`.

| File | Why there |
|------|-----------|
| `~/.config/llama.cpp/config.ini` | The only path llama.cpp reads by itself. Router-level settings: `host`, `port`, `models-max` |
| `~/.config/llama.cpp/models.ini` | Per-model presets. `--models-preset` has no default path, so the location comes from `$LLAMA_ARG_MODELS_PRESET` (exported in `~/.zshrc`) |

**Both ini files carry their reasoning as comments next to each value**; read them there.
What lives on pi's side instead:

- **`modelOverrides`, not `models`.** The built-in provider hardcodes `reasoning: false`,
  so a thinking model needs an override in `models.json`. The key must be the router's
  model id exactly; pi ignores unknown ids without a word.
- **`thinkingLevelMap` is mandatory for a Qwen3.8-style template**, which accepts only
  `low`/`medium`/`xhigh` and calls `raise_exception` otherwise — pi's `high` returns HTTP
  500. Derive the map from the model's own template rather than copying this one.
- **`contextWindow` in `models.json` must match `c` in `models.ini`**, or pi computes its
  compaction threshold against a window the server does not have.
- **`enabledModels` needs `llama.cpp/**`**, per the [glob rule](#rules-the-tokens-must-obey).
- **The port is pinned to 9931**, keeping 8080 free. pi prefers the URL stored by
  `/login` over `$LLAMA_BASE_URL`, so changing it means re-running `/login llama.cpp`.
- **The API key belongs in `$LLAMA_API_KEY`** (`~/.custom_env`, untracked), read by both
  llama-server and pi. Without one the router leaves CORS open to every origin.
- **Downloads bypass `/llama`'s progress bar** when the preset carries `hf-repo`; the
  status stays `loading`. Watch `~/.cache/huggingface/hub/`. Preset-sourced models report
  `can_remove: false`, so deleting one means removing that directory by hand.
- **The presets are shared config; serving them is not.** A preset travels to machines
  that will never serve it — harmless, and the `enabledModels` check skips with a reason
  where `auth.json` names no `llama.cpp` provider.

`tests/llama.test.ts` covers what is static: no secret or path in either ini, every preset
has a model source, every `modelOverrides` key matches a preset section, and
`enabledModels` actually reaches the models.

## New machine setup

1. `export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME/pi/agent"` must be active (already
   in `~/.zshrc`). Without it pi reads `~/.pi/agent`.
2. `curl -fsSL https://pi.dev/install.sh | sh` — installs into this directory
   (`install/`, `bin/pi`) and links a `pi` on `PATH`; `pi update` upgrades it
3. Clone the dotfiles repo — brings `extensions/`, `agents/`, `prompts/`,
   `AGENTS.md`, `check.sh`, this README, the `.sample` files and the
   `~/.pi -> .config/pi` symlink.
4. Create the real config from the samples:
   ```bash
   cd ~/.config/pi/agent
   cp settings.json.sample settings.json   # fill defaultProvider/defaultModel
   cp models.json.sample models.json       # replace <<<...>>> with real ARNs, or
                                           # rewrite for this machine's providers
   cp auth.json.sample auth.json           # or use /login
   cp claude-bridge.json.sample claude-bridge.json   # plan: this account's
                                                     # Claude plan
   cp mcp.json.sample mcp.json             # tokens as ${VAR}, never literal
   cp quota-rotate.json.sample quota-rotate.json
   ```
   `models.json` must define `tier:fast`, `tier:mid` and `tier:strong`, or the agents
   cannot resolve a model.
5. Claude: run `claude` once and log in — `pi-claude-bridge` uses Claude Code's login,
   not pi's `/login`. Claude Code's own `settings.json` must not carry
   `CLAUDE_CODE_USE_BEDROCK`: the bridge inherits it, sends every turn to Bedrock and
   fails with `403 Authentication failed`.
6. Telegram: export `TELEGRAM_BOT_TOKEN` in `~/.custom_env`, then `/telegram-setup`
   and `/telegram-connect` in pi. With the variable set and no token saved yet, setup
   prefills and stores the reference `$TELEGRAM_BOT_TOKEN` instead of the token itself.
   A token already in `telegram.json` wins the prefill, so to convert one, replace it
   with `$TELEGRAM_BOT_TOKEN` in the setup editor or in the file.
7. Local models:
   - Ollama — pull whatever `models.json` lists, so this needs no editing when the
     model changes:
     ```bash
     python3 -c 'import json;print("\n".join(m["id"] for m in json.load(open("models.json"))["providers"]["ollama"]["models"]))' \
       | xargs -n1 ollama pull
     ```
   - llama.cpp — `brew install llama.cpp`, then start the router in a new shell
     (`llama-server`, no `--model`) so it picks up `config.ini` and
     `$LLAMA_ARG_MODELS_PRESET`. In pi: `/login llama.cpp` with the URL built from
     `config.ini`'s `host`/`port`, then `/llama` to load a model — the first load
     downloads it.
8. Language servers: install through mason. `./check.sh` lists what `pi-lsp.json`
   expects and whether it runs.
9. Verify: `pi --list-models` and `./check.sh`

## Security note

The subagent extension defaults to `agentScope: "user"`, so only agents in this
directory are loaded. Project-local `.pi/agents/*.md` are repo-controlled prompts
that can instruct the model to read files and run commands — enable them
(`agentScope: "both"`) only for repositories you trust.
