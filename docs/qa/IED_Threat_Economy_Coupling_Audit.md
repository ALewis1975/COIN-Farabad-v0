# IED / Threat Economy Coupling Audit

**Date:** 2026-04-02
**Branch:** copilot/full-project-health-assessment
**Method:** Static grep-level analysis — no runtime required
**Scope:** Verify that `fn_threatGovernorCheck` gates are correctly connected to the IED, VBIED, and Suicide Bomber spawn paths, and that per-district attack budgets are consistently enforced.

---

## 1) Architecture Overview

The threat economy is organized in two independent layers:

### Layer A — Scheduling layer (`fn_threatSchedulerTick` → governor)

Called on a server tick interval (`ARC_threatSchedulerIntervalS`, default 120 s).

```
fn_bootstrapServer (line 827)
  └─ fn_threatSchedulerTick   [interval-gated; per-district loop]
       └─ fn_threatGovernorCheck(districtId, "IED", tier)
            ├─ GLOBAL_COOLDOWN check
            ├─ DISTRICT_COOLDOWN check
            ├─ BUDGET_EXHAUSTED check  (spent_today >= budget_points)
            ├─ ESCALATION_TIER check   (VBIED requires tier≥2, SUICIDE requires tier≥3)
            └─ CIVSUB GREEN score gate (budget bonus when G≥80)
       └─ fn_threatScheduleEvent(districtId, tier)  ← STUB (logs only; no spawn)
```

`fn_threatScheduleEvent` is a **logging stub** only. It does **not** spawn any world object or set incident state. The spawn ticks are wired separately.

### Layer B — Execution layer (`fn_execTickActive` → spawn ticks)

Called from the active-execution tick. Operates on the current active incident / objective kind.

```
fn_execTickActive (line 127–129)
  ├─ fn_iedSpawnTick          [gates: activeIncidentType=="IED" && objectiveKind=="IED_DEVICE"]
  ├─ fn_vbiedSpawnTick        [gates: activeIncidentType=="IED" && objectiveKind=="VBIED_VEHICLE"]
  └─ fn_suicideBomberSpawnTick [gates: objectiveKind in SB_*_APPROACH set]

fn_iedComplexAttackStage      [standalone; called from incident execution path]
fn_vbiedDrivenSpawnTick       [standalone; called from incident execution path]
```

---

## 2) Per-Spawn-Path Analysis

### 2.1 fn_iedSpawnTick

| Check | Present? | Details |
|---|---|---|
| `fn_threatGovernorCheck` call | ❌ No | Execution layer — intent is to act on an already-scheduled incident; governor not required at this layer |
| Active incident type gate | ✅ Yes | `activeIncidentType == "IED"` |
| Objective kind gate | ✅ Yes | `activeObjectiveKind == "IED_DEVICE"` |
| AO activation guard | ✅ Yes | `activeExecActivated == true` |
| Armed state guard | ✅ Yes | `activeObjectiveArmed == true` |
| Object presence guard | ✅ Yes | `objectFromNetId` null-checked |
| Per-call idempotency | ✅ Yes | Passive detect flag `ARC_objectiveDiscovered` prevents repeated discovery triggers |
| **Budget spend-down** | ❌ Not called | Budget is decremented only inside `fn_threatGovernorCheck` at scheduling time; execution layer does not decrement |

