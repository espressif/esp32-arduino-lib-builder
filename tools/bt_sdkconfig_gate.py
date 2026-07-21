#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""sdkconfig.h diff gate for the selectable BT stack.

Only BT-related CONFIG_* symbols may differ between the default (NimBLE) base build
and a flavor (e.g. Bluedroid) build for the SAME memory config. Anything else means a
non-BT setting leaked into the flavor build and must be fixed.

The set of symbols allowed to differ is AUTO-DERIVED from three self-updating sources,
so nothing is hand-maintained and it tracks options being added/removed/renamed:

  1. Kconfig dependency closure -- every option whose 'depends_on' (transitively, and
     including inherited menu/if deps) references a BT symbol. Read from the build's own
     build/config/kconfig_menus.json, which covers every component that took part in the
     build (managed components included), each with its resolved dependency expression.
     This catches BT options that lack a BT_ prefix AND cross-component options outside
     components/bt (e.g. CONFIG_NETWORK_PROV_BLE_SEC_CONN depends on BT_NIMBLE_ENABLED).
  2. Options declared under components/bt -- belt-and-suspenders if the menus dump from
     (1) is unavailable.
  3. sdkconfig.rename aliases whose canonical (new) name is a BT symbol (e.g.
     CONFIG_A2DP_ENABLE -> CONFIG_BT_A2DP_ENABLE). These are compat macros, not Kconfig
     nodes, so (1) does not see them.

'select'/'imply' relations are NOT expressed in kconfig_menus.json, so a symbol that is
*selected* by a BT option without any BT 'depends_on' (e.g. BLE Mesh selecting an mbedtls
option) is not derived here. That rare case is handled by the optional per-flavor
escape-hatch file (--allow-file); otherwise the gate fails loudly rather than silently.

Exit status: 0 = gate passes, 1 = a non-BT symbol leaked (or inputs missing).
"""

import argparse
import json
import os
import re
import sys

# CONFIG_* prefixes that are unconditionally BT-owned.
BT_PREFIX_RE = re.compile(r"^CONFIG_(BT_|BTDM_|BLE_|BLUEDROID_|NIMBLE_|BR_EDR_)")
# Same prefixes, but on bare Kconfig symbol names (no CONFIG_) as used in kconfig_menus.json.
BT_NAME_RE = re.compile(r"^(BT_|BTDM_|BLE_|BLUEDROID_|NIMBLE_|BR_EDR_)")
# Identifier tokens inside a 'depends_on' expression.
TOKEN_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
# Expression keywords that are not symbol references.
EXPR_KEYWORDS = {"y", "n", "if", "on"}
# Symbols whose value legitimately varies for reasons unrelated to the BT stack.
IGNORE_SYMS = {"CONFIG_ARDUINO_IDF_COMMIT", "CONFIG_ARDUINO_IDF_BRANCH"}


def _expr_tokens(expr):
    if not expr:
        return set()
    return {t for t in TOKEN_RE.findall(expr)} - EXPR_KEYWORDS


def bt_driven_syms_from_menus(menus_path):
    """Return CONFIG_<name> for every option whose dependency closure reaches a BT symbol.

    Returns an empty set (silently) if the dump is missing or unparsable, so the other
    allow-set sources act as a fallback.
    """
    if not menus_path or not os.path.isfile(menus_path):
        return set()
    try:
        with open(menus_path, encoding="utf-8") as fh:
            menus = json.load(fh)
    except (OSError, ValueError):
        return set()

    # symbol name -> set of symbols referenced by its (inherited + own) dependency exprs
    refs = {}

    def walk(nodes, inherited):
        for node in nodes:
            acc = inherited | _expr_tokens(node.get("depends_on"))
            name = node.get("name")
            if name:
                refs.setdefault(name, set()).update(acc)
            walk(node.get("children") or [], acc)

    walk(menus, set())

    def reaches_bt(sym, seen):
        if sym in seen:
            return False
        seen.add(sym)
        for ref in refs.get(sym, ()):
            if BT_NAME_RE.match(ref) or (ref in refs and reaches_bt(ref, seen)):
                return True
        return False

    return {
        "CONFIG_" + sym
        for sym in refs
        if not BT_NAME_RE.match(sym) and reaches_bt(sym, set())
    }


def _iter_files(root, prefixes):
    """Yield paths under root whose basename starts with any of the given prefixes."""
    if not root or not os.path.isdir(root):
        return
    for dirpath, _dirnames, filenames in os.walk(root):
        for fn in filenames:
            if any(fn.startswith(p) for p in prefixes):
                yield os.path.join(dirpath, fn)


_KCONFIG_DECL_RE = re.compile(r"^\s*(?:menuconfig|config)\s+([A-Za-z0-9_]+)")


def bt_component_decl_syms(idf_dir):
    """CONFIG_<name> for every option DECLARED under components/bt (any Kconfig* file)."""
    out = set()
    bt_dir = os.path.join(idf_dir, "components", "bt") if idf_dir else None
    for path in _iter_files(bt_dir, ("Kconfig",)):
        try:
            with open(path, encoding="utf-8", errors="ignore") as fh:
                for line in fh:
                    m = _KCONFIG_DECL_RE.match(line)
                    if m:
                        out.add("CONFIG_" + m.group(1))
        except OSError:
            continue
    return out


_RENAME_RE = re.compile(r"^(CONFIG_[A-Za-z0-9_]+)\s+(!?CONFIG_[A-Za-z0-9_]+)")


def rename_alias_syms(idf_dir):
    """Legacy sdkconfig.rename aliases whose canonical (new) name is a BT symbol."""
    out = set()
    comp_dir = os.path.join(idf_dir, "components") if idf_dir else None
    for path in _iter_files(comp_dir, ("sdkconfig.rename",)):
        try:
            with open(path, encoding="utf-8", errors="ignore") as fh:
                for line in fh:
                    m = _RENAME_RE.match(line)
                    if not m:
                        continue
                    canonical = m.group(2).lstrip("!")
                    if BT_PREFIX_RE.match(canonical):
                        out.add(m.group(1))
        except OSError:
            continue
    return out


def build_allow_set(menus_path, idf_dir):
    """Union of the three auto-derived sources of BT-owned / BT-driven symbols."""
    return (
        bt_driven_syms_from_menus(menus_path)
        | bt_component_decl_syms(idf_dir)
        | rename_alias_syms(idf_dir)
    )


_DEFINE_RE = re.compile(r"^#define\s+(CONFIG_[A-Za-z0-9_]+)\s*(.*)$")


def read_defines(path):
    """Map CONFIG_* symbol -> defined value string, from a compile-time sdkconfig.h."""
    defines = {}
    with open(path, encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            m = _DEFINE_RE.match(line)
            if not m:
                continue
            sym = m.group(1)
            if sym in IGNORE_SYMS:
                continue
            defines[sym] = m.group(2).rstrip()
    return defines


def differing_symbols(base_path, variant_path):
    """Symbols whose #define value (or presence) differs between the two headers."""
    base = read_defines(base_path)
    variant = read_defines(variant_path)
    sentinel = object()
    return sorted(
        sym for sym in set(base) | set(variant)
        if base.get(sym, sentinel) != variant.get(sym, sentinel)
    )


