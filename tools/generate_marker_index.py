#!/usr/bin/env python3
"""Generate marker index markdown/json outputs from mission.sqm."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Iterable


def _parse_item_blocks(text: str) -> Iterable[str]:
    pattern = re.compile(r"\bclass\s+Item\d+\b")
    idx = 0
    while True:
        match = pattern.search(text, idx)
        if not match:
            break
        start = match.start()
        brace_start = text.find("{", match.end())
        if brace_start == -1:
            idx = match.end()
            continue
        depth = 1
        pos = brace_start + 1
        n = len(text)
        while pos < n and depth:
            ch = text[pos]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
            pos += 1
        if depth == 0:
            yield text[start:pos]
            idx = match.end()
        else:
            idx = match.end()


def _read_prop(block: str, key: str) -> str:
    match = re.search(rf"\b{re.escape(key)}\s*=\s*\"([^\"]*)\";", block)
    return match.group(1) if match else ""


def _read_num(block: str, key: str, default: float) -> float:
    match = re.search(rf"\b{re.escape(key)}\s*=\s*([-+]?\d+(?:\.\d+)?);", block)
    return float(match.group(1)) if match else default


def _read_position(block: str) -> list[float]:
    # Eden marker position is {x, z, y}; normalize to [x, y, z].
    match = re.search(r"\bposition\s*\[\]\s*=\s*\{([^}]*)\};", block)
    if not match:
        return []
    raw = [part.strip() for part in match.group(1).split(",") if part.strip()]
    nums = [float(v) for v in raw]
    if len(nums) >= 3:
        return [nums[0], nums[2], nums[1]]
    return nums[:2]


def _extract_markers(sqm_text: str) -> list[dict]:
    markers = []
    for block in _parse_item_blocks(sqm_text):
        marker_count = block.count('dataType="Marker";')
        if marker_count != 1:
            continue
        shape = _read_prop(block, "markerType")
        marker = {
            "name": _read_prop(block, "name"),
            "type": _read_prop(block, "type"),
            "shape": shape,
            "pos": _read_position(block),
            "text": _read_prop(block, "text"),
            "color": _read_prop(block, "colorName"),
            "alpha": max(0.0, min(1.0, _read_num(block, "alpha", 1.0))),
            "usageNotes": "Editor marker from mission.sqm.",
            "source": "mission.sqm",
            "aliases": [],
            "consumers": [],
            "status": "active",
        }
        if marker["name"]:
            markers.append(marker)
    markers.sort(key=lambda item: item["name"])
    return markers


def _extract_aliases(path: Path) -> list[dict]:
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8")
    pairs = re.findall(r'\[\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\]', text)
    aliases = [{"alias": alias, "canonical": canonical} for alias, canonical in pairs]
    aliases.sort(key=lambda item: item["alias"])
    return aliases


def _extract_referenced_markers(root: Path) -> set[str]:
    exts = {".sqf", ".hpp", ".ext"}
    refs: set[str] = set()
    string_pattern = re.compile(r'"([A-Za-z][A-Za-z0-9_]*)"')
    likely_prefixes = (
        "ARC_",
        "arc_",
        "marker_",
        "mkr_",
        "AEON_",
        "respawn_",
        "epw_",
        "Main_",
        "NE_",
        "NW_",
        "SE_",
        "SW_",
        "North_",
        "South_",
        "tug",
        "plane_",
    )
    for path in root.rglob("*"):
        if path.suffix.lower() not in exts:
            continue
        if any(part.startswith(".") for part in path.parts):
            continue
        if path.parts and path.parts[0] in {"vendor", "dist", "build", "generated"}:
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for value in string_pattern.findall(text):
            if value.startswith(likely_prefixes):
                refs.add(value)
    return refs


def _prefix(name: str) -> str:
    return f"{name.split('_', 1)[0]}_" if "_" in name else name


def _make_summary(markers: list[dict]) -> dict:
    by_shape: dict[str, int] = {}
    by_prefix: dict[str, int] = {}
    for marker in markers:
        shape = marker["shape"] or "(empty)"
        by_shape[shape] = by_shape.get(shape, 0) + 1
        pref = _prefix(marker["name"])
        by_prefix[pref] = by_prefix.get(pref, 0) + 1
    return {
        "total": len(markers),
        "byShape": dict(sorted(by_shape.items())),
        "byPrefix": dict(sorted(by_prefix.items())),
    }


def _render_md(summary: dict, markers: list[dict], aliases: list[dict], unresolved: list[str]) -> str:
    lines = ["# Marker Index", "", "## Summary", "", f"- Total markers: **{summary['total']}**", "- By shape:"]
    for shape, count in summary["byShape"].items():
        lines.append(f"  - `{shape}`: {count}")
    lines.append("- By prefix:")
    for pref, count in summary["byPrefix"].items():
        lines.append(f"  - `{pref}`: {count}")

    lines.extend([
        "",
        "## Full Marker Table",
        "",
        "| Name | Type | Shape | Pos | Text | Color | Alpha | Usage Notes |",
        "|---|---|---|---|---|---|---:|---|",
    ])
    for marker in markers:
        pos = json.dumps(marker["pos"]) if marker["pos"] else "[]"
        lines.append(
            "| `{name}` | `{type}` | `{shape}` | `{pos}` | {text} | `{color}` | {alpha:.3f} | {notes} |".format(
                name=marker["name"],
                type=marker["type"],
                shape=marker["shape"],
                pos=pos,
                text=marker["text"],
                color=marker["color"],
                alpha=marker["alpha"],
                notes=marker["usageNotes"],
            )
        )

    lines.extend(["", "## Alias Section", "", "| Alias | Canonical |", "|---|---|"])
    for item in aliases:
        lines.append(f"| `{item['alias']}` | `{item['canonical']}` |")

    lines.extend(["", "## Unresolved-Reference Section", ""])
    if unresolved:
        lines.append("Markers referenced in code but missing from `mission.sqm` and alias canonical/alias sets:")
        lines.append("")
        for name in unresolved:
            lines.append(f"- `{name}`")
    else:
        lines.append("No unresolved marker references detected.")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate marker index outputs from mission.sqm")
    parser.add_argument("--sqm", required=True, type=Path)
    parser.add_argument("--out-md", required=True, type=Path)
    parser.add_argument("--out-json", required=True, type=Path)
    parser.add_argument("--aliases", default=Path("data/farabad_marker_aliases.sqf"), type=Path)
    args = parser.parse_args()

    sqm_text = args.sqm.read_text(encoding="utf-8", errors="ignore")
    markers = _extract_markers(sqm_text)
    aliases = _extract_aliases(args.aliases)

    known = {m["name"] for m in markers}
    known.update(item["alias"] for item in aliases)
    known.update(item["canonical"] for item in aliases)

    referenced = _extract_referenced_markers(Path("."))
    unresolved = sorted(name for name in referenced if name not in known)

    summary = _make_summary(markers)
    payload = {
        "summary": summary,
        "markers": markers,
        "aliases": aliases,
        "unresolvedReferences": unresolved,
    }

    args.out_json.parent.mkdir(parents=True, exist_ok=True)
    args.out_md.parent.mkdir(parents=True, exist_ok=True)
    args.out_json.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    args.out_md.write_text(_render_md(summary, markers, aliases, unresolved), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