**Assessment:** Correct by design for the IED case. The IED execution tick operates on a device that was already authorized at scheduling time. Budget spend-down is absent because `fn_threatScheduleEvent` is still a stub (see Finding #1).

---

### 2.2 fn_vbiedSpawnTick

| Check | Present? | Details |
|---|---|---|
| `fn_threatGovernorCheck` call | ❌ No | Same intent as iedSpawnTick — execution layer |
| Active incident type gate | ✅ Yes | `activeIncidentType == "IED"` |
| Objective kind gate | ✅ Yes | `activeObjectiveKind == "VBIED_VEHICLE"` |
| Escalation tier requirement (tier≥2) | ⚠️ Partial | `ARC_vbiedCooldownSeconds` (default 1800 s) provides a cooldown, but does **not** check the escalation tier from the district risk model |
| Own cooldown gate | ✅ Yes | `activeVbiedLastArmedAt` checked against `ARC_vbiedCooldownSeconds` |
| Per-district budget | ❌ Not enforced | No budget check at this layer |

**Assessment:** The VBIED execution path has its own cooldown but bypasses the escalation-tier gate (tier≥2 required in governor). If a VBIED incident is created through a path that bypasses the scheduler (e.g., direct mission event), the tier requirement is not enforced at execution time. This gap is logged as **Finding #2**.

---

### 2.3 fn_suicideBomberSpawnTick

| Check | Present? | Details |
|---|---|---|
| `fn_threatGovernorCheck` call | ❌ No | Execution layer |
| Objective kind gate | ✅ Yes | `objectiveKind in ["SB_MARKET_APPROACH", "SB_CHECKPOINT_APPROACH", "SB_SHURA_APPROACH"]` |
| Escalation tier requirement (tier≥3) | ❌ No | Governor requires tier≥3, execution tick does not check |
| Fairness gate | ✅ Yes | No players within 200 m of approach path midpoint → EXPIRED |
| Per-district budget | ❌ Not enforced | No budget check at this layer |
| `ARC_suicideBomberEnabled` flag | ✅ Yes | |
| Idempotency | ✅ Yes | `ARC_suicideBomberSpawned` flag |

**Assessment:** Same pattern as VBIED. Execution-layer tier gates (tier≥3) and budget enforcement are absent. Logged as **Finding #3**.

---

### 2.4 fn_vbiedDrivenSpawnTick

Referenced in `fn_threatScheduleEvent` stub comment. No direct call found in `fn_execTickActive` in the current codebase.

**Assessment:** Path is documented in the stub but not yet wired into the active execution tick. Logged as **Finding #4**.

---

## 3) Budget Spend-Down Analysis

The governor maintains `threat_v0_attack_budget[districtId].spent_today` and gates new events when `spent_today >= budget_points`. **However**, `spent_today` is only incremented by the governor's caller in `fn_threatSchedulerTick` (which calls the governor and would decrement budget on allow).

Tracing the scheduler code:

```sqf
// fn_threatSchedulerTick line 76–80:
private _govResult = [_districtId, "IED", _tier] call ARC_fnc_threatGovernorCheck;
private _allowed   = _govResult select 0;
if (_allowed) then {
    [_districtId, _tier] call ARC_fnc_threatScheduleEvent;  // stub — no budget write
    ...
```

`fn_threatGovernorCheck` checks `spent_today >= budget_points` but does **not** increment `spent_today` itself (the governor is read-only). Incrementing `spent_today` would need to happen in `fn_threatSchedulerTick` after a successful governor pass, or inside `fn_threatScheduleEvent`.

**Finding #5:** `threat_v0_attack_budget[districtId].spent_today` is never incremented in the current code. The budget gate is enforced read-only only; once the scheduler clears a district, no counter advances. The budget will always return `spent_today = 0 < budget_points` until this is wired.

---

## 4) CIVSUB GREEN Score Gate

`fn_threatGovernorCheck` reads `civsub_v1_districts[districtId].G` and applies a budget bonus (+5 pts, capped at 10) when `G >= 80` and `tier < 2`. This write goes to `threat_v0_attack_budget` state via `ARC_fnc_stateSet`, which is correct (server-only write). The CIVSUB read is read-only (no district state mutation). ✅

---

## 5) Summary of Findings

| # | Finding | Severity | Layer | Status |
|---|---|---|---|---|
| F1 | `fn_threatScheduleEvent` is a stub (logs only; no world spawn or state change) | P2 | Scheduling | **OPEN** — spawn ticks are wired separately; stub must be expanded to write a threat record or the two-layer design must be formally documented as the intent |
| F2 | VBIED execution path does not enforce escalation-tier gate (tier≥2) at spawn time | P2 | Execution | **OPEN** — if VBIED incident bypasses scheduler, tier not enforced |
| F3 | Suicide Bomber execution path does not enforce escalation-tier gate (tier≥3) at spawn time | P2 | Execution | **OPEN** — same gap as F2 |
| F4 | `fn_vbiedDrivenSpawnTick` is referenced in stub but not found in active execution wiring (`fn_execTickActive`) | P2 | Execution | **OPEN** — path may be missing or not yet activated |
| F5 | `threat_v0_attack_budget[districtId].spent_today` never incremented — budget gate is effectively disabled | P1 | Scheduling | **OPEN** — budget counter must be incremented in `fn_threatSchedulerTick` after allow, or in `fn_threatScheduleEvent` when expanded |

---

## 6) Recommended Fixes (in order)

### Fix F5 (P1) — Wire budget spend-down in fn_threatSchedulerTick

After `fn_threatScheduleEvent` returns `true`, increment `spent_today` for the district:

```sqf
// In fn_threatSchedulerTick, after the _allowed branch:
if (_allowed) then {
    [_districtId, _tier] call ARC_fnc_threatScheduleEvent;

    // Consume one budget point for this district
    private _budgetMap = ["threat_v0_attack_budget", createHashMap] call ARC_fnc_stateGet;
    if (!(_budgetMap isEqualType createHashMap)) then { _budgetMap = createHashMap; };
    private _bEntry = [_budgetMap, _districtId, createHashMap] call _hg;
    if (!(_bEntry isEqualType createHashMap)) then { _bEntry = createHashMap; };
    private _spent = [_bEntry, "spent_today", 0] call _hg;
    if (!(_spent isEqualType 0)) then { _spent = 0; };
    _bEntry set ["spent_today", _spent + 1];
    _budgetMap set [_districtId, _bEntry];
    ["threat_v0_attack_budget", _budgetMap] call ARC_fnc_stateSet;

    _scheduledAny = true;
};
```

### Fix F1 (P2) — Document or implement fn_threatScheduleEvent

Option A: Expand the stub to write a threat record to `threat_v0_records` state (linking district + tier), which the spawn ticks can consume when an appropriate incident is active.

Option B: Document formally that the two-layer model is intentional — the scheduler approves via the governor and logs intent, and the spawn ticks use independent logic (active incident + objective kind) with their own guards. If option B, add an explicit note in `fn_threatScheduleEvent` to that effect and ensure F5 is resolved.

### Fixes F2 / F3 (P2) — Add escalation-tier guards in VBIED and Suicide Bomber spawn ticks

Add a district-risk read and tier check at the top of each spawn tick:

```sqf
// fn_vbiedSpawnTick and fn_suicideBomberSpawnTick:
private _districtId = ["activeIncidentCivsubDistrictId", ""] call ARC_fnc_stateGet;
if (!(_districtId isEqualTo "")) then {
    private _secLevel = missionNamespace getVariable [format ["ARC_district_%1_secLevel", _districtId], "NORMAL"];
    private _tier = 0;
    if (_secLevel isEqualTo "ELEVATED") then { _tier = 1; };
    if (_secLevel isEqualTo "HIGH_RISK") then { _tier = 2; };
    // VBIED requires tier >= 2; SUICIDE requires tier >= 3
    if (_tier < 2) exitWith { false }; // adjust threshold per type
};
```

### Fix F4 (P2) — Wire fn_vbiedDrivenSpawnTick

Verify whether `fn_vbiedDrivenSpawnTick` should be called from `fn_execTickActive` alongside the other spawn ticks. If yes, add the call behind the `ARC_vbiedDrivenEnabled` flag.

---

## 7) Validation Checklist (static)

- [x] `fn_threatGovernorCheck` called in `fn_threatSchedulerTick` (confirmed line 76)
- [x] Governor checks: global cooldown, district cooldown, budget, escalation tier, CIVSUB GREEN gate
- [x] `fn_iedSpawnTick` gated by incident type + objective kind + AO activation (no governor required)
- [x] `fn_vbiedSpawnTick` has own cooldown (ARC_vbiedCooldownSeconds), but no tier check
- [x] `fn_suicideBomberSpawnTick` has fairness gate (no players near path), but no tier check
- [ ] `spent_today` increment after successful schedule (F5 — NOT PRESENT)
- [ ] `fn_vbiedDrivenSpawnTick` wired into execution tick (F4 — NOT CONFIRMED)

---

## 8) Runtime Checks (BLOCKED)

The following require a dedicated server session to validate:

- Attack budget exhaustion behavior after multiple incidents in one district in one session
- District cooldown reset behavior after server restart / schema migration
- Escalation tier transitions from NORMAL → ELEVATED → HIGH_RISK in live play
- CIVSUB GREEN score gate effect on budget under live CIVSUB traffic
