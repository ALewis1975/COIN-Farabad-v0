# Threat Economy Operator Tooling v1

## Scope

This implementation closes Epic 7 observability/operator tooling gaps by publishing a server-built, read-only Threat Economy snapshot and documenting how operators explain scheduler allow/deny outcomes.

- Snapshot contract: `ARC_pub_threatEconomySnapshot` (`schema = threat_economy_obs_v1`)
- Public state embedding: `ARC_pub_state.threatEconomy`
- Console VM embedding: `ARC_consoleVM_payload.sections.threat.data.economy`
- Server authority only: clients consume/read snapshots and never write Threat Economy state

## Telemetry field catalog (read model)

| Field | Meaning | Source |
|---|---|---|
| `summary.enabled` | Threat system on/off gate | `threat_v0_enabled` |
| `summary.hot_risk_count` / `critical_risk_count` | Number of districts above risk thresholds | `threat_v0_district_risk[*].risk_level` |
| `summary.cooldown_active_count` | Districts currently under district cooldown | `threat_v0_district_risk[*].cooldown_until` |
| `summary.budget_exhausted_count` | Districts where `spent_today >= budget_points` | `threat_v0_attack_budget` |
| `summary.budget_points_total` / `spent_today_total` | Aggregate budget and spend | `threat_v0_attack_budget` |
| `scheduler.interval_s` / `last_tick_ts` / `next_tick_due_in_s` | Scheduler pacing visibility | `ARC_threatSchedulerIntervalS`, `threat_v0_scheduler_last_ts` |
| `cooldowns.global_until` / `global_remaining_s` / `global_active` | Global cooldown guardrail state | `threat_v0_global_cooldown_until` |
| `lastDecision` | Last scheduler governor decision (allow/deny) | `threat_v0_economy_last_decision` |
| `lastAllowedDecision` / `lastDeniedDecision` | Last successful and denied governor checks | `threat_v0_economy_last_allowed_decision`, `threat_v0_economy_last_denied_decision` |
| `denyReasonTaxonomy` / `denyReasonCounts` | Deny reason contract and cumulative counts | `threat_v0_economy_deny_reason_enum`, `threat_v0_economy_deny_counts` |
| `topRiskDistricts` / `topSpentDistricts` | Operator quick-look ranking (top 5) | Derived from risk/budget maps |
| `districtRows[]` | Per-district audit row (risk, cooldown, budget, capacity, disruption penalty) | `threat_v0_district_risk`, `threat_v0_attack_budget` |

## Thresholds and deny taxonomy

### Thresholds

- `risk_hot_gte = 70`
- `risk_critical_gte = 85`
- `budget exhausted` when `spent_today >= budget_points`

These are observability thresholds only (no campaign rebalance introduced in this PR).

### Scheduler deny reasons (governor)

- `THREAT_DISABLED`
- `GLOBAL_COOLDOWN`
- `DISTRICT_COOLDOWN`
- `BUDGET_EXHAUSTED`
- `ESCALATION_TIER`
- `BAD_DISTRICT`
- `NOT_SERVER`

## Logging/event taxonomy for economy decisions

Scheduler decisions are logged via structured server logs:

- Allow:
  - `[ARC][THREAT] ARC_fnc_threatSchedulerTick: governor allowed district=%1 type=%2 tier=%3`
- Deny:
  - `[ARC][THREAT] ARC_fnc_threatSchedulerTick: governor denied district=%1 type=%2 tier=%3 reason=%4`

Use these logs with `lastDecision`/`denyReasonCounts` for audit and troubleshooting.

## Operator/admin tooling boundaries

- Implemented in this PR:
  - Read-only economy diagnostics snapshot for operator/admin inspection.
  - Explicit deny reason taxonomy and cumulative deny counters.
  - Last decision context for “why scheduled/why denied” answers.
- Not implemented in this PR:
  - New admin reset/control RPCs.

Admin controls are deferred intentionally to avoid expanding remoteExec/control surfaces in this Epic 7 slice. Any future controls must be explicit, bounded, role-gated, server-mediated, logged, and documented.

## Operator interpretation runbook

1. Check `summary.enabled` and `cooldowns.global_active`.
2. Inspect `lastDecision` and, if denied, record `deny_reason`, `district_id`, `tier`, and `ts`.
3. Review `denyReasonCounts` for repeated systemic denies (cooldown vs budget vs tier gates).
4. Use `districtRows` to audit district-level risk/cooldown/capacity.
5. Prioritize districts from `topRiskDistricts` and `topSpentDistricts`.
6. Correlate with `Console_VM_v1.sections.threat.data.snapshot.events` for adjacent threat activity context.

## Completion rubric

- **PASS (static)**: snapshot schema/fields and contract checks pass; no client-authoritative writes added.
- **PASS (runtime local MP)**: operators can explain allow/deny outcomes using snapshot + logs.
- **BLOCKED (dedicated/JIP unavailable)**: late-join consistency and dedicated-only observability behavior not claimed until run in dedicated/JIP environment.
