#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Unit tests for tools/bt_sdkconfig_gate.py.

Run from the repo root (or anywhere):
    python3 -m unittest discover -s tools/testing -p 'test_*.py'
    python3 tools/testing/test_bt_sdkconfig_gate.py
"""

import contextlib
import io
import json
import os
import re
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bt_sdkconfig_gate as gate  # noqa: E402


def _write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)
    return path


class ExprTokensTest(unittest.TestCase):
    def test_extracts_symbols_and_drops_keywords(self):
        self.assertEqual(
            gate._expr_tokens("BT_ENABLED && SOC_BT_SUPPORTED"),
            {"BT_ENABLED", "SOC_BT_SUPPORTED"},
        )

    def test_keywords_removed(self):
        # y / n / if / on are expression keywords, not symbol references.
        self.assertEqual(gate._expr_tokens("FOO if BAR = y"), {"FOO", "BAR"})

    def test_empty(self):
        self.assertEqual(gate._expr_tokens(""), set())
        self.assertEqual(gate._expr_tokens(None), set())


class ReadDefinesTest(unittest.TestCase):
    def test_parses_and_ignores_volatile_syms(self):
        with tempfile.TemporaryDirectory() as d:
            p = _write(
                os.path.join(d, "sdkconfig.h"),
                '#define CONFIG_BT_ENABLED 1\n'
                '#define CONFIG_FOO 42\n'
                '#define CONFIG_ARDUINO_IDF_COMMIT "abc123"\n'
                '#define CONFIG_ARDUINO_IDF_BRANCH "release/v6.1"\n'
                '/* not a define */\n',
            )
            defines = gate.read_defines(p)
        self.assertEqual(defines, {"CONFIG_BT_ENABLED": "1", "CONFIG_FOO": "42"})

    def test_valueless_define_is_present_with_empty_value(self):
        # A bare `#define CONFIG_X` (no value) still counts as "present" so a
        # presence-only difference against the other stack is detected.
        with tempfile.TemporaryDirectory() as d:
            p = _write(os.path.join(d, "sdkconfig.h"), "#define CONFIG_BT_X\n")
            self.assertEqual(gate.read_defines(p), {"CONFIG_BT_X": ""})


class DifferingSymbolsTest(unittest.TestCase):
    def test_value_and_presence_differences(self):
        with tempfile.TemporaryDirectory() as d:
            base = _write(
                os.path.join(d, "base.h"),
                "#define CONFIG_BT_NIMBLE_ENABLED 1\n"
                "#define CONFIG_FOO 1\n"
                "#define CONFIG_SAME 7\n",
            )
            variant = _write(
                os.path.join(d, "var.h"),
                "#define CONFIG_BT_BLUEDROID_ENABLED 1\n"
                "#define CONFIG_FOO 2\n"
                "#define CONFIG_SAME 7\n",
            )
            diff = gate.differing_symbols(base, variant)
        # CONFIG_SAME identical -> excluded. Presence-only diffs are included.
        self.assertEqual(
            diff,
            ["CONFIG_BT_BLUEDROID_ENABLED", "CONFIG_BT_NIMBLE_ENABLED", "CONFIG_FOO"],
        )


class ClassifyLeaksTest(unittest.TestCase):
    def test_bt_prefixed_never_a_leak(self):
        diff = ["CONFIG_BT_NIMBLE_ENABLED", "CONFIG_BLE_MESH", "CONFIG_BR_EDR_X"]
        self.assertEqual(gate.classify_leaks(diff, set(), []), [])

    def test_non_bt_symbol_is_a_leak(self):
        self.assertEqual(
            gate.classify_leaks(["CONFIG_FOO"], set(), []), ["CONFIG_FOO"]
        )

    def test_allow_set_suppresses_leak(self):
        self.assertEqual(
            gate.classify_leaks(["CONFIG_FOO"], {"CONFIG_FOO"}, []), []
        )

    def test_allow_pattern_suppresses_leak(self):
        self.assertEqual(
            gate.classify_leaks(["CONFIG_FOO_BAR"], set(), [re.compile("FOO_")]),
            [],
        )


class LoadAllowFileTest(unittest.TestCase):
    def test_skips_comments_blanks_and_bad_regex(self):
        with tempfile.TemporaryDirectory() as d:
            p = _write(
                os.path.join(d, "allow"),
                "# a comment\n"
                "\n"
                "CONFIG_MBEDTLS_.*\n"
                "[invalid(regex\n",
            )
            with contextlib.redirect_stderr(io.StringIO()):
                pats = gate.load_allow_file(p)
        self.assertEqual(len(pats), 1)
        self.assertTrue(pats[0].search("CONFIG_MBEDTLS_FOO"))

    def test_missing_file_is_empty(self):
        self.assertEqual(gate.load_allow_file("/nonexistent/allow"), [])


class MenusClosureTest(unittest.TestCase):
    def test_direct_and_transitive_and_cross_component(self):
        with tempfile.TemporaryDirectory() as d:
            menus = [
                # BT-named node: excluded from the result (it IS a BT symbol).
                {"name": "BT_NIMBLE_ENABLED", "depends_on": "BT_ENABLED"},
                # Non-BT name depending directly on a BT symbol -> included.
                {"name": "NETWORK_PROV_BLE_SEC_CONN", "depends_on": "BT_NIMBLE_ENABLED"},
                # Transitive: depends on the above (which reaches BT) -> included.
                {"name": "SOME_PROV_HELPER", "depends_on": "NETWORK_PROV_BLE_SEC_CONN"},
                # Unrelated -> excluded.
                {"name": "LWIP_THING", "depends_on": "LWIP_IPV6"},
            ]
            p = _write(os.path.join(d, "menus.json"), json.dumps(menus))
            result = gate.bt_driven_syms_from_menus(p)
        self.assertEqual(
            result,
            {"CONFIG_NETWORK_PROV_BLE_SEC_CONN", "CONFIG_SOME_PROV_HELPER"},
        )

    def test_inherited_menu_dependency(self):
        # A child under a menu that depends on BT inherits the dependency even
        # though the child's own depends_on has no BT reference.
        with tempfile.TemporaryDirectory() as d:
            menus = [
                {
                    "depends_on": "BT_ENABLED",
                    "children": [{"name": "CHILD_OPT", "depends_on": "y"}],
                }
            ]
            p = _write(os.path.join(d, "menus.json"), json.dumps(menus))
            result = gate.bt_driven_syms_from_menus(p)
        self.assertEqual(result, {"CONFIG_CHILD_OPT"})

    def test_missing_or_bad_json_is_empty(self):
        self.assertEqual(gate.bt_driven_syms_from_menus(""), set())
        self.assertEqual(gate.bt_driven_syms_from_menus("/nope.json"), set())
        with tempfile.TemporaryDirectory() as d:
            bad = _write(os.path.join(d, "m.json"), "{not json")
            self.assertEqual(gate.bt_driven_syms_from_menus(bad), set())

    def test_dependency_cycle_terminates(self):
        # A -> B -> A with no BT reference must terminate (not recurse forever)
        # and yield nothing; the same cycle plus a BT edge must include both.
        with tempfile.TemporaryDirectory() as d:
            no_bt = _write(
                os.path.join(d, "cycle.json"),
                json.dumps(
                    [
                        {"name": "A", "depends_on": "B"},
                        {"name": "B", "depends_on": "A"},
                    ]
                ),
            )
            self.assertEqual(gate.bt_driven_syms_from_menus(no_bt), set())

            with_bt = _write(
                os.path.join(d, "cycle_bt.json"),
                json.dumps(
                    [
                        {"name": "A", "depends_on": "B"},
                        {"name": "B", "depends_on": "A || BT_ENABLED"},
                    ]
                ),
            )
            self.assertEqual(
                gate.bt_driven_syms_from_menus(with_bt), {"CONFIG_A", "CONFIG_B"}
            )


class ComponentDeclTest(unittest.TestCase):
    def test_reads_config_and_menuconfig_under_components_bt(self):
        with tempfile.TemporaryDirectory() as d:
            _write(
                os.path.join(d, "components", "bt", "Kconfig"),
                'menu "BT"\n'
                "config BT_FOO\n"
                '    bool "foo"\n'
                "menuconfig BT_BAR\n"
                "    bool\n"
                "endmenu\n",
            )
            # A nested Kconfig.* file is also picked up.
            _write(
                os.path.join(d, "components", "bt", "host", "Kconfig.projbuild"),
                "config BT_HOST_OPT\n    bool\n",
            )
            syms = gate.bt_component_decl_syms(d)
        self.assertEqual(syms, {"CONFIG_BT_FOO", "CONFIG_BT_BAR", "CONFIG_BT_HOST_OPT"})

    def test_no_idf_dir(self):
        self.assertEqual(gate.bt_component_decl_syms(""), set())


class RenameAliasTest(unittest.TestCase):
    def test_only_aliases_whose_canonical_is_bt(self):
        with tempfile.TemporaryDirectory() as d:
            _write(
                os.path.join(d, "components", "bt", "sdkconfig.rename"),
                "CONFIG_A2DP_ENABLE CONFIG_BT_A2DP_ENABLE\n"
                "CONFIG_SOMETHING CONFIG_OTHER_THING\n"
                "CONFIG_NEG !CONFIG_BT_NIMBLE_ENABLED\n"
                "# comment line\n",
            )
            syms = gate.rename_alias_syms(d)
        self.assertEqual(syms, {"CONFIG_A2DP_ENABLE", "CONFIG_NEG"})

    def test_suffixed_rename_file_is_read(self):
        # Per-chip rename files (sdkconfig.rename.<chip>) match the basename prefix.
        with tempfile.TemporaryDirectory() as d:
            _write(
                os.path.join(d, "components", "bt", "sdkconfig.rename.esp32"),
                "CONFIG_OLD_BLE CONFIG_BT_NEW_BLE\n",
            )
            self.assertEqual(gate.rename_alias_syms(d), {"CONFIG_OLD_BLE"})


class BuildAllowSetTest(unittest.TestCase):
    def test_unions_all_three_sources(self):
        with tempfile.TemporaryDirectory() as d:
            menus = _write(
                os.path.join(d, "menus.json"),
                json.dumps([{"name": "PROV_HELPER", "depends_on": "BT_NIMBLE_ENABLED"}]),
            )
            _write(
                os.path.join(d, "components", "bt", "Kconfig"),
                "config BT_DECLARED\n    bool\n",
            )
            _write(
                os.path.join(d, "components", "bt", "sdkconfig.rename"),
                "CONFIG_LEGACY CONFIG_BT_A2DP_ENABLE\n",
            )
            allow = gate.build_allow_set(menus, d)
        self.assertEqual(
            allow,
            {"CONFIG_PROV_HELPER", "CONFIG_BT_DECLARED", "CONFIG_LEGACY"},
        )


class MainIntegrationTest(unittest.TestCase):
    def _run(self, base_text, variant_text, extra_argv=None, menus=None):
        with tempfile.TemporaryDirectory() as d:
            base = _write(os.path.join(d, "base.h"), base_text)
            variant = _write(os.path.join(d, "var.h"), variant_text)
            argv = ["--base", base, "--variant", variant, "--variant-name", "bluedroid"]
            if menus is not None:
                argv += ["--menus", _write(os.path.join(d, "menus.json"), json.dumps(menus))]
            if extra_argv:
                # Resolve any allow-file placeholder into the temp dir.
                extra_argv = [
                    _write(os.path.join(d, "allow"), a[len("ALLOW:"):])
                    if isinstance(a, str) and a.startswith("ALLOW:")
                    else a
                    for a in extra_argv
                ]
                argv += extra_argv
            out, err = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                rc = gate.main(argv)
            return rc, out.getvalue(), err.getvalue()

    def test_pass_when_only_bt_differs(self):
        rc, _out, _err = self._run(
            "#define CONFIG_BT_NIMBLE_ENABLED 1\n#define CONFIG_FOO 1\n",
            "#define CONFIG_BT_BLUEDROID_ENABLED 1\n#define CONFIG_FOO 1\n",
        )
        self.assertEqual(rc, 0)

    def test_fail_on_non_bt_leak(self):
        rc, out, _err = self._run(
            "#define CONFIG_FOO 1\n",
            "#define CONFIG_FOO 2\n",
        )
        self.assertEqual(rc, 1)
        self.assertIn("CONFIG_FOO", out)

    def test_menus_closure_allows_bt_driven_symbol(self):
        rc, _out, _err = self._run(
            "#define CONFIG_NETWORK_PROV_BLE_SEC_CONN 1\n",
            "#define CONFIG_NETWORK_PROV_BLE_SEC_CONN 0\n",
            menus=[{"name": "NETWORK_PROV_BLE_SEC_CONN", "depends_on": "BT_NIMBLE_ENABLED"}],
        )
        self.assertEqual(rc, 0)

    def test_allow_file_suppresses_leak(self):
        rc, _out, _err = self._run(
            "#define CONFIG_MBEDTLS_X 1\n",
            "#define CONFIG_MBEDTLS_X 2\n",
            extra_argv=["--allow-file", "ALLOW:CONFIG_MBEDTLS_.*\n"],
        )
        self.assertEqual(rc, 0)

    def test_missing_variant_file(self):
        with tempfile.TemporaryDirectory() as d:
            base = _write(os.path.join(d, "base.h"), "#define CONFIG_FOO 1\n")
            err = io.StringIO()
            with contextlib.redirect_stderr(err):
                rc = gate.main(["--base", base, "--variant", os.path.join(d, "missing.h")])
        self.assertEqual(rc, 1)
        self.assertIn("flavor sdkconfig.h not found", err.getvalue())

    def test_missing_base_file(self):
        with tempfile.TemporaryDirectory() as d:
            variant = _write(os.path.join(d, "var.h"), "#define CONFIG_FOO 1\n")
            err = io.StringIO()
            with contextlib.redirect_stderr(err):
                rc = gate.main(["--base", os.path.join(d, "missing.h"), "--variant", variant])
        self.assertEqual(rc, 1)
        self.assertIn("base sdkconfig.h not found", err.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
