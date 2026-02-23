# Farabad COIN v0 — Task Decomposition

**Version:** 1.0  
**Date:** 2026-02-23  
**Source:** Architecture & Readiness Plan §5–§8, verified scope counts.

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

### Task 2.1 — Implement `CfgRemoteExec` Allowlist

| Field | Value |
|-------|-------|
| **PR Mode** | I — Security Hardening |
| **Severity** | P1 — Open attack surface |
| **Files** | `description.ext` |
| **Est. Lines** | ~80 new lines |
| **Reference** | `docs/security/RemoteExec_Hardening_Plan.md` §2 |

**Problem:** No `CfgRemoteExec` in `description.ext`. Engine runs in default permissive mode — any connected client can invoke any function via `remoteExec`.

**Fix:** Add `CfgRemoteExec` class with:
- 33 client→server ARC function allowlist entries
- 17 server→client ARC function allowlist entries (with JIP flags per plan)
- 13 engine command allowlist entries
- `mode = 1` (whitelist only) for both Functions and Commands classes

**Pre-requisites:** Must smoke-test in local MP — a missing allowlist entry silently blocks functionality.

**Acceptance:**
- [ ] `CfgRemoteExec` class present in `description.ext`
- [ ] `mode = 1` for both Functions and Commands
- [ ] All 33 client→server endpoints listed
- [ ] All 17 server→client endpoints listed with correct JIP flags
- [ ] All 13 engine commands listed
- [ ] Config sanity check passes

---

### Task 2.2 — Cap Unbounded State Arrays

| Field | Value |
|-------|-------|
| **PR Mode** | D — Performance Optimization |
| **Severity** | P2 — Long-campaign stability |
| **Files** | `functions/core/fn_intelLog.sqf`, `functions/core/fn_incidentClose.sqf`, or dedicated pruner |
| **Est. Lines** | ~15 |

**Problem:** `intelLog`, `incidentHistory`, and `metricsSnapshots` arrays grow without bound in `ARC_state`. Over a long campaign, `stateSave`/`stateLoad` serialization could hit `missionProfileNamespace` size limits.

**Fix:** Add prune-on-write after each push:
```sqf
// Example for intelLog (cap at 500 entries):
private _log = ["intelLog", []] call ARC_fnc_stateGet;
_log pushBack _entry;
private _max = missionNamespace getVariable ["ARC_intelLogMaxEntries", 500];
if ((count _log) > _max) then { _log = _log select [((count _log) - _max), _max]; };
["intelLog", _log] call ARC_fnc_stateSet;
```

**Suggested caps:**
| Array | Max | Rationale |
|-------|-----|-----------|
| `intelLog` | 500 | ~8 hours at typical intel rate |
| `incidentHistory` | 200 | ~8 hours at 60s incident cadence |
| `metricsSnapshots` | 100 | Public broadcast already tails to 8 |

**Acceptance:**
- [ ] Each array has a configurable max cap
- [ ] Prune preserves most recent entries (tail, not head)
- [ ] `stateSave` succeeds after cap enforcement

---

### Task 2.3 — Optimize Guard Post AllUnits Scan

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
- [ ] Guard behavior unchanged for units within trigger radius
- [ ] Measurable reduction in per-tick cost (diag_log timing comparison)

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
| 9 | **2.2** — Array caps | D | Low risk, bounded scope | XS |
| 10 | **2.3** — Guard post optimization | D | Low risk | XS |

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
| `#` indexing | `hash-index-operator` | ✅ |
| `toLowerANSI` | — | ❌ **Not covered** (add rule) |
| `createHashMapFromArray` | — | ❌ **Not covered** (sqflint catches it) |
| `keys _map` | — | ❌ **Not covered** (sqflint catches it) |

**Note:** Consider adding `toLowerANSI` and optionally `createHashMapFromArray` / `keys` rules to the compat scanner for earlier detection.
