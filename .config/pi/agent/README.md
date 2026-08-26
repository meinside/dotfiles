# pi coding agent config

Config directory for [pi](https://github.com/earendil-works/pi-mono) (`pi-coding-agent`).

**pi does not support XDG paths.** `getAgentDir()` (`dist/config.js`) returns
`$PI_CODING_AGENT_DIR` if set, otherwise `~/.pi/agent`, and `~/.zshrc` exports it.
A committed `~/.pi -> .config/pi` symlink makes that fallback land here too, so the
variable is now a second line of defence rather than the only one — and extensions
that build their own `~/.pi/agent` paths instead of calling `getAgentDir()` stay
inside this directory. Read `~/.pi/agent` in upstream docs as "this directory".

```bash
export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME/pi/agent"
```

## Files

| Path | Tracked in dotfiles | Purpose |
|------|---------------------|---------|
| `settings.json` | `.sample` mirror | Theme, default model, `enabledModels` for `Ctrl+P` cycling. Holds no secrets since it references tiers instead of ARNs |
| `models.json` | `.sample` only | Providers, models and the tier aliases. Holds the AWS account ID inside Bedrock inference profile ARNs, hence the `.sample` indirection |
| `auth.json` | `.sample` template | Credentials. Never commit the real file. The sample is a **template**, not a mirror: it documents providers (such as `google`) that may not be configured here |
| `models-store.json` | no | Generated model catalog cache. Do not edit or commit. `check.sh` reads it to cross-check prices |
| `pi-lsp.json` | yes | Language server routes for the `@narumitw/pi-lsp` extension. No secrets or machine-specific paths, so it is committed as-is |
| `magpi.json` | yes | MagPi's config: the 100 MB cache budget and a pinned `allowPrivateNetwork: false`. Written only by an explicit `/magpi` config command, which merges the file with the changed key rather than expanding it, so there is no runtime churn to keep out of git |
| `mcporter.json` | `.sample` mirror | `pi-mcporter`'s exposure policy (`defaultExposure`, per-server overrides). Not the MCP server definitions themselves — those live in `~/.config/mcporter/mcporter.json` (XDG; falls back to `~/.mcporter/mcporter.json`), a separate file tracked only as `.sample` in `.config/mcporter/`, outside this directory. Missing entirely, this file just falls back to pi-mcporter's own defaults (`defaultExposure: index`) rather than failing pi's startup |
| `sandbox.json` | yes | `pi-sandbox`'s OS-level policy (allowed domains, filesystem allow/deny lists). No secrets or account IDs, just paths and hostnames, so it is committed as-is like `pi-lsp.json`. Mutated live by `/sandbox-allow ... for all projects`, so tracking it turns that prompt into an auditable `git diff` instead of a silent policy change |
| `magpi-cache/` | no | MagPi's fetch cache (24 h TTL, capped at 100 MB, LRU eviction) |
| `cost-tracker/` | no | `@ctogg/pi-cost-counter`'s append-only cost ledger, one JSONL file per day under `YYYY/MM/`. Contains the Bedrock inference profile ARNs, hence never committed |
| `npm/` | no | `pi install` target. Ships its own `.gitignore` containing `*` |
| `extensions/subagent/` | yes | Vendored subagent extension |
| `extensions/guard.ts` | yes | Blocks writes to credential files, confirms package installs and irreversible commands |
| `extensions/git-checkpoint.ts` | yes | Vendored upstream example: per-turn git stash checkpoints for `/fork` |
| `extensions/statusline.ts` | yes | Claude Code style footer ([notes](#statusline-extension)) |
| `AGENTS.md` | yes | [Global instructions](#global-instructions-agentsmd) for every session and subagent, general rules only |
| `agents/*.md` | yes | Subagent definitions, read by the subagent extension |
| `prompts/*.md` | yes | Prompt templates, invoked as `/name` in the editor |
| `check.sh` | yes | Entry point for the checks: runs `tests/` on node's test runner and reports what this machine has |
| `tests/*.ts` | yes | The checks themselves. `lib.ts` is shared helpers, the rest are `node:test` files runnable on their own |
| `../../llama.cpp/config.ini` | yes | llama.cpp's own user-level config, auto-loaded by every llama.cpp binary from `${XDG_CONFIG_HOME:-~/.config}/llama.cpp/config.ini`. Outside this directory, but committed and checked here because pi's built-in `llama.cpp` provider depends on it ([notes](#llamacpp-provider)) |
| `../../llama.cpp/models.ini` | yes | The router's model presets, pointed at by `$LLAMA_ARG_MODELS_PRESET`. Tracked as a mirror rather than a `.sample`: it holds no secret, no path and no machine-specific value, so a sample would be a byte-identical copy that only invites drift |

`~/.gitignore` ignores `.config/` wholesale, so tracked files here were added with
`git add -f`. Files holding secrets or machine-specific values are committed as
`<name>.sample` with `<<<placeholder>>>` markers, the convention already used for
`.config/claude`, `.config/git`, etc. The two `llama.cpp/*.ini` files are the
counter-example that shows where the line is: they were written so that every path
lives in an environment variable and every model is named by Hugging Face repo, so
there is nothing left to placeholder and they are tracked directly.

## Global instructions (AGENTS.md)

`AGENTS.md` here is pi's *global* context file: `loadProjectContextFiles`
(`dist/core/resource-loader.js`) reads the agent directory first, then `AGENTS.md`
/ `CLAUDE.md` from cwd and every ancestor. It reaches the subagents below too,
since `index.ts` spawns `pi` without `--no-context-files`.

Its subject is verification — find a project's quality gates before editing, run
them as the work proceeds, never silence one for a green run — because nothing
else here can carry that policy: `buildSystemPrompt`
(`dist/core/system-prompt.js`) ships three guidelines, none about correctness, and
`agents/*.md` must stay byte-identical to upstream.

Hence its two constraints. **General rules only:** per-project rules belong in
that project's own `AGENTS.md` and notes about this directory in this README, so
the file says "read the project's `README.md` first" rather than naming
`./check.sh`. **Short and publishable:** it is billed on every turn of every
session and subagent, in a public repo.

It offers `lsp_diagnostics` / `lsp_fix` only as a fallback and only "if they are
among your tools": they come from `@narumitw/pi-lsp`, and `--tools` is an
allowlist over extension tools too, so `scout`, `planner` and `reviewer` lack them
while `worker` has them. That wording also survives dropping the package.

Keep the file in this directory. The ancestor walk has no repository boundary — it
stops at the filesystem root — so an `AGENTS.md` at `~`, the dotfiles repo root,
would load into every session under the home directory.

## Vendored subagent extension

pi intentionally ships **no built-in sub-agents** (`docs/usage.md`, "Design
Principles"), so tiered model usage comes from the upstream `subagent` example
extension, vendored here.

- **Upstream repo:** <https://github.com/earendil-works/pi-mono>
- **Upstream path:** `packages/coding-agent/examples/extensions/subagent/`
- **Local copy of upstream:** resolved by `tests/lib.ts`'s `piPackageDir()` (and `check.sh`'s shell equivalent) to `<package root>/examples/extensions/subagent/` — `brew --prefix pi-coding-agent` when Homebrew has the formula, otherwise the real path of the `pi` binary on `PATH`, so this works without Homebrew too (e.g. `pi.dev/install.sh` on Linux)
- **Vendored from:** pi 0.84.3

It registers a `subagent` tool that spawns a **separate `pi` process** per
delegation (`index.ts`: `args.push("--model", model)`), giving each agent an
isolated context window. Agents are discovered from `agents/*.md` by `agents.ts`.

### Agents

| Agent | `model:` | Upstream model | Tools | Role |
|-------|----------|----------------|-------|------|
| `scout` | `tier:fast:low` | `claude-haiku-4-5` | read, grep, find, ls, bash | Fast recon, returns compressed context |
| `planner` | `tier:strong:high` | `claude-sonnet-4-5` | read, grep, find, ls | Produces an implementation plan, makes no changes |
| `reviewer` | `tier:strong:high` | `claude-sonnet-4-5` | read, grep, find, ls, bash | Code review, read-only bash |
| `worker` | `tier:mid:medium` | `claude-sonnet-4-5` | all | Performs the actual implementation |

The `model:` line is the only local edit in these files, and the `Upstream model`
column is what the example pins there; both are what to re-apply after an upstream
update.

Each pin carries a thinking level, because `settings.json`
`defaultThinkingLevel` reaches every spawned child otherwise: for an agent that
declares its own `model:`, `index.ts` passes `--model` but deliberately **not**
`--thinking` (`inheritsDispatchConfig` is false), and `sdk.js` then falls back to
that setting, so `scout` would do "fast recon" at whatever level the interactive
session happened to be on. `resolveCliModel` consumes a trailing `:<level>`
before the model lookup, so `tier:fast:low` still resolves the pattern
`tier:fast` — see [Rules the tokens must obey](#rules-the-tokens-must-obey).

The split follows the convention visible across large public subagent collections
(wshobson/agents, VoltAgent/awesome-claude-code-subagents, @vigolium/piolium), and
the economics agree: planners and reviewers read a lot and write little, so an
expensive model costs little there, while an implementer emits many output tokens,
where the same model costs the most. Do not "upgrade" `worker` to the top tier;
upgrade `planner` instead so `worker` needs less rework.

An agent without a `model:` line inherits the dispatching session's model **and**
its thinking level: since pi 0.84.x, `index.ts` builds a `dispatchDefaults` from
`ctx.model` (as `provider/id`) and `ctx.thinkingLevel`, and passes both to the
child when the agent declares no model of its own. That is a change from 0.83.0,
where `--model` was appended only for an agent with a pin and a model-less agent
started where a fresh session would — on `enabledModels[0]` rather than
`defaultModel`, since `findInitialModel` returns the first scoped model before it
consults the saved default, which here meant opus. Either way the conclusion for
this directory is the same, and the reason is now the opposite one: a model-less
agent would silently follow `/model` in the parent, so "fast recon" would run on
whatever the session is on. Every agent here therefore pins a tier explicitly.
(`PI_MODEL` / `PI_PROVIDER` remain exported to bash-tool commands only and are
never read back as input; they play no part in this.)

### Workflow prompt templates

| Command | Chain |
|---------|-------|
| `/implement <task>` | scout → planner → worker |
| `/scout-and-plan <task>` | scout → planner (no implementation) |
| `/implement-and-review <task>` | worker → reviewer → worker |

Ad-hoc delegation also works (`Use scout to find all authentication code`,
`Run 2 scouts in parallel: ...`; max 8 tasks, 4 concurrent, `Ctrl+O` expands
output and per-step cost).

### Updating the vendored files

The vendored files are byte-identical to upstream except the `model:` lines, which
the comparison ignores — so the tier pins are expected and no diff counts need
keeping in sync. That clean `diff` is the update-detection mechanism, which is why
these files carry no provenance comments or extra frontmatter keys. Run it after
every `brew upgrade pi-coding-agent`, and before committing a change here:

```bash
~/.config/pi/agent/check.sh      # -v to print the diffs
```

`check.sh` is a wrapper: it resolves the upstream prefix, then hands over to
`node --test tests/*.test.ts`. Node runs the TypeScript directly, so there is
nothing to build and no test dependency to install; a single file also runs on its
own, for example `node --test tests/samples.test.ts`. The split is deliberate:
fixed expectations (drift, tier resolution, sample leaks, guard policy) are
assertions, while machine-specific facts (which models this machine has, which
language servers are installed) arrive as `node:test` diagnostics and skips — the
same notes-versus-failures distinction the shell version made by hand.
`tiers.test.ts` goes further than that version could: it imports pi's own
`resolveCliModel` and asserts pi picks the model the uniqueness check found, so the
local matching rule cannot drift away from `dist/core/model-resolver.js` in
silence.

Resolving that upstream prefix used to mean only `brew --prefix pi-coding-agent`,
which fails outright on a machine that installed pi via `pi.dev/install.sh`
(no Homebrew involved, so no formula to resolve) — the exact failure mode this
readme originally shipped with, since it was only tested on macOS with
Homebrew. Both `check.sh` and `tests/lib.ts`'s `piPackageDir()` now try `brew
--prefix` first, then fall back to resolving the real path of the `pi` binary
on `PATH` and checking both the Homebrew bottle layout
(`libexec/lib/node_modules/...`) and the plain `npm install -g` layout
(`lib/node_modules/...`, what the installer script and a bare global npm
install both produce) relative to it.

When it reports drift:

```bash
U="$(./check.sh 2>&1 | head -1 | sed -E 's/.*upstream: //')"   # or read it from ./check.sh's own output
C=~/.config/pi/agent

diff -u $C/extensions/subagent/index.ts $U/subagent/index.ts   # inspect first

cp $U/subagent/index.ts $U/subagent/agents.ts $C/extensions/subagent/
cp $U/git-checkpoint.ts $C/extensions/
cp $U/subagent/prompts/*.md $C/prompts/
cp $U/subagent/agents/*.md $C/agents/     # then re-apply the tiers from the
                                          # Agents table
~/.config/pi/agent/check.sh
```

Then bump "Vendored from" above.

If a pi session is running while upgrading Homebrew's copy, disable its cleanup
so the Cellar directory the running process started from stays in place:

```bash
HOMEBREW_NO_INSTALL_CLEANUP=1 brew upgrade pi-coding-agent
brew cleanup pi-coding-agent    # after the session ends
```

On a machine installed via `pi.dev/install.sh` instead (no Homebrew, no
Cellar), the installer replaces the previous version in place — there is no
equivalent stale-directory risk to guard against.

## Guard extension

pi has no tool permission system, on purpose: built-in tools run with the
permissions of the pi process, and pi's `docs/security.md` points at containers or
micro-VMs rather than per-call prompts. That is no use for a config that edits the
home directory itself. `extensions/guard.ts` is the narrow middle ground — the
patterns live in the file, the decisions are:

- Credential files are **blocked, not confirmed**: `~/.ssh`, `~/.gnupg`, `~/.aws`,
  `~/.config/gcloud`, `~/.config/rclone`, `~/.netrc`, `~/.npmrc`,
  `~/.ollama/id_ed25519`, `auth.json`, and Claude's `settings.json` (whose hooks
  run commands). There is no case where the agent should rewrite them, so a prompt
  would only be a chance to say yes by mistake. Directories rather than single
  files where a vendor keeps adding state: `~/.aws` was two files until
  `sso/cache` and `cli/cache` turned up holding live tokens.
- Most of those are also **unreadable** through `read` and `grep`, plus the
  transcript stores (`sessions/`, `history.jsonl`, shell histories). A secret the
  agent reads goes to the provider and into `sessions/*.jsonl` in the clear, so
  reading one is already the damage, before anyone tries to exfiltrate it. The two
  lists differ on purpose: `~/.aws/config` and Claude's `settings.json` stay
  readable, and transcripts are read-blocked without being write-blocked.
- Package managers and irreversible git/filesystem operations **ask once**.
  Read-only and reversible forms are excluded deliberately: a gate that fires on
  every `ls` gets removed, and a noisy one trains blind acceptance.
- With no UI to ask (`-p`, `--mode json`) a match is **blocked**, so headless runs
  fail loudly instead of installing something.
- `!` commands go through `user_bash`, which only enforces that same no-UI rule.
  They were already an explicit user action.

`extensions/git-checkpoint.ts` is the other half: an unmodified copy of pi's
example that stashes a checkpoint each turn so `/fork` can restore code state.
Keeping it a separate file lets `check.sh` diff it against upstream and lets
`pi config` disable it on its own.

The read block is a guard against accidents, **not a boundary**. `bash` can still
`cat` any of those files: gating it on patterns would be trivially bypassable
(`$HOME`, quoting, `python -c`) and would fire on `check.sh`, which reads the real
`auth.json` to prove the sample carries no live credentials — exactly the routine
prompt this file avoids on purpose. Command matching is substring-based over the
whole command, so it also trips on a pattern quoted inside an unrelated script.

The `tool_call` check asks whether the target sits inside a guarded path, which
leaves `grep` pointed at an ancestor (`~`, `~/.config`) free to walk into the
secrets underneath. Blocking every ancestor would block `grep` on this directory,
so a `tool_result` handler drops the offending lines from the result instead and
appends a count, since a model reasoning from a silently shortened result is its
own failure mode. `tests/guard.test.ts` pins both halves.

What actually lowers the risk is credential hygiene, a short-lived AWS session
rather than a long-lived key, and — now that MagPi pulls untrusted web pages into
context, where an injected instruction can ask for a file and then post it to a
public URL — doing that kind of work in an isolated environment, as
`docs/security.md` recommends. `extensions/pi-sandbox` (below) is that boundary
for `bash` specifically; the two extensions are complementary, not redundant.

## Sandbox extension

`extensions/guard.ts` says its own read block is "a guard against accidents, not
a boundary" because `bash` can `cat` any pattern-matched path — encoding,
quoting, or `python -c` all bypass a string match trivially. [`pi-sandbox`](https://github.com/carderne/pi-sandbox)
(npm `pi-sandbox`) closes that gap with an actual OS boundary: `bash` runs under
a generated Seatbelt profile on macOS or bubblewrap namespaces + seccomp on
Linux, backed by `@carderne/sandbox-runtime`. Reads outside the allowlist and
writes outside the workspace fail closed at the kernel, not at a regex.

`read`/`write`/`edit` tool calls get the same filesystem policy applied directly,
since the OS sandbox cannot cover tools that run in-process rather than as a
subprocess.

Policy lives in `sandbox.json` (tracked, see [Files](#files) above) and follows
two rules learned the hard way while writing it:

- **`allowWrite` also grants read on the same path**, so a cache directory that
  happens to keep a credential file at its root (`~/.cargo/credentials.toml`,
  `~/.gem/credentials`) is scoped to the specific cache subdirectory
  (`.../cargo/registry`, `.../gem/specs`) rather than allowed wholesale. The
  credential files themselves are hard-blocked in `denyWrite` on top, since
  `denyWrite` always wins and is never prompted.
- **`*.example.com` also matches the bare `example.com`** in `pi-sandbox`'s
  `domainMatchesPattern` — but only there, and that is not the enforcing layer;
  see the entry below, which corrects what this bullet used to conclude.
- **A wildcard does *not* cover the bare domain at the layer that enforces it.**
  The opposite was written here, and it was wrong: `pi-sandbox`'s
  `domainMatchesPattern` does return true for the bare `example.com` given
  `*.example.com`, but that function only decides whether to *prompt*.
  Enforcement is `matchesDomainPattern` in `@carderne/sandbox-runtime`, which
  requires a strict subdomain (`h.endsWith("." + base)`). So a bare domain
  present only as a wildcard is hard-blocked by the runtime proxy *without a
  prompt*: with only `*.github.com` listed, `https://github.com/` returned
  `000` and `git clone https://github.com/...` failed with `CONNECT tunnel
  failed, response 403` — measured by generating a sandbox straight from this
  `sandbox.json` with `@carderne/sandbox-runtime`'s own `srt` CLI. `pypi.org`,
  `crates.io` and `rubygems.org` were in the same state. The literals
  "redundant with a wildcard" that this file once bragged about removing are
  back (`github.com`, `pypi.org`, `crates.io`, `rubygems.org`, plus
  `nodejs.org`, `pub.dev`, `luarocks.org`), the wildcards stay for
  the subdomains that serve artifacts, and `tests/sandbox.test.ts`'s
  redundancy invariant — which actively enforced the broken state — was
  replaced by its inverse, `BARE_DOMAINS_TOOLS_NEED`.
- **A package's own data directory can sit outside the workspace it ships
  in.** `@ctogg/pi-cost-counter` writes to `~/.pi/cost-tracker`, a sibling of
  this agent directory rather than a path under it, and broke silently
  (`EPERM` on `mkdir`) the first time a sandboxed session tried to log a cost
  entry. `allowRead`/`allowWrite` list both `~/.pi/cost-tracker` and its
  symlink-resolved twin `~/.config/pi/cost-tracker`, since the sandbox
  canonicalizes through the `~/.pi -> .config/pi` symlink at policy-check time
  but a still-missing target directory can defeat that resolution depending on
  which layer resolves it — listing both sides is cheaper than trusting it.

- **A check that cannot read a file skips instead of failing, which looks like a
  pass.** `tests/llama.test.ts` verifies the llama.cpp router config in
  `~/.config/llama.cpp`, outside this directory and therefore outside the
  tightened `allowRead`. Under the sandbox it hit `EPERM` on `readFileSync`; the
  test now reports the reason and skips rather than crashing, but a skipped check
  verifies nothing, so `~/.config/llama.cpp` is in `allowRead`. It stays out of
  `allowWrite`: pi's own `edit`/`write` tools go through `guard.ts` instead and
  leave a reviewable diff, while a bash-level write grant would let a session
  mutate a running service's config with nothing to review. Adding a model does
  not need it either — `/llama` downloads into the Hugging Face cache and the
  router lists it without touching the ini.
- **`magpi-cache` lives in pi's data dir, not its config dir.** The web cache
  `magpi_fetch` fills, and whose paths it hands back for `read`/`grep`, is
  `~/.pi/agent/magpi-cache` — `~/.pi` was not in `allowRead` at all, so every path
  the tool reported came back `Operation not permitted` even though the tool itself
  had just written it (tools run in-process, outside the sandbox; only `bash` is
  confined). Only that subdirectory is listed, so `~/.pi/agent/auth.json` and the
  session files stay outside; and only for reading, for the same reason as the ini
  above. `~/.config/pi/agent/magpi-cache` is an *older* location whose ~9.5 MB of
  pages are still there and were readable all along — it is inside this directory,
  which is why the two get confused.

Toolchains here run through `asdf`, which moves everything to XDG paths
(`~/.local/share/{asdf,cargo,rustup,npm,pipx,uv}`) rather than the classic
`~/.cargo`, `~/.rustup`, `~/.npm` the package's own example config assumes; the
committed `allowRead`/`allowWrite` lists reflect the real paths for this setup,
confirmed against `CARGO_HOME`, `RUSTUP_HOME`, `GOPATH`, and `npm config get
prefix` rather than assumed. `allowBrowserProcess` stays `false` since nothing
here drives a browser; the package's own example config warns that flag opens a
real hole (Chrome's cookie/login-data stores become bash-readable) and should
only be on for `agent-browser`-style workflows.

### What the first tightened policy actually broke

The default `allowRead` (`".", "~/.config", "~/.local", "Library"`) was replaced
here by specific subpaths, which is the right direction but silently removed
things every toolchain needs. Each of the following was reproduced by running
the real command inside a sandboxed `bash`, not inferred from the lists:

- **`~/.config/git` read.** `git config --list --global` fails with `fatal:
  unable to access '~/.config/git/config': Operation not permitted`, and so does
  anything linking libgit2 — `cargo new` dies with `failed to stat
  '~/.config/git/config'; class=Config`. Only `config`, `ignore` and
  `attributes` are listed, plus `~/.gitconfig`, `~/.gitignore` and
  `~/.gitignore_global`, so a `~/.config/git/credentials` alongside them stays
  unreadable; the directory is deliberately *not* allowed wholesale.
- **`GOCACHE`.** `go build` cannot start at all: `failed to initialize build
  cache at ~/Library/Caches/go-build`. `~/Library/Caches/go-build` (macOS) and
  `~/.cache` (Linux, `~/.cache/go-build`) are now writable, as is
  `~/Library/Application Support/go` / `~/.config/go` for the telemetry and
  `go env -w` files that produced the second error on the same command.
- **`$CARGO_HOME` root.** Scoping to `cargo/{git,registry}` left out the
  `.package-cache` lock, `.global-cache`, and `bin`, so `cargo build`/`cargo
  install` could not run. Those three are listed individually rather than
  opening `~/.local/share/cargo`, because `allowWrite` implies read and the
  credential files there are only hard-blocked for *writes*.
- **`PATH` directories.** `command -v gopls ruff biome taplo marksman
  lua-language-server` reported every one of them missing under the sandbox
  although all are installed: execute is a read on both platforms, so
  `~/.local/bin`, `~/bin`, `~/.local/share/cargo/bin`,
  `~/.local/share/nvim/mason` and `~/.luarocks` have to be readable for `bash`
  to see the same tools `pi-lsp` (which spawns in-process, outside the sandbox)
  happily uses.
- **`/tmp` on macOS only.** `/tmp` is a symlink to `/private/tmp`, and the
  `allowWrite` entry did not follow it: `mkdir /tmp/x` was denied while
  `$TMPDIR` (`/tmp/claude`, set by `sandbox-runtime` itself) worked. `/private/tmp`
  is listed next to `/tmp` — a no-op on Linux, where `/tmp` is a real directory.
  That `$TMPDIR` survives the sandbox being switched off mid-session while the
  directory itself does not, so `os.tmpdir()` can name a path nothing has created:
  `mkdtemp` then fails with `ENOENT` (sandbox off) or, if a test reaches for the
  real macOS `$TMPDIR` under `/var/folders` instead, with `EPERM` (sandbox on,
  since only `/tmp` is writable). `statusline.test.ts` therefore creates
  `tmpdir()` before using it — both failures were reproduced here.
- **`~/.tool-versions`.** asdf walks up to `$HOME` looking for it, and the home
  root is `denyRead`. On Linux this is worse than a denial: `denyRead` is
  implemented as a `tmpfs` over the directory, so the file is *absent* rather
  than refused and asdf silently resolves a different version.
- **`~/.asdf`.** `ASDF_DATA_DIR` is exported to `~/.local/share/asdf` on this
  machine, but asdf 0.16+ defaults to `~/.asdf`; both are listed so the Linux
  boxes work whether or not the variable is set there.
- **Language downloads.** `curl` to `nodejs.org`, `static.rust-lang.org`,
  `cache.ruby-lang.org`, `www.python.org`, `go.dev`, `dl.google.com` and
  `ghcr.io` all returned `000`: `asdf plugin add` worked (GitHub) but `asdf
  install <lang>` could not fetch a single runtime, and `brew install` could not
  fetch a bottle. Both the wildcard and the bare literal are listed where a
  tool hits the apex host, since the runtime's wildcard matching is
  strict-subdomain only (see the bullet above). Which hosts these are was not
  guessed: every installed `asdf` plugin (`babashka clojure erlang gleam golang
  janet java lua meson nim ninja nodejs python ruby rust zig`) was grepped for
  the URLs its own scripts and version-definition files fetch. That is where
  `download.clojure.org`, `dl.google.com`, `golang.org`, `nodejs.org`,
  `luarocks.org`, `*.lua.org`, `nim-lang.org`, `sh.rustup.rs`, `ziglang.org`,
  `cache.ruby-lang.org`, `www.python.org` and `ftpmirror.gnu.org` (python-build
  compiling its own readline/openssl) come from; most plugins resolve to
  `github.com` alone. Two entries added on assumption were removed again after
  that grep: `api.adoptium.net` (asdf-java's Temurin rows are GitHub release
  URLs, and the JDK actually installed here, `openjdk-25.0.2`, comes from
  `download.java.net`, which was added instead) and `astral.sh` (`uv` is a
  Homebrew install and `ruff` a mason one, so the installer script host is never
  hit). `repo1.maven.org` is kept for `deps.edn`/Maven Central resolution rather
  than any plugin, and `storage.googleapis.com` is the loosest entry in the list
  — any GCS bucket, accepted for Flutter/Dart. `pip download`, `npm i` and `gem
  fetch` were verified working *before* these additions and need nothing.
- **`allowUnauthenticatedSocksProxy`.** Documented above as what makes
  Git-over-SSH work on macOS, but `~/.ssh` is unreadable under this policy, so
  SSH cannot authenticate anyway (`ssh -T git@github.com` fails); it is now
  `false`, closing the local-proxy exposure it was paying for nothing. Turning
  it back on only makes sense together with an `allowRead` entry for a key.
- `~/.cache/{npm,pip,uv}` were dropped as dead weight once `~/.cache` itself is
  writable (prefix matching), and `/root` joined `denyRead` for parity with
  `/Users` and `/home` on a Linux box entered as root. `~/.npmrc` stays
  unreadable on purpose: public-registry installs do not need it and it holds a
  token.

- **`~/.eclipse` (jdtls).** Fixing the `PATH` reads above made `tests/lsp.test.ts`
  *start* failing on `jdtls is usable` — not a regression from that change but a
  failure it uncovered: while `~/.local/share/nvim/mason/bin` was unreadable the
  case was skipped as "not installed here". Under the sandbox Eclipse cannot
  write its fallback configuration area and reports
  `java.io.FileNotFoundException: ~/.eclipse/…/configuration/….log (No such file
  or directory)`, which is one of `lsp.test.ts`'s `EXEC_FAILURE_MARKERS`, so the
  probe is read as "on PATH but does not exec". `~/.eclipse` is therefore
  allowed for read and write like any other toolchain state directory. Note this
  only ever affected `jdtls` invoked from `bash`: `pi-lsp` spawns language
  servers from pi's own process, which the OS sandbox does not cover. (The entry
  went live mid-session, without a restart, because granting an unrelated
  permission prompt reloads the config — see below.)
- **`~/.gitignore`.** A `git clone` under the fixed policy still warned `unable
  to access '~/.gitignore'`; git probes that name as well as
  `~/.gitignore_global`, so both are listed. The `failed to store: -60008` on the
  same clone is the macOS keychain credential helper, which stays blocked on
  purpose.

None of this is visible to `tests/sandbox.test.ts` (see below), and when a
`sandbox.json` edit takes effect is worth knowing exactly, because it is not
"never until restart": `pi.on("session_start")` initializes from disk,
`/sandbox-enable` after a `/sandbox-disable` calls `loadConfig()` again (nothing
caches it), and — the surprising one — granting *any* permission prompt runs
`applyChoice() -> refreshSandbox() -> SandboxManager.reset()` plus a fresh
`initializeSandbox(loadConfig(cwd))`, so an unrelated grant silently activates
whatever the file currently says. Outside those three moments an edit lies
dormant and re-running a probe reproduces the old behaviour, which is easy to
mistake for the edit not working.

What that reload does to the *network* half was observed to misbehave once, and a
second apparent misbehaviour turned out to be self-inflicted. The real one: a
re-init left the filesystem policy correctly updated while every domain,
including ones that had worked a minute earlier, returned `000` — the proxy
bridge did not come back with the reset. It has not been reproduced since, so
treat it as a transient rather than a rule. The self-inflicted one is worth more
than the bug: later in the same session `example.com`, `www.wikipedia.org` and a
domain that had *just been removed* from `allowedDomains` all answered `200`, and
`/sandbox` showed exactly those three under session allowances. `pi.on("tool_call")`
runs `extractDomainsFromCommand()` over the bash command *text*, so every URL
literal in a probe loop raises its own prompt; granting them to let the probe
finish both whitelists them for the session and — via `applyChoice() ->
refreshSandbox()` — reloads `sandbox.json` as a side effect. That is what
activated the `~/.eclipse` entry above without a restart and turned the `jdtls`
failure green mid-session. Consequences for anyone probing this policy: keep
hostnames that are *supposed* to be blocked out of the command line unless the
prompt is going to be refused, remember that session allowances are invisible to
the agent (so a `200` proves nothing on its own), and read domain results only
from a session where `/sandbox` lists no allowances — or better, from outside pi:
build a runtime config from `sandbox.json` the way `buildRuntimeConfig()` does
(expand `~`, fold `allowWrite` into `allowRead`) and run the probe under `node
.../@carderne/sandbox-runtime/dist/cli.js -s <that file> -c '<command>'`, which
has no prompt path at all. It has to be outside pi: nested, it fails with `EPERM`
on its own mux socket.

`/sandbox` shows the active policy and session allowances, `Alt+S` toggles the
sandbox for the session, and `/sandbox-allow {read,write,domain} <path>` prompts
to extend `allowRead`/`allowWrite`/`allowedDomains` — once, for the session, for
this project (`.pi/sandbox.json`), or for all projects (here). `tests/sandbox.test.ts`
pins the committed JSON's invariants (which credential paths stay hard-blocked,
that `allowRead`/`allowWrite`/`denyRead`/`denyWrite` stay sorted, that the bare
domains tools need are listed literally next to their wildcard) but not the live
effect
pi-sandbox computes from it: Node's built-in TypeScript loader refuses to strip
types for anything under `node_modules`
(`ERR_UNSUPPORTED_NODE_MODULES_TYPE_STRIPPING`), so `pi-sandbox/src/policy.ts`'s
real `matchesPattern`/`domainMatchesPattern` can't be imported and exercised
the way `guard.test.ts` imports `extensions/guard.ts` directly. That gap showed
up twice while writing this policy — the `~/.pi/cost-tracker` EPERM above, and
a second one where dropping `~/Library` from `allowRead` (correctly, to close
the Chrome-credentials hole) also silently took Homebrew's own
`~/Library/Caches/Homebrew` bootsnap cache with it, breaking `brew` itself
under a sandboxed `bash` — both found by running real commands under the
policy, not by the test file.

What the test file does catch is `sandbox.json` and itself drifting apart:
`filesystem.denyWrite` is asserted to equal, not merely contain,
`GENERIC_SECRET_GLOBS ∪ CREDENTIAL_PATHS` as defined in `sandbox.test.ts`. A
plain "the expected paths are present" check only fails when something is
removed; union-equality also fails when something is *added* to `denyWrite`
without a matching entry in the test — the direction that would otherwise let
a new credential path go unpinned. `allowRead`/`allowWrite`/`allowedDomains`
are left on the weaker per-invariant style on purpose: they are meant to grow
through ordinary `/sandbox-allow` usage, and a fixed expected set there would
fight that instead of catching drift.

`tests/sandbox-deps.test.ts` checks a different failure mode: `sandbox.json`
commits `enabled: true` machine-wide, but pi-sandbox needs OS-level helpers
(`rg` on both platforms; `bwrap`/`socat` on Linux) to actually enforce it, and
a missing one fails sandbox initialization rather than pi-sandbox itself
failing loudly at every `bash` call. It also checks user namespace
availability, on two different sysctls depending on which one the kernel
carries: `kernel.apparmor_restrict_unprivileged_userns` (Ubuntu 24.04+, `= 1`
by default) is a diagnostic, not a failure, since an AppArmor profile might
already compensate for it and this check has no way to see that; the older,
more universal `kernel.unprivileged_userns_clone` has no such escape hatch, so
`= 0` there — checked only as a fallback when the AppArmor knob is absent —
*is* a real failure, with the sysctl fix printed. Same notes-versus-failures
split as `lsp.test.ts`: a missing Linux-only dependency on macOS is `t.skip`,
not a failure.

`tests/extensions-deps.test.ts` covers the one binary dependency outside
pi-sandbox: `extensions/git-checkpoint.ts` and `extensions/statusline.ts` both
shell out to `git` directly (`pi.exec`/`execFile`), bypassing pi's own tool
layer entirely, so a machine without `git` on `PATH` gets a silent no-op
checkpoint and a blank footer status instead of an error at the point of use.
`pi-magpi`, `pi-mcporter`, `pi-ask-user`, `@ctogg/pi-cost-counter`, and
`@narumitw/pi-retry` were checked too and spawn nothing external; only
`@narumitw/pi-lsp` does, and that's what `lsp.test.ts` already covers per
server. All three dependency-presence checks (`lsp.test.ts`,
`sandbox-deps.test.ts`, `extensions-deps.test.ts`) share one `PATH` lookup,
`resolveCommand()` in `tests/lib.ts`, rather than each reimplementing
`command -v` through `spawnSync`.

### Troubleshooting: `apply-seccomp: ... nested userns ... CAP_SYS_ADMIN` on Ubuntu 24.04+

Seen on a stock Ubuntu 24.04+ machine (Oracle Cloud instance, nothing custom
about the host): every `bash` command inside pi fails with a `CAP_SYS_ADMIN`
error from `apply-seccomp` (from `@carderne/sandbox-runtime`), even though a
bare `bwrap --unshare-all ... echo ok` outside pi works fine. Cause: bwrap's
own first-level userns works, but `apply-seccomp` needs a **second, nested**
unprivileged userns inside it, which Ubuntu's AppArmor mitigation for this
(upstream profile
[`bwrap-userns-restrict`](https://gitlab.com/apparmor/apparmor/-/blob/main/profiles/apparmor/profiles/extras/bwrap-userns-restrict),
shipped by Canonical since noble) blocks via the `unpriv_bwrap` and
`unprivileged_userns` profiles — **regardless of the
`kernel.apparmor_restrict_unprivileged_userns` sysctl**, which only affects
genuinely unconfined processes, not ones already governed by a loaded
profile. Confirm with `sudo aa-status` (look for `bwrap`, `unpriv_bwrap`,
`unprivileged_userns` under enforce mode) and `sudo dmesg | grep -i apparmor`
(look for `apparmor="DENIED" ... capname="sys_admin"`). Confirmed
unaffected: macOS M1 and Raspberry Pi 5 running Raspberry Pi OS — this is
specific to Ubuntu 24.04+'s AppArmor policy, not `pi-sandbox` or `bwrap` in
general.

A scoped AppArmor override that keeps these profiles enforcing was tried at
length here and didn't work — the blanket `audit deny capability,` in
`unpriv_bwrap` won against local-override allows regardless of `priority=`,
and `no_new_privs` (which bwrap sets) blocks exec transitions to any other
named profile outright. The working fix:

```bash
sudo aa-complain bwrap unpriv_bwrap unprivileged_userns
```

This logs violations instead of blocking them, for exactly these three
profiles — narrower than disabling the sysctl (which affects every unconfined
process on the machine), but it does remove Ubuntu's userns hardening for
anything else that also runs through `bwrap` on that machine. **It does not
survive a reboot** (verified: `aa-complain` only changes in-kernel state, not
the on-disk `flags=` in `/etc/apparmor.d/bwrap-userns-restrict`) — re-run the
command after every reboot, or make it stick on purpose:

```bash
sudo sed -i 's/flags=(attach_disconnected, mediate_deleted)/flags=(attach_disconnected, mediate_deleted, complain)/' /etc/apparmor.d/bwrap-userns-restrict
sudo apparmor_parser -r /etc/apparmor.d/bwrap-userns-restrict
```

To revert back to full enforcement:

```bash
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=1
sudo aa-enforce bwrap unpriv_bwrap unprivileged_userns
```

## Statusline extension

`extensions/statusline.ts` replaces pi's footer with the three-line Claude Code
layout (`user@host 📂dir (branch*)`, then model/context/cost/tokens/durations,
then whatever other extensions published through `ctx.ui.setStatus()`), and
`/statusline` toggles back to the built-in one. That toggle is remembered on
`globalThis` for the rest of the pi process, so a session switch, `/fork` or
`/reload` — each of which re-imports the extension and re-fires `session_start` —
keeps the choice instead of reinstating `CONFIG.enabledByDefault`. The api/wall
clock timers live in the same place for the same reason.

The numbers are re-derived from the raw session log, since extensions get no
access to what the built-in footer computes internally. Deliberate consequences,
all of them inherited from pi's own accounting (`FooterComponent.render()` in
`dist/modes/interactive/components/footer.js`):

- **Everything is session-wide, including abandoned branches.** `getEntries()`
  returns the whole tree, so tokens, cost and the `+N/-M` line counts still
  include work discarded by a rewind or a `/fork`. For cost that is simply true
  (the money was spent); for the line counts it means the footer answers "how
  much editing has this session done", not "what is in the working tree".
- **`CH` is the latest response's cache hit rate**, not a session average — same
  as `latestCacheHitRate` upstream.
- **`+N/-M` only sees the `edit` and `write` tools.** `write` over an existing
  file counts the whole file as added (the old content is not in the log), and
  edits made through `bash` (`sed`, heredocs) are invisible.
- **No `(sub)` marker for subscription-backed models.** The built-in footer shows
  `$0.000 (sub)` using `modelRuntime.isUsingSubscription()`, which extensions
  cannot reach, so this footer just omits the cost group when the cost is zero.

Two things it does *not* inherit, because pi's behaviour is elsewhere: `(auto)`
reads `compaction.enabled` from `.pi/settings.json` only when
`ctx.isProjectTrusted()` is true, matching `SettingsManager`, which ignores
project settings for an untrusted project entirely; and the `*` dirty marker
treats *any* `git status --porcelain` output as dirty even when git also reports
an error, so a repository dirty enough to overflow `execFile`'s `maxBuffer` does
not read as clean.

`tests/statusline.test.ts` pins the accounting and the formatters — the scan is
incremental across renders, so it also asserts that scanning entry-by-entry
matches scanning the whole log at once, and that a log *shorter* than the cursor
(a session file swapped underneath) restarts the scan instead of silently
skipping it. Unlike `guard.test.ts`, it cannot import the extension directly:
statusline.ts has runtime imports of `getAgentDir` and `truncateToWidth`, which
resolve only inside pi's own installation, so the test registers a
`module.registerHooks()` resolve hook that redirects the two `@earendil-works/*`
specifiers into the package `piPackageDir()` already locates, then imports the
module dynamically. The git polling and the timers are not covered.

## Model tiers

Agents and `settings.json` never name a concrete model. They reference role
tokens embedded in the `name` of a `models.json` entry:

| Token | Meaning |
|-------|---------|
| `tier:fast` | Cheap, mechanical lookup and recon |
| `tier:mid` | Default implementation model |
| `tier:strong` | Architecture, review, adversarial verification |
| `tier:fable` | Experimental top-end model. No agent uses it, and it is kept out of the `Ctrl+P` cycle |
| `tier:local-fast` | Local Ollama model, zero cost, answers in seconds ([notes](#ollama-provider)) |
| `tier:local-strong` | Local llama.cpp model, zero cost but slow enough to be for delegated work rather than conversation ([notes](#llamacpp-provider)) |

Only `models.json` knows which provider and model a tier resolves to, so a
machine with entirely different providers needs no changes anywhere else — and this
table deliberately does not repeat the current mapping, which would be a copy that
rots the next time a tier moves. `./check.sh` prints it instead
(`tiers.test.ts`, "tier tokens and their models"), including which model a mistyped
tier would silently land on and which prefixes are too ambiguous to pin.

Bedrock (this machine):

```json
{ "id": "arn:aws:bedrock:...:application-inference-profile/...",
  "name": "tier:strong (claude-opus-5)" }
```

Direct Anthropic — no custom model needed, just attach the alias to a built-in
model with `modelOverrides`:

```json
{ "providers": { "anthropic": { "modelOverrides": {
    "claude-opus-4-5":   { "name": "tier:strong (claude-opus-4.5)" },
    "claude-sonnet-4-5": { "name": "tier:mid (claude-sonnet-4.5)" },
    "claude-haiku-4-5":  { "name": "tier:fast (claude-haiku-4.5)" }
} } } }
```

Local-only machine:

```json
{ "id": "qwen3-coder:30b", "name": "tier:strong (qwen3-coder-30b)" }
{ "id": "gemma4:e4b",      "name": "tier:mid (gemma4-e4b)" }
```

### Pricing

`cost` is **USD per 1M tokens**, `cacheWrite` the 5-minute cache write price and
`cacheRead` the cache hit price. The reference is always the
[AWS Bedrock pricing page](https://aws.amazon.com/bedrock/pricing/) for
**us-east-1, on-demand**. Update these whenever a tier points at a new model; they
only drive the footer's cost readout, so a stale value is silently wrong rather
than broken.

Why us-east-1 specifically: an application inference profile hides which model and
region it resolves to, so the numbers need one fixed basis. Bedrock prices the
`us.` and `global.` cross-region profiles the same as us-east-1, while `eu.` and
`au.` run about 10% higher — do not chase those; the file stays on the us-east-1
basis.

AWS's Price List API (`pricing.us-east-1.amazonaws.com/.../AmazonBedrock/...`) is
not usable here: it still only carries Claude 2 and Claude 3 era models, so the
pricing page is authoritative. `check.sh` cross-checks these values against
`models-store.json` (only differences are reported, never a failure — see the
[file table](#files)).

### Rules the tokens must obey

From pi's resolver (`dist/core/model-resolver.js`). `check.sh` enforces
the first two:

- **Unique.** `--model` falls back to a case-insensitive substring match over id
  and name. An ambiguous substring is **not** an error: pi sorts the matches by id
  and silently takes the highest one. `--model bedrock-claude` used to resolve to
  the most expensive model this way.
- **Never a thinking level.** A trailing `:<suffix>` is consumed as a thinking
  level when it is one of `off`, `minimal`, `low`, `medium`, `high`, `xhigh`,
  `max`, and the rest is the pattern. That is what makes the agents'
  `tier:fast:low` work — and what makes `tier:high` a trap, since the pattern is
  then `tier`, which matches every entry. pi sorts those by id and takes the
  highest, so a mistyped tier quietly runs an agent on whichever model happens to
  sort last; `./check.sh` names that model rather than this paragraph, since it
  changes with the ids. `fast` / `mid` / `strong` / `fable` / `local` are safe as
  tier names precisely because none of them is a level.
- **A shared prefix is ambiguous too, even one nobody defined.** Tokens like
  `tier:local-fast` and `tier:local-strong` are each unique, but the bare
  `tier:local` is a substring of both, so it hits two models and pi silently takes
  the higher id. Never pin a prefix; `check.sh` reports every shared prefix it can
  derive, while its uniqueness assertion only covers tokens an agent actually uses.
- **A bare, non-glob pattern only ever resolves to one model — even in
  `enabledModels`.** `tier:local` is not a glob (no `*`, `?`, `[`), so
  `enabledModels: ["tier:local"]` does not enable both local models; it
  substring-matches them, then applies the same "sort by id, take the highest"
  rule as `--model`. Use an actual glob such as `"ollama/*"` (matches on
  `provider/id`) whenever a tier name is meant to cover more than one model.
- **`*` does not cross a `/`.** Globs go through minimatch, so a pattern needs one
  segment per `/` in `provider/id`. Ollama ids have none (`ollama/*` works), but
  llama.cpp names its models after the Hugging Face repo they came from
  (`llama.cpp/<hf-user>/<repo>:<quant>`), and there `llama.cpp/*` matches
  **nothing at all** — the model simply never appears in `/model`, which looks
  like a broken server rather than a bad glob. It needs `llama.cpp/**`.
  `llama.test.ts` asserts this by asking pi's own resolver.
- The colon itself is fine. Full-pattern matching happens before the colon split,
  which is also why Ollama ids such as `<model>:<tag>` work.

A wrong token behaves differently depending on where it is used:

| Path | Unmatched `tier:typo` |
|------|----------------------|
| `--model` (agents, CLI) | Hard error, no fallback — strict mode exists precisely to avoid resolving to a different model |
| `enabledModels` / `--models` | Warns `Invalid thinking level "typo"` at startup, then matches the `tier` prefix and scopes the wrong model |
| `defaultModel` | Silently ignored: it is looked up as `getModel(defaultProvider, defaultModel)`, an `id === value` match with no name, substring or glob handling, so **a tier name never matches** and pi falls through to `enabledModels[0]`. The value must be a raw id, here a Bedrock ARN |

`settings.json` patterns are intentionally **not** validated by the script: that
would mean reimplementing globs, `provider/id` handling and thinking-level
parsing, which rots as pi changes. pi already warns about unmatched scope
patterns on startup.

## Sample files

A fresh clone starts from the committed `.sample` files, since the real
`settings.json` / `models.json` / `auth.json` are untracked. `check.sh` enforces
that they parse, that a fresh machine can bootstrap (every tier an agent asks for
resolves exactly once in `models.json.sample`), and that no sample carries an ARN,
an AWS account id or a value taken from the real `auth.json`.

Samples are **not** required to mirror the real config. Which providers and models
a machine has is machine specific, so an entry present on only one side is
reported as a note, not a failure — the same for a differing `settings.json` key.
Treat those notes as a reminder to sync when the difference was not intentional.

- `models.json.sample` is generated from the real file by replacing each Bedrock
  ARN with its `<<<...>>>` placeholder, keyed on the tier name. Regenerate it
  whenever a model is added or a tier is renamed.
- `settings.json.sample` tracks `settings.json` minus the two keys pi rewrites at
  runtime: `lastChangelogVersion` (on upgrade) and `defaultThinkingLevel` (on the
  in-session toggle). The sample holds the intended starting level, not whatever
  the last session was left on. `defaultProvider` and `defaultModel` are both
  placeholders: both are machine specific, and they only work as a pair, so a
  `<<<...>>>` left in either one makes the default inert
  ([above](#rules-the-tokens-must-obey)). The model placeholder names
  `pi --list-models` rather than `models.json`, because the id may belong to a
  built-in catalog model, and says *not a tier* because that is the one wrong value
  that looks right. `check.sh` fails a half-filled pair, and a `defaultModel` that is
  neither a placeholder nor a real id.
- `auth.json.sample` is maintained by hand as a template.

## Packages

`settings.json` `packages`, installed into `npm/` on first launch. The list stays
short on purpose: every entry also loads in each subagent process, and a package
runs with full system access (`docs/packages.md`), so what earns a place is small,
dependency-free, auditable code.

| Package | Why |
|---------|-----|
| `@ctogg/pi-cost-counter` | Appends every assistant message's `usage` to `~/.pi/cost-tracker/YYYY/MM/DD.jsonl` and adds `/cost [Nd]` for daily and per-model totals. The statusline below shows the *current session*; this is the only cross-session ledger. 284 lines, no dependencies, no network access, append-only writes |
| `@narumitw/pi-lsp` | Language server tools, see [Language servers](#language-servers-pi-lsp) |
| `@narumitw/pi-retry` | Marks empty-detail and stalled provider streams as retryable and hands them to pi's own backoff rather than looping itself. 325 lines, no dependencies, no network or filesystem access |
| `pi-ask-user` | An `ask_user` tool with a structured form, so the model asks instead of guessing. Also ships an `ask-user` skill. Needs a UI: it degrades where `ctx.hasUI` is false, so subagents do not get it |
| `pi-magpi` | `magpi_fetch` / `magpi_search` / `magpi_cached`: pages fetched as markdown behind a 24 h cache, with official-API handlers for GitHub, GitLab, npm, PyPI, crates, rubygems, maven, hex, arxiv, Wikipedia, StackExchange and HN. Search scrapes `lite.duckduckgo.com`, the one fragile part. SSRF-guarded: a model-supplied URL cannot reach loopback, link-local (AWS IMDS) or private ranges unless `allowPrivateNetwork` is set |
| `pi-mcporter` | Bridges MCP servers into pi through a `mcporter` proxy tool, with per-server exposure levels (`on-demand`/`index`/`match`/`native`, see `mcporter.json` above) that control how much of a server's tool schema lands in context before it is ever called. **Documented exception** to the bar below: it drags in `@modelcontextprotocol/{client,server,core}`, `es-toolkit`, `zod` and `rolldown`, the last shipping a 16 MB prebuilt native binary (`@rolldown/binding-darwin-arm64/*.node`) — precisely what `pi-smart-fetch` was rejected for. Kept anyway: nothing dependency-free does what MCP access does, and the exposure-level design is the point — it is what lets pi see a server's tools on demand instead of native MCP integrations (Claude Code included) dumping every connected server's full schema into every session's context |
| `pi-sandbox` | OS-level `bash` and `read`/`write`/`edit` sandboxing (Seatbelt on macOS, bubblewrap+seccomp on Linux) via `@carderne/sandbox-runtime`, policy in `sandbox.json` (see [Sandbox extension](#sandbox-extension)). **Second documented exception**: `sandbox-runtime` ships prebuilt per-arch binaries for its own enforcement (`vendor/seccomp/{x64,arm64}/apply-seccomp`, ~0.6-0.7 MB each; an unused `vendor/srt-win/*.exe` pair too) — the same category of weight `pi-smart-fetch` was rejected for. Kept anyway, for the same reason as `pi-mcporter`: nothing dependency-free gives `bash` an actual kernel-enforced filesystem/network boundary instead of a pattern match, and `extensions/guard.ts` says plainly that its own read block is not one |

Measured: `npm/` holds 95 MB. Before `pi-mcporter` it was 19 MB; `pi-mcporter`'s
`mcporter` dependency chain accounts for 60 MB of the jump to 79 MB (see above);
`pi-sandbox` plus `@carderne/sandbox-runtime` account for the remaining ~16 MB
to 95 MB, roughly 7 MB of it the two `apply-seccomp` binaries. All three
packages are pure JavaScript except for the one native binary each of
`pi-mcporter` and `pi-sandbox` carries. Startup went from 0.67 s to 1.03 s after
`pi-mcporter` alone — paid again by every subagent process; `pi-sandbox` was not
isolated in a follow-up measurement, since every launch is now sandboxed by
default and there is no more an unsandboxed baseline to diff against on this
machine. `pi-mcporter` was not isolated in the 0.67→1.03 s figure either:
end-to-end trials with and without it (`pi --no-session -p "OK"`, 5 runs each)
were noisy (~4.6 s vs ~5.6 s, network call time dominating) and not clean
enough to state a per-launch cost separately. Nearly all of the
pre-`pi-mcporter` total is MagPi's HTML and PDF
conversion dependencies; retry and ask-user together cost 160 KB and nothing
measurable, and cost-counter 28 KB.

Cost-counter records `message.model`, which under `amazon-bedrock` is the full
inference profile ARN, so **`/cost` prints the AWS account ID** and its "by model"
column (padded to 45 characters) wraps. The ledger under `cost-tracker/` holds the
same ARNs; `~/.gitignore` covers `.config/` wholesale, so it is only reachable by
an explicit `git add -f` like the tracked files here. Accuracy rides on the `cost`
blocks in `models.json` — `tests/pricing.test.ts` is what keeps those honest, and
ollama is priced at 0 so local runs record zero rather than nothing.

MagPi builds its paths from `homedir()` plus pi's `CONFIG_DIR_NAME` instead of
calling `getAgentDir()`, so its config and cache would sit in `~/.pi/agent/`. The
`~/.pi -> .config/pi` symlink above resolves that to this directory, which is why
`magpi.json` and `magpi-cache/` appear in the table. Cost-counter is the same
case, one level up: `homedir()` plus a hardcoded `.pi/cost-tracker`. `magpi.json` sets two of
MagPi's four keys: a 100 MB cache budget with LRU eviction (its default is
unlimited), and `allowPrivateNetwork: false`, which is already the default but is
pinned because it is the SSRF guard that keeps a model-supplied URL away from AWS
IMDS on a machine holding Bedrock credentials. `ttlHours` stays at 24: package
registry metadata is exactly the kind of thing a longer cache would answer
stalely, and `refresh` on a single call bypasses the cache anyway. `/magpi status`
reports scope, ttl, budget and what the session saved; `/magpi scope project`
would move writes to `.pi/magpi-cache` inside the repo, and it records that
project-locally when the project is trusted.

Rejected on the same criteria: `pi-smart-fetch`, which puts
`@earendil-works/pi-tui@^0.82.1` in `dependencies` against the host's 0.84.1 —
core packages must be peer dependencies — and pulls 54 MB of prebuilt Rust
binaries through `wreq-js`. `pi-mcporter` and `pi-sandbox` above trip the same
native-binary and dependency-weight tripwire and were kept anyway, each as its
own deliberate exception — not a change to the bar itself. The line the two
actually cross is capability, not weight: neither MCP access nor a real OS
sandbox boundary can be built dependency-free, unlike everything else in the
table.

## Language servers (pi-lsp)

`settings.json` lists `npm:@narumitw/pi-lsp` under `packages`, and pi installs
missing packages into `npm/` on first launch (unless `PI_OFFLINE` is set), so a
fresh machine needs no manual step. It adds `lsp_diagnostics`, `lsp_fix` and
`/lsp`.

`pi-lsp.json` **replaces** pi-lsp's built-in catalog, and it is deliberately a
superset of what any single machine has installed: the file stays identical
everywhere, servers come from mason so the binary is shared with neovim, and
`check.sh` reports what is missing here. That is safe because an entry whose
command is absent stays inert until a call includes a file matching its
extensions — the catch is that it then aborts that whole call, losing the other
servers' results too, since the "skipped unavailable server" pre-check only
applies to catalog defaults. So the risk is not an unused language, it is a
language used here whose server was never installed.

- **`check.sh` separates the two states.** A server missing from `PATH` is a
  note, not a failure, since the file is machine independent. A server that is
  on `PATH` but cannot exec *is* a failure: mason wrappers hardcode the asdf
  interpreter present at install time (`ruby-lsp`, `fennel-ls`), so an asdf
  upgrade leaves them installed but dead with exit 126, in neovim too. Reinstall
  the server through mason.
- **`pushDiagnosticsGraceMs`** on the push-only servers stops a clean file from
  waiting out the full `timeout`.
- **Ruby needs both servers**: `ruby-lsp` gives parse errors only, `rubocop --lsp`
  the style layer. `clojure-lsp` embeds clj-kondo and needs no companion.
- **biome lints but does not typecheck**, so `.ts` type errors are uncovered; add
  `vtsls` if that ever matters. Its extension list omits `.json` on purpose, to
  leave JSON a single route through `vscode-json-language-server`. Python is
  split the same way as Ruby: `ruff` for lint, `ty` for types.
- **`lsp_fix` only really works for gopls** (`source.organizeImports`). rubocop
  exposes autocorrect as per-diagnostic quickfixes and biome marks most fixes
  *unsafe*, both of which `source.fixAll` skips: use `rubocop -a` and
  `biome check --write`.

## Ollama provider

`models.json` registers a local Ollama provider, which backs `tier:local-fast`.
Non-obvious bits:

- `apiKey` is a dummy string. Ollama ignores it, but pi hides models with no
  configured auth, so the placeholder is required.
- `compat.supportsDeveloperRole: false` — Ollama rejects the `developer` role, so
  the system prompt must go out as `system`.
- `gemma4:e4b` is the **GGUF** tag, chosen over `gemma4:e4b-mlx` on purpose:
  - The MLX runner is text-only. It advertises vision/audio in the registry
    manifest, but the runtime drops the image and the model only sees an
    `[img-0]` placeholder. Ollama issues
    [#16700](https://github.com/ollama/ollama/issues/16700),
    [#17065](https://github.com/ollama/ollama/issues/17065); pending PRs
    [#17487](https://github.com/ollama/ollama/pull/17487),
    [#17600](https://github.com/ollama/ollama/pull/17600).
  - MLX generation collapses as context grows (measured here: 38 tok/s at short
    context, 17-20 tok/s at 4-16k), while GGUF holds a flat ~29.5 tok/s.
- Verified on the GGUF tag: vision, streaming and parallel tool calls,
  tool-result round-trips, thinking combined with tool calls.

Both points are findings about a specific tag, so they name it; which tag
`tier:local-fast` currently points at is `models.json`'s business, and `check.sh`
prints it.

If MLX vision lands upstream, re-benchmark before switching, and add `"image"` to
the model's `input` only after confirming it at runtime.

## llama.cpp provider

Unlike Ollama, this one is **not** a hand-written `models.json` provider: pi ships a
hidden built-in extension (`dist/extensions/index.js`: `builtInExtensions =
[{ name: "llama.cpp", ... hidden: true }]`) that registers both the `llama.cpp`
provider and the `/llama` command, and discovers models from a running
[router server](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md#using-multiple-models)
(`docs/llama-cpp.md`). Only *loaded* (or idle-`sleeping`) models reach `/model`.

The server side is two files, both tracked, both free of paths and secrets:

| File | Why there |
|------|-----------|
| `~/.config/llama.cpp/config.ini` | The **only** path llama.cpp reads by itself: `/etc/llama.cpp/config.ini`, then `${XDG_CONFIG_HOME:-~/.config}/llama.cpp/config.ini` (`common/arg.cpp`, `common_params_apply_system_config`). Router-level settings live here — `host`, `port`, and `models-max = 1`, which the router strips from child presets (`server-models.cpp`, `unset_reserved_args`) |
| `~/.config/llama.cpp/models.ini` | Per-model presets. `--models-preset` has **no** default path, and the ini parser expands neither `~` nor `$VARS`, so the location comes from `$LLAMA_ARG_MODELS_PRESET` (exported in `~/.zshrc` and `~/.bashrc`) and every artifact is named by Hugging Face repo or URL instead of a local file |

Non-obvious bits, each of which failed silently once here:

- **A preset section needs its own `hf-repo`.** The router lists a sourceless
  section in `GET /models` all the same; the failure only shows up on load. With
  `hf-repo` the router downloads on first load, and once cached the cache entry
  carries the same `repo:quant` name (`common/preset.cpp`, `load_from_cache`) and
  *merges* with the preset, so there is no duplicate entry.
- **`modelOverrides`, not `models`.** The built-in provider hardcodes
  `reasoning: false` and `supportsReasoningEffort: false` (`dist/extensions/llama/provider.js`),
  so a thinking model needs `models.json` to override it. The override key must be
  the router's model id exactly; pi ignores unknown ids without a word.
- **`thinkingLevelMap` is mandatory for a Qwen3.8-style template.** Its chat
  template accepts only `low`, `medium`, `xhigh` and calls `raise_exception` on
  anything else — pi's `high` returns **HTTP 500** from the Jinja engine, measured.
  The map sends `xhigh` for pi's `high`/`xhigh`/`max` and `low` for
  `minimal`/`low`. Any local model with thinking controls needs the same treatment,
  derived from its own template rather than copied from this one.
- **`enabledModels` needs `llama.cpp/**`**, per the [glob rule](#rules-the-tokens-must-obey).
- **The presets are shared config; serving them is not.** Both ini files are
  tracked, so a preset section written for this machine travels to every other one,
  and a Linux box that only runs cloud models fails `check.sh` for a model it was
  never meant to serve. That is inert at runtime — a preset does nothing until
  something asks for that model, and `hf-repo` fetches it then — but the
  `enabledModels` check only makes sense where the router is actually reachable, so
  it keys off `auth.json` naming a `llama.cpp` provider (machine-local, written by
  `/login`, and the one thing pi cannot reach a router without). It reads whether
  the key is there, never its value. A machine that skips this check says so with a
  reason; a machine that does serve the presets still fails on a bad glob.
- **Downloads bypass `/llama`'s progress bar** when the preset carries `hf-repo`,
  because the *child* process downloads rather than the router; the status stays
  `loading`. Watch `~/.cache/huggingface/hub/` instead. Preset-sourced models also
  report `can_remove: false`, so deleting one means removing that directory by hand
  (`DELETE /models` only works for pure cache entries).
- **The port is pinned to 9931**, llama.cpp's announced future default
  ([PR #26508](https://github.com/ggml-org/llama.cpp/pull/26508)), to keep 8080
  free for dev servers. pi prefers the URL stored by `/login` over
  `$LLAMA_BASE_URL`, so changing it means re-running `/login llama.cpp`;
  `llama.test.ts` reports the mismatch as a diagnostic.
- **An API key belongs in `$LLAMA_API_KEY`** (`~/.custom_env`, untracked), which
  llama-server and pi both read. Without one the router warns that CORS is open to
  every origin, which matters even on a loopback listener.

Measured on this machine (M1 Pro, 32 GB) with the model behind `tier:local-strong`
at the time — a 27B dense hybrid-attention model at Q4_K_M, 16.8 GB of weights.
The figures are properties of that pairing, not of llama.cpp, so they are worth
re-measuring after any model or quant change:

| | Value |
|---|---|
| Generation | **4.1-4.4 tok/s** |
| Prefill | **38 tok/s** — a 3.6k-token prompt costs 95 s |
| Prompt cache hit | Same prompt again: **0.64 s** (3618 of 3622 tokens reused); appending a sentence reused 3106 and cost 14 s |
| Resident | **21.4 GB wired**, which pushes the rest of the machine into ~7.4 GB of swap |
| Idle sleep | `sleep-idle-seconds` drops that to **3.6 GB wired**, but the prompt cache does **not** survive it (`cache_n=0` on wake), so the next request pays a full re-prefill |

So `--cache-ram -1` plus `--cache-reuse 256` is what makes the model usable at all,
and `tier:local-strong` is meant for delegated, non-interactive work rather than
conversation. `sleep-idle-seconds = 900` follows from the table: a turn takes
1.5-2 min, so gaps inside an active session run 2-5 min and must not trigger a
sleep, while a real walk-away should not keep 21 GB pinned. The measurement behind
it is worth repeating on other hardware:

```bash
P=~/.config/llama.cpp/models.ini
M=$(sed -n 's/^\[\(.*\/.*\)\]$/\1/p' $P | head -1)          # the preset's model id
U=$(sed -n 's/^port *= *\(.*\)/\1/p' ~/.config/llama.cpp/config.ini | head -1)
IDLE=$(sed -n 's/^sleep-idle-seconds *= *\(.*\)/\1/p' $P | head -1)
Q=/tmp/long.json   # any prompt of a few thousand tokens, as an OpenAI chat body

time curl -s 127.0.0.1:$U/v1/chat/completions -d @$Q -H 'Content-Type: application/json' \
  | python3 -c 'import json,sys;t=json.load(sys.stdin)["timings"];print(t["prompt_n"],t["cache_n"])'
time curl -s 127.0.0.1:$U/v1/chat/completions -d @$Q -H 'Content-Type: application/json' >/dev/null
                                        # second run must be < 1 s: prompt cache
sleep $((IDLE + 15))                    # /props and /models do not reset the timer
curl -s "127.0.0.1:$U/props?model=$M" | grep -o '"is_sleeping":[a-z]*'
vm_stat | grep 'wired down'             # compare against the loaded figure
time curl -s 127.0.0.1:$U/v1/chat/completions -d @$Q -H 'Content-Type: application/json' >/dev/null
                                        # wake cost: cache_n back to 0 means full re-prefill
```

`tests/llama.test.ts` covers what is checkable statically: no secret or path in
either ini, every preset has a model source, every `modelOverrides` key matches a
preset section, and `enabledModels` actually reaches the models — the last one
through pi's own `resolveModelScopeWithDiagnostics`, so the glob rule cannot drift.

## New machine setup

1. `export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME/pi/agent"` must be active
   (already in `~/.zshrc`). Without it pi reads `~/.pi/agent` instead.
2. `brew install pi-coding-agent`
3. Clone the dotfiles repo — brings `extensions/`, `agents/`, `prompts/`,
   `AGENTS.md`, `check.sh`, this README, the `.sample` files, and the
   `~/.pi -> .config/pi` symlink (tracked, so no manual step).
4. Create the real config from the samples:
   ```bash
   cd ~/.config/pi/agent
   cp settings.json.sample settings.json  # see Sample files for defaultProvider/
                                          # defaultModel below
   cp models.json.sample models.json   # replace <<<...>>> with real Bedrock ARNs,
                                       # or rewrite it for whatever providers this
                                       # machine has
   cp auth.json.sample auth.json       # or use /login
   ```
   `models.json` must define `tier:fast`, `tier:mid` and `tier:strong`, otherwise
   the agents cannot resolve a model. See [Model tiers](#model-tiers) and [Sample
   files](#sample-files).
5. Local models:
   - Ollama: pull whatever `models.json` lists, so this step needs no editing when
     the model changes:
     ```bash
     python3 -c 'import json;print("\n".join(m["id"] for m in json.load(open("models.json"))["providers"]["ollama"]["models"]))' \
       | xargs -n1 ollama pull
     ```
   - llama.cpp: `brew install llama.cpp`, then start the router in a new shell
     (`llama-server`, no `--model`) so it picks up `config.ini` and
     `$LLAMA_ARG_MODELS_PRESET`. In pi: `/login llama.cpp` with the URL built from
     `config.ini`'s `host`/`port`, then `/llama` to load a model — the first load
     downloads it. See [llama.cpp provider](#llamacpp-provider).
6. Language servers: install through mason, as
   [above](#language-servers-pi-lsp). `./check.sh` lists what `pi-lsp.json`
   expects and whether it runs.
7. Verify: `pi --list-models` and `./check.sh`
## Security note

The subagent extension defaults to `agentScope: "user"`, so only agents in this
directory are loaded. Project-local `.pi/agents/*.md` are repo-controlled prompts
that can instruct the model to read files and run commands — enable them
(`agentScope: "both"`) only for repositories you trust.
