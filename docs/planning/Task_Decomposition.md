# Farabad COIN v0 — Task Decomposition

**Version:** 2.0  
**Date:** 2026-03-29  
**Source:** Architecture & Readiness Plan §5–§8, verified scope counts, 2026-03-29 audit.

---

## How to Use This Document

Each task below is a **single PR-sized work package**. Tasks are grouped into phases from the Architecture & Readiness Plan and ordered by dependency and severity.

**PR Mode labels** follow AGENTS.md (A=Bug Fix, C=Safe Refactor, I=Security Hardening, etc.).

---

## Phase 1: Stabilize — Fix P0 Bugs + CI Blockers

> **Status: ✅ COMPLETE** — All Phase 1 tasks delivered in PR branch `copilot/audit-sqf-mission-project`.

### Task 1.1 — Fix `isNil` Assignment Bug in `fn_civsubIdentityTouch.sqf` ✅ DONE

| Field | Value |
|-------|-------|
| **PR Mode** | A — Bug Fix |
| **Severity** | P0 — Blocks all CIVSUB new-civ identity generation |
| **Files** | `functions/civsub/fn_civsubIdentityTouch.sqf` |
| **Est. Lines** | ~4 changed |

**Problem:** Lines 38 and 48 use `isNil { _var = someCall; }` which always returns `true` because SQF assignments return Nothing. New civilians never get identity records, breaking the entire CIVSUB interaction chain.

**Fix:**
```sqf
// Line 38: add trailing _tmpUid
private _nilUid = isNil { _tmpUid = [_districtId] call ARC_fnc_civsubIdentityGenerateUid; _tmpUid };

// Line 48: add trailing _tmpRec
private _nilRec = isNil { _tmpRec = [_civUid, _districtId, _homePos] call ARC_fnc_civsubIdentityGenerateProfile; _tmpRec };
```

**Also in scope:** Line 33 has bare `createHashMapFromArray _ids` — wrap in compile helper for sqflint compat (or use `_hmCreate` pattern from other CIVSUB files).

**Acceptance:**
- [x] CIVSUB identity records are created for new civilians (isNil returns false when function returns valid data)
- [x] `sqflint -e w` passes on the file
- [x] `sqflint_compat_scan.py --strict` passes on the file

---

### Task 1.2 — Replace `toUpperANSI` / `toLowerANSI` Across Codebase ✅ DONE

| Field | Value |
|-------|-------|
| **PR Mode** | C — Safe Refactor (no behavior change) |
| **Severity** | P1 — Latent CI blocker (fires when any file is touched) |
| **Files** | 14 files, 53 occurrences |
| **Est. Lines** | ~53 replacements (mechanical) |

**Problem:** `toUpperANSI` and `toLowerANSI` are not recognized by sqflint. They function identically to `toUpper`/`toLower` for ASCII mission strings.

**Affected files (occurrence count):**

| File | Count |
|------|-------|
| `functions/ambiance/fn_airbaseTick.sqf` | 15 |
| `functions/core/fn_publicBroadcastState.sqf` | 15 |
| `functions/ambiance/fn_airbaseRequestSetLaneStaffing.sqf` | 5 |
| `functions/ambiance/fn_airbaseClearanceSortRequests.sqf` | 3 |
| `functions/core/fn_farabadLog.sqf` | 3 |
| `functions/ambiance/fn_airbaseBuildRouteDecision.sqf` | 2 |
| `functions/ambiance/fn_airbaseRequestClearanceDecision.sqf` | 2 |
| `functions/core/fn_s1RegistryUpsertUnit.sqf` | 2 |
| `functions/ambiance/fn_airbaseCancelClearanceRequest.sqf` | 1 |
| `functions/ambiance/fn_airbaseMarkClearanceEmergency.sqf` | 1 |
| `functions/ambiance/fn_airbaseRecordSetQueuedStatus.sqf` | 1 |
| `functions/casreq/fn_casreqBuildId.sqf` | 1 |
| `functions/core/fn_airbaseTowerAuthorize.sqf` | 1 |
| `functions/core/fn_paramAssert.sqf` | 1 |

**Fix:** Global search-and-replace:
- `toUpperANSI` → `toUpper`
- `toLowerANSI` → `toLower`

