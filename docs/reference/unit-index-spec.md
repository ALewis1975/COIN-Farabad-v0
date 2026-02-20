# Unit Index Specification

This document defines the canonical schema and normalization rules for unit index generation outputs.

## Canonical output files

- Human-readable output: `docs/reference/unit-index.md`
- Machine-readable output: `docs/reference/unit-index.json`

## Shared workflow conventions

Both index generators (`tools/generate_marker_index.py` and `tools/generate_unit_index.py`) follow the same contributor workflow conventions:

- Outputs are deterministic across repeated runs on unchanged inputs.
- Generated artifacts do not embed timestamps.
- Canonical generated docs are published under `docs/reference/`.
- Contributors regenerate artifacts with script-local commands in the same style: `python3 tools/<generator>.py`.

## Canonical schema

### Required fields

Each unit entry MUST provide all required fields:

- `varName`
- `className`
- `side`
- `isPlayable`
- `isPlayer`
- `groupId`
- `unitType`
- `source`

### Optional fields

Each unit entry MAY provide these optional fields:

- `groupName`
- `roleHint`
- `status`
- `consumers`
- `notes`

## Field normalization rules

Apply these normalization rules before writing either canonical output file:

1. **Stable ordering**
   - Sort entries with a stable sort by `varName` (ascending).
   - For ties on `varName`, apply stable secondary keys in this order: `groupId`, then `className`.

2. **Boolean normalization**
   - `isPlayable` and `isPlayer` MUST be encoded as JSON booleans (`true`/`false`) in machine-readable output.
   - Human-readable output MUST render these values consistently as lowercase boolean literals (`true`/`false`).

3. **Empty string vs null policy**
   - Required text-like fields MUST use empty strings (`""`) when a value is unknown or unavailable; they MUST NOT be `null`.
   - Optional text-like fields (`groupName`, `roleHint`, `status`, `notes`) SHOULD use empty strings (`""`) when intentionally blank.
   - Optional list-like fields (for example, `consumers`) SHOULD use empty arrays (`[]`) when intentionally blank.
   - Use `null` only when the distinction between “intentionally blank” and “not collected/not applicable” is explicitly required by a downstream consumer.
