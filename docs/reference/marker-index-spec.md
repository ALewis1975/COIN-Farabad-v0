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
