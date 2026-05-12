# State Ownership Ledger

**Version:** 1.1
**Date:** 2026-05-08
**Status:** Active. Wave 2 / Wave 4-T1 deliverable of `docs/architecture/Architecture_Plan_2026-05-08.md`.
**Mode:** F — Documentation-Only Changes

---

## 1) Purpose

Architecture Plan §2.1 / §2.4 require every replicated `missionNamespace` key to have a single documented writer. This ledger is that document.

It is the canonical "who writes this variable?" reference. It MUST be updated in the same PR that introduces or relocates a writer for any `ARC_pub_*` key (or any other replicated mission variable owned by core).

A "writer" for the purposes of this ledger is any code path that calls `missionNamespace setVariable [<key>, _v, true]` (replicated form). Local writes (`true`-flag omitted) are noted only when relevant for cache/derivation.

This ledger does NOT cover:
- Per-object replicated state (`object setVariable [k, v, true]`) — covered in subsystem baselines.
- `uiNamespace` / client-local UI state.
- Server-internal scratch (`_v` only, not replicated).

---

## 2) Status legend

| Symbol | Meaning |
|---|---|
| ✅ | Single documented writer; no other write site found at audit time. |
| ⚠️ | Multiple writers, all server-owned and intentional (reset/init + steady-state publisher). Listed individually. |
| ❌ | Multiple writers with at least one non-authoritative or undocumented site. Remediation required. |

All writers in this ledger are required to be **server-side only**. Any client-side write to a replicated key is automatically a ❌.

---

## 3) Replicated key ledger

### 3.1 Core public state

| Key | Status | Writer(s) | Reset / init writer | Purpose |
|---|:---:|---|---|---|
| `ARC_pub_state` | ✅ | `functions/core/fn_statePublishPublic.sqf:51` | — | Authoritative public snapshot of core state. Cadence-gated. |
| `ARC_pub_stateUpdatedAt` | ✅ | `functions/core/fn_statePublishPublic.sqf:53` | — | Last-publish wall clock for `ARC_pub_state`. JIP freshness signal. |
| `ARC_pub_stateLastPublishMeta` | ✅ | `functions/core/fn_statePublishPublic.sqf:54` | — | `[source, now]` metadata for the last publish. Local (not replicated). |
| `ARC_pub_stateLastPublishSuppressed` | ✅ | `functions/core/fn_statePublishPublic.sqf:35,47` | — | Diagnostic-only; records suppressed-publish reason. Local. |
| `ARC_pub_stateSchema` | ✅ | `functions/core/fn_publicBroadcastState.sqf:1188` | — | Schema version banner for clients. |

### 3.2 Tasking / orders / queue

| Key | Status | Writer(s) | Reset / init writer | Purpose |
|---|:---:|---|---|---|
| `ARC_pub_orders` | ✅ | `functions/command/fn_intelOrderBroadcast.sqf:99` | — | Active orders snapshot for clients. |
| `ARC_pub_ordersUpdatedAt` | ✅ | `functions/command/fn_intelOrderBroadcast.sqf:100` | — | Freshness signal. |
| `ARC_pub_ordersMeta` | ✅ | `functions/command/fn_intelOrderBroadcast.sqf:101` | — | Snapshot meta (count, source). |
| `ARC_pub_queue` | ✅ | `functions/command/fn_intelQueueBroadcast.sqf:175` | — | Pending queue snapshot. |
| `ARC_pub_queuePending` | ✅ | `functions/command/fn_intelQueueBroadcast.sqf:176` | — | Same content as `ARC_pub_queue`; alias for migration period. |
| `ARC_pub_queueTail` | ✅ | `functions/command/fn_intelQueueBroadcast.sqf:177` | — | Bounded recent-decisions tail. |
| `ARC_pub_queueUpdatedAt` | ✅ | `functions/command/fn_intelQueueBroadcast.sqf:178` | — | Freshness signal. |
| `ARC_pub_queueMeta` | ✅ | `functions/command/fn_intelQueueBroadcast.sqf:179` | — | Snapshot meta. |

### 3.3 Intel / ops log

