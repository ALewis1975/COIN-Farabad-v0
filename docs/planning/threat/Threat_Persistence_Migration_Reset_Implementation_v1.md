# Threat Persistence / Migration / Reset Implementation v1

## Scope

This Epic 5 slice implements static, non-dedicated hardening for threat persistence contracts:

- explicit schema/version contract documentation aligned to current runtime keys,
- migration matrix + idempotency/replay rules,
- reset/rebuild contract with bounded-state expectations,
- restart invariants checklist spanning threat, economy, and virtual pool stores.

Runtime controlled restart, dedicated-server, and JIP proof remain outside this sandbox and are not claimed.

## Threat schema/version contract (runtime-aligned)

Server-authoritative baseline is seeded by `ARC_fnc_threatInit` and `ARC_fnc_threatEconomyInit`:

- schema version keys: `threat_v0_version`, `threat_v0_family_contract_v`
- required enum contracts:
  - `threat_v0_family_enum`
  - `threat_v0_state_enum`
  - `threat_v0_deny_reason_enum`
  - `threat_v0_economy_deny_reason_enum`
- required identity/index keys:
  - `threat_v0_campaign_id`, `threat_v0_seq`
  - `threat_v0_records` (pairs-array ThreatRecord rows)
  - `threat_v0_open_index`, `threat_v0_closed_index`
  - `threat_v0_vgroup_active_index`
- required bounded/event keys:
  - `threat_v0_closed_max`
  - `threat_v0_event_seq`, `threat_v0_events`, `threat_v0_events_max`
- required economy backing keys:
  - `threat_v0_district_risk`
  - `threat_v0_attack_budget`
  - `threat_v0_global_cooldown_until`
  - `threat_v0_scheduler_last_ts`
  - `threat_v0_economy_deny_counts`
  - `threat_v0_economy_last_decision`
  - `threat_v0_economy_last_allowed_decision`
  - `threat_v0_economy_last_denied_decision`

### Required vs optional field framing (ThreatRecord level)

For `threat_v0_records` rows, this Epic 5 slice treats the following as contract-required for migration compatibility:

- required: `threat_id`, `type`, `state`, `created_ts`, `updated_ts`, `rev`
- required linkage blocks (may be empty but must exist): `links`, `area`, `world`
- optional/forward-compatible: additional per-family fields and future metadata are preserved as unknown keys during migration.

Epic 4 family normalization fields (`family`, normalized `state`/deny semantics) are treated as required for newly written records, while migration remains non-destructive for legacy rows that predate normalized fields.

Epic 2 lifecycle/spawn metadata expectations remain:

- `world.spawn_token`
- `world.spawn_intent_ts`
- `world.spawn_attempt_count`
- cleanup convergence markers (`cleanup_completed`, `cleanup_ts`)

These are required for lifecycle-safe runtime behavior when present, but this static Epic 5 slice does not re-implement Epic 2 spawn/cleanup logic.

## Migration matrix and idempotency rules

| From | To | Rule | Idempotency expectation |
|---|---|---|---|
| `vLegacy` | `v0` | Default missing required keys only; preserve unknown keys untouched | Re-running migration produces the same object shape and values |
| `v0_partial` | `v0` | Fill only absent required keys; preserve existing populated keys | Replay-safe (no destructive overwrite) |
| `v0` | `v0` | No-op migration | Strictly idempotent |

### Migration invariants

1. Migration is non-destructive: unknown/future keys are never removed.
2. Required keys are guaranteed present after migration.
3. Existing values for already-present keys are never overwritten by defaults.
4. Applying migration multiple times yields identical output after first convergence.

Static scenarios for these invariants are defined in `tests/migrations/threat_persistence_schema_scenarios.json` and validated with `scripts/dev/validate_state_migrations.py --scenarios ...`.

## Reset/rebuild contract (server authority, bounded-state guarantees)

`ARC_fnc_resetAll` is the server-mediated reset entrypoint for threat persistence reinitialization.

Contract goals for reset/rebuild:

1. Clear threat identity/index roots (`campaign_id`, `seq`, record/index arrays).
2. Re-run `ARC_fnc_threatInit` to reseed required schema/version keys and economy defaults.
3. Preserve single-writer authority: server mutates state; clients consume refreshed snapshots.
4. Prevent contradictory state after reset by requiring post-reset checks:
   - `threat_v0_records` and open/closed indexes are coherent arrays.
   - virtual/economy snapshots can be rebuilt from state without missing required keys.
   - no orphaned threat IDs remain in public snapshot projections.

This slice provides static contract checks and explicit operator procedure guidance only; no new remoteExec/admin write surfaces are introduced.

## Restart invariants checklist (Threat + Economy + Virtual Pool)

### Threat store invariants

- [ ] `threat_v0_campaign_id` is non-empty after bootstrap/init.
- [ ] `threat_v0_seq` monotonic behavior preserved after restore.
- [ ] `threat_v0_records` and indexes deserialize with valid array types.
- [ ] event stream keys (`event_seq`, `events`, `events_max`) remain bounded and typed.

### Threat economy invariants

- [ ] district risk/budget maps are present and typed as HashMap stores.
- [ ] deny taxonomy + count maps remain readable by economy snapshot builder.
- [ ] last allow/deny decision records remain array-typed and snapshot-safe.

### Virtual pool invariants

- [ ] `VIRTUAL_OPFOR` records persist with valid `state` and `vgroup_id`.
- [ ] `threat_v0_vgroup_active_index` remains array-typed and orphan-diagnosable.
- [ ] protected-zone and locality diagnostics remain publishable in read models.

### Cross-store publication invariants

- [ ] `ARC_pub_state.threat`, `ARC_pub_state.threatEconomy`, and `ARC_pub_state.threatVirtualPool` all publish without schema gaps.
- [ ] Console VM threat section embeds all three read models consistently after restore.

## Validation evidence status

- **PASS (static):** schema/migration/reset contract documentation + static checks.
- **BLOCKED (runtime restart):** controlled restart deterministic recovery.
- **BLOCKED (dedicated/JIP):** late-join snapshot correctness post-restart.

These blocked runtime checks remain required for Epic 5/6 closure and are intentionally not claimed complete in this PR.