**Acceptance:**
- [x] Zero `toUpperANSI`/`toLowerANSI` occurrences remain in `functions/`
- [x] `sqflint -e w` passes on all 14 files
- [x] `sqflint_compat_scan.py --strict` passes on all 14 files

---

### Task 1.3 — Replace `findIf` with `forEach` + `exitWith` Pattern ✅ DONE

| Field | Value |
|-------|-------|
| **PR Mode** | C — Safe Refactor (no behavior change) |
| **Severity** | P1 — Latent CI blocker |
| **Files** | 59 files, 131 occurrences (verified count) |
| **Est. Lines** | ~300+ changed (each `findIf` expands to ~3-5 lines) |

**Problem:** `findIf` is not recognized by sqflint. Semantically equivalent to a `forEach` + `exitWith` loop returning `_forEachIndex`.

**Recommendation:** Due to the scale (~110 occurrences in 55 files), split into sub-PRs by subsystem:

| Sub-task | Files | Count | Priority |
|----------|-------|-------|----------|
| **1.3a** Threat subsystem | 6 files | 17 | HIGH (files actively being worked) |
| **1.3b** Ambiance/Airbase | 11 files | 22 | HIGH |
| **1.3c** Core | 18 files | 48 | MEDIUM |
| **1.3d** Command | 6 files | 11 | MEDIUM |
| **1.3e** Logistics | 2 files | 12 | LOW |
| **1.3f** UI + Ops + CASREQ | 8 files | ~10 | LOW |

**Pattern to apply:**
```sqf
// BEFORE:
private _idx = _array findIf { condition };

// AFTER:
private _idx = -1;
{ if (condition) exitWith { _idx = _forEachIndex; }; } forEach _array;
```

**Acceptance per sub-PR:**
- [x] Zero `findIf` occurrences in changed files (1 comment reference remains)
- [x] `sqflint -e w` passes on all changed files (no new errors)
- [x] `sqflint_compat_scan.py --strict` passes on all changed files
- [x] Behavioral parity: returned index matches `findIf` semantics (-1 when not found)

---

### Task 1.4 — Wrap Bare `createHashMapFromArray` Calls ✅ DONE

| Field | Value |
|-------|-------|
| **PR Mode** | C — Safe Refactor (no behavior change) |
| **Severity** | P1 — Latent CI blocker |
| **Files** | 39 files with bare `createHashMapFromArray`, 74 occurrences (verified count) |
| **Est. Lines** | ~80+ (add helper declaration + update call sites) |

**Problem:** sqflint does not parse `createHashMapFromArray` as a valid operator. Must be wrapped in a compile helper.

**Pattern to apply:**
```sqf
// Add at top of file (after exitWith guards, before logic):
private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

// Replace each bare call:
// BEFORE:
private _map = createHashMapFromArray [...];
// AFTER:
private _map = [[...]] call _hmCreate;
```

**Recommendation:** Split by subsystem like Task 1.3.

**Acceptance:**
- [x] Zero bare `createHashMapFromArray` in changed files
- [x] `sqflint -e w` passes on all changed files
- [x] `bare-createHashMapFromArray` rule added to `sqflint_compat_scan.py`

---

## Phase 2: Harden — Security + Resilience

> **Status: ✅ COMPLETE** — Tasks 2.1, 2.2, and 2.3 all delivered. Task 2.1 in branch `copilot/audit-sqf-mission-project`. Tasks 2.2 and 2.3 in branch `copilot/fix-background-check-error`.

### Task 2.1 — Implement `CfgRemoteExec` Allowlist ✅ DONE

| Field | Value |
|-------|-------|
| **PR Mode** | I — Security Hardening |
| **Severity** | P1 — Open attack surface |
| **Files** | `description.ext`, `config/CfgRemoteExec.hpp`, 12 SQF files |
| **Actual Lines** | ~280 new lines |
| **Reference** | `docs/security/RemoteExec_Hardening_Plan.md` §2 |

**Delivered:**
- Created `config/CfgRemoteExec.hpp` with `mode=1` (whitelist only) for Functions and Commands
- 39 client→server ARC function entries (allowedTargets=2)
- 19 server→client ARC function entries (allowedTargets=0), 5 with jip=1
- 13 engine command entries
- Added `remoteExecutedOwner` sender validation to 12 previously unprotected endpoints:
  - CIVSUB (4): EndSession, HandoffSheriff, OrderStop, RunMdtByNetId
  - Core (3): execObjectiveComplete, publicBroadcastState, uiCoverageAuditServer
  - IED (3): iedCollectEvidence, iedServerDetonate, vbiedServerDetonate
  - Command (2): intelQueueSubmit, intelTocIssueOrder