| Key | Status | Writer(s) | Reset / init writer | Purpose |
|---|:---:|---|---|---|
| `ARC_pub_intelLog` | ⚠️ | `functions/core/fn_intelBroadcast.sqf:26` | `functions/core/fn_resetAll.sqf:311` | Bounded intel-log slice. Reset clears, broadcaster updates. |
| `ARC_pub_opsLog` | ⚠️ | `functions/core/fn_intelBroadcast.sqf:27` | `functions/core/fn_resetAll.sqf:312` | Bounded ops-log slice. Reset clears, broadcaster updates. |
| `ARC_pub_intelUpdatedAt` | ⚠️ | `functions/core/fn_intelBroadcast.sqf:28` | `functions/core/fn_resetAll.sqf:313` | Freshness signal. |

### 3.4 Mission scoring

| Key | Status | Writer(s) | Reset / init writer | Purpose |
|---|:---:|---|---|---|
| `ARC_pub_missionScore` | ✅ | `functions/core/fn_missionScoreGenerate.sqf:173` | — | Mission scorecard snapshot. |
| `ARC_pub_missionScoreAt` | ✅ | `functions/core/fn_missionScoreGenerate.sqf:174` | — | Freshness signal. |

### 3.5 CASREQ / air ops

| Key | Status | Writer(s) | Reset / init writer | Purpose |
|---|:---:|---|---|---|
| `ARC_pub_casreqBundle` | ⚠️ | `functions/casreq/fn_casreqBroadcastDelta.sqf:45` | `functions/casreq/fn_casreqInitServer.sqf:37` | CASREQ delta bundle. Init seeds empty, broadcaster updates. |
| `ARC_pub_airbaseUiSnapshotRev` | ✅ | `functions/core/fn_publicBroadcastState.sqf:976` | — | Monotonic UI revision counter. **Server-local (no `true` flag) by design** — used to gate the replicated `ARC_pub_airbaseUiSnapshot` publish below. Listed here for naming-family completeness; not actually replicated. |
| `ARC_pub_airbaseUiSnapshot` | ✅ | `functions/core/fn_publicBroadcastState.sqf:977` | — | Airbase tab snapshot. |
| `ARC_pub_airbaseUiSnapshotUpdatedAt` | ✅ | `functions/core/fn_publicBroadcastState.sqf:978` | — | Freshness signal. |

### 3.6 Company command / unit status

| Key | Status | Writer(s) | Reset / init writer | Purpose |
|---|:---:|---|---|---|
| `ARC_pub_companyCommand` | ✅ | `functions/core/fn_publicBroadcastState.sqf:985` | — | Company-command snapshot. |
| `ARC_pub_companyCommandUpdatedAt` | ✅ | `functions/core/fn_publicBroadcastState.sqf:986` | — | Freshness signal. |
| `ARC_pub_unitStatuses` | ⚠️ | `functions/core/fn_tocRequestAcceptIncident.sqf:60`, `functions/core/fn_incidentMarkReadyToClose.sqf:60`, `functions/core/fn_incidentClose.sqf:398` | — | Unit status rows recomputed at incident lifecycle transitions. **Three writers, all server-owned, all incident-lifecycle.** Acceptable but worth a future single-writer extraction. |

### 3.7 Medical

| Key | Status | Writer(s) | Reset / init writer | Purpose |
|---|:---:|---|---|---|
| `ARC_pub_baseMed` | ✅ | `functions/medical/fn_medicalBroadcast.sqf:42` | — | Single-writer publisher invoked from both `fn_medicalTick.sqf` (slow recovery) and `fn_medicalOnCasualty.sqf` (immediate KIA drop). Clamps to [0, 1] before replication. S-OWN-2 resolved 2026-05-11. |

### 3.8 IED / EOD

| Key | Status | Writer(s) | Reset / init writer | Purpose |
|---|:---:|---|---|---|
| `ARC_pub_eodDispoApprovals` | ✅ | `functions/ied/fn_iedDispoBroadcast.sqf:37` | — | EOD disposition approvals. |
| `ARC_pub_eodDispoApprovalsUpdatedAt` | ✅ | `functions/ied/fn_iedDispoBroadcast.sqf:38` | — | Freshness signal. |

### 3.9 Debug / diagnostics (dev-profile only)

