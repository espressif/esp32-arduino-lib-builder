#!/bin/bash
#
# tools/copy-bt-variant.sh
#
# Adds one alternative Bluetooth stack "flavor" (e.g. Bluedroid + BT Classic) to the
# per-chip SDK that the default NimBLE build already populated, WITHOUT duplicating the
# whole SDK tree. Only the handful of libraries whose code actually depends on the BT
# host are shipped a second time; everything else (includes, flags, linker scripts and
# all non-BT archives) is shared between the two stacks.
#
# WHICH LIBRARIES ARE SWAPPED
#   A library must be swapped iff its compiled code can change with the selected BT
#   host. That is exactly the set of components that depend (directly or transitively)
#   on IDF's "bt" component. We read that straight from each build's own dependency
#   graph in build/project_description.json (reqs/priv_reqs/managed_reqs), so there is
#   NO hardcoded allow/deny list and new BT-dependent components are picked up
#   automatically. On a typical build this resolves to: bt, esp_hid, protocomm,
#   network_provisioning, esp_local_ctrl. mbedtls & friends are dependencies OF bt
#   (not dependents), so they are correctly left shared.
#
#   The swappable set is the UNION of the bt-dependents of the default (NimBLE) build
#   and of this flavor build, not just the flavor's. copy-libs.sh records the NimBLE
#   set in .bt_meta/<chip>/sig_nimble; this script reads it and unions it in. That makes
#   the mechanism symmetric and future-proof: a component that depends on bt in only ONE
#   stack (a NimBLE-only or a Bluedroid-only BT feature) is still shipped per-stack and
#   moved out of the always-linked ld_libs. Each stack's link list then contains only
#   the archives that stack actually built (a stack-only archive is compiled against that
#   host's config and must not be linked into the other stack).
#
# HOW IT SHIPS THEM
#   The flavor archives are copied into $AR_SDK/lib/<flavor>/ under their ORIGINAL
#   basenames (stripped). Keeping the basename is REQUIRED: IDF linker fragments place
#   sections by archive name (e.g. *libbt.a:(.iram1 ...)), so a renamed archive would
#   silently lose its IRAM/PSRAM/bss placement. The board menu prepends
#   -L.../lib/<flavor> so these resolve ahead of the shared default copies. The default
#   (NimBLE) archives shipped by copy-libs.sh in $AR_SDK/lib are the other option.
#
# This script is invoked by the "bt-variant" CMake target after the flavor's elf is
# built. On the PRIMARY pass (AR_BT_PRIMARY=1, same memory config as idf-libs) it:
#   * discovers the swappable set from project_description.json and ships the flavor
#     archives into $AR_SDK/lib/<flavor>/,
#   * writes flags/ld_libs_bt_nimble and flags/ld_libs_bt_<flavor> (the -l names for
#     each stack) and sets the default flags/ld_libs_bt to the NimBLE set,
#   * removes the swappable set from the always-linked flags/ld_libs,
#   * verifies flags/defines carries no BT CONFIG_* macros,
#   * verifies the shipped (NimBLE-generated) linker scripts place BT archives the same
#     way the flavor build does (placement gate), since those scripts are shared.
#
# On EVERY pass (primary and each memory variant) it:
#   * stashes the flavor sdkconfig.h under $AR_SDK/<memconf>/<flavor>/include,
#   * enforces the sdkconfig.h diff gate (only BT CONFIG_* may differ vs NimBLE).
# On each MEMORY-VARIANT pass it additionally runs the memory-agnostic guard (see
# below).
#
# NOTE the swappable archives are shipped ONCE (from the primary pass) and shared
# across every memory config, exactly like copy-libs.sh ships the NimBLE BT archives
# once into $AR_SDK/lib. That is only valid if a BT archive is flash-mode/PSRAM
# independent (BT memory placement lives in the linker scripts, not in the archive).
# The primary pass records a content signature (bt_lib_sig) of each swappable archive
# and every memory-variant pass re-checks it (bt_check_mem_agnostic): if a swapped
# archive ever becomes memory-dependent the build fails loudly, because it could no
# longer be shipped as a single shared file. The NimBLE side is guarded the same way
# from copy-libs.sh (reference) + copy-mem-variant.sh (re-check).
#
# Precompiled controller/PHY blobs (e.g. libbtdm_app.a, libbtbb.a) live outside build/
# and are identical for both stacks, so copy-libs.sh ships them once and they are never
# considered here.
#
# Args (mirroring tools/copy-libs.sh):
#   $1 IDF_TARGET  $2 CHIP_VARIANT  $3 FLASHMODE  $4 SPIRAM_OCT(y/n)  $5 IS_XTENSA(y/n)
# Env:
#   AR_BT_VARIANT  required, e.g. "bluedroid" (matches configs/defconfig.bt_<flavor>)
#   AR_BT_PRIMARY  "1" on the primary pass, unset/"0" on memory-variant passes

