#!/usr/bin/env python3
"""Lightweight pre-sqflint compatibility scanner for SQF parser pain points."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class PatternRule:
    name: str
    regex: re.Pattern[str]
    approved_equivalent: str
    notes: str


RULES: list[PatternRule] = [
    PatternRule(
        name="findIf",
        regex=re.compile(r"\bfindIf\b"),
        approved_equivalent="Use a `forEach` loop with `_forEachIndex` + `exitWith`.",
        notes="sqflint parser compatibility: prefer explicit loop search.",
    ),
    PatternRule(
        name="trim-operator",
        regex=re.compile(r"\btrim\s+[_\w\(\[]"),
        approved_equivalent="Wrap via compiled helper, e.g. `_trimFn = compile \"params ['_s']; trim _s\";` then `[_v] call _trimFn`.",
        notes="Direct `trim` usage can trip parser compatibility in some sqflint versions.",
    ),
    PatternRule(
        name="fileExists-operator",
        regex=re.compile(r"\bfileExists\s+[_\w\(\[]"),
        approved_equivalent="Wrap via compiled helper and call it (same strategy as trim).",
        notes="Direct `fileExists` usage can trip parser compatibility in some sqflint versions.",
    ),
    PatternRule(
        name="hashmap-getOrDefault-method",
        regex=re.compile(r"\b[_A-Za-z]\w*\s+getOrDefault\s*\["),
        approved_equivalent="Prefer call form: `[map, key, default] call getOrDefault`.",
        notes="Method-style HashMap calls can misparse under older sqflint builds.",
    ),
    PatternRule(
        name="isNotEqualTo",
        regex=re.compile(r"\bisNotEqualTo\b"),
        approved_equivalent="Use `!(_a isEqualTo _b)` or `!=` when type/semantics allow.",
        notes="Known parser-compatibility pain point in older sqflint versions.",
    ),
    PatternRule(
        name="toUpperANSI",
        regex=re.compile(r"\btoUpperANSI\b"),
        approved_equivalent="Use `toUpper` for ASCII mission strings.",
        notes="Known parser-compatibility pain point in older sqflint versions.",
    ),
    PatternRule(
        name="toLowerANSI",
        regex=re.compile(r"\btoLowerANSI\b"),
        approved_equivalent="Use `toLower` for ASCII mission strings.",
        notes="Known parser-compatibility pain point in older sqflint versions.",
    ),
    PatternRule(
        name="hash-index-operator",
        regex=re.compile(r"(?:[A-Za-z_][A-Za-z0-9_]*|\))\s*#\s*[0-9A-Za-z_\(]"),
        approved_equivalent="Use `select` with explicit bounds/type guards.",
        notes="`#` indexing (with or without surrounding spaces) is not parsed by sqflint 0.3.2.",
    ),
    PatternRule(
        name="bare-createHashMapFromArray",
        regex=re.compile(r"(?<!\")createHashMapFromArray\b"),
        approved_equivalent="Wrap via compiled helper: `_hmCreate = compile \"params ['_a']; createHashMapFromArray _a\";` then `[args] call _hmCreate`.",
        notes="sqflint 0.3.2 cannot parse bare `createHashMapFromArray`; use compile-string wrapper.",
    ),
    PatternRule(
        name="bare-keys",
        regex=re.compile(r"\bkeys\s+_"),
        approved_equivalent="Use `_keysFn` compile helper: `private _keysFn = compile \"params ['_m']; keys _m\";` then `[_map] call _keysFn`.",
        notes="sqflint 0.3.2 does not recognise `keys` as an operator; a compile-string wrapper is required.",
    ),
    PatternRule(
        name="hashmap-get-bare",
        regex=re.compile(r"\b[_A-Za-z]\w*\s+get\s+[_\"A-Za-z(]"),
        approved_equivalent="Use `_hmGet` compile helper: `private _hmGet = compile \"params ['_h','_k']; _h get _k\";` then `[_map, _key] call _hmGet`.",
        notes="Direct HashMap `get` method (without getOrDefault) fails to parse under sqflint 0.3.2.",
    ),
    PatternRule(
        name="array-insert-method",
        regex=re.compile(r"\b[_A-Za-z]\w*\s+insert\s*\["),
        approved_equivalent="Use a compile helper: `private _arrInsert = compile \"params ['_a','_i','_v']; _a insert [_i, _v]\";` then `[_arr, _idx, _items] call _arrInsert`.",
        notes="Array `insert` method fails to parse under sqflint 0.3.2.",
    ),
]


def _git_changed_sqf_files() -> list[Path]:
    cmd = ["git", "diff", "--name-only", "--diff-filter=ACMR", "HEAD", "--", "*.sqf"]
    proc = subprocess.run(cmd, check=False, capture_output=True, text=True)
    if proc.returncode != 0:
        return []
    return [Path(line.strip()) for line in proc.stdout.splitlines() if line.strip()]


def _is_compat_wrapper_line(line: str, rule_name: str) -> bool:
    if rule_name in {
        "trim-operator",
        "fileExists-operator",
        "bare-createHashMapFromArray",
        "bare-keys",
        "hashmap-get-bare",
        "array-insert-method",
    }:
        return "compile" in line and '"' in line
    return False


def scan_file(path: Path) -> list[tuple[int, PatternRule, str]]:
    findings: list[tuple[int, PatternRule, str]] = []
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError as exc:
        print(f"[sqflint-compat-scan] WARN: unable to read {path}: {exc}")
        return findings

    for idx, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped.startswith("//"):
            continue
        for rule in RULES:
            if _is_compat_wrapper_line(line, rule.name):
                continue
            if rule.regex.search(line):
                findings.append((idx, rule, line.rstrip()))
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description="Scan SQF files for known sqflint parser-compatibility patterns.")
    parser.add_argument("files", nargs="*", help="SQF files to scan. If omitted, scans changed *.sqf files vs HEAD.")
    parser.add_argument("--strict", action="store_true", help="Exit non-zero when findings are present.")
    args = parser.parse_args()

    files = [Path(f) for f in args.files if f.endswith(".sqf")]
    if not files:
        files = _git_changed_sqf_files()

    if not files:
        print("[sqflint-compat-scan] No SQF files to scan.")
        return 0

    total = 0
    for f in files:
        findings = scan_file(f)
        if not findings:
            continue
        print(f"\n[sqflint-compat-scan] {f}:")
        for line_no, rule, snippet in findings:
            total += 1
            print(f"  L{line_no}: [{rule.name}] {rule.notes}")
            print(f"    snippet: {snippet}")
            print(f"    approved: {rule.approved_equivalent}")

    if total == 0:
        print(f"[sqflint-compat-scan] PASS: scanned {len(files)} file(s); no known parser-compat patterns found.")
        return 0

    print(f"\n[sqflint-compat-scan] WARN: found {total} pattern match(es) across {len(files)} file(s).")
    return 1 if args.strict else 0


if __name__ == "__main__":
    sys.exit(main())
