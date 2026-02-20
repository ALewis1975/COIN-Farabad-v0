#!/usr/bin/env python3
"""Generate unit index artifacts from mission.sqm groups/units."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MISSION_PATH = ROOT / "mission.sqm"
JSON_OUT = ROOT / "docs" / "reference" / "unit-index.json"
MD_OUT = ROOT / "docs" / "reference" / "unit-index.md"

CLASS_INLINE_RE = re.compile(r"^\s*class\s+(\w+)\s*\{\s*$")
CLASS_RE = re.compile(r"^\s*class\s+(\w+)\s*$")
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

    for line in lines:
        stripped = line.strip()

        if pending_class and stripped == "{":
            node = Node(pending_class)
            stack[-1].children.append(node)
            stack.append(node)
            pending_class = None
            continue

        if stripped in {"};", "}"}:
            if len(stack) > 1:
                stack.pop()
            continue

        inline_match = CLASS_INLINE_RE.match(line)
        if inline_match:
            node = Node(inline_match.group(1))
            stack[-1].children.append(node)
            stack.append(node)
            continue

        class_match = CLASS_RE.match(line)
        if class_match:
            pending_class = class_match.group(1)
            continue

        assign_match = ASSIGN_RE.match(line)
        if assign_match:
            key, _, raw = assign_match.groups()
            stack[-1].properties[key] = parse_scalar(raw)

    return root


def walk(node: Node):
    yield node
    for child in node.children:
        yield from walk(child)


def get_child(node: Node, name: str) -> Node | None:
    for child in node.children:
        if child.name == name:
            return child
    return None


def get_group_key(group: Node) -> str:
    custom = get_child(group, "CustomAttributes")
    if custom is not None:
        for attr in custom.children:
            if attr.properties.get("property") != "groupID":
                continue
            value_node = get_child(attr, "Value")
            if value_node is None:
                continue
            data_node = get_child(value_node, "data")
            if data_node is None:
                continue
            value = str(data_node.properties.get("value", "")).strip()
            if value:
                return value

    side = str(group.properties.get("side", ""))
    group_id = str(group.properties.get("id", ""))
    return f"{side}:{group_id}" if side or group_id else "unknown-group"


def as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    text = str(value).strip().lower()
    return text in {"1", "true", "yes"}


def extract_units(group: Node, group_key: str) -> list[dict[str, Any]]:
    entities = get_child(group, "Entities")
    if entities is None:
        return []

    units: list[dict[str, Any]] = []
    for candidate in entities.children:
        if candidate.properties.get("dataType") != "Object":
            continue

        attrs = get_child(candidate, "Attributes")
        attrs_props = attrs.properties if attrs else {}
        var_name = str(attrs_props.get("name", ""))
        is_playable = as_bool(attrs_props.get("isPlayable", 0))
        is_player = as_bool(attrs_props.get("isPlayer", 0) or attrs_props.get("player", 0))
        class_name = str(candidate.properties.get("type", ""))
        side = str(candidate.properties.get("side", group.properties.get("side", "")))

        units.append(
            {
                "varName": var_name,
                "className": class_name,
                "unitType": class_name,
                "side": side,
                "isPlayable": is_playable,
                "isPlayer": is_player,
                "groupId": group_key,
                "source": "mission.sqm",
            }
        )

    units.sort(key=lambda item: (not item["isPlayable"], item["varName"], item["className"]))
    return units


def build_payload(root: Node) -> dict[str, Any]:
    groups: list[dict[str, Any]] = []
    for node in walk(root):
        if node.properties.get("dataType") != "Group":
            continue
        group_key = get_group_key(node)
        groups.append(
            {
                "groupKey": group_key,
                "side": str(node.properties.get("side", "")),
                "id": str(node.properties.get("id", "")),
                "units": extract_units(node, group_key),
            }
        )

    groups.sort(key=lambda item: item["groupKey"])
    return {
        "groups": groups,
        "units": [unit for group in groups for unit in group["units"]],
    }


def write_markdown(groups: list[dict[str, Any]], path: Path) -> None:
    lines = [
        "# Unit Index",
        "",
        "Generated from `mission.sqm` grouped by editor group ID.",
        "",
    ]

    for group in groups:
        group_key = group["groupKey"] or "(unassigned)"
        lines.extend([
            f"## {group_key}",
            "",
            f"Side: `{group['side']}` · Group id: `{group['id']}`",
            "",
            "| varName | className | unitType | playable | player |",
            "|---|---|---|---|---|",
        ])
        for unit in group["units"]:
            lines.append(
                "| "
                + " | ".join(
                    [
                        str(unit["varName"]).replace("|", "\\|"),
                        str(unit["className"]).replace("|", "\\|"),
                        str(unit["unitType"]).replace("|", "\\|"),
                        str(unit["isPlayable"]).lower(),
                        str(unit["isPlayer"]).lower(),
                    ]
                )
                + " |"
            )
        lines.append("")

    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    tree = parse_mission_tree(MISSION_PATH)
    payload = build_payload(tree)
    JSON_OUT.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown(payload["groups"], MD_OUT)


if __name__ == "__main__":
    main()
