# District ID Static QA Note

## Accepted district ID forms

- Canonical persisted form: `D01` .. `D20` (uppercase `D` + zero-padded 2-digit number).
- Threat sentinel form: `D00` (only for unresolved threat district context when resolver cannot map from position).

## Rejection / normalization behavior

- Inputs are trimmed and uppercased before validation.
- Non-string or empty values are rejected.
- Values outside canonical range (for example `D1`, `D21`, `DX1`, `A03`) are rejected.
- Threat creation path (`ARC_fnc_threatCreateFromTask`) behavior:
  1. use provided `district_id` when canonical (`D01..D20`);
  2. otherwise resolve from position via `ARC_fnc_threadResolveDistrictId`;
  3. if still invalid/unavailable, persist sentinel `D00` and compose `THR:D00:######`.

## UI handling expectation

- `D00` must be treated as **UNRESOLVED DISTRICT** in operator-facing UI labels/tooltips.
- Raw IDs should remain available in debug/inspector payloads for auditability (`district_id_source` and normalized `district_id`).
