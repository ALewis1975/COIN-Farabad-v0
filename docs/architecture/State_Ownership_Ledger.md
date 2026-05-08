# State Ownership Ledger

**Version:** 1.0
**Date:** 2026-05-08
**Status:** Active. Wave 2 deliverable of `docs/architecture/Architecture_Plan_2026-05-08.md`.
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
| `ARC_pub_baseMed` | ⚠️ | `functions/medical/fn_medicalTick.sqf:37`, `functions/medical/fn_medicalOnCasualty.sqf:56` | — | Two writers: tick recomputes; casualty handler updates immediately. **Both server-owned and intentional**, but a single publisher (e.g. `ARC_fnc_medicalBroadcast`) called from both sites would simplify ownership. |

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

---

## 4) Findings

| ID | Status | Description | Recommendation |
|---|:---:|---|---|
| S-OWN-1 | Open | `ARC_pub_unitStatuses` has three writer call-sites (incident accept / mark-ready / close). All are server-owned, but maintaining identical recompute logic in three places risks drift. | Extract a single `ARC_fnc_unitStatusBroadcast` publisher; the three call-sites invoke it. Defer to Wave 2 follow-on PR. |
| S-OWN-2 | Open | `ARC_pub_baseMed` has two writers (tick + casualty handler). | Funnel both sites through `ARC_fnc_medicalBroadcast` (or rename existing publisher) so the writer table collapses to one row. |
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

### v1.0 — 2026-05-08

- Initial issuance. Captures all 26 replicated `ARC_pub_*` keys discovered on current head.
- Three findings (S-OWN-1..3) recorded as open Wave 2 follow-ons; none are blocking.
- Linked from `docs/architecture/Architecture_Plan_2026-05-08.md` §2.1 / §2.4 acceptance criteria.