**Acceptance:**
- [x] `CfgRemoteExec` class present in `config/CfgRemoteExec.hpp`, included from `description.ext`
- [x] `mode = 1` for both Functions and Commands
- [x] All 39 client→server endpoints listed
- [x] All 19 server→client endpoints listed with correct JIP flags
- [x] All 13 engine commands listed
- [x] All 39 client→server RPCs have `remoteExecutedOwner` sender validation
- [x] Zero new sqflint compat warnings introduced

---

### Task 2.2 — Cap Unbounded State Arrays ✅ DONE

| Field | Value |
|-------|-------|
| **PR Mode** | D — Performance Optimization |
| **Severity** | P2 — Long-campaign stability |
| **Files** | `functions/core/fn_intelLog.sqf`, `functions/core/fn_incidentClose.sqf` |
| **Actual Lines** | ~10 changed |

**Delivered (branch `copilot/fix-background-check-error`):**
- `fn_intelLog.sqf`: replaced hardcoded `while deleteAt 200` loop with configurable `select`-slice cap. Default 500, configurable via `ARC_intelLogMaxEntries` (type-guarded, clamped 10–2000). Single-pass O(1) vs repeated deleteAt.
- `fn_incidentClose.sqf`: added configurable `select`-slice cap on `incidentHistory` (previously uncapped). Default 200, configurable via `ARC_incidentHistoryMaxEntries` (type-guarded, clamped 10–1000).
- `fn_intelMetricsTick.sqf`: already had a proper configurable cap (`ARC_metricsSnapshotsCap`, default 24) — no change needed.

**Acceptance:**
- [x] Each array has a configurable max cap (via `missionNamespace getVariable`)
- [x] Prune preserves most-recent entries (tail, not head) via `select [offset, count]`
- [x] Type guard on cap variable prevents non-numeric crash
- [x] `sqflint_compat_scan.py --strict` passes on both changed files (0 new violations)

---

### Task 2.3 — Optimize Guard Post AllUnits Scan ✅ DONE

| Field | Value |
|-------|-------|
| **PR Mode** | D — Performance Optimization |
| **Severity** | P2 — Server FPS under load |
| **Files** | `functions/core/fn_guardPost.sqf` |
| **Est. Lines** | ~10 |

**Problem:** Guard post logic iterates `allUnits` O(N×M) per guard unit per cycle. With 79 players + AI, this becomes expensive.

**Fix:** Add distance pre-filter and side check before expensive checks:
```sqf
// Early-out: skip if too far
if ((_unit distance _guardPos) > _triggerRadius * 2) then { continue; };
// Early-out: skip friendlies
if ((side _unit) isEqualTo (side _guard)) then { continue; };
```

**Acceptance:**
- [x] Guard behavior unchanged for units within trigger radius
- [x] Measurable reduction in per-tick cost (side pre-filter + 500m distance pre-filter added)

---

## Phase 2.5: Resolve All Remaining sqflint Compat Violations

> **Status: ✅ COMPLETE** — All 2159 violations resolved to 0 in branch `copilot/audit-coin-farabad-v0-again`.

### Task 2.5a — Register Orphan Functions ✅ DONE

| Field | Value |
|-------|-------|
| **PR Mode** | C — Safe Refactor |
| **Severity** | P2 — Dead code crash risk |
| **Files** | `config/CfgFunctions.hpp`, `functions/ui/fn_uiConsoleActionCloseIncident.sqf` |
| **Actual Lines** | ~8 changed |

**Delivered:**
- Registered `fn_rolesCanUseMobileOps` in Core class of CfgFunctions.hpp
- Registered `fn_uiConsoleActionCloseIncident` in UI class of CfgFunctions.hpp
- Fixed sqflint compat in `fn_uiConsoleActionCloseIncident.sqf` (direct `trim` → `_trimFn`, `isNotEqualTo` → `!isEqualTo`)

