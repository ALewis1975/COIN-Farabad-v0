#!/usr/bin/env python3
"""Static validation for marker index generator outputs."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def _count_markdown_markers(markdown_text: str) -> int:
    in_table = False
    count = 0
    for line in markdown_text.splitlines():
        if line.strip() == "## Full Marker Table":
            in_table = True
            continue
        if in_table and line.startswith("## "):
            break
        if not in_table:
            continue
        if line.strip().lower().startswith("| name |"):
            continue
        if re.match(r"^\|\s*[^|]+\s*\|", line) and not re.match(r"^\|\s*-+\s*\|", line):
            count += 1
    return count


def _contains_legacy_marker(value: object, legacy_markers: list[str]) -> str | None:
    if not isinstance(value, str):
        return None
    for legacy in legacy_markers:
        if re.search(rf"\b{re.escape(legacy)}\b", value):
            return legacy
    return None


def _run_validation_pass(
    *,
    args: argparse.Namespace,
    mode: str,
    expected_warning: str | None,
) -> tuple[int, int, int]:
    with tempfile.TemporaryDirectory(prefix=f"marker-index-validate-{mode}-") as tmpdir:
        tmp_path = Path(tmpdir)
        out_md = tmp_path / "marker-index.md"
        out_json = tmp_path / "marker-index.json"

        cmd = [
            sys.executable,
            str(args.generator),
            "--sqm",
            str(args.sqm),
            "--out-md",
            str(out_md),
            "--out-json",
            str(out_json),
            "--consumer-detection",
            mode,
        ]
        env = os.environ.copy()
        if mode == "auto-no-rg":
            env["PATH"] = ""
            cmd[-1] = "auto"

        run = subprocess.run(cmd, capture_output=True, text=True, env=env)
        if run.returncode != 0:
            sys.stderr.write(f"Generator failed in mode '{mode}'.\n")
            sys.stderr.write(run.stdout)
            sys.stderr.write(run.stderr)
            raise SystemExit(1)

        stderr_lines = [line.strip() for line in run.stderr.splitlines() if line.strip()]
        if expected_warning:
            if expected_warning not in stderr_lines:
                sys.stderr.write(
                    f"Expected warning not found in mode '{mode}': {expected_warning!r}; stderr={stderr_lines!r}\n"
                )
                raise SystemExit(1)
        elif stderr_lines:
            sys.stderr.write(f"Unexpected stderr in mode '{mode}': {stderr_lines!r}\n")
            raise SystemExit(1)

        try:
            payload = json.loads(out_json.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as exc:
            sys.stderr.write(f"Failed to parse generated JSON in mode '{mode}': {exc}\n")
            raise SystemExit(1)

        markers = payload.get("markers")
        summary = payload.get("summary", {})
        if not isinstance(markers, list):
            sys.stderr.write(f"Generated JSON is missing list field 'markers' in mode '{mode}'\n")
            raise SystemExit(1)

        json_marker_count = len(markers)
        summary_total = summary.get("total")
        if summary_total != json_marker_count:
            sys.stderr.write(
                f"JSON summary mismatch in mode '{mode}': summary.total={summary_total} but markers={json_marker_count}\n"
            )
            raise SystemExit(1)

        md_text = out_md.read_text(encoding="utf-8")
        md_total_match = re.search(r"-\s+Total markers:\s+\*\*(\d+)\*\*", md_text)
        if not md_total_match:
            sys.stderr.write(f"Markdown summary total not found in mode '{mode}'.\n")
            raise SystemExit(1)
        md_summary_total = int(md_total_match.group(1))
        md_table_count = _count_markdown_markers(md_text)

        if md_summary_total != json_marker_count or md_table_count != json_marker_count:
            sys.stderr.write(
                f"Marker count mismatch in mode '{mode}': "
                f"json={json_marker_count}, md-summary={md_summary_total}, md-table={md_table_count}\n"
            )
            raise SystemExit(1)

        primary_fields = ("name", "text")
        for index, marker in enumerate(markers):
            for field in primary_fields:
                legacy = _contains_legacy_marker(marker.get(field), args.legacy_markers)
                if legacy:
                    sys.stderr.write(
                        f"Legacy marker '{legacy}' found in mode '{mode}' marker[{index}].{field}: {marker.get(field)!r}\n"
                    )
                    raise SystemExit(1)

        if mode in ("off", "auto-no-rg"):
            non_empty_consumers = [m.get("name", "") for m in markers if m.get("consumers")]
            if non_empty_consumers:
                sys.stderr.write(
                    f"Expected empty consumers in mode '{mode}', but found populated entries: {non_empty_consumers[:5]!r}\n"
                )
                raise SystemExit(1)

        return json_marker_count, md_summary_total, md_table_count


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate marker index generation outputs")
    parser.add_argument("--sqm", default="mission.sqm", type=Path)
    parser.add_argument("--generator", default="tools/generate_marker_index.py", type=Path)
    parser.add_argument(
        "--legacy-markers",
        nargs="+",
        default=["EPW_Holding", "epw_holding_1"],
        help="Legacy marker names that must not appear in primary output fields.",
    )
    args = parser.parse_args()

    warning = (
        "[marker-index] WARNING: optional dependency 'rg' unavailable; "
        "consumer detection disabled; consumers=[] fallback enabled."
    )

    modes: list[tuple[str, str | None]] = [("off", None)]
    if shutil.which("rg"):
        modes.append(("on", None))
    else:
        modes.append(("auto", warning))
    modes.append(("auto-no-rg", warning))

    results: list[tuple[str, int, int, int]] = []
    for mode, expected_warning in modes:
        json_total, md_summary_total, md_table_total = _run_validation_pass(
            args=args,
            mode=mode,
            expected_warning=expected_warning,
        )
        results.append((mode, json_total, md_summary_total, md_table_total))

    mode_summaries = ", ".join(
        f"{mode}:json={j}/md-summary={m}/md-table={t}" for mode, j, m, t in results
    )
    print(f"PASS: marker-index validation completed across modes ({mode_summaries})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
