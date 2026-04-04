#!/usr/bin/env python3
"""Generate vehicle index artifacts from mission.sqm standalone objects.

Covers all dataType="Object" entries that are NOT inside a dataType="Group"
(group-owned units are covered by generate_unit_index.py).

Outputs:
  docs/reference/vehicle-index.json  — machine-readable
  docs/reference/vehicle-index.md   — human-readable

Regenerate with: python3 tools/generate_vehicle_index.py
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MISSION_PATH = ROOT / "mission.sqm"
JSON_OUT = ROOT / "docs" / "reference" / "vehicle-index.json"
MD_OUT = ROOT / "docs" / "reference" / "vehicle-index.md"

# ---------------------------------------------------------------------------
# Classification helpers
# ---------------------------------------------------------------------------

# Prefixes / substrings that identify fixed-wing aircraft types
_FIXED_WING_PATTERNS = (
    "_F16", "_f16", "F16C", "F-16",
    "_A10", "A10C", "A-10",
    "_C130", "C130J", "USAF_C130",
    "_C17", "USAF_C17",
    "_KC135", "usaf_kc135",
    "_EC130", "EC130",
    "_RQ4", "USAF_RQ4", "rksla3_uav_rq7",
    "FIR_F16", "FIR_A10", "aws_C130",
    "_B_UAV_01", "B_UAV_01",  # vanilla fixed-wing UAV / drone
)

# Prefixes / substrings that identify rotary-wing aircraft
_ROTARY_PATTERNS = (
    "AH64", "AH_64", "RHS_AH64",
    "UH60", "UH_60", "RHS_UH60",
    "CH47", "CH_47", "RHS_CH",
    "OH58", "OH_58", "ad_oh58",
    "B_Heli", "O_Heli", "C_Heli",
    "Peral_527",  # Bell OH-58 lookalike mod
)

# Ground vehicle prefixes
_GROUND_VEHICLE_PATTERNS = (
    "rhsusf_m12", "rhsusf_m10", "rhsusf_m99", "rhsusf_M1",
    "rhsusf_M977", "rhsusf_M978", "rhsusf_mrzr", "rhsusf_m115",
    "UK3CB_C_Hilux", "UK3CB_C_LandRover",
    "d3s_tundra", "d3s_Q7", "d3s_challenger", "d3s_raptor",
    "d3s_teslaS", "d3s_titan", "d3s_eldorado", "d3s_evoque",
    "d3s_Aprilia", "d3s_e89_12_M",
    "Peral_M151", "Peral_B600", "Peral_B809E", "Peral_USN6",
    "Fox_Firetruck", "Fox_HeavyRescue",
    "AL_maas_trailer",
    "Boxloader_",
    "B_Truck", "B_MRAP", "B_G_Offroad",
    "renelerchberg",
    "B_UGV",
)

# Equipment / supplies / crates (not personnel-carrying vehicles)
_EQUIPMENT_PATTERNS = (
    "B_Slingload", "rhsusf_props_",
    "ACRE_Radio", "US_Warfare",
    "RuggedTerminal",
)

# Props / dressing (aesthetic objects that happen to be Objects, not Land_*)
_PROP_PATTERNS = (
    "plp_bo_", "plp_ct_", "plp_up_",
    "plp_upm_",
    "CUP_vojenska", "CUP_lekarnicka",
    "RoadCone", "RoadBarrier", "RoadSign",
    "FoldTable", "Fridge_", "Coffin_", "Flag_", "Banner_",
    "Static_Radio", "Reflector_Cone", "light_generator",
    "FoldedFlag", "ClutterCutter", "ShootingRange",
    "UserTexture", "WaterPump", "Wire",
    "MapBoard_Pink", "N4_to", "Gunrack",
    "UK3CB_B_Searchlight",
    "B_Deck_Crew",
    "FirstAidKit",
    "PowGen_Big",
    "Fox_Arrow",  # ladder prop
    "Peral_600K_fire", "Peral_AS32A", "Peral_B600_towbar",
    "Peral_H2_Forklift", "Peral_MJ_1E", "Peral_pedestrian",
    "Peral_pilot_boarding",
    "Sign_F",
    "MFR_B_GermanShepherd",
)


def classify_type(class_name: str) -> str:
    """Return a category label for a given classname."""
    if any(p in class_name for p in _FIXED_WING_PATTERNS):
        return "Fixed-Wing"
    if any(p in class_name for p in _ROTARY_PATTERNS):
        return "Rotary-Wing"
    if any(p in class_name for p in _GROUND_VEHICLE_PATTERNS):
        return "Ground Vehicle"
    if any(class_name.startswith(p) for p in _EQUIPMENT_PATTERNS):
        return "Equipment"
    if any(class_name.startswith(p) or p in class_name for p in _PROP_PATTERNS):
        return "Prop"
    if class_name.startswith("Land_") or class_name.startswith("marking_"):
        return "Prop"
    # Infantry / crew placed as standalone objects
    if any(tag in class_name for tag in (
        "_army_ocp_", "_airforce_", "UK3CB_TK", "UK3CB_MEC",
        "B_soldier", "B_engineer_F", "B_Pilot_F", "FIR_USAF_GroundCrew",
        "B_UAV_AI",
    )):
        return "Infantry (standalone)"
    return "Other"


# ---------------------------------------------------------------------------
# Tree parser (reused from generate_unit_index.py pattern)
# ---------------------------------------------------------------------------

CLASS_RE = re.compile(r"^\s*class\s+(\w+)\s*$")
CLASS_INLINE_RE = re.compile(r"^\s*class\s+(\w+)\s*\{\s*$")
ASSIGN_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)(\[\])?\s*=\s*(.+);\s*$")


@dataclass
class Node:
    name: str
    properties: dict[str, Any] = field(default_factory=dict)
    children: list["Node"] = field(default_factory=list)


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


def parse_mission_tree(path: Path) -> Node:
    lines = path.read_text(encoding="utf-8").splitlines()
    root = Node("__root__")
    stack: list[Node] = [root]
    pending_class: str | None = None
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if stripped == "};" or stripped == "}":
            if len(stack) > 1:
                stack.pop()
            pending_class = None
            i += 1
            continue

        if m := CLASS_INLINE_RE.match(line):
            node = Node(m.group(1))
            stack[-1].children.append(node)
            stack.append(node)
            pending_class = None
            i += 1
            continue

        if m := CLASS_RE.match(line):
            pending_class = m.group(1)
            i += 1
            continue

        if stripped == "{" and pending_class is not None:
            node = Node(pending_class)
            stack[-1].children.append(node)
            stack.append(node)
            pending_class = None
            i += 1
            continue

        if m := ASSIGN_RE.match(line):
            key = m.group(1)
            raw_value = m.group(3).strip()
            stack[-1].properties[key] = parse_scalar(raw_value)
            i += 1
            continue

        i += 1
    return root


def get_child(node: Node, name: str) -> Node | None:
    for child in node.children:
        if child.name == name:
            return child
    return None


def walk(node: Node):
    yield node
    for child in node.children:
        yield from walk(child)


# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

def format_pos(pos: Any) -> list[float]:
    if isinstance(pos, list) and len(pos) == 3:
        return [round(float(x), 4) for x in pos]
    return []


def extract_vehicles(root: Node) -> list[dict[str, Any]]:
    """
    Walk the tree and collect all dataType="Object" nodes that are NOT
    direct children of a dataType="Group" node.

    For each object, resolve the nearest ancestor Layer name for context.
    """
    records: list[dict[str, Any]] = []

    def _walk_layer(node: Node, layer_path: list[str], in_group: bool) -> None:
        dt = node.properties.get("dataType", "")

        if dt == "Group":
            # Walk children but mark as in_group — we don't index these here
            ents = get_child(node, "Entities")
            if ents:
                for child in ents.children:
                    _walk_layer(child, layer_path, in_group=True)
            return

        if dt == "Layer":
            layer_name = str(node.properties.get("name", node.name))
            new_path = layer_path + [layer_name]
            ents = get_child(node, "Entities")
            if ents:
                for child in ents.children:
                    _walk_layer(child, new_path, in_group)
            return

        if dt == "Object" and not in_group:
            pos_node = get_child(node, "PositionInfo")
            pos = []
            if pos_node:
                raw = pos_node.properties.get("position", [])
                pos = format_pos(raw)

            attrs = get_child(node, "Attributes")
            var_name = ""
            if attrs:
                var_name = str(attrs.properties.get("name", ""))

            class_name = str(node.properties.get("type", ""))
            side = str(node.properties.get("side", "Empty"))
            obj_id = str(node.properties.get("id", ""))
            layer = layer_path[-1] if layer_path else ""
            layer_full = " > ".join(layer_path) if layer_path else ""

            records.append({
                "id": obj_id,
                "className": class_name,
                "varName": var_name,
                "category": classify_type(class_name),
                "side": side,
                "layer": layer,
                "layerPath": layer_full,
                "pos": pos,
                "source": "mission.sqm",
            })
            return

        # Logic, Waypoint, Trigger, etc. — recurse into children
        ents = get_child(node, "Entities")
        if ents:
            for child in ents.children:
                _walk_layer(child, layer_path, in_group)

    # The top-level Mission.Entities tree
    mission = get_child(root, "Mission")
    if mission:
        top_ents = get_child(mission, "Entities")
        if top_ents:
            for child in top_ents.children:
                _walk_layer(child, [], False)

    return records


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

CATEGORIES_ORDER = [
    "Fixed-Wing",
    "Rotary-Wing",
    "Ground Vehicle",
    "Infantry (standalone)",
    "Equipment",
    "Prop",
    "Other",
]


def write_markdown(records: list[dict[str, Any]], path: Path) -> None:
    by_category: dict[str, list[dict[str, Any]]] = {c: [] for c in CATEGORIES_ORDER}
    for r in records:
        cat = r.get("category", "Other")
        by_category.setdefault(cat, []).append(r)

    columns = ["id", "className", "varName", "side", "layer", "pos"]
    header = "| " + " | ".join(columns) + " |"
    separator = "|" + "|".join(["---"] * len(columns)) + "|"

    def fmt_cell(value: Any) -> str:
        if isinstance(value, list):
            text = json.dumps(value, separators=(",", ":"))
        else:
            text = str(value)
        return text.replace("|", "\\|")

    lines: list[str] = [
        "# Vehicle / Object Index",
        "",
        "Generated deterministically from `mission.sqm` standalone objects (not inside editor groups).",
        "No embedded timestamps are included.",
        "Regenerate with: `python3 tools/generate_vehicle_index.py`.",
        "Published under `docs/reference/`.",
        "",
        "## Summary",
        "",
        f"- Total standalone objects: **{len(records)}**",
    ]

    # Per-category counts
    for cat in CATEGORIES_ORDER:
        n = len(by_category.get(cat, []))
        if n:
            lines.append(f"- {cat}: **{n}**")

    lines += [""]

    for cat in CATEGORIES_ORDER:
        items = by_category.get(cat, [])
        if not items:
            continue
        lines.append(f"## {cat} ({len(items)})")
        lines.append("")
        lines += [header, separator]
        for r in sorted(items, key=lambda x: (x["className"], x["id"])):
            cells = []
            for col in columns:
                cells.append(fmt_cell(r.get(col, "")))
            lines.append("| " + " | ".join(cells) + " |")
        lines.append("")

    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    root = parse_mission_tree(MISSION_PATH)
    records = extract_vehicles(root)

    # Sort deterministically
    records.sort(key=lambda r: (r.get("category", ""), r.get("className", ""), r.get("id", "")))

    by_cat = {c: [] for c in CATEGORIES_ORDER}
    for r in records:
        cat = r.get("category", "Other")
        by_cat.setdefault(cat, []).append(r)

    json_payload: dict[str, Any] = {
        "summary": {
            "total": len(records),
            "by_category": {c: len(v) for c, v in by_cat.items() if v},
        },
        "objects": records,
    }

    JSON_OUT.write_text(json.dumps(json_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown(records, MD_OUT)
    print(f"[vehicle-index] {len(records)} standalone objects written to {MD_OUT} and {JSON_OUT}")


if __name__ == "__main__":
    main()
