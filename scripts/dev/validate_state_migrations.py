#!/usr/bin/env python3
"""Static validation harness for ARC public-state migration scenarios."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def migrate_state(source: dict[str, Any], defaults: dict[str, Any], required_keys: list[str]) -> dict[str, Any]:
    """Non-destructive migration: preserve source fields and default only missing required keys."""
    migrated = dict(source)
    for key in required_keys:
        if key not in migrated:
            migrated[key] = defaults[key]
    return migrated


def validate_scenario(scenario: dict[str, Any], defaults: dict[str, Any], required_keys: list[str]) -> list[str]:
    errors: list[str] = []
    sid = scenario.get("id", "<unknown>")
    source = scenario.get("source", {})

    if not isinstance(source, dict):
        return [f"{sid}: scenario source must be an object"]

    migrated = migrate_state(source, defaults, required_keys)

    missing_keys = [key for key in required_keys if key not in migrated]
    if missing_keys:
        errors.append(f"{sid}: required keys missing after migration: {missing_keys}")

    for key in scenario.get("expected_defaulted", []):
        if key not in defaults:
            errors.append(f"{sid}: expected_defaulted key '{key}' not in defaults")
            continue
        if migrated.get(key) != defaults[key]:
            errors.append(
                f"{sid}: expected default for '{key}' = {defaults[key]!r}, got {migrated.get(key)!r}"
            )

    expected_preserved = scenario.get("expected_preserved", {})
    if not isinstance(expected_preserved, dict):
        errors.append(f"{sid}: expected_preserved must be an object")
    else:
        for key, expected_value in expected_preserved.items():
            if key not in migrated:
                errors.append(f"{sid}: expected preserved key '{key}' missing after migration")
                continue
            if migrated[key] != expected_value:
                errors.append(
                    f"{sid}: key '{key}' destructively overwritten: expected {expected_value!r}, got {migrated[key]!r}"
                )

    # Unknown keys must survive unchanged.
    unknown_keys = [key for key in source if key not in required_keys]
    for key in unknown_keys:
        if key not in migrated:
            errors.append(f"{sid}: unknown key '{key}' dropped during migration")
        elif migrated[key] != source[key]:
            errors.append(
                f"{sid}: unknown key '{key}' changed value during migration: expected {source[key]!r}, got {migrated[key]!r}"
            )

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate state migration scenarios for ARC public-state schema.")
    parser.add_argument(
        "--scenarios",
        default="tests/migrations/state_schema_scenarios.json",
        help="Path to migration scenario JSON file",
    )
    args = parser.parse_args()

    scenario_path = Path(args.scenarios)
    if not scenario_path.is_file():
        print(f"ERROR: scenario file not found: {scenario_path}", file=sys.stderr)
        return 1

    data = json.loads(scenario_path.read_text(encoding="utf-8"))
    required_keys = data.get("required_keys", [])
    defaults = data.get("defaults", {})
    scenarios = data.get("scenarios", [])

    if not isinstance(required_keys, list) or not all(isinstance(k, str) for k in required_keys):
        print("ERROR: required_keys must be a list of strings", file=sys.stderr)
        return 1

    if not isinstance(defaults, dict):
        print("ERROR: defaults must be an object", file=sys.stderr)
        return 1

    missing_defaults = [key for key in required_keys if key not in defaults]
    if missing_defaults:
        print(f"ERROR: defaults missing required keys: {missing_defaults}", file=sys.stderr)
        return 1

    if not isinstance(scenarios, list) or not scenarios:
        print("ERROR: scenarios must be a non-empty list", file=sys.stderr)
        return 1

    all_errors: list[str] = []
    for scenario in scenarios:
        if not isinstance(scenario, dict):
            all_errors.append("Scenario entries must be objects")
            continue
        all_errors.extend(validate_scenario(scenario, defaults, required_keys))

    if all_errors:
        print("State migration validation FAILED:")
        for err in all_errors:
            print(f"  - {err}")
        return 1

    print(f"State migration validation passed ({len(scenarios)} scenarios).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