| Key | Status | Writer(s) | Reset / init writer | Purpose |
|---|:---:|---|---|---|
| `ARC_pub_debug` | ✅ | `functions/core/fn_publicBroadcastState.sqf:1175` | — | Debug snapshot; only emitted when `ARC_profile_devMode` is true. |
| `ARC_pub_debugUpdatedAt` | ✅ | `functions/core/fn_publicBroadcastState.sqf:1177` | — | Freshness signal. |

### 3.10 S1 (Section 1) registry

| Key | Status | Writer(s) | Reset / init writer | Purpose |
|---|:---:|---|---|---|
| `ARC_pub_s1_registry` | ✅ | `functions/core/fn_s1RegistrySnapshot.sqf:190` | — | Replicated S1 unit-roster snapshot. |
| `ARC_pub_s1_registryUpdatedAt` | ⚠️ | `functions/core/fn_s1RegistrySnapshot.sqf:191` | `functions/core/fn_s1RegistryInit.sqf:50`, `functions/core/fn_resetAll.sqf:342` | Freshness signal. Three writers, all server-owned and part of one registry lifecycle: init seeds `-1`, snapshot updates with `serverTime`, reset path resets to current `serverTime`. Acceptable for Phase 2 closure (multi-writer pattern matches S-OWN-1..3). Single-writer extraction tracked as S-OWN-4 (P2, non-blocking). |

---

## 3a) Subsystem-runtime replicated state (non-`ARC_pub_*`)

This section covers replicated `missionNamespace` keys outside the `ARC_pub_*` family that act as cross-machine subsystem state. They are intentionally replicated (clients read them for UI gating, AI behavior, or scheduler awareness) but are not part of the public-snapshot contract.

The bar is lower here than for `ARC_pub_*`: a single documented server writer per **logical group** is sufficient (e.g. `airbase_v1_runwayState/Owner/Until` are written from the same lock-state-machine). Multi-writer rows are acceptable when they belong to the same state machine; cross-subsystem writes are not.

### 3a.1 Airbase v1 runtime

| Key group | Status | Writer(s) | Purpose |
|---|:---:|---|---|
| `airbase_v1_*` configuration constants (`airbase_v1_opsStatusInterval_s`, `airbase_v1_controller_timeout_*`, `airbase_v1_arrival_*`, `airbase_v1_depart_*`, `airbase_v1_runwayReserveWindow_*`, `airbase_v1_runwayOccupyTimeout_*`, `airbase_v1_taxi_center_connectors`, `airbase_v1_inbound_taxi_markers`, `airbase_v1_diaryEnabled`, `airbase_v1_firstDepartureDelay*`, `airbase_v1_p_return`, `airbase_v1_fw_depart_*`, `airbase_v1_debug_forceAiOnly`) | ✅ | `functions/ambiance/fn_airbaseInit.sqf:29..292` | Tuning constants seeded at airbase init from `initServer.sqf`/`ARC_ConfigData.sqf`. Single writer (`airbaseInit`). |
| `airbase_v1_rt` | ⚠️ | `functions/ambiance/fn_airbaseInit.sqf:230,477,617`, `functions/ambiance/fn_airbaseAdminResetControlState.sqf:61`, `functions/ambiance/fn_airbaseSpawnArrival.sqf:230` | Airbase runtime hashmap. Multiple writers all in the airbase subsystem (init, admin reset, spawn-arrival side-effect). All server-owned. Future single-writer extraction is worth tracking (S-OWN-5). |
| `airbase_v1_execActive`, `airbase_v1_execFid` | ✅ | `functions/ambiance/fn_airbaseInit.sqf:478,479` (init) + airbase exec lifecycle | Runtime exec gating. Server-only. |
| `airbase_v1_runwayState`, `airbase_v1_runwayOwner`, `airbase_v1_runwayUntil` | ⚠️ | `functions/ambiance/fn_airbaseRunwayLockReserve.sqf:48..50`, `fn_airbaseRunwayLockOccupy.sqf:50..52`, `fn_airbaseRunwayLockRelease.sqf:47..49`, `fn_airbaseRunwayLockSweep.sqf:53..55`, `fn_airbaseAdminResetControlState.sqf:70..72`, `fn_airbaseInit.sqf:482..484` | Runway lock state machine. Three transitions (RESERVE / OCCUPY / RELEASE) plus init / admin-reset / sweep recovery — same state machine across multiple file boundaries. Acceptable but worth documenting as a single writer family. |
| `airbase_v1_lastTickAt`, `airbase_v1_bubble_active` | ✅ | `functions/ambiance/fn_airbaseTick.sqf:26,40` | Tick freshness + bubble flag. |

