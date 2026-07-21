#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Unit tests for tools/sdk_includes.py.

Run from the repo root (or anywhere):
    python3 -m unittest discover -s tools/testing -p 'test_*.py'
    python3 tools/testing/test_sdk_includes.py
"""

import contextlib
import io
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import sdk_includes as si  # noqa: E402


def _write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)
    return path


def _mkdirs(*paths):
    for p in paths:
        os.makedirs(p, exist_ok=True)


class MapToComponentTest(unittest.TestCase):
    def test_component_include_subdir(self):
        with tempfile.TemporaryDirectory() as d:
            inc = os.path.join(d, "components", "bt", "include")
            _mkdirs(inc)
            fname, out_sub, comp_root = si.map_to_component(inc)
            self.assertEqual(fname, "bt")
            self.assertEqual(out_sub, "/include")
            self.assertEqual(comp_root, os.path.join(d, "components", "bt"))

    def test_component_root_itself(self):
        with tempfile.TemporaryDirectory() as d:
            inc = os.path.join(d, "managed_components", "foo")
            _mkdirs(inc)
            fname, out_sub, comp_root = si.map_to_component(inc)
            self.assertEqual(fname, "foo")
            self.assertEqual(out_sub, "")

    def test_skipped_components(self):
        with tempfile.TemporaryDirectory() as d:
            for skip in ("arduino", "config"):
                inc = os.path.join(d, "components", skip, "include")
                _mkdirs(inc)
                self.assertIsNone(si.map_to_component(inc), skip)

    def test_no_component_ancestor(self):
        with tempfile.TemporaryDirectory() as d:
            inc = os.path.join(d, "just", "some", "dir")
            _mkdirs(inc)
            self.assertIsNone(si.map_to_component(inc))

    def test_build_root_and_config_skip(self):
        with tempfile.TemporaryDirectory() as d:
            # A generated include dir under build/ maps like a component.
            gen = os.path.join(d, "build", "gen", "include")
            _mkdirs(gen)
            self.assertEqual(si.map_to_component(gen), ("gen", "/include", os.path.join(d, "build", "gen")))
            # build/config is intentionally skipped (it holds sdkconfig, not public headers).
            cfg = os.path.join(d, "build", "config")
            _mkdirs(cfg)
            self.assertIsNone(si.map_to_component(cfg))


class RelAndPioLineTest(unittest.TestCase):
    def test_rel_of(self):
        self.assertEqual(si.rel_of("bt", "/include"), "bt/include")
        self.assertEqual(si.rel_of("esp_hid", ""), "esp_hid")

    def test_pio_cpppath_line(self):
        self.assertEqual(
            si.pio_cpppath_line('FRAMEWORK_SDK_DIR, "esp32s31"', "bt", "/include"),
            '        join(FRAMEWORK_SDK_DIR, "esp32s31", "include", "bt", "include"),',
        )

    def test_pio_cpppath_line_root(self):
        self.assertEqual(
            si.pio_cpppath_line("PFX", "esp_hid", ""),
            '        join(PFX, "include", "esp_hid"),',
        )

    def test_pio_cpppath_line_multi_segment(self):
        self.assertEqual(
            si.pio_cpppath_line("PFX", "bt", "/controller/bredr/include"),
            '        join(PFX, "include", "bt", "controller", "bredr", "include"),',
        )


class IncludeDirsFromCompileCommandsTest(unittest.TestCase):
    def test_prefers_aggregate_entry_and_parses_both_i_forms(self):
        with tempfile.TemporaryDirectory() as d:
            a = os.path.join(d, "a")
            b = os.path.join(d, "b")
            other = os.path.join(d, "other")
            _mkdirs(a, b, other)
            cc = _write(
                os.path.join(d, "compile_commands.json"),
                json.dumps(
                    [
                        {
                            "file": "/x/other/thing.c",
                            "directory": d,
                            "arguments": ["cc", "-I", other, "-c"],
                        },
                        {
                            "file": "/x/main/arduino-lib-builder-gcc.c",
                            "directory": d,
                            # both "-I <dir>" and "-Idir" and a relative "-Irel".
                            "arguments": ["cc", "-I", a, "-I" + b, "-Irel_b", "-c"],
                        },
                    ]
                ),
            )
            _mkdirs(os.path.join(d, "rel_b"))
            dirs = si.include_dirs_from_compile_commands(cc)
        # Only the aggregate gcc.c entry is used; 'other' is ignored.
        self.assertIn(os.path.realpath(a), dirs)
        self.assertIn(os.path.realpath(b), dirs)
        self.assertIn(os.path.realpath(os.path.join(d, "rel_b")), dirs)
        self.assertNotIn(os.path.realpath(other), dirs)

    def test_dedup_and_command_string_fallback(self):
        with tempfile.TemporaryDirectory() as d:
            a = os.path.join(d, "a")
            _mkdirs(a)
            cc = _write(
                os.path.join(d, "cc.json"),
                json.dumps(
                    [
                        # No gcc.c entry -> union across all; string "command" form.
                        {"file": "x.c", "directory": d, "command": f"cc -I{a} -I {a} -c"}
                    ]
                ),
            )
            dirs = si.include_dirs_from_compile_commands(cc)
        self.assertEqual(dirs, [os.path.realpath(a)])

    def test_nonexistent_dirs_dropped(self):
        with tempfile.TemporaryDirectory() as d:
            cc = _write(
                os.path.join(d, "cc.json"),
                json.dumps([{"file": "x.c", "directory": d, "arguments": ["cc", "-I", "/no/such/dir"]}]),
            )
            self.assertEqual(si.include_dirs_from_compile_commands(cc), [])

    def test_trailing_dash_I_without_argument_is_ignored(self):
        # A dangling "-I" as the final token must not raise IndexError.
        with tempfile.TemporaryDirectory() as d:
            cc = _write(
                os.path.join(d, "cc.json"),
                json.dumps([{"file": "x.c", "directory": d, "arguments": ["cc", "-I"]}]),
            )
            self.assertEqual(si.include_dirs_from_compile_commands(cc), [])


class CopyHeadersTest(unittest.TestCase):
    def test_copies_headers_and_never_overwrites(self):
        with tempfile.TemporaryDirectory() as d:
            src = os.path.join(d, "src")
            dst = os.path.join(d, "dst")
            _write(os.path.join(src, "a.h"), "A")
            _write(os.path.join(src, "sub", "b.hpp"), "B")
            _write(os.path.join(src, "c.inc"), "C")
            _write(os.path.join(src, "skip.c"), "not a header")
            _write(os.path.join(dst, "a.h"), "OLD")  # pre-existing -> must survive
            copied = si.copy_headers(src, dst)
            # a.h already existed (not counted/overwritten); b.hpp + c.inc copied.
            self.assertEqual(copied, 2)
            with open(os.path.join(dst, "a.h")) as fh:
                self.assertEqual(fh.read(), "OLD")
            self.assertTrue(os.path.isfile(os.path.join(dst, "sub", "b.hpp")))
            self.assertTrue(os.path.isfile(os.path.join(dst, "c.inc")))
            self.assertFalse(os.path.isfile(os.path.join(dst, "skip.c")))


class RegisteredRelsTest(unittest.TestCase):
    def test_parses_iwithprefixbefore_tokens(self):
        with tempfile.TemporaryDirectory() as d:
            p = _write(
                os.path.join(d, "includes"),
                "-iwithprefixbefore bt/include -iwithprefixbefore esp_hid ",
            )
            self.assertEqual(si.registered_rels(p), {"bt/include", "esp_hid"})

    def test_missing_file(self):
        self.assertEqual(si.registered_rels("/no/such/includes"), set())


class ResolveRelativeIncludesTest(unittest.TestCase):
    def test_method1_same_relative_path_from_source(self):
        with tempfile.TemporaryDirectory() as d:
            sdk_inc = os.path.join(d, "sdk", "include")
            out_cpath = os.path.join(sdk_inc, "bt", "include")
            comp_root = os.path.join(d, "idf", "components", "bt")
            src_item = os.path.join(comp_root, "include")
            _mkdirs(out_cpath, src_item)
            # Header (already copied into the SDK) references a sibling private header.
            _write(os.path.join(out_cpath, "esp_bt.h"), '#include "../private/bredr.h"\n')
            # The real source of that private header lives in the IDF tree.
            _write(os.path.join(comp_root, "private", "bredr.h"), "PRIV")
            si.resolve_relative_includes(out_cpath, src_item, comp_root, sdk_inc)
            self.assertTrue(os.path.isfile(os.path.join(sdk_inc, "bt", "private", "bredr.h")))

    def test_method2_component_root_fallback(self):
        with tempfile.TemporaryDirectory() as d:
            sdk_inc = os.path.join(d, "sdk", "include")
            out_cpath = os.path.join(sdk_inc, "bt", "include")
            comp_root = os.path.join(d, "idf", "components", "bt")
            src_item = os.path.join(comp_root, "include")
            _mkdirs(out_cpath, src_item)
            _write(
                os.path.join(out_cpath, "esp_bt.h"),
                '#include "../../controller/esp32/cfg.h"\n',
            )
            # Method 1 (relative from src) misses; method 2 strips ../ and looks under comp_root.
            _write(os.path.join(comp_root, "controller", "esp32", "cfg.h"), "CFG")
            si.resolve_relative_includes(out_cpath, src_item, comp_root, sdk_inc)
            self.assertTrue(os.path.isfile(os.path.join(sdk_inc, "controller", "esp32", "cfg.h")))

    def test_transitive_resolution(self):
        # a.h -> ../p/b.h -> ../q/c.h : the loop must resolve both hops.
        with tempfile.TemporaryDirectory() as d:
            sdk_inc = os.path.join(d, "sdk", "include")
            out_cpath = os.path.join(sdk_inc, "bt", "include")
            comp_root = os.path.join(d, "idf", "components", "bt")
            src_item = os.path.join(comp_root, "include")
            _mkdirs(out_cpath, src_item)
            _write(os.path.join(out_cpath, "a.h"), '#include "../p/b.h"\n')
            _write(os.path.join(comp_root, "p", "b.h"), '#include "../q/c.h"\n')
            _write(os.path.join(comp_root, "q", "c.h"), "C")
            si.resolve_relative_includes(out_cpath, src_item, comp_root, sdk_inc)
            self.assertTrue(os.path.isfile(os.path.join(sdk_inc, "bt", "p", "b.h")))
            self.assertTrue(os.path.isfile(os.path.join(sdk_inc, "bt", "q", "c.h")))

    def test_non_header_target_is_not_copied(self):
        with tempfile.TemporaryDirectory() as d:
            sdk_inc = os.path.join(d, "sdk", "include")
            out_cpath = os.path.join(sdk_inc, "bt", "include")
            comp_root = os.path.join(d, "idf", "components", "bt")
            src_item = os.path.join(comp_root, "include")
            _mkdirs(out_cpath, src_item)
            _write(os.path.join(out_cpath, "a.h"), '#include "../src/impl.c"\n')
            _write(os.path.join(comp_root, "src", "impl.c"), "SOURCE")
            si.resolve_relative_includes(out_cpath, src_item, comp_root, sdk_inc)
            self.assertFalse(os.path.isfile(os.path.join(sdk_inc, "bt", "src", "impl.c")))

    def test_escapes_sdk_are_skipped(self):
        with tempfile.TemporaryDirectory() as d:
            sdk_inc = os.path.join(d, "sdk", "include")
            out_cpath = os.path.join(sdk_inc, "bt")
            comp_root = os.path.join(d, "idf", "components", "bt")
            _mkdirs(out_cpath, comp_root)
            _write(os.path.join(out_cpath, "x.h"), '#include "../../../../../etc/evil.h"\n')
            # Must not raise and must not copy anything outside the SDK.
            si.resolve_relative_includes(out_cpath, comp_root, comp_root, sdk_inc)
            self.assertFalse(os.path.exists(os.path.join(d, "etc", "evil.h")))


class CmdBaseIntegrationTest(unittest.TestCase):
    def test_end_to_end_populates_tree_flags_and_cpppath(self):
        with tempfile.TemporaryDirectory() as d:
            bt_inc = os.path.join(d, "idf", "components", "bt", "include")
            _mkdirs(bt_inc)
            _write(os.path.join(bt_inc, "esp_bt.h"), '#include "../private/p.h"\n')
            _write(os.path.join(d, "idf", "components", "bt", "private", "p.h"), "P")

            cc = _write(
                os.path.join(d, "compile_commands.json"),
                json.dumps(
                    [
                        {
                            "file": "/x/main/arduino-lib-builder-gcc.c",
                            "directory": d,
                            "arguments": ["cc", "-I", bt_inc, "-c", "x.c"],
                        }
                    ]
                ),
            )
            sdk_inc = os.path.join(d, "sdk", "include")
            flags_inc = os.path.join(d, "sdk", "flags", "includes")

            out, err = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                rc = si.main(
                    [
                        "base",
                        "--compile-commands", cc,
                        "--sdk-include", sdk_inc,
                        "--flags-includes", flags_inc,
                        "--pio-prefix", 'FRAMEWORK_SDK_DIR, "esp32s31"',
                    ]
                )
            self.assertEqual(rc, 0)

            # Header copied into the shared tree, plus the resolved relative include.
            self.assertTrue(os.path.isfile(os.path.join(sdk_inc, "bt", "include", "esp_bt.h")))
            self.assertTrue(os.path.isfile(os.path.join(sdk_inc, "bt", "private", "p.h")))

            # flags/includes carries the GCC search-path token (trailing space, no newline).
            with open(flags_inc) as fh:
                self.assertEqual(fh.read(), "-iwithprefixbefore bt/include ")

            # pio CPPPATH entry printed to stdout for copy-libs.sh to capture.
            self.assertIn(
                '        join(FRAMEWORK_SDK_DIR, "esp32s31", "include", "bt", "include"),',
                out.getvalue(),
            )

    def test_missing_compile_commands(self):
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            rc = si.main(
                [
                    "base",
                    "--compile-commands", "/no/such/cc.json",
                    "--sdk-include", "/tmp/x",
                    "--flags-includes", "/tmp/x/flags",
                    "--pio-prefix", "PFX",
                ]
            )
        self.assertEqual(rc, 1)


class CmdAppendIntegrationTest(unittest.TestCase):
    def test_appends_only_new_dirs_and_updates_pio(self):
        with tempfile.TemporaryDirectory() as d:
            # Two flavor include dirs; one is already registered (must be skipped).
            bt_inc = os.path.join(d, "idf", "components", "bt", "include")
            bredr_inc = os.path.join(d, "idf", "components", "bt", "controller", "bredr", "include")
            _mkdirs(bt_inc, bredr_inc)
            _write(os.path.join(bredr_inc, "bredr_cfg.h"), "BREDR")

            cc = _write(
                os.path.join(d, "cc.json"),
                json.dumps(
                    [
                        {
                            "file": "/x/main/arduino-lib-builder-gcc.c",
                            "directory": d,
                            "arguments": ["cc", "-I", bt_inc, "-I", bredr_inc, "-c"],
                        }
                    ]
                ),
            )
            sdk_inc = os.path.join(d, "sdk", "include")
            _mkdirs(sdk_inc)
            # 'bt/include' already registered by the base pass.
            flags_inc = _write(
                os.path.join(d, "sdk", "flags", "includes"),
                "-iwithprefixbefore bt/include ",
            )
            pio = _write(
                os.path.join(d, "sdk", "pioarduino-build.py"),
                "    CPPPATH=[\n"
                '        join(FRAMEWORK_SDK_DIR, "esp32s31", "include", "bt", "include"),\n'
                "    ],\n",
            )

            err = io.StringIO()
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
                rc = si.main(
                    [
                        "append",
                        "--compile-commands", cc,
                        "--sdk-include", sdk_inc,
                        "--flags-includes", flags_inc,
                        "--pio-file", pio,
                    ]
                )
            self.assertEqual(rc, 0)

            rel = "bt/controller/bredr/include"
            with open(flags_inc) as fh:
                flags = fh.read()
            # New dir appended; existing bt/include registered exactly once.
            self.assertIn(f"-iwithprefixbefore {rel}", flags)
            self.assertEqual(flags.count("-iwithprefixbefore bt/include "), 1)

            # Header copied and pio CPPPATH updated with the new flavor dir.
            self.assertTrue(
                os.path.isfile(os.path.join(sdk_inc, "bt", "controller", "bredr", "include", "bredr_cfg.h"))
            )
            with open(pio) as fh:
                pio_text = fh.read()
            self.assertIn(
                'join(FRAMEWORK_SDK_DIR, "esp32s31", "include", "bt", "controller", "bredr", "include"),',
                pio_text,
            )

    def test_pio_file_missing_still_updates_flags(self):
        # A flavor-only include dir must still be added to flags/includes even when
        # pioarduino-build.py is absent (PlatformIO update is skipped, not fatal).
        with tempfile.TemporaryDirectory() as d:
            inc = os.path.join(d, "idf", "components", "esp_hid", "include")
            _mkdirs(inc)
            _write(os.path.join(inc, "hid.h"), "H")
            cc = _write(
                os.path.join(d, "cc.json"),
                json.dumps(
                    [{"file": "/x/main/arduino-lib-builder-gcc.c", "directory": d,
                      "arguments": ["cc", "-I", inc, "-c"]}]
                ),
            )
            sdk_inc = os.path.join(d, "sdk", "include")
            _mkdirs(sdk_inc)
            flags_inc = _write(os.path.join(d, "sdk", "flags", "includes"), "")

            err = io.StringIO()
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
                rc = si.main(
                    [
                        "append",
                        "--compile-commands", cc,
                        "--sdk-include", sdk_inc,
                        "--flags-includes", flags_inc,
                        "--pio-file", os.path.join(d, "does_not_exist.py"),
                    ]
                )
            self.assertEqual(rc, 0)
            with open(flags_inc) as fh:
                self.assertIn("-iwithprefixbefore esp_hid/include", fh.read())

    def test_nothing_new_leaves_files_untouched(self):
        with tempfile.TemporaryDirectory() as d:
            inc = os.path.join(d, "idf", "components", "bt", "include")
            _mkdirs(inc)
            cc = _write(
                os.path.join(d, "cc.json"),
                json.dumps(
                    [{"file": "/x/main/arduino-lib-builder-gcc.c", "directory": d,
                      "arguments": ["cc", "-I", inc, "-c"]}]
                ),
            )
            sdk_inc = os.path.join(d, "sdk", "include")
            _mkdirs(sdk_inc)
            # bt/include is already registered, so append has nothing to do.
            flags_before = "-iwithprefixbefore bt/include "
            flags_inc = _write(os.path.join(d, "sdk", "flags", "includes"), flags_before)
            pio_before = "    CPPPATH=[\n    ],\n"
            pio = _write(os.path.join(d, "sdk", "pioarduino-build.py"), pio_before)

            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                rc = si.main(
                    [
                        "append",
                        "--compile-commands", cc,
                        "--sdk-include", sdk_inc,
                        "--flags-includes", flags_inc,
                        "--pio-file", pio,
                    ]
                )
            self.assertEqual(rc, 0)
            with open(flags_inc) as fh:
                self.assertEqual(fh.read(), flags_before)
            with open(pio) as fh:
                self.assertEqual(fh.read(), pio_before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