def load_allow_file(path):
    """Compile the optional escape-hatch regexes (one ERE per line; '#'/blank ignored)."""
    patterns = []
    if not path or not os.path.isfile(path):
        return patterns
    with open(path, encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            try:
                patterns.append(re.compile(line))
            except re.error:
                sys.stderr.write(f"WARNING: ignoring invalid allow-file regex: {line}\n")
    return patterns


def classify_leaks(diff_syms, allow_set, allow_patterns):
    """Return the differing symbols that are NOT explained by BT (i.e. real leaks)."""
    bad = []
    for sym in diff_syms:
        if BT_PREFIX_RE.match(sym):
            continue
        if sym in allow_set:
            continue
        if any(p.search(sym) for p in allow_patterns):
            continue
        bad.append(sym)
    return bad


def main(argv=None):
    ap = argparse.ArgumentParser(description="BT sdkconfig.h diff gate")
    ap.add_argument("--base", required=True, help="default (NimBLE) sdkconfig.h")
    ap.add_argument("--variant", required=True, help="flavor sdkconfig.h")
    ap.add_argument("--idf-dir", default="", help="IDF source tree (components/bt, renames)")
    ap.add_argument("--menus", default="", help="build/config/kconfig_menus.json")
    ap.add_argument("--allow-file", default="", help="optional escape-hatch regex file")
    ap.add_argument("--variant-name", default="", help="flavor name (for messages)")
    ap.add_argument("--memconf", default="", help="memory config (for messages)")
    args = ap.parse_args(argv)

    if not os.path.isfile(args.base):
        sys.stderr.write(
            f"ERROR: base sdkconfig.h not found: {args.base} (was the default build run first?)\n"
        )
        return 1
    if not os.path.isfile(args.variant):
        sys.stderr.write(f"ERROR: flavor sdkconfig.h not found: {args.variant}\n")
        return 1

    diff_syms = differing_symbols(args.base, args.variant)
    allow_set = build_allow_set(args.menus, args.idf_dir)
    allow_patterns = load_allow_file(args.allow_file)
    bad = classify_leaks(diff_syms, allow_set, allow_patterns)

    if bad:
        name = args.variant_name or "flavor"
        allow_file = args.allow_file or f"configs/bt_{name}.sdkconfig_allow"
        print(f"ERROR: sdkconfig.h diff gate failed for '{name}' ({args.memconf}).")
        print("       These non-BT CONFIG_* symbols differ between the NimBLE base and the flavor:")
        for sym in bad:
            print(f"         - {sym}")
        print("       The default and flavor builds must differ ONLY in BT configuration.")
        print("       If a symbol is a legitimate transitive consequence of the flavor, add it")
        print(f"       to {allow_file}; otherwise fix configs/defconfig.bt_{name}")
        print("       (or the shared defconfig layers) so the leak goes away.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