### 3a.2 CIVSUB v1 runtime

| Key group | Status | Writer(s) | Purpose |
|---|:---:|---|---|
| `civsub_v1_*` configuration constants (`civsub_v1_enabled`, `civsub_v1_persist`, `civsub_v1_seed`, `civsub_v1_tick_s`, `civsub_v1_version`, `civsub_v1_civs_enabled`, `civsub_v1_civ_tick_s`, `civsub_v1_civ_cap_*`, `civsub_v1_civ_minSeparation_m`, `civsub_v1_spawn_cache_locRadius_m`, `civsub_v1_civ_preferredFaction`, `civsub_v1_civ_classPool*`, `civsub_v1_scheduler_*`, `civsub_v1_rumor_enabled`, `civsub_v1_debug`, `civsub_v1_showPapers_forceCoop`, `civsub_v1_editorTestCivs*`) | ✅ | `initServer.sqf:199..257` (current home; relocation pending W7-T2) | Tuning constants seeded by mission init. Single writer (`initServer`). |
| `civsub_v1_traffic_*` configuration constants | ✅ | `initServer.sqf:291..430`, `functions/civsub/fn_civsubTrafficInit.sqf:19..93` | Tuning constants split between mission init and traffic init. Both are server-only and run once at boot; relocation pending W7-T2. |
| `civsub_v1_locnpc_*` configuration constants | ✅ | `initServer.sqf:437..` | Tuning constants for location NPC scheduler. |
| `civsub_v1_schedulerThreadRunning`, `civsub_v1_scheduler_lastTick_ts` | ⚠️ | `functions/civsub/fn_civsubSchedulerInit.sqf:15,24,34` | Thread-running flag set at start (true) and shutdown (false) by the same scheduler init function. Single writer-file. |
| `civsub_v1_traffic_threadRunning` | ✅ | `functions/civsub/fn_civsubTrafficInit.sqf:19,113` | Same pattern: start / shutdown in one file. |
| `civsub_v1_civs_enabled` | ⚠️ | `initServer.sqf:211` (init), `functions/civsub/fn_civsubCivSamplerStop.sqf:9` (stop) | Init seeds true; stop function disables. Two writers, both server-owned, one logical state machine. |
| `civsub_v1_civ_registry`, `civsub_v1_civ_despawnQueue`, `civsub_v1_civ_cleanup_last_ts` | ✅ | `functions/civsub/fn_civsubCivCleanupTick.sqf:74..76` (cleanup); `civsub_v1_civ_despawnQueue` also written by `fn_civsubCivSamplerStop.sqf:18` (drain on stop) | Civ-cleanup tick is the single steady-state writer; sampler-stop drains the queue at shutdown. Acceptable. |
| `civsub_v1_locnpc_registry` | ✅ | `functions/civsub/fn_civsubLocNpcTick.sqf:141` | Per-tick registry recompute. |
| `civsub_v1_lastSave_ts` | ✅ | `functions/civsub/fn_civsubPersistSave.sqf:157` | Persistence timestamp. |
| `civsub_v1_traffic_dbg_*` debug counters | ✅ | `initServer.sqf:426..430` (seeded) + traffic spawn paths (incremented) | Debug-only diagnostics; bounded counters reset on init. |

### 3a.3 CASREQ v1 runtime

| Key | Status | Writer(s) | Purpose |
|---|:---:|---|---|
| `casreq_v1_enabled`, `casreq_v1_schemaVersion`, `casreq_v1_idPattern` | ✅ | `functions/casreq/fn_casreqInitServer.sqf:11,16,19` | Subsystem identity / schema constants. Single writer (init). |

### 3a.4 Findings — non-`ARC_pub_*` runtime state

These rows do not block Phase 2 closure but are worth tracking so the ledger remains current.

