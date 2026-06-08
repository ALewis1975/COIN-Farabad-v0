# PR #613 QA Metadata Backfill — Threat Economy Reason Taxonomy

**Date:** 2026-06-08  
**Mode:** J — Operations / Config / Data Maintenance  
**PR:** #613 — `Feature/threat economy reason taxonomy`  
**Merged PR head:** `391e562884460032a70a2668a2efe2d32a918294`  
**Merge commit:** `a84fd16f33fb507a5407f95b25dc9f3c121b9c9f`  
**Status:** Backfill record. Runtime validation remains blocked.

---

## 1) Purpose

PR #613 merged with the default PR template still present. This record backfills the missing QA metadata so future reviewers can understand the mode, scope, acceptance criteria, validation status, risk, and rollback path.

---

## 2) Effective PR metadata

| Field | Value |
|---|---|
| Mode | B — Feature Delivery |
| Primary subsystem | Threat / Threat Economy |
| Runtime behavior class | Observability / read-model metadata; behavior-adjacent because scheduler and governor decision records gain metadata fields |
| Runtime proof | `BLOCKED_RUNTIME` |
| Follow-up safeguards | Function registration PR, CI wiring PR, and CIVSUB / Threat / IED reliability sweep |

---

## 3) Changed scope

| Path | Purpose |
|---|---|
| `functions/threat/fn_threatEconomyReasonMeta.sqf` | Adds stable reason-code metadata helper. |
| `functions/threat/fn_threatEconomyInit.sqf` | Seeds `threat_v0_economy_reason_taxonomy` and derives deny-reason enum from taxonomy. |
| `functions/threat/fn_threatGovernorCheck.sqf` | Returns `[allowed, reasonCode, reasonMeta]` while preserving the first two fields. |
| `functions/threat/fn_threatSchedulerTick.sqf` | Adds `reason_code` and `reason_meta` to allow/deny/warning decision records. |
| `functions/threat/fn_threatEconomySnapshotBuild.sqf` | Exposes `reasonTaxonomy`, enriched deny reason counts, and warning decision state. |
| `tests/static/threat_economy_reason_taxonomy_checks.sh` | Adds static contract checks for taxonomy observability. |

---

## 4) Acceptance criteria

- Threat Economy reason taxonomy includes allow, deny, warning, category, label, operator hint, and blocks-event metadata.
- Existing deny codes remain available through `threat_v0_economy_deny_reason_enum` and `denyReasonTaxonomy`.
- `ARC_fnc_threatGovernorCheck` keeps the first two return fields backward-compatible.
- Scheduler decision records carry stable `reason_code` and `reason_meta` fields.
- Threat economy snapshot exposes taxonomy and enriched denial-count observability.
- No budget thresholds, cooldown durations, escalation-tier gates, protected-zone gates, RemoteExec surface, persistence schema, scheduler cadence, or physical spawn behavior intentionally changes.

---

## 5) Validation status

| Check | Result | Notes |
|---|---|---|
| GitHub Actions preflight on PR head `391e562884460032a70a2668a2efe2d32a918294` | PASS | Existing workflow passed for the PR head. |
| New taxonomy test wired into CI | BLOCKED | Addressed by follow-up CI wiring PR. |
| Hosted MP runtime | BLOCKED_RUNTIME | Requires Arma runtime. |
| Dedicated/JIP runtime | BLOCKED_RUNTIME | Requires dedicated/JIP operator run. |
| CIVSUB / Threat / IED coupling proof | BLOCKED_RUNTIME | Must be executed through `docs/qa/CIVSUB_Threat_IED_Reliability_Sweep_2026-06-08.md`. |

---

## 6) Risk notes

- The change is observability-oriented but touches scheduler/governor decision record shape.
- Existing callers that use only the first two governor return fields remain compatible.
- `ARC_fnc_threatEconomyReasonMeta` must be registered in `CfgFunctions.hpp` so compile-audit and precompile paths see it.
- The taxonomy static test must be wired into `.github/workflows/arma-preflight.yml`.
- Runtime behavior is not validated by this backfill.

---

## 7) Rollback

Revert PR #613 if the reason taxonomy or decision-record metadata causes runtime or compatibility failures. If the issue is limited to operator surfaces, first remove the snapshot exposure fields while preserving existing deny-count state.
