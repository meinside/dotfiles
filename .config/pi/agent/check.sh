#!/usr/bin/env bash
#
# Verify this config directory, as documented in README.md. The checks live in
# tests/ and run on node's built-in test runner; each file's header says what it
# pins and why. Machine-specific differences (which models, which language
# servers) arrive as notes or skips; only drift, an unresolvable tier, a leak, a
# server that cannot exec or a guard regression fails. Node runs the TypeScript
# directly, so there is nothing to build and nothing to install.
#
# Usage: ./check.sh [-v]     # -v prints diffs for drifting vendored files
#
set -uo pipefail

[ "${1:-}" = "-v" ] && export PI_CHECK_VERBOSE=1

C="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# pi.dev/install.sh may install its own node without adding it to shell profiles;
# the launcher puts it on PATH the same way.
pi_node_bin="${XDG_DATA_HOME:-$HOME/.local/share}/pi-node/current/bin"
[ -x "$pi_node_bin/node" ] && PATH="$pi_node_bin:$PATH"
if ! command -v node >/dev/null; then
    echo "error: node not found; install Node.js 22.19+ or let pi.dev/install.sh install it" >&2
    exit 2
fi

# Resolved once, by the same function the tests use, and handed to them through
# PI_CHECK_PREFIX: saves every test file a `brew --prefix` and a PATH search. They
# fall back to resolving it themselves when run directly (node --test tests/x.test.ts).
# Checked here rather than in a test: without it every vendored case fails with the
# same cause, and tiers.test.ts cannot borrow pi's resolver at all.
if ! PI_PACKAGE_DIR="$(node --input-type=module -e \
    "import { piPackageDir } from '$C/tests/lib.ts'; console.log(piPackageDir())" 2>&1)"; then
    echo "error: $PI_PACKAGE_DIR" >&2
    exit 2
fi
export PI_CHECK_PREFIX="$PI_PACKAGE_DIR"
U="$PI_PACKAGE_DIR/examples/extensions"
if [ ! -d "$U/subagent" ]; then
    echo "error: upstream examples not found in $U" >&2
    exit 2
fi

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