| ID | Status | Description | Recommendation |
|---|:---:|---|---|
| S-OWN-4 | Open (P2, non-blocking) | `ARC_pub_s1_registryUpdatedAt` has three writers (init / snapshot / reset). All server-owned and part of the same registry lifecycle. Same pattern shape as S-OWN-1..3; does not block Phase 2 closure. | Funnel through a single `ARC_fnc_s1RegistryBroadcast` (or absorb the freshness write into `ARC_fnc_s1RegistrySnapshot`). |
| S-OWN-5 | Open (P3, non-blocking) | `airbase_v1_rt` runtime hashmap is written from five sites within the airbase subsystem. All server-owned and in-subsystem; no client-side writers. | Optional consolidation — extract a single `ARC_fnc_airbaseRtUpdate` helper used by all five sites. |
| S-OWN-6 | Open (P2, non-blocking) | Many `civsub_v1_*` and `airbase_v1_*` tuning constants currently live in `initServer.sqf` and are written with the replicated `true` flag even though clients only read them as constants. | Wave 7-T2 relocates these to `data/ARC_ConfigData.sqf` or subsystem `*Init` files. The replicated-flag itself is correct (clients do read them). |

---

## 4) Findings

| ID | Status | Description | Recommendation |
|---|:---:|---|---|
| S-OWN-1 | Open | `ARC_pub_unitStatuses` has three writer call-sites (incident accept / mark-ready / close). All are server-owned, but maintaining identical recompute logic in three places risks drift. | Extract a single `ARC_fnc_unitStatusBroadcast` publisher; the three call-sites invoke it. Defer to Wave 2 follow-on PR. |
| S-OWN-2 | Resolved 2026-05-11 | `ARC_pub_baseMed` had two writers (tick + casualty handler). | Resolved by introducing `ARC_fnc_medicalBroadcast` as the single publisher; both call-sites now route through it. |
| S-OWN-3 | Open | `ARC_pub_intelLog` / `ARC_pub_opsLog` have a steady-state writer (`intelBroadcast`) and a reset writer (`resetAll`). Acceptable pattern, but document explicitly so future writers do not creep in. | This ledger entry IS the documentation. Add a comment in `fn_intelBroadcast.sqf` referencing this file. |

None of the findings above are P1; the ledger has no ❌ entries on current head.

---

## 5) Update policy

This ledger MUST be updated when any of the following changes:

- A new `ARC_pub_*` key (or other replicated `missionNamespace` key owned by core) is added.
- The single writer for an existing key changes file or function.
- A second writer is introduced (must move from ✅ to ⚠️ with explicit justification).

Process:

1. Open the same PR that introduces the writer change.
2. Add or update the row in §3 with file:line citations.
3. If status moves from ✅ to ⚠️ or ❌, add an entry to §4 with remediation plan.
4. Bump §6 change log.

---

## 6) Change log

### v1.2 — 2026-05-11

- S-OWN-2 resolved: `ARC_pub_baseMed` now has a single writer (`ARC_fnc_medicalBroadcast`); both `medicalTick` and `medicalOnCasualty` route through the new publisher. §3.7 row updated from ⚠️ to ✅; §4 finding marked resolved.

### v1.1 — 2026-05-08

- Wave 4-T1 extension: §3.10 added for the S1 registry replicated keys (`ARC_pub_s1_registry`, `ARC_pub_s1_registryUpdatedAt`).
- Added new §3a covering subsystem-runtime replicated state outside the `ARC_pub_*` family (`airbase_v1_*`, `civsub_v1_*`, `casreq_v1_*`).
- Three new findings (S-OWN-4..6); none are blocking. S-OWN-6 is closed by Wave 7-T2 (config relocation), not by code changes inside this ledger.
- Truth-status: branch-local. Findings derived from current cloned working branch; not yet `origin/main`-confirmed per `Farabad_Source_of_Truth_and_Workflow_Spec.md`.
- Acceptance criterion (Wave 4-T1): every `ARC_pub_*` key reachable from `grep -n "setVariable .*true\]"` is now in §3 with a single writer or documented multi-writer rationale.

### v1.0 — 2026-05-08

- Initial issuance. Captures all 26 replicated `ARC_pub_*` keys discovered on current head.
- Three findings (S-OWN-1..3) recorded as open Wave 2 follow-ons; none are blocking.
- Linked from `docs/architecture/Architecture_Plan_2026-05-08.md` §2.1 / §2.4 acceptance criteria.
