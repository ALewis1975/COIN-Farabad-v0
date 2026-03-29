#!/usr/bin/env python3
"""Lightweight pre-sqflint compatibility scanner for SQF parser pain points.

Rules are classified into two severity levels:

  * "error"    – simple, safe 1:1 replacements that should be enforced in CI.
  * "advisory" – known sqflint 0.3.2 parser limitations whose workarounds
                 require compile-wrapper helpers or large-scale mechanical
                 rewrites.  These are reported as warnings but do NOT block
                 CI in --strict mode.  Fixing them is optional and must be
                 done carefully (correct scope, placement, etc.).
"""

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
    severity: str  # "error" or "advisory"


RULES: list[PatternRule] = [
    # ── Enforceable rules (safe 1:1 replacements) ──────────────────────
    PatternRule(
        name="findIf",
        regex=re.compile(r"\bfindIf\b"),
        approved_equivalent="Use a `forEach` loop with `_forEachIndex` + `exitWith`.",
        notes="sqflint parser compatibility: prefer explicit loop search.",
        severity="error",
    ),
    PatternRule(
        name="toUpperANSI",
        regex=re.compile(r"\btoUpperANSI\b"),
        approved_equivalent="Use `toUpper` for ASCII mission strings.",
        notes="Known parser-compatibility pain point in older sqflint versions.",
        severity="error",
    ),
    PatternRule(
        name="toLowerANSI",
        regex=re.compile(r"\btoLowerANSI\b"),
        approved_equivalent="Use `toLower` for ASCII mission strings.",
        notes="Known parser-compatibility pain point in older sqflint versions.",
        severity="error",
    ),
    # ── Advisory rules (sqflint 0.3.2 parser limitations) ─────────────
    # These are valid SQF that the engine handles correctly.  sqflint
    # 0.3.2 cannot parse them, but the recommended workarounds involve
    # compile-string helpers or bulk mechanical rewrites that are very
    # error-prone.  Report only — do not block CI.
    PatternRule(
        name="trim-operator",
        regex=re.compile(r"\btrim\s+[_\w\(\[]"),
        approved_equivalent="Wrap via compiled helper, e.g. `_trimFn = compile \"params ['_s']; trim _s\";` then `[_v] call _trimFn`.",
        notes="Direct `trim` usage can trip parser compatibility in some sqflint versions.",
        severity="advisory",
    ),
    PatternRule(
        name="fileExists-operator",
        regex=re.compile(r"\bfileExists\s+[_\w\(\[]"),
        approved_equivalent="Wrap via compiled helper and call it (same strategy as trim).",
        notes="Direct `fileExists` usage can trip parser compatibility in some sqflint versions.",
        severity="advisory",
    ),
    PatternRule(
        name="hashmap-getOrDefault-method",
        regex=re.compile(r"\b[_A-Za-z]\w*\s+getOrDefault\s*\["),
        approved_equivalent="Prefer call form: `[map, key, default] call getOrDefault`.",
        notes="Method-style HashMap calls can misparse under older sqflint builds.",
        severity="advisory",
    ),
    PatternRule(
        name="isNotEqualTo",
        regex=re.compile(r"\bisNotEqualTo\b"),
        approved_equivalent="Use `!(_a isEqualTo _b)` or `!=` when type/semantics allow.",
        notes="Known parser-compatibility pain point in older sqflint versions.",
        severity="advisory",
    ),
    PatternRule(
        name="hash-index-operator",
        regex=re.compile(r"\s#\s"),
        approved_equivalent="Use `select` with explicit bounds/type guards.",
        notes="`#` indexing may not be parsed by older sqflint releases.",
        severity="advisory",
    ),
    PatternRule(
        name="bare-createHashMapFromArray",
        regex=re.compile(r"(?<!\")createHashMapFromArray\b"),
        approved_equivalent="Wrap via compiled helper: `_hmCreate = compile \"params ['_a']; createHashMapFromArray _a\";` then `[args] call _hmCreate`.",
        notes="sqflint 0.3.2 cannot parse bare `createHashMapFromArray`; use compile-string wrapper.",
        severity="advisory",
    ),
]


def _git_changed_sqf_files() -> list[Path]:
    cmd = ["git", "diff", "--name-only", "--diff-filter=ACMR", "HEAD", "--", "*.sqf"]
    proc = subprocess.run(cmd, check=False, capture_output=True, text=True)
    if proc.returncode != 0:
        return []
    return [Path(line.strip()) for line in proc.stdout.splitlines() if line.strip()]


def _is_compat_wrapper_line(line: str, rule_name: str) -> bool:
    if rule_name in {"trim-operator", "fileExists-operator", "bare-createHashMapFromArray"}:
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
    parser.add_argument("--strict", action="store_true", help="Exit non-zero when error-severity findings are present.")
    args = parser.parse_args()

    files = [Path(f) for f in args.files if f.endswith(".sqf")]
    if not files:
        files = _git_changed_sqf_files()

    if not files:
        print("[sqflint-compat-scan] No SQF files to scan.")
        return 0

    error_count = 0
    advisory_count = 0
    for f in files:
        findings = scan_file(f)
        if not findings:
            continue
        print(f"\n[sqflint-compat-scan] {f}:")
        for line_no, rule, snippet in findings:
            tag = "ERROR" if rule.severity == "error" else "advisory"
            if rule.severity == "error":
                error_count += 1
            else:
                advisory_count += 1
            print(f"  L{line_no}: [{tag}:{rule.name}] {rule.notes}")
            print(f"    snippet: {snippet}")
            print(f"    approved: {rule.approved_equivalent}")

    total = error_count + advisory_count
    if total == 0:
        print(f"[sqflint-compat-scan] PASS: scanned {len(files)} file(s); no known parser-compat patterns found.")
        return 0

    parts = []
    if error_count > 0:
        parts.append(f"{error_count} error(s)")
    if advisory_count > 0:
        parts.append(f"{advisory_count} advisory note(s) (sqflint 0.3.2 parser limitations)")
    summary = ", ".join(parts)
    print(f"\n[sqflint-compat-scan] Found {summary} across {len(files)} file(s).")

    if advisory_count > 0 and error_count == 0:
        print("[sqflint-compat-scan] Advisory notes are informational only and do not block CI.")
        print("[sqflint-compat-scan] These are valid SQF constructs that sqflint 0.3.2 cannot parse.")

    # In --strict mode, only error-severity findings cause a non-zero exit.
    return 1 if (args.strict and error_count > 0) else 0


if __name__ == "__main__":
    sys.exit(main())