IDF_TARGET=$1
CHIP_VARIANT=$2
IS_XTENSA=$5
OCT_FLASH="$3"
if [ "$4" = "y" ]; then
	OCT_PSRAM="opi"
else
	OCT_PSRAM="qspi"
fi
MEMCONF=$OCT_FLASH"_$OCT_PSRAM"

source ./tools/config.sh

if [ -z "$AR_BT_VARIANT" ]; then
	echo "ERROR: AR_BT_VARIANT is not set"
	exit 1
fi

if [ "$IS_XTENSA" = "y" ]; then
	TOOLCHAIN="xtensa-$IDF_TARGET-elf"
else
	TOOLCHAIN="riscv32-esp-elf"
fi

BT_META_DIR="$AR_ROOT/.bt_meta/$CHIP_VARIANT"
SIG_FLAVOR="$BT_META_DIR/sig_$AR_BT_VARIANT"
FLAGS_DIR="$AR_SDK/flags"
PROJ_DESC="build/project_description.json"

echo "* BT variant '$AR_BT_VARIANT' for $CHIP_VARIANT (MEMCONF=$MEMCONF, primary=${AR_BT_PRIMARY:-0})"

# The swappable-library discovery (bt_swappable_libs), the archive signature
# (bt_lib_sig) and the memory-agnostic guard (bt_check_mem_agnostic) all live in
# tools/config.sh so copy-libs.sh, copy-mem-variant.sh and this script share one
# implementation.

# ---------------------------------------------------------------------------
# sdkconfig.h diff gate: only BT-related CONFIG_* symbols may differ between the
# NimBLE base and this flavor for the SAME memory config. Anything else means a
# non-BT setting leaked into the flavor build and must be fixed.
#
# The whole gate -- auto-deriving the set of BT-owned/BT-driven symbols and classifying
# the diff -- lives in tools/bt_sdkconfig_gate.py (single process, unit-testable). The
# allow set is derived from three self-updating sources so nothing is hand-maintained
# and it tracks options being added/removed/renamed: (1) every option whose Kconfig
# dependency closure reaches a BT symbol (from build/config/kconfig_menus.json, which
# also covers cross-component options like CONFIG_NETWORK_PROV_BLE_SEC_CONN); (2) options
# declared under components/bt; (3) sdkconfig.rename aliases whose canonical name is a BT
# symbol. See that script's docstring for details.
# ---------------------------------------------------------------------------
# Resolve the IDF source tree (used to derive the set of BT-owned config symbols).
IDF_DIR="${IDF_PATH:-$AR_ROOT/esp-idf}"

# ---------------------------------------------------------------------------
# Flavor-only precompiled libraries.
#
# Besides the component archives discovered from project_description.json, the flavor's
# elf link line can reference precompiled vendor blobs by ABSOLUTE path (not CMake
# components, so the dependency graph never sees them). The base (NimBLE) build already
# ships the ones common to both stacks (e.g. libble_app.a, libbtdm_common.a, libbtbb.a)
# into $AR_SDK/lib and lists them in flags/ld_libs, so those must NOT be duplicated. A
# flavor-only blob -- e.g. the BR/EDR controller lib libbredr_app.a, pulled in only when
# BT Classic is enabled -- is absent from the base, so nothing links it and the flavor
# fails at link time (undefined bredr_* / r_orca_* symbols). Ship exactly those here.
#
# Echoes the absolute path of every '.a' in the flavor link line, so the caller can
# filter to the blobs the base did not already provide. Generic (any future Bluedroid-only
# controller/PHY blob is picked up automatically), matching copy-libs.sh's own link-line
# parsing.
bt_flavor_ar_files() {
	local raw=""
	if [ -f "build/CMakeFiles/arduino-lib-builder.elf.dir/link.txt" ]; then
		raw=$(cat "build/CMakeFiles/arduino-lib-builder.elf.dir/link.txt")
	elif [ -f "build/build.ninja" ]; then
		raw=$(grep 'LINK_LIBRARIES =' build/build.ninja)
	fi
	local tok
	for tok in $raw; do
		case "$tok" in
		*.a)
			# Normalize build-relative paths to absolute, like copy-libs.sh.
			[ "${tok:0:1}" = "/" ] || tok="$PWD/build/$tok"
			[ -f "$tok" ] && printf '%s\n' "$tok"
			;;
		esac
	done
}

