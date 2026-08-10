#!/usr/bin/env bash
#
# Verify this config directory, as documented in README.md. Each check explains
# itself where it is implemented below:
#
#   1. vendored files  2. agent tiers  3. sample files  4. model pricing  5. lsp
#
# Machine-specific differences (which models, which language servers) are reported
# as notes; only drift, an unresolvable tier, a leak or a broken server fails.
#
# Does not reimplement pi's model resolution (globs, provider/id, thinking-level
# suffixes): that lives in dist/core/model-resolver.js and a copy here would rot.
#
# Usage: ./check.sh [-v]     # -v prints diffs for drifting files
#
set -uo pipefail

VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

C="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="$(brew --prefix pi-coding-agent 2>/dev/null)" || true
U="$PREFIX/libexec/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions"
if [ -z "$PREFIX" ] || [ ! -d "$U/subagent" ]; then
    echo "error: upstream examples not found (looked in ${U:-brew --prefix pi-coding-agent})" >&2
    exit 2
fi

ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[33m!\033[0m %s\n' "$1"; }

echo "pi: $(pi --version 2>/dev/null | head -1)  upstream: $U"
fail=0

# --- 1. vendored files ------------------------------------------------------
echo
echo "Vendored files:"
# local path : path under examples/extensions (the subagent files keep their own
# directory upstream, the standalone extensions sit at the top level)
for pair in \
    extensions/subagent/index.ts:subagent/index.ts \
    extensions/subagent/agents.ts:subagent/agents.ts \
    extensions/git-checkpoint.ts:git-checkpoint.ts \
    prompts/implement.md:subagent/prompts/implement.md \
    prompts/scout-and-plan.md:subagent/prompts/scout-and-plan.md \
    prompts/implement-and-review.md:subagent/prompts/implement-and-review.md \
    agents/scout.md:subagent/agents/scout.md \
    agents/planner.md:subagent/agents/planner.md \
    agents/reviewer.md:subagent/agents/reviewer.md \
    agents/worker.md:subagent/agents/worker.md; do
    rel="${pair%%:*}"
    up="$U/${pair#*:}"
    [ -f "$C/$rel" ] || {
        bad "$rel missing locally"
        fail=1
        continue
    }
    [ -f "$up" ] || {
        bad "$rel missing upstream"
        fail=1
        continue
    }

    if diff -q <(grep -v '^model:' "$C/$rel") <(grep -v '^model:' "$up") >/dev/null; then
        ok "$rel"
    else
        bad "$rel drifted from upstream"
        fail=1
        [ "$VERBOSE" = 1 ] && diff -u "$C/$rel" "$up" | sed 's/^/      /'
    fi
done

# --- 2. agent tier tokens ---------------------------------------------------
# pi matches --model as a case-insensitive substring and resolves an ambiguous
# match silently to the highest-sorting id, so uniqueness matters. A trailing
# `:<thinking level>` is consumed as the thinking level before that lookup, so it
# is stripped here too: `tier:fast:low` must check `tier:fast`. That also keeps
# the old trap caught -- `tier:high` leaves the pattern `tier`, which matches
# every entry and so fails as ambiguous.
echo
echo "Agent tiers:"
names="$(python3 -c 'import json,sys
for prov in (json.load(open(sys.argv[1])).get("providers") or {}).values():
    for m in (prov.get("models") or []):
        if m.get("name"): print(m["name"])' "$C/models.json" 2>/dev/null)"

if [ -z "$names" ]; then
    bad "models.json unreadable or defines no named models; skipping tier check"
    fail=1
else
    for f in "$C"/agents/*.md; do
        agent="$(basename "$f")"
        token="$(sed -n 's/^model: *//p' "$f" | head -1)"
        pattern="$token"
        level=""
        case "${token##*:}" in
        off | minimal | low | medium | high | xhigh | max)
            level="${token##*:}"
            pattern="${token%:*}"
            ;;
        esac
        hits="$(printf '%s\n' "$names" | grep -icF -- "${pattern:-__none__}")"

        if [ -z "$token" ]; then
            bad "$agent has no model: line (would fall back to defaultModel)"
            fail=1
        elif [ "$hits" -eq 0 ]; then
            bad "$agent -> $pattern not defined in models.json"
            fail=1
        elif [ "$hits" -gt 1 ]; then
            bad "$agent -> $pattern matches $hits models (ambiguous)"
            fail=1
        else
            ok "$agent -> $pattern${level:+ (thinking $level)}"
        fi
    done
fi

# --- 3. sample files --------------------------------------------------------
# A fresh clone starts from the *.sample files: an unresolvable tier stops a new
# machine from working, and a leak is unrecoverable once pushed.
echo
echo "Sample files:"
python3 - "$C" <<'PY' || fail=1
import json, re, sys
from glob import glob

cfg = sys.argv[1]
fails, notes = [], []
PLACEHOLDER = re.compile(r"^<<<.*>>>$")
SECRET = re.compile(r"(key|token|secret|password|credential)$", re.I)


def load(name):
    try:
        return json.load(open(f"{cfg}/{name}"))
    except Exception:
        return None


def leaves(obj, prefix=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield from leaves(v, f"{prefix}{k}.")
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from leaves(v, f"{prefix}{i}.")
    else:
        yield prefix.rstrip("."), obj


def entries(c):
    return {
        (p, m.get("name")): m.get("id", "")
        for p, pv in (c.get("providers") or {}).items()
        for m in (pv.get("models") or [])
    }


samples = {}
for name in ("models.json", "settings.json", "auth.json"):
    data = load(f"{name}.sample")
    if data is None:
        fails.append(f"{name}.sample missing or not valid JSON")
    else:
        samples[name] = data

# leak scan: no literal ARNs, no account id taken from the real models.json
real_models = load("models.json")
accounts = set(re.findall(r"\b\d{12}\b", json.dumps(real_models))) if real_models else set()
for name in samples:
    raw = open(f"{cfg}/{name}.sample").read()
    if "arn:aws" in raw:
        fails.append(f"{name}.sample contains a literal arn:aws")
    for a in sorted(a for a in accounts if a in raw):
        fails.append(f"{name}.sample contains account id {a}")

# models.json.sample is what a fresh machine starts from, so it must define every
# tier the agents ask for and must placeholder its ARNs. It is not required to
# match models.json entry for entry: which providers and models a machine has is
# machine specific, so entries on one side only are reported, not failed.
if "models.json" in samples:
    sample = entries(samples["models.json"])
    for key, sid in sample.items():
        if isinstance(sid, str) and sid.startswith("arn:"):
            fails.append(f"models.json.sample: {key[1]!r} id is a literal ARN")

    sample_names = [str(k[1]) for k in sample if k[1]]
    tokens = set()
    LEVELS = ("off", "minimal", "low", "medium", "high", "xhigh", "max")
    for agent in sorted(glob(f"{cfg}/agents/*.md")):
        for line in open(agent):
            if line.startswith("model:"):
                token = line.split(":", 1)[1].strip()
                # a trailing thinking level is consumed before the model lookup,
                # so bootstrap only needs the pattern to resolve
                if token.rsplit(":", 1)[-1] in LEVELS:
                    token = token.rsplit(":", 1)[0]
                tokens.add(token)
                break
    for token in sorted(t for t in tokens if t):
        hits = [n for n in sample_names if token.lower() in n.lower()]
        if len(hits) != 1:
            fails.append(
                f"models.json.sample defines {token!r} {len(hits)} times; agents cannot bootstrap"
            )
    if real_models:
        real = entries(real_models)
        only_real = sorted(str(k[1]) for k in real.keys() - sample.keys())
        only_sample = sorted(str(k[1]) for k in sample.keys() - real.keys())
        for name in only_real:
            notes.append(f"models.json.sample has no {name!r} (fine if machine specific)")
        for name in only_sample:
            notes.append(f"models.json has no {name!r} (fine if machine specific)")
        for key, rid in real.items():
            sid = sample.get(key)
            if not rid.startswith("arn:") or sid is None or sid.startswith("arn:"):
                continue  # absent, or already reported as a literal ARN
            if not PLACEHOLDER.match(sid):
                fails.append(f"models.json.sample: {key[1]!r} id is not a <<<placeholder>>>")
    notes.append(f"models.json.sample resolves {len(tokens)} agent tier(s)")

# settings.json.sample tracks settings.json closely, but a difference is a
# reminder rather than an error: pi rewrites lastChangelogVersion on upgrade and
# defaultThinkingLevel on the in-session toggle (both excluded outright), and the
# rest may legitimately differ per machine.
RUNTIME_KEYS = ("lastChangelogVersion", "defaultThinkingLevel")
real_settings = load("settings.json")
if "settings.json" in samples:
    if "lastChangelogVersion" in samples["settings.json"]:
        fails.append("settings.json.sample should not carry lastChangelogVersion")
    if real_settings:
        strip = lambda d: {k: v for k, v in d.items() if k not in RUNTIME_KEYS}
        a, b = strip(real_settings), strip(samples["settings.json"])
        diff = sorted(set(a) ^ set(b)) + sorted(k for k in a if k in b and a[k] != b[k])
        if diff:
            notes.append(
                "settings.json.sample differs on " + ", ".join(diff) + " (sync if not machine specific)"
            )
        else:
            notes.append("settings.json.sample matches settings.json")

# auth.json.sample is a hand written template; it must hold no real values
if "auth.json" in samples:
    secrets = {v for _, v in leaves(load("auth.json") or {}) if isinstance(v, str) and len(v) > 8}
    leaked = [
        f"{path} ({'real value' if v in secrets else 'not a placeholder'})"
        for path, v in leaves(samples["auth.json"])
        if isinstance(v, str) and (v in secrets or (SECRET.search(path) and not PLACEHOLDER.match(v)))
    ]
    if leaked:
        fails.append("auth.json.sample leaks: " + ", ".join(leaked))
    else:
        notes.append("auth.json.sample has no real credentials")

for line in notes:
    print(f"  \033[32m✓\033[0m {line}")
for line in fails:
    print(f"  \033[33m!\033[0m {line}")
raise SystemExit(1 if fails else 0)
PY

# --- 4. model pricing --------------------------------------------------------
# Prices are USD per 1M tokens, us-east-1 on-demand (see README). Application
# inference profile ARNs hide the model, so the tier's parenthesised slug is
# matched against pi's catalog instead. Differences are notes, never failures.
echo
echo "Model pricing (us-east-1):"
python3 - "$C" <<'PRICES'
import json, re, sys

cfg = sys.argv[1]
OK = "  \033[32m\u2713\033[0m %s"
TODO = "  \033[2m\u00b7\033[0m %s"
FIELDS = ("input", "output", "cacheRead", "cacheWrite")
PREFIXES = ("anthropic.", "us.anthropic.", "global.anthropic.")


def load(name):
    try:
        return json.load(open(f"{cfg}/{name}"))
    except Exception:
        return None


catalog, real = load("models-store.json"), load("models.json")
if not catalog or not real:
    print(TODO % "models-store.json or models.json unreadable; skipping price check")
    raise SystemExit(0)

costs = {}


def walk(node):
    if isinstance(node, dict):
        if isinstance(node.get("cost"), dict) and node.get("id"):
            costs.setdefault(str(node["id"]), node["cost"])
        for value in node.values():
            walk(value)
    elif isinstance(node, list):
        for value in node:
            walk(value)


walk(catalog)
models = ((real.get("providers") or {}).get("amazon-bedrock") or {}).get("models") or []
for model in models:
    found = re.search(r"\(([^)]+)\)", model.get("name") or "")
    mine = model.get("cost")
    if not found or not isinstance(mine, dict):
        continue
    slug = found.group(1)
    # us-east-1 is served by the bare and us./global. prefixed catalog ids
    hits = sorted(k for k in costs if any(k.startswith(p + slug) for p in PREFIXES))
    if not hits:
        print(TODO % f"{slug}: not in pi's catalog; verify against the AWS pricing page")
        continue
    theirs = costs[hits[0]]
    off = [f for f in FIELDS if abs(float(mine.get(f, 0)) - float(theirs.get(f, 0))) > 1e-9]
    if off:
        detail = ", ".join(f"{f} {mine.get(f)} vs {theirs.get(f)}" for f in off)
        print(TODO % f"{slug}: differs from catalog on {detail}")
    else:
        print(OK % f"{slug} {mine['input']}/{mine['output']}/{mine['cacheRead']}/{mine['cacheWrite']} per 1M")
PRICES

# --- 5. lsp servers ---------------------------------------------------------
# pi-lsp.json replaces pi-lsp's built-in catalog, so a configured command that
# cannot start fails a whole lsp_diagnostics call instead of being skipped. mason
# wrappers hardcode the asdf interpreter present at install time, which is why
# each command is executed and not just looked up on PATH.
echo
echo "LSP servers:"
python3 - "$C" <<'PY' || fail=1
import json, shutil, subprocess, sys

cfg = sys.argv[1]
OK = "  \033[32m\u2713\033[0m %s"
BAD = "  \033[33m!\033[0m %s"
TODO = "  \033[2m\u00b7\033[0m %s"

try:
    conf = json.load(open(f"{cfg}/pi-lsp.json"))
except FileNotFoundError:
    print(OK % "pi-lsp.json absent; pi-lsp would use its built-in catalog")
    raise SystemExit(0)
except Exception as exc:
    print(BAD % f"pi-lsp.json is not valid JSON: {exc}")
    raise SystemExit(1)

# both shapes are accepted by pi-lsp: a bare server map, or {"servers": {...}}
servers = conf.get("servers") if isinstance(conf.get("servers"), dict) else conf
fails, missing = [], []
for name, spec in sorted(servers.items()):
    if not isinstance(spec, dict):
        continue
    argv = spec.get("command") or []
    if not argv:
        fails.append(f"{name}: no command")
        continue
    if not spec.get("extensions"):
        fails.append(f"{name}: no extensions, so nothing routes to it")
    path = shutil.which(argv[0])
    if not path:
        missing.append(name)
        continue

    # exit 126/127 is the exec failure we care about; a hang means it started
    try:
        p = subprocess.run(
            [path, "--version"], capture_output=True, text=True, timeout=5
        )
        rc, err = p.returncode, (p.stderr or "") + (p.stdout or "")
    except subprocess.TimeoutExpired:
        rc, err = 0, ""
    except OSError as exc:
        rc, err = 126, str(exc)

    broken = rc in (126, 127) or any(
        s in err
        for s in ("bad interpreter", "cannot execute", "No such file or directory")
    )
    if broken:
        detail = next((l for l in err.splitlines() if l.strip()), f"exit {rc}")
        fails.append(f"{name}: on PATH but does not exec ({detail.strip()})")
    else:
        print(OK % f"{name} -> {path}")

# not installed here is expected: pi-lsp.json is shared across machines. It only
# bites once a file of that type is diagnosed on this one.
for name in missing:
    print(TODO % f"{name}: not installed")
if missing:
    print(TODO % "install the above, or drop the entries from pi-lsp.json")
for line in fails:
    print(BAD % line)
raise SystemExit(1 if fails else 0)
PY

echo
if [ "$fail" -ne 0 ]; then
    echo "Problems found. See README.md for the update and sample-regeneration"
    echo "procedures. -v adds diffs for drifting vendored files."
    exit 1
fi
echo "All checks passed."