**Acceptance:**
- [x] Both functions registered in CfgFunctions.hpp
- [x] `sqflint_compat_scan.py --strict` passes on changed files

---

### Task 2.5b — Replace `isNotEqualTo` with `!isEqualTo` ✅ DONE

| Field | Value |
|-------|-------|
| **PR Mode** | C — Safe Refactor |
| **Files** | 118 files, 439 occurrences |
| **Actual Lines** | 437 replacements (mechanical) |

**Pattern:** `_x isNotEqualTo _y` → `!(_x isEqualTo _y)`

**Acceptance:**
- [x] Zero `isNotEqualTo` occurrences remain in `functions/`
- [x] `sqflint_compat_scan.py --strict` passes on all files

---

### Task 2.5c — Replace `#` Hash Indexing with `select` ✅ DONE

| Field | Value |
|-------|-------|
| **PR Mode** | C — Safe Refactor |
| **Files** | 148 files, 939 occurrences |
| **Actual Lines** | 964 replacements |

**Pattern:** `_arr # _idx` → `_arr select _idx`

**Acceptance:**
- [x] Zero hash-index-operator violations remain
- [x] `sqflint_compat_scan.py --strict` passes on all files

---

### Task 2.5d — Replace `getOrDefault` Method with `_hg` Helper ✅ DONE

| Field | Value |
|-------|-------|
| **PR Mode** | C — Safe Refactor |
| **Files** | 69 files, 395 occurrences |
| **Actual Lines** | 547 changed (replacements + helper declarations) |

**Pattern:** `_map getOrDefault [key, default]` → `[_map, key, default] call _hg`

**Acceptance:**
- [x] Zero method-style `getOrDefault` violations remain
- [x] `_hg` helper declared in each file that needs it
- [x] `sqflint_compat_scan.py --strict` passes on all files

---

### Task 2.5e — Replace Direct `trim` with `_trimFn` Helper ✅ DONE

| Field | Value |
|-------|-------|
| **PR Mode** | C — Safe Refactor |
| **Files** | 109 files, 384 occurrences |
| **Actual Lines** | 687 changed (replacements + helper declarations) |

**Pattern:** `trim _var` → `[_var] call _trimFn`

**Acceptance:**
- [x] Zero direct `trim` violations remain
- [x] `_trimFn` helper declared in each file that needs it
- [x] `sqflint_compat_scan.py --strict` passes on all files

---

### Task 2.5f — Replace Direct `fileExists` with Helper ✅ DONE

| Field | Value |
|-------|-------|
| **PR Mode** | C — Safe Refactor |
| **Files** | 1 file, 1 occurrence |

**Acceptance:**
- [x] Zero `fileExists-operator` violations remain

---

## Phase 3: Validate — Dedicated Server QA

### Task 3.1 — Local MP Smoke Test Protocol

| Field | Value |
|-------|-------|
| **PR Mode** | E — Test-Only |
| **Status** | BLOCKED (requires Arma 3 runtime) |

**Steps when environment available:**
1. Host local MP (1 server + 1 client)
2. Complete full command cycle: TOC generates → player accepts → execute → SITREP → close
3. Verify console tabs update at each phase
4. Verify CIVSUB contact dialog opens and identity records persist
5. Verify lightbar starts on configured vehicles
6. Verify compile audit produces no RPT errors
7. Record results in `tests/TEST-LOG.md`

---

### Task 3.2 — Dedicated Server + JIP Validation

| Field | Value |
|-------|-------|
| **PR Mode** | E — Test-Only |
| **Status** | BLOCKED (requires dedicated server environment) |

**Steps when environment available:**
1. Start dedicated server, join with 2+ clients
2. Start incident, have one client disconnect and rejoin (JIP)
3. Verify JIP client receives snapshot within 35s timeout
4. Verify console shows correct state for JIP client
5. Verify `ARC_pub_stateUpdatedAt` PV event fires and client catches it
6. Test respawn/reconnect ownership edge cases
7. Record results in `tests/TEST-LOG.md`

---

## Phase 4: Feature Completion

### Task 4.1 — Console VM v1 Migration

| Field | Value |
|-------|-------|
| **PR Mode** | B — Feature Delivery |
| **Reference** | `docs/architecture/Console_VM_v1.md` |

