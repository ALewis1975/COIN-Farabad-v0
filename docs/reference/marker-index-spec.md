# Marker Index Specification

This document defines the canonical schema and normalization rules for marker index generation outputs.

## Canonical output files

- Human-readable output: `docs/reference/marker-index.md`
- Machine-readable output: `docs/reference/marker-index.json`

## Static validation command

Run this command to validate generator execution, JSON parseability, and markdown/JSON marker-count parity:

```bash
python3 scripts/dev/validate_marker_index.py --sqm mission.sqm
```

## Dependency policy

Marker index tooling has one dependency policy shared by generator and validator:

- **Required dependencies:** Python 3.11+ and repository inputs (`mission.sqm`, alias mapping).
- **Optional enhancement:** `ripgrep` (`rg`) for static consumer detection.
- **Behavior when optional tool is absent:** generation still succeeds deterministically, and each marker entry emits `"consumers": []`.
- **Warning format (stderr):**

```text
[marker-index] WARNING: optional dependency 'rg' unavailable; consumer detection disabled; consumers=[] fallback enabled.
```

### Consumer detection modes

`tools/generate_marker_index.py` supports `--consumer-detection {auto,on,off}` (or `MARKER_INDEX_CONSUMER_DETECTION`):

- `auto` (default): use `rg` when present; otherwise emit the standard warning and degrade to `consumers=[]`.
- `on`: prefer `rg`; if unavailable, follow the same warning + fallback behavior as `auto`.
- `off`: skip consumer detection explicitly with no warning.

## Shared workflow conventions

Both index generators (`tools/generate_marker_index.py` and `tools/generate_unit_index.py`) follow the same contributor workflow conventions:

- Outputs are deterministic across repeated runs on unchanged inputs.
- Generated artifacts do not embed timestamps.
- Canonical generated docs are published under `docs/reference/`.
- Contributors regenerate artifacts with script-local commands in the same style: `python3 tools/<generator>.py`.

## Canonical schema

### Required fields

Each marker entry MUST provide all required fields:

- `name`
- `type`
- `shape`
- `pos`
- `text`
- `color`
- `alpha`
- `usageNotes`

### Recommended fields

Each marker entry SHOULD provide these optional-but-recommended fields:

- `source`
- `aliases`
- `consumers`
- `status`

## Field normalization rules

Apply these normalization rules before writing either canonical output file:

1. **Position shape (`pos`)**
   - Encode `pos` as `[x, y, z]` when altitude is present.
   - Encode `pos` as `[x, y]` when altitude is not present.

2. **Stable ordering**
   - Sort entries by `name` using a stable sort.

3. **Missing textual fields**
   - Use empty strings (`""`) instead of `null` for missing textual values.

4. **Alpha bounds (`alpha`)**
   - Clamp `alpha` to the inclusive range `0..1`.

5. **Status enum (`status`)**
   - `active`: marker is current and expected to be used by live systems.
   - `legacy`: marker remains for backward compatibility or migration support.
   - `unresolved`: marker is discovered but not yet fully classified/validated.
