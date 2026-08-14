#!/usr/bin/env bash
#
# Verify this config directory, as documented in README.md. The checks themselves
# live in tests/ and run on node's built-in test runner:
#
#   vendored.test.ts  the vendored files still match upstream except model: lines
#   tiers.test.ts     every agent pins a tier that pi resolves to exactly one model
#   samples.test.ts   a fresh clone can bootstrap and no sample leaks a secret
#   pricing.test.ts   models.json costs against pi's catalog (reported, never fails)
#   lsp.test.ts       every pi-lsp.json command is present and can exec
#   guard.test.ts     guard.ts blocks what README says it blocks
#   sandbox.test.ts   sandbox.json holds the invariants README.md documents (see
#                     its header for why pi-sandbox's own matching logic can't be
#                     borrowed the way guard.ts's is)
#
# Machine-specific differences (which models, which language servers) arrive as
# notes or skips; only drift, an unresolvable tier, a leak, a server that cannot
# exec or a guard regression fails. Node runs the TypeScript directly, so there is
# nothing to build and nothing to install.
#
# Usage: ./check.sh [-v]     # -v prints diffs for drifting vendored files
#
set -uo pipefail

[ "${1:-}" = "-v" ] && export PI_CHECK_VERBOSE=1

C="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Mirrors tests/lib.ts's piPackageDir(): Homebrew's libexec/lib/node_modules
# layout first (fast, version-independent symlink), then a marker search
# through the real path of the `pi` binary on PATH for
# node_modules/@earendil-works/pi-coding-agent — covers plain `npm install -g`
# (including what pi.dev/install.sh does) regardless of how many directories
# separate the npm bin symlink from the package root, which a fixed number of
# `dirname` hops cannot assume.
find_pi_package_dir() {
    local prefix pi_bin pi_real marker
    marker="node_modules/@earendil-works/pi-coding-agent"
    if command -v brew >/dev/null 2>&1; then
        prefix="$(brew --prefix pi-coding-agent 2>/dev/null)" || true
        if [ -n "$prefix" ] && [ -d "$prefix/libexec/lib/node_modules/@earendil-works/pi-coding-agent" ]; then
            printf '%s\n' "$prefix/libexec/lib/node_modules/@earendil-works/pi-coding-agent"
            return 0
        fi
    fi
    pi_bin="$(command -v pi 2>/dev/null)" || return 1
    pi_real="$(readlink -f "$pi_bin" 2>/dev/null || realpath "$pi_bin" 2>/dev/null)" || return 1
    case "$pi_real" in
        *"$marker"*)
            printf '%s\n' "${pi_real%%"$marker"*}$marker"
            return 0
            ;;
    esac
    return 1
}

PI_PACKAGE_DIR="$(find_pi_package_dir)" || true
U="$PI_PACKAGE_DIR/examples/extensions"

# Checked here rather than in a test: without it every vendored case fails with
# the same cause, and tiers.test.ts cannot borrow pi's resolver at all.
if [ -z "$PI_PACKAGE_DIR" ] || [ ! -d "$U/subagent" ]; then
    echo "error: upstream examples not found (tried brew --prefix and the pi binary on PATH; looked in ${U:-<unresolved>})" >&2
    exit 2
fi
if ! command -v node >/dev/null; then
    echo "error: node not found; it comes with pi (brew install pi-coding-agent, or pi.dev/install.sh)" >&2
    exit 2
fi

# Saves every test file a subprocess and the same resolution work; they fall
# back to running it themselves when invoked directly (node --test tests/samples.test.ts).
export PI_CHECK_PREFIX="$PI_PACKAGE_DIR"

echo "pi: $(pi --version 2>/dev/null | head -1)  upstream: $U"
echo

if node --test --test-reporter=spec "$C"/tests/*.test.ts; then
    echo
    echo "All checks passed."
    exit 0
fi

echo
echo "Problems found. See README.md for the update and sample-regeneration"
echo "procedures. -v adds diffs for drifting vendored files."
exit 1
