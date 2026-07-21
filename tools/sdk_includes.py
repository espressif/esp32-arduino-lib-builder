#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Single source of truth for populating the SDK include tree + search paths.

The per-chip Arduino SDK exposes a component's public headers in two places that must
stay in sync:
  * flags/includes    - the GCC search path (-iwithprefixbefore <rel>), used by the
                        Arduino IDE/CLI build.
  * pioarduino-build.py CPPPATH - the same dirs, used by the PlatformIO build.

Both are derived from the include dirs of a build's aggregate public compile command
(the main/arduino-lib-builder-gcc.c entry in build/compile_commands.json). This module
owns the mapping (IDF include dir -> SDK location), the header copy, the resolution of
relative "../" includes, and the registration in BOTH consumers, so there is exactly ONE
implementation shared by:
  * tools/copy-libs.sh   'base'   - the default (NimBLE) build populates the tree fresh.
  * tools/copy-bt-variant.sh 'append' - a BT flavor (e.g. Bluedroid) unions in any
                        public include dirs the default build did not expose (the "bt"
                        component adds include dirs conditionally on the host, e.g.
                        bredr/include and the whole Bluedroid host api/include surface).

'append' only adds dirs not already registered and never overwrites shipped headers,
which is correct because the design shares all headers across stacks except the per-flavor
sdkconfig.h. It updates flags/includes AND the pio CPPPATH so both builds see the flavor.
"""

import argparse
import json
import os
import re
import shutil
import sys

HEADER_EXTS = (".h", ".hpp", ".inc")
# Component names copy-libs.sh deliberately does not ship as SDK include dirs.
SKIP_COMPONENTS = {"arduino", "config"}
# Parent dir names that terminate the walk up to a component root.
COMPONENT_ROOTS = {"components", "managed_components", "build"}
# Relative #include directives that reference files outside any include dir.
_REL_INCLUDE_RE = re.compile(r'#include\s*"([^"]*\.\./[^"]*)"')


def log(msg):
    """Progress goes to stderr so 'base' mode can pipe pio CPPPATH lines on stdout."""
    sys.stderr.write(msg + "\n")


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------
def include_dirs_from_compile_commands(cc_path):
    """Ordered, de-duplicated absolute -I dirs from the aggregate public compile entry.

    Prefers the main/arduino-lib-builder-gcc.c entry (its include path is the union of
    every public dependency's public headers). Falls back to the union across all entries
    if that source is ever renamed.
    """
    with open(cc_path, encoding="utf-8") as fh:
        entries = json.load(fh)

    def tokens(entry):
        if isinstance(entry.get("arguments"), list):
            return entry["arguments"]
        return (entry.get("command") or "").split()

    def dirs_of(entry):
        directory = entry.get("directory") or ""
        toks = tokens(entry)
        out, i = [], 0
        while i < len(toks):
            tok = toks[i]
            path = None
            if tok == "-I" and i + 1 < len(toks):
                path, i = toks[i + 1], i + 1
            elif tok.startswith("-I") and len(tok) > 2:
                path = tok[2:]
            if path:
                if not os.path.isabs(path):
                    path = os.path.join(directory, path)
                real = os.path.realpath(path)
                if os.path.isdir(real):
                    out.append(real)
            i += 1
        return out

    ordered = None
    for entry in entries:
        if str(entry.get("file", "")).endswith("arduino-lib-builder-gcc.c"):
            ordered = dirs_of(entry)
            break
    if ordered is None:
        ordered = [d for e in entries for d in dirs_of(e)]

    seen, result = set(), []
    for d in ordered:
        if d not in seen:
            seen.add(d)
            result.append(d)
    return result


# ---------------------------------------------------------------------------
# Mapping: IDF include dir -> (component name, subpath under the component)
# ---------------------------------------------------------------------------
def map_to_component(inc_dir):
    """Return (fname, out_sub, comp_root) or None, mirroring copy-libs.sh's walk.

    out_sub has a leading '/' (or '' for the component root itself). comp_root is the
    absolute component directory (used to resolve '../' includes that escape the subdir).
    """
    ipath = inc_dir
    fname = os.path.basename(ipath)
    dname = os.path.basename(os.path.dirname(ipath))
    while dname not in COMPONENT_ROOTS:
        parent = os.path.dirname(ipath)
        if parent == ipath:  # hit filesystem root without a component root
            return None
        ipath = parent
        fname = os.path.basename(ipath)
        dname = os.path.basename(os.path.dirname(ipath))
    if fname in SKIP_COMPONENTS:
        return None
    out_sub = inc_dir[len(ipath):]
    return fname, out_sub, ipath


def rel_of(fname, out_sub):
    return (fname + out_sub).replace(os.sep, "/")


def pio_cpppath_line(pio_prefix, fname, out_sub):
    """One CPPPATH entry: join(<prefix>, "include", "<fname>", "<seg>"...),"""
    segments = [fname] + [s for s in out_sub.strip("/").split("/") if s]
    quoted = ", ".join(f'"{s}"' for s in segments)
    return f'        join({pio_prefix}, "include", {quoted}),'


# ---------------------------------------------------------------------------
# Copy + relative-include resolution
# ---------------------------------------------------------------------------
def copy_headers(src_dir, dst_dir):
    """Copy *.h/*.hpp/*.inc from src_dir into dst_dir, never overwriting existing files."""
    copied = 0
    for root, _dirs, files in os.walk(src_dir):
        rel_root = os.path.relpath(root, src_dir)
        target_root = dst_dir if rel_root == "." else os.path.join(dst_dir, rel_root)
        for fn in files:
            if not fn.endswith(HEADER_EXTS):
                continue
            dst = os.path.join(target_root, fn)
            if os.path.exists(dst):
                continue
            os.makedirs(target_root, exist_ok=True)
            shutil.copy2(os.path.join(root, fn), dst)
            copied += 1
    return copied


def resolve_relative_includes(out_cpath, src_item, comp_root, sdk_include_root):
    """Copy headers referenced via '../' relative #include from just-copied headers.

    Some public headers reference files by relative path that live elsewhere in the
    component source tree and are not part of any include dir (so they were never copied).
    Resolve where the compiler would look, find the source, copy it, and repeat for
    transitive deps. Only header files are copied; already-present files terminate cycles.
    """
    canonical_sdk = os.path.realpath(sdk_include_root)

    def seed():
        pairs = []
        for root, _dirs, files in os.walk(out_cpath):
            for fn in files:
                if fn.endswith(HEADER_EXTS):
                    f = os.path.join(root, fn)
                    src_dir = src_item + os.path.dirname(f)[len(out_cpath):]
                    pairs.append((f, src_dir))
        return pairs

    scan = seed()
    while scan:
        nxt = []
        for f, src_dir in scan:
            out_dir = os.path.dirname(f)
            try:
                with open(f, encoding="utf-8", errors="ignore") as fh:
                    text = fh.read()
            except OSError:
                continue
            for rel_inc in _REL_INCLUDE_RE.findall(text):
                # realpath (like bash's `realpath -m`) so the SDK-containment guard is not
                # defeated by symlinks in the prefix (e.g. macOS /tmp -> /private/tmp).
                resolved_out = os.path.realpath(os.path.join(out_dir, rel_inc))
                if (not resolved_out.startswith(canonical_sdk + os.sep)
                        or os.path.isfile(resolved_out)):
                    continue
                # Method 1: same relative path from the header's source dir.
                resolved_src = os.path.realpath(os.path.join(src_dir, rel_inc))
                # Method 2: strip leading '../' and look under the component root.
                if not os.path.isfile(resolved_src):
                    tail = re.sub(r"^(\.\./)+", "", rel_inc)
                    resolved_src = os.path.join(comp_root, tail)
                if not os.path.isfile(resolved_src):
                    continue
                if not resolved_src.endswith(HEADER_EXTS):
                    continue
                os.makedirs(os.path.dirname(resolved_out), exist_ok=True)
                shutil.copy2(resolved_src, resolved_out)
                log(f"Auto-copied missing relative include: {rel_inc} (from {os.path.basename(f)})")
                nxt.append((resolved_out, os.path.dirname(resolved_src)))
        scan = nxt


# ---------------------------------------------------------------------------
# flags/includes helpers
# ---------------------------------------------------------------------------
def registered_rels(flags_includes_path):
    rels = set()
    try:
        with open(flags_includes_path, encoding="utf-8") as fh:
            toks = fh.read().split()
    except OSError:
        return rels
    for i, tok in enumerate(toks):
        if tok == "-iwithprefixbefore" and i + 1 < len(toks):
            rels.add(toks[i + 1])
    return rels


# ---------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------
def process(inc_dirs, sdk_include_root, skip_rels):
    """Map/copy/resolve each include dir. Returns ordered list of (rel, fname, out_sub)."""
    result, seen = [], set()
    for inc_dir in inc_dirs:
        mapped = map_to_component(inc_dir)
        if not mapped:
            continue
        fname, out_sub, comp_root = mapped
        rel = rel_of(fname, out_sub)
        if rel in seen or rel in skip_rels:
            continue
        seen.add(rel)
        out_cpath = os.path.join(sdk_include_root, *rel.split("/"))
        copied = copy_headers(inc_dir, out_cpath)
        resolve_relative_includes(out_cpath, inc_dir, comp_root, sdk_include_root)
        result.append((rel, fname, out_sub, copied))
    return result


def cmd_base(args):
    inc_dirs = include_dirs_from_compile_commands(args.compile_commands)
    processed = process(inc_dirs, args.sdk_include, skip_rels=set())

    # flags/includes: -iwithprefixbefore <rel>, space-separated, trailing space, no newline.
    rel_str = "".join(f"-iwithprefixbefore {rel} " for rel, _f, _s, _c in processed)
    flags_dir = os.path.dirname(args.flags_includes)
    if flags_dir:
        os.makedirs(flags_dir, exist_ok=True)
    with open(args.flags_includes, "w", encoding="utf-8") as fh:
        fh.write(rel_str)

    # pio CPPPATH entries -> stdout (copy-libs.sh redirects this into pioarduino-build.py).
    for _rel, fname, out_sub, _c in processed:
        print(pio_cpppath_line(args.pio_prefix, fname, out_sub))

    log(f"* Populated SDK include tree: {len(processed)} dir(s)")
    return 0


def cmd_append(args):
    already = registered_rels(args.flags_includes)
    inc_dirs = include_dirs_from_compile_commands(args.compile_commands)
    processed = process(inc_dirs, args.sdk_include, skip_rels=already)
    if not processed:
        return 0

    addition = "".join(f" -iwithprefixbefore {rel}" for rel, _f, _s, _c in processed)
    with open(args.flags_includes, "a", encoding="utf-8") as fh:
        fh.write(addition + " ")

    for rel, _f, _s, copied in processed:
        log(f"  +include: {rel}  ({copied} header(s) added)")

    _update_pio_cpppath(args.pio_file, processed)
    log(f"* Synced {len(processed)} flavor-only include dir(s) into the shared SDK")
    return 0


def _update_pio_cpppath(pio_file, processed):
    """Insert new CPPPATH entries into an already-generated pioarduino-build.py."""
    if not pio_file or not os.path.isfile(pio_file):
        log("  (pioarduino-build.py not found; skipping PlatformIO CPPPATH update)")
        return
    with open(pio_file, encoding="utf-8") as fh:
        lines = fh.readlines()

    cpppath_idx = next((i for i, ln in enumerate(lines) if ln.strip() == "CPPPATH=["), None)
    if cpppath_idx is None:
        log("  (CPPPATH block not found in pioarduino-build.py; skipping)")
        return

    # Recover the prefix (e.g. FRAMEWORK_SDK_DIR, "esp32s31") from an existing entry so
    # new lines match the generated file exactly.
    prefix = None
    for ln in lines[cpppath_idx + 1:]:
        m = re.search(r'join\((.*?),\s*"include"', ln)
        if m:
            prefix = m.group(1)
            break
    if prefix is None:
        log("  (could not determine pio path prefix; skipping CPPPATH update)")
        return

    new_lines = [pio_cpppath_line(prefix, fname, out_sub) + "\n"
                 for _rel, fname, out_sub, _c in processed]
    lines[cpppath_idx + 1:cpppath_idx + 1] = new_lines
    with open(pio_file, "w", encoding="utf-8") as fh:
        fh.writelines(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Populate/sync the SDK include tree + search paths")
    sub = ap.add_subparsers(dest="mode", required=True)

    b = sub.add_parser("base", help="populate the tree fresh from the default build")
    b.add_argument("--compile-commands", required=True)
    b.add_argument("--sdk-include", required=True, help="$AR_SDK/include")
    b.add_argument("--flags-includes", required=True, help="$AR_SDK/flags/includes")
    b.add_argument("--pio-prefix", required=True, help='e.g. FRAMEWORK_SDK_DIR, "esp32s31"')
    b.set_defaults(func=cmd_base)

    a = sub.add_parser("append", help="union flavor-only include dirs into the shared tree")
    a.add_argument("--compile-commands", required=True)
    a.add_argument("--sdk-include", required=True, help="$AR_SDK/include")
    a.add_argument("--flags-includes", required=True, help="$AR_SDK/flags/includes")
    a.add_argument("--pio-file", default="", help="$AR_SDK/pioarduino-build.py")
    a.set_defaults(func=cmd_append)

    args = ap.parse_args(argv)
    if not os.path.isfile(args.compile_commands):
        sys.stderr.write(f"ERROR: {args.compile_commands} not found\n")
        return 1
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
