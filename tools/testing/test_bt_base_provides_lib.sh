#!/usr/bin/env bash
#
# Regression test for bt_base_provides_lib (tools/config.sh).
#
# A base-provided archive -- whether shared (lib/) OR shipped per memory config as a
# mem-variant (e.g. libspi_flash.a under <memconf>/) -- must be recognised so
# copy-bt-variant.sh does NOT duplicate it into lib/<flavor>/. The libspi_flash.a case
# is the specific regression: spi_flash is a flash-mode/PSRAM-dependent mem-variant lib
# that appears on the flavor's link line but is not in the shared lib/, so the old
# "-f $AR_SDK/lib/lib<name>.a" check wrongly shipped it as a flavor-only blob.
#
# Run: bash tools/testing/test_bt_base_provides_lib.sh
#
# NOTE: no `set -u` here -- config.sh (sourced below) references optional env like
# $GITHUB_TOKEN unguarded, which is fine in normal use but trips nounset.

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# config.sh is safe to source (its top-level work is guarded and cwd-relative). Sandbox
# PWD to a scratch dir so its AR_* derivations never touch the real repo, and silence its
# progress/DEBUG output. bt_base_provides_lib takes sdk/memconf as args, so the sourced
# globals are irrelevant to the assertions.
tmp="$(mktemp -d "${TMPDIR:-/tmp}/btbase.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
# shellcheck disable=SC1090
source "$TOOLS_DIR/config.sh" >/dev/null 2>&1 || true

if ! declare -F bt_base_provides_lib >/dev/null; then
	echo "FAIL: bt_base_provides_lib not defined after sourcing config.sh"
	exit 1
fi

fail=0
assert_provided() {   # name memconf : expect provided (return 0)
	if bt_base_provides_lib "$1" "$SDK" "$2"; then
		echo "ok  : provided '$1' (memconf='$2')"
	else
		echo "FAIL: expected '$1' (memconf='$2') to be base-provided"; fail=1
	fi
}
assert_not_provided() {   # name memconf : expect NOT provided (return 1)
	if bt_base_provides_lib "$1" "$SDK" "$2"; then
		echo "FAIL: expected '$1' (memconf='$2') to NOT be base-provided"; fail=1
	else
		echo "ok  : not-provided '$1' (memconf='$2')"
	fi
}

# Fake SDK: a shared component archive (libbt.a) and a per-memconf mem-variant archive
# (libspi_flash.a under qio_opi/), mirroring the real layout.
SDK="$tmp/sdk"
mkdir -p "$SDK/lib" "$SDK/qio_opi"
: > "$SDK/lib/libbt.a"
: > "$SDK/qio_opi/libspi_flash.a"

# Shared archive in lib/ -> provided regardless of memconf.
assert_provided     bt         qio_opi
assert_provided     bt         ""
# Mem-variant archive under <memconf>/ -> provided (THE spi_flash regression).
assert_provided     spi_flash  qio_opi
# Same mem-variant lib is NOT provided when it is neither in lib/ nor in the given
# memconf dir (e.g. empty memconf, or a memconf that has not been populated) -> the
# flavor blob path would (correctly) still consider a genuinely-absent archive.
assert_not_provided spi_flash  ""
assert_not_provided spi_flash  dio_qspi
# A genuinely flavor-only vendor blob (present nowhere in the base) -> NOT provided,
# so copy-bt-variant.sh will ship it into lib/<flavor>/ as intended.
assert_not_provided bredr_app  qio_opi

if [ "$fail" -eq 0 ]; then
	echo "ALL PASS (bt_base_provides_lib)"
else
	echo "FAILURES DETECTED"
fi
exit "$fail"
