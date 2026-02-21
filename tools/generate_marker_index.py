#!/usr/bin/env python3
"""Generate marker index artifacts from mission.sqm and alias/reference hints."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MISSION_PATH = ROOT / "mission.sqm"
ALIASES_PATH = ROOT / "data" / "farabad_marker_aliases.sqf"
JSON_OUT = ROOT / "docs" / "reference" / "marker-index.json"
MD_OUT = ROOT / "docs" / "reference" / "marker-index.md"

RG_AVAILABLE = shutil.which("rg") is not None
if not RG_AVAILABLE:
    print("Warning: ripgrep (rg) not found; consumer detection will be skipped.", file=sys.stderr)

TEXT_FIELDS = ("name", "type", "shape", "text", "color", "usageNotes", "source", "status")


def parse_scalar(raw: str) -> Any:
    value = raw.strip()
    if value.startswith('"') and value.endswith('"'):
        return value[1:-1]
    if value.startswith("{") and value.endswith("}"):
        body = value[1:-1].strip()
        if not body:
            return []
        return [parse_scalar(part) for part in body.split(",")]
    try:
        if "." in value or "e" in value.lower():
            return float(value)
        return int(value)
    except ValueError:
        return value


def clamp_alpha(value: Any) -> float:
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        return 1.0
    return min(1.0, max(0.0, numeric))


def parse_aliases(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    pairs = re.findall(r'\[\s*"([^\"]+)"\s*,\s*"([^\"]+)"\s*\]', text)
    return {legacy: canonical for legacy, canonical in pairs}


def canonicalize_marker_text(value: str, aliases: dict[str, str]) -> str:
    normalized = value
    for legacy, canonical in sorted(aliases.items(), key=lambda item: len(item[0]), reverse=True):
        normalized = re.sub(rf"\b{re.escape(legacy)}\b", canonical, normalized)
    return normalized


def parse_mission_markers(path: Path) -> list[dict[str, Any]]:
    class_inline_re = re.compile(r"^\s*class\s+(\w+)\s*\{\s*$")
    class_re = re.compile(r"^\s*class\s+(\w+)\s*$")
    assign_re = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)(\[\])?\s*=\s*(.+);\s*$")

    lines = path.read_text(encoding="utf-8").splitlines()
    depth = 0
    stack: list[dict[str, Any]] = []
    pending_class: str | None = None
    markers: list[dict[str, Any]] = []

    def close_to_depth(target_depth: int) -> None:
        nonlocal stack
        while stack and stack[-1]["depth"] > target_depth:
            node = stack.pop()
            if node["properties"].get("dataType") != "Marker":
                continue
            marker = node["properties"].copy()
            layer_name = ""
            for ancestor in reversed(stack):
                props = ancestor.get("properties", {})
                if props.get("dataType") == "Layer":
                    layer_name = str(props.get("name", ""))
                    break
            marker["_layer"] = layer_name
            markers.append(marker)

    for line in lines:
        stripped = line.strip()

        if pending_class and stripped == "{":
            depth += 1
            stack.append({"name": pending_class, "depth": depth, "properties": {}})
            pending_class = None
            continue

        if stripped in {"};", "}"}:
            depth = max(0, depth - 1)
            close_to_depth(depth)
            continue

        class_inline_match = class_inline_re.match(line)
        if class_inline_match:
            depth += 1
            stack.append({"name": class_inline_match.group(1), "depth": depth, "properties": {}})
            continue

        class_match = class_re.match(line)
        if class_match:
            pending_class = class_match.group(1)
            continue

        if stripped == "{":
            depth += 1
            continue

        assign_match = assign_re.match(line)
        if assign_match and stack and depth == stack[-1]["depth"]:
            key, _, raw = assign_match.groups()
            stack[-1]["properties"][key] = parse_scalar(raw)

    close_to_depth(-1)
    return markers


def rg_consumers(symbol: str) -> list[str]:
    if not symbol:
        return []
    if not RG_AVAILABLE:
        return []
    cmd = [
        "rg",
        "--files-with-matches",
        "--fixed-strings",
        "--glob",
        "!mission.sqm",
        "--glob",
        "!docs/reference/marker-index.json",
        "--glob",
        "!docs/reference/marker-index.md",
        symbol,
        str(ROOT),
    ]
    result = subprocess.run(cmd, check=False, capture_output=True, text=True)
    if result.returncode not in (0, 1):
        raise RuntimeError(f"ripgrep failed for {symbol}: {result.stderr.strip()}")
    files = [Path(line).resolve().relative_to(ROOT).as_posix() for line in result.stdout.splitlines() if line.strip()]
    return sorted(set(files))


def normalize_entry(
    marker: dict[str, Any], aliases: dict[str, str], aliases_by_canonical: dict[str, list[str]]
) -> dict[str, Any]:
    raw_name = str(marker.get("name", ""))
    name = aliases.get(raw_name, raw_name)
    pos = marker.get("position", marker.get("pos", []))
    if not isinstance(pos, list):
        pos = []
    pos_norm = [float(value) for value in pos[:3]]
    while pos_norm and abs(pos_norm[-1]) < 1e-9:
        pos_norm.pop()

    consumers = set(rg_consumers(name))
    for alias in aliases_by_canonical.get(name, []):
        consumers.update(rg_consumers(alias))

    raw_shape = marker.get("shape", marker.get("markerShape", marker.get("markerType", "")))

    entry: dict[str, Any] = {
        "name": name,
        "type": str(marker.get("type", "")),
        "shape": str(raw_shape),
        "pos": pos_norm,
        "text": canonicalize_marker_text(str(marker.get("text", "")), aliases),
        "color": str(marker.get("colorName", marker.get("color", ""))),
        "alpha": clamp_alpha(marker.get("alpha", marker.get("a", 1))),
        "usageNotes": "",
        "source": f"mission.sqm{(':' + marker.get('_layer')) if marker.get('_layer') else ''}",
        "aliases": sorted(aliases_by_canonical.get(name, [])),
        "consumers": sorted(consumers),
        "status": "unresolved",
    }

    for field in TEXT_FIELDS:
        entry[field] = str(entry.get(field, ""))
    return entry


def format_cell(value: Any) -> str:
    if isinstance(value, list):
        text = ", ".join(str(item) for item in value)
    else:
        text = str(value)
    return text.replace("|", "\\|")


def write_markdown(entries: list[dict[str, Any]], path: Path) -> None:
    columns = ["name", "type", "shape", "pos", "text", "color", "alpha", "aliases", "consumers", "status", "usageNotes"]
    header = "| " + " | ".join(columns) + " |"
    separator = "|" + "|".join(["---"] * len(columns)) + "|"
    rows = [header, separator]

    for entry in entries:
        cells = []
        for col in columns:
            value = entry.get(col, "")
            if col == "pos":
                value = json.dumps(value, separators=(",", ":"))
            elif col == "alpha":
                value = f"{float(value):.3f}".rstrip("0").rstrip(".")
            cells.append(format_cell(value))
        rows.append("| " + " | ".join(cells) + " |")

    content = "\n".join([
        "# Marker Index",
        "",
        "Generated deterministically from `mission.sqm`, alias mappings, and static repository search hints.",
        "No embedded timestamps are included.",
        "Regenerate with: `python3 tools/generate_marker_index.py`.",
        "Published under `docs/reference/`.",
        "",
        "## Summary",
        "",
        f"- Total markers: **{len(entries)}**",
        "",
        "## Full Marker Table",
        "",
        *rows,
        "",
    ])
    path.write_text(content, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate marker index artifacts")
    parser.add_argument("--sqm", type=Path, default=MISSION_PATH)
    parser.add_argument("--aliases", type=Path, default=ALIASES_PATH)
    parser.add_argument("--out-json", type=Path, default=JSON_OUT)
    parser.add_argument("--out-md", type=Path, default=MD_OUT)
    args = parser.parse_args()

    aliases = parse_aliases(args.aliases)
    aliases_by_canonical: dict[str, list[str]] = {}
    for legacy, canonical in aliases.items():
        aliases_by_canonical.setdefault(canonical, []).append(legacy)

    raw_markers = parse_mission_markers(args.sqm)
    entries = [normalize_entry(marker, aliases, aliases_by_canonical) for marker in raw_markers]
    entries.sort(key=lambda item: item["name"])

    json_payload = {
        "summary": {"total": len(entries)},
        "markers": entries,
    }
    args.out_json.write_text(json.dumps(json_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown(entries, args.out_md)


if __name__ == "__main__":
    main()
