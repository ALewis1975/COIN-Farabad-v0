# State Migration Checks (Static Harness)

This harness defines **old-schema -> current-schema** migration scenarios for `ARC_pub_state` and validates them without requiring an Arma runtime.

## Files

- Scenario matrix: `tests/migrations/state_schema_scenarios.json`
- Static validator: `scripts/dev/validate_state_migrations.py`

## What is validated

For every scenario, the validator enforces:

1. **Required keys present** after migration.
2. **Defaulting for missing fields** uses the contract defaults.
3. **No destructive overwrite on unknown fields** (forward compatibility).

## Run locally

```bash
python3 scripts/dev/validate_state_migrations.py
```

## Checklist (for static review and CI)

- [ ] Scenario added/updated in `tests/migrations/state_schema_scenarios.json`.
- [ ] `python3 scripts/dev/validate_state_migrations.py` passes.
- [ ] Unknown source keys are preserved verbatim in expected assertions.
- [ ] Defaults table still includes every `required_key`.

## Blocked runtime-only validations (tracked separately)

These checks remain blocked in container/CI and require hosted MP or dedicated server runs:

- Persistence durability across restart with migration replay.
- JIP snapshot correctness during in-flight migration windows.
- Late-client recovery after schema migration-triggered broadcasts.
- Reconnect/respawn ownership edge cases across migrated state payloads.
