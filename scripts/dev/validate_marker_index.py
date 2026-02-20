#!/usr/bin/env python3
"""Static validation for marker index generator outputs."""

from __future__ import annotations

import argparse
import json
import re
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

    with tempfile.TemporaryDirectory(prefix="marker-index-validate-") as tmpdir:
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
        ]
        run = subprocess.run(cmd, capture_output=True, text=True)
        if run.returncode != 0:
            sys.stderr.write("Generator failed to execute successfully.\n")
            sys.stderr.write(run.stdout)
            sys.stderr.write(run.stderr)
            return 1

        try:
            payload = json.loads(out_json.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as exc:
            sys.stderr.write(f"Failed to parse generated JSON: {exc}\n")
            return 1

        markers = payload.get("markers")
        summary = payload.get("summary", {})
        if not isinstance(markers, list):
            sys.stderr.write("Generated JSON is missing list field: markers\n")
            return 1

        json_marker_count = len(markers)
        summary_total = summary.get("total")
        if summary_total != json_marker_count:
            sys.stderr.write(
                f"JSON summary mismatch: summary.total={summary_total} but markers={json_marker_count}\n"
            )
            return 1

        md_text = out_md.read_text(encoding="utf-8")
        md_total_match = re.search(r"-\s+Total markers:\s+\*\*(\d+)\*\*", md_text)
        if not md_total_match:
            sys.stderr.write("Markdown summary total not found.\n")
            return 1
        md_summary_total = int(md_total_match.group(1))
        md_table_count = _count_markdown_markers(md_text)

        if md_summary_total != json_marker_count or md_table_count != json_marker_count:
            sys.stderr.write(
                "Marker count mismatch across outputs: "
                f"json={json_marker_count}, md-summary={md_summary_total}, md-table={md_table_count}\n"
            )
            return 1

        primary_fields = ("name", "text")
        for index, marker in enumerate(markers):
            for field in primary_fields:
                legacy = _contains_legacy_marker(marker.get(field), args.legacy_markers)
                if legacy:
                    sys.stderr.write(
                        f"Legacy marker '{legacy}' found in marker[{index}].{field}: {marker.get(field)!r}\n"
                    )
                    return 1

        print(
            "PASS: generator executed, JSON parsed, marker counts match, and no legacy markers "
            f"in primary fields (json={json_marker_count}, md-summary={md_summary_total}, md-table={md_table_count})"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