sdkconfig_diff_gate() {
	local base="$1" variant="$2"
	# Optional escape hatch, normally ABSENT: BT dependency-driven symbols are
	# auto-derived by the gate script, so this file is only needed for the rare
	# 'select'/'imply'-driven case not expressed as a Kconfig 'depends_on' (e.g. BLE
	# Mesh selecting an mbedtls option). One extended-regex per line; '#'/blank ignored.
	local allow_file="configs/bt_${AR_BT_VARIANT}.sdkconfig_allow"
	python3 "$AR_ROOT/tools/bt_sdkconfig_gate.py" \
		--base "$base" \
		--variant "$variant" \
		--idf-dir "$IDF_DIR" \
		--menus "build/config/kconfig_menus.json" \
		--allow-file "$allow_file" \
		--variant-name "$AR_BT_VARIANT" \
		--memconf "$MEMCONF"
}

# ---------------------------------------------------------------------------
# PRIMARY pass: discover the swappable set, ship the flavor archives, write flag files.
# ---------------------------------------------------------------------------
if [ "${AR_BT_PRIMARY:-0}" = "1" ]; then
	if [ ! -f "$PROJ_DESC" ]; then
		echo "ERROR: $PROJ_DESC not found for the flavor build"
		exit 1
	fi

	rm -rf "$AR_SDK/lib/$AR_BT_VARIANT"
	mkdir -p "$AR_SDK/lib/$AR_BT_VARIANT"
	mkdir -p "$BT_META_DIR"
	: > "$SIG_FLAVOR"
	LD_BT_FLAVOR=""
	flavor_names=""

	# Ship this flavor's BT archives (the components that depend on bt in the FLAVOR
	# build) and record their reference signatures. LD_BT_FLAVOR lists exactly what this
	# flavor built -- a component that is bt-dependent only in the OTHER stack must NOT be
	# linked here (it was compiled against the other host's config), so the flavor list is
	# intentionally limited to flavor_names.
	while IFS=$'\t' read -r comp file; do
		[ -z "$comp" ] && continue
		[ -f "$file" ] || continue
		name=$(basename "$file"); name="${name#lib}"; name="${name%.a}"

		echo "$name $(bt_lib_sig "$file")" >> "$SIG_FLAVOR"

		# Ship the archive under its original basename (linker fragments place sections
		# by basename, so it must be preserved).
		cp -f "$file" "$AR_SDK/lib/$AR_BT_VARIANT/lib$name.a"
		"$TOOLCHAIN-strip" -g "$AR_SDK/lib/$AR_BT_VARIANT/lib$name.a" 2>/dev/null
		LD_BT_FLAVOR="$LD_BT_FLAVOR -l$name"
		flavor_names="$flavor_names $name"
	done < <(bt_swappable_libs)

	if [ -z "$flavor_names" ]; then
		echo "ERROR: no swappable BT libraries discovered for '$AR_BT_VARIANT'."
		echo "       Expected at least the host stack (libbt.a) to depend on bt. Check the flavor build"
		echo "       and $PROJ_DESC."
		exit 1
	fi

	# Ship flavor-only precompiled blobs (see bt_flavor_ar_files). These are static vendor
	# archives, identical across memory configs, so -- like copy-libs.sh's controller blobs
	# -- they are shipped once from the primary pass and are NOT part of the memory-agnostic
	# guard (which covers the per-build component archives only). We keep only blobs the base
	# build did not already provide (neither in the shared $AR_SDK/lib nor as a per-memconf
	# mem-variant archive) and that are not this flavor's own component archives (handled
	# above), so common and mem-variant archives stay shared via flags/ld_libs.
	while IFS= read -r file; do
		[ -z "$file" ] && continue
		name=$(basename "$file"); name="${name#lib}"; name="${name%.a}"
		case "$name" in main | arduino) continue ;; esac
		# Already provided by the base build on the -L search path: a shared archive in
		# lib/, or a per-memconf mem-variant archive (e.g. libspi_flash.a) under <memconf>/.
		# Either way it is linked via flags/ld_libs and must NOT be duplicated as a flavor
		# blob -- doing so would break memory-agnosticism and shadow the correct per-memconf
		# copy. See bt_base_provides_lib in tools/config.sh.
		bt_base_provides_lib "$name" "$AR_SDK" "$MEMCONF" && continue
		# This flavor's own component archive -> already shipped into lib/<flavor>/ above.
		skip=0
		for n in $flavor_names; do [ "$n" = "$name" ] && { skip=1; break; }; done
		[ "$skip" = 1 ] && continue
		# Don't ship the same blob twice if it appears more than once on the link line.
		[ -f "$AR_SDK/lib/$AR_BT_VARIANT/lib$name.a" ] && continue

		cp -f "$file" "$AR_SDK/lib/$AR_BT_VARIANT/lib$name.a"
		"$TOOLCHAIN-strip" -g "$AR_SDK/lib/$AR_BT_VARIANT/lib$name.a" 2>/dev/null
		LD_BT_FLAVOR="$LD_BT_FLAVOR -l$name"
		echo "  flavor-only precompiled: lib$name.a"
	done < <(bt_flavor_ar_files)

	# NimBLE (default) build's bt-dependent component names, recorded by copy-libs.sh in
	# sig_nimble (col 1). Reading them here lets us treat the swappable set as the UNION
	# of both stacks' bt-dependents instead of just the flavor's -- future-proofing
	# against a component that depends on bt in only ONE stack (e.g. a NimBLE-only or a
	# Bluedroid-only BT feature). Without the union such a component would silently stay
	# in the always-linked ld_libs with a single stack's archive.
	nimble_names=""
	if [ -f "$BT_META_DIR/sig_nimble" ]; then
		nimble_names=$(awk '{print $1}' "$BT_META_DIR/sig_nimble")
	fi

	# swappable = union of both stacks' bt-dependent component names (deterministic order).
	swappable=$(printf '%s\n' $flavor_names $nimble_names | LC_ALL=C sort -u)

	# Build the NimBLE link list from the union: include -l<name> for every union member
	# that the default build actually shipped into lib/ (that is exactly the NimBLE
	# bt-dependent set, and it also picks up any component that is bt-dependent only under
	# NimBLE). Flavor-only components have no lib/ archive, so they are omitted here.
	LD_BT_NIMBLE=""
	for name in $swappable; do
		in_flavor=0
		for n in $flavor_names; do [ "$n" = "$name" ] && { in_flavor=1; break; }; done
		has_nimble=0
		[ -f "$AR_SDK/lib/lib$name.a" ] && has_nimble=1
		[ "$has_nimble" = 1 ] && LD_BT_NIMBLE="$LD_BT_NIMBLE -l$name"
		if [ "$in_flavor" = 1 ] && [ "$has_nimble" = 1 ]; then
			echo "  swappable: lib$name.a  (both stacks)"
		elif [ "$in_flavor" = 1 ]; then
			echo "  swappable: lib$name.a  ($AR_BT_VARIANT only)"
		else
			echo "  swappable: lib$name.a  (nimble only)"
		fi
	done

	# Strip leading spaces and publish the per-stack link lists.
	LD_BT_NIMBLE="${LD_BT_NIMBLE# }"
	LD_BT_FLAVOR="${LD_BT_FLAVOR# }"
	echo -n "$LD_BT_NIMBLE" > "$FLAGS_DIR/ld_libs_bt_nimble"
	echo -n "$LD_BT_FLAVOR" > "$FLAGS_DIR/ld_libs_bt_$AR_BT_VARIANT"
	# Default BT libs file (used by boards without the BLE Stack menu) = NimBLE set.
	echo -n "$LD_BT_NIMBLE" > "$FLAGS_DIR/ld_libs_bt"

	# Remove the whole union from the always-linked ld_libs; the BT libs are now supplied
	# exclusively through flags/ld_libs_bt* (selected by the board menu). Using the union
	# ensures a NimBLE-only bt-dependent archive is also moved out of ld_libs (otherwise
	# it would be linked unconditionally AND via the menu).
	if [ -f "$FLAGS_DIR/ld_libs" ]; then
		new_ld=""
		for tok in $(cat "$FLAGS_DIR/ld_libs"); do
			keep=1
			for sw in $swappable; do
				if [ "$tok" = "-l$sw" ]; then keep=0; break; fi
			done
			[ $keep -eq 1 ] && new_ld="$new_ld $tok"
		done
		new_ld="${new_ld# }"
		echo -n "$new_ld" > "$FLAGS_DIR/ld_libs"
	fi

	# flags/defines must stay BT-agnostic (BT config belongs in sdkconfig.h only).
	if [ -f "$FLAGS_DIR/defines" ] && grep -qE '\-DCONFIG_(BT_|BTDM_|BLE_|BLUEDROID_|NIMBLE_)' "$FLAGS_DIR/defines"; then
		echo "ERROR: flags/defines contains BT CONFIG_* macros; it must be identical for every BT stack."
		exit 1
	fi

	# Linker-script placement gate. The shipped linker scripts ($AR_SDK/ld/*.ld) are
	# generated from the default (NimBLE) build and shared by every BT stack, because
	# BT memory placement is keyed by archive BASENAME (that is why flavor archives
	# keep their original names). Confirm the flavor build did not generate different
	# placement for any BT archive; if it did, the shared scripts would misplace the
	# flavor's sections and the flavor would need its own per-stack linker scripts.
	if [ -d "$AR_SDK/ld" ]; then
		for ld in "$AR_SDK/ld"/*.ld; do
			[ -f "$ld" ] || continue
			grep -qE 'lib(bt|ble|btdm|bredr|nimble)[A-Za-z0-9_]*\.a' "$ld" || continue
			fb=$(find build \( -path '*/CMakeFiles/*' -prune \) -o -name "$(basename "$ld")" -print 2>/dev/null | head -n1)
			[ -n "$fb" ] && [ -f "$fb" ] || continue
			if ! diff -q "$ld" "$fb" >/dev/null 2>&1; then
				echo "ERROR: linker script $(basename "$ld") places BT archives differently for '$AR_BT_VARIANT' than for NimBLE."
				echo "       BT memory placement is stack-dependent, so the single shared set of shipped"
				echo "       linker scripts would misplace the flavor's sections (IRAM/PSRAM/bss)."
				echo "       This flavor must ship its own linker scripts per stack (like the per-memconf"
				echo "       handling) and select them via the board menu before it can be released."
				exit 1
			fi
		done
	fi

	echo "* Wrote flags/ld_libs_bt_nimble, flags/ld_libs_bt_$AR_BT_VARIANT and excluded the swappable set from flags/ld_libs"

	# Ship any flavor-only public include dirs. The shared include tree + search paths
	# (flags/includes and pioarduino CPPPATH) come from the default (NimBLE) build, but the
	# "bt" component adds include dirs conditionally on the host, so a flavor can expose
	# public headers the NimBLE build never shipped (e.g. bredr_user_cfg.h under
	# .../controller/bredr/include, pulled by the shared esp_bt.h when
	# UC_BT_CTRL_BR_EDR_IS_ENABLE, and the whole Bluedroid host api/include surface). The
	# shared tools/sdk_includes.py (append mode) unions those dirs into BOTH search paths so
	# an Arduino or PlatformIO flavor sketch can find them. No-op when the flavor exposes
	# nothing extra.
	if [ -f "build/compile_commands.json" ]; then
		python3 "$AR_ROOT/tools/sdk_includes.py" append \
			--compile-commands "build/compile_commands.json" \
			--sdk-include "$AR_SDK/include" \
			--flags-includes "$FLAGS_DIR/includes" \
			--pio-file "$AR_SDK/pioarduino-build.py" || exit 1
	fi
fi

# ---------------------------------------------------------------------------
# EVERY pass: stash the per-memconf flavor sdkconfig.h and run the diff gate.
# ---------------------------------------------------------------------------
if [ ! -f "build/config/sdkconfig.h" ]; then
	echo "ERROR: build/config/sdkconfig.h not found for the flavor build"
	exit 1
fi
VAR_INC_DIR="$AR_SDK/$MEMCONF/$AR_BT_VARIANT/include"
mkdir -p "$VAR_INC_DIR"
cp -f "build/config/sdkconfig.h" "$VAR_INC_DIR/sdkconfig.h"
echo "#define CONFIG_ARDUINO_IDF_COMMIT \"$IDF_COMMIT\"" >> "$VAR_INC_DIR/sdkconfig.h"
echo "#define CONFIG_ARDUINO_IDF_BRANCH \"$IDF_BRANCH\"" >> "$VAR_INC_DIR/sdkconfig.h"

if ! sdkconfig_diff_gate "$AR_SDK/$MEMCONF/include/sdkconfig.h" "$VAR_INC_DIR/sdkconfig.h"; then
	exit 1
fi

# ---------------------------------------------------------------------------
# MEMORY-VARIANT passes: memory-agnostic guard. The swappable archives were shipped
# once by the primary pass; verify this memory config rebuilds them identically (see
# bt_check_mem_agnostic in config.sh). The primary pass writes the reference above, so
# it is skipped here.
# ---------------------------------------------------------------------------
if [ "${AR_BT_PRIMARY:-0}" != "1" ]; then
	if ! bt_check_mem_agnostic "$SIG_FLAVOR" "$AR_BT_VARIANT" "$MEMCONF"; then
		exit 1
	fi
fi

echo "* BT variant '$AR_BT_VARIANT' ($MEMCONF) OK"