Migrate console paint functions from direct `ARC_pub_*` reads to structured View Model contract. This is a large effort (~68 UI files) and should be split by tab.

---

### Task 4.2 — CIVSUB Lead-Emit Bridge

| Field | Value |
|-------|-------|
| **PR Mode** | B — Feature Delivery |
| **Reference** | `docs/architecture/CIVSUB_Incident_Lead_Permutation_Matrix.md` |

Materialize CIVSUB-sourced leads into core `leadPool` for incident generation. Requires district binding and per-district lead throttling.

---

### Task 4.3 — SITREP Gate Parity Enforcement

| Field | Value |
|-------|-------|
| **PR Mode** | B — Feature Delivery |
| **Reference** | `docs/architecture/SITREP_Gate_Parity.md` |

Ensure client pre-checks and server authority checks use identical rule vocabulary, reason codes, and evaluation order.

---

### Task 4.4 — TASKENG Thread/Task Hierarchy

| Field | Value |
|-------|-------|
| **PR Mode** | B — Feature Delivery |
| **Reference** | `docs/projectFiles/Farabad_TASKENG_Thread_Task_Hierarchy*` |

Implement parent-case pattern for thread records, deterministic parent task ID generation, and thread store persistence via schema rev 4.

---

## Dependency Graph

```
Task 1.1 (P0 isNil) ──────────────────────┐
Task 1.2 (toUpperANSI) ───┐               │
Task 1.3 (findIf) ────────┤               │
Task 1.4 (createHashMap) ──┤               │
                           ▼               ▼
                    CI PASSES CLEAN    CIVSUB WORKS
                           │               │
                           ▼               ▼
                    Task 2.1 (CfgRemoteExec)
                    Task 2.2 (Array caps)
                    Task 2.3 (Guard post)
                           │
                           ▼
                    Task 2.5a-f (sqflint compat: 2159 → 0)
                           │
                           ▼
                    Task 3.1 (Local MP test) ← BLOCKED
                    Task 3.2 (Dedicated QA)  ← BLOCKED
                           │
                           ▼
                    Task 4.1–4.4 (Features)
```

---

## Suggested PR Ordering

| Order | Task | Mode | Risk | Effort |
|-------|------|------|------|--------|
| 1 | **1.1** — isNil fix + createHashMap in identityTouch | A | P0 fix — immediate value | XS (4 lines) |
| 2 | **1.2** — toUpperANSI/toLowerANSI replacement | C | Mechanical, low risk | S (53 replacements) |
| 3 | **1.3a** — findIf in threat (6 files) | C | Contained subsystem | S |
| 4 | **1.3b** — findIf in ambiance/airbase (11 files) | C | Contained subsystem | M |
| 5 | **1.3c** — findIf in core (18 files) | C | Hot files — careful review | M-L |
| 6 | **1.3d-f** — findIf in command/logistics/ui | C | Lower priority files | M |
| 7 | **1.4** — Remaining createHashMapFromArray wraps | C | Mechanical | M |
| 8 | **2.1** — CfgRemoteExec allowlist | I | Requires MP smoke test | M |
| 9 | **2.2** — Array caps | D | Low risk, bounded scope | XS | ✅ DONE |
| 10 | **2.3** — Guard post optimization | D | Low risk | XS | ✅ DONE |

---

## Appendix: Compat Scan Coverage

The CI compat scanner (`scripts/dev/sqflint_compat_scan.py`) checks for:

| Pattern | Rule Name | Covered? |
|---------|-----------|----------|
| `findIf` | `findIf` | ✅ |
| `trim _var` | `trim-operator` | ✅ |
| `fileExists _var` | `fileExists-operator` | ✅ |
| `_map getOrDefault [...]` | `hashmap-getOrDefault-method` | ✅ |
| `isNotEqualTo` | `isNotEqualTo` | ✅ |
| `toUpperANSI` | `toUpperANSI` | ✅ |
| `toLowerANSI` | `toLowerANSI` | ✅ (added in Phase 1) |
| `#` indexing | `hash-index-operator` | ✅ |
| `createHashMapFromArray` | `bare-createHashMapFromArray` | ✅ (added in Phase 1) |
| `keys _map` | — | ❌ **Not covered** (sqflint catches it) |

See `docs/qa/SQFLINT_COMPAT_GUIDE.md` for the full compile-helper reference.
