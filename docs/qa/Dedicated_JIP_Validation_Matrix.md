# Dedicated / JIP Validation Matrix

**Version:** 1.0
**Date:** 2026-05-08
**Status:** Active. Wave 5 release-candidate gate of `docs/architecture/Architecture_Plan_2026-05-08.md`.
**Mode:** F — Documentation-Only Changes
**Companion:** `docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md` (completion ledger).

---

## 1) Purpose

This document is the **exact smoke checklist** to run on a real dedicated server before the mission is declared release-candidate-ready. It exists so that paid dedicated/JIP time is spent on **integration validation**, not basic feature discovery (Architecture Plan §6 / Phase 5).

A check in this matrix has three possible outcomes recorded in `tests/TEST-LOG.md`:

- `PASS` — verified clean against current head.
- `FAIL` — reproducible issue; opens a bounded single-mode PR.
- `BLOCKED` — environment / dependency unavailable; do not pass to release without resolving.

**Hard rule:** Do not start this matrix until every prerequisite in §2 is true. Static evidence does not satisfy any check below.

---

## 2) Prerequisites — must be true before running this matrix

- [ ] `docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md` completion board has zero `blocked by mission data` subsystems.
- [ ] `docs/security/RemoteExec_Endpoint_Audit_Matrix.md` has no `❌` entries on client→server endpoints (warnings/⚠️ acceptable with documented rationale).
- [ ] `docs/architecture/State_Ownership_Ledger.md` has no `❌` entries.
- [ ] `tests/TEST-LOG.md` shows a recent compat + sqflint pass against current head.
- [ ] Mod stack used for the validation run is documented (preset version + ACE/CBA/3CB/RHS/CUP versions). Any mod-stack change invalidates prior PASS results.

If any prerequisite is false, this matrix is **gated** and should not be run.

---

## 3) Validation matrix

### 3.1 Dedicated server fresh start

| ID | Check | How to verify | Acceptance |
|---|---|---|---|
| D-1 | Server reaches steady state | Watch RPT for `[ARC][INFO] ARC_serverReady=true`; confirm `missionNamespace getVariable "ARC_serverReady"` is `true` within 60s of mission load. | No script errors before `ARC_serverReady`. |
| D-2 | All `ARC_fnc_*` registrations resolve | Run `ARC_fnc_devCompileAuditServer` once `ARC_serverReady` is true. | Audit reports 0 missing files; WARN-only entries for compile attempts (no FAIL rows). |
| D-3 | Marker / Eden prerequisites resolved | Inspect RPT for any `[ARC][WARN]` lines mentioning unresolved markers (`gate_*`, `epw_holding`, `mkr_SHERIFF_HOLDING`, AEON taxi/arrival markers). | No unresolved-marker warnings on first 5 minutes of server time. |
| D-4 | Initial public snapshot published | Confirm `ARC_pub_state`, `ARC_pub_orders`, `ARC_pub_queue`, `ARC_pub_companyCommand`, `ARC_pub_airbaseUiSnapshot` are all set within 90s of `ARC_serverReady`. | All five keys non-empty; `*UpdatedAt` keys are recent (`serverTime - X < 60`). |

### 3.2 Persistence save / load across restart

| ID | Check | How to verify | Acceptance |
|---|---|---|---|
| P-1 | Trigger a save | Operator action: TOC tab → Save (`ARC_fnc_tocRequestSave`). | Save logs `[ARC][PERSIST] save OK` with key counts. |
| P-2 | Restart the server | Stop the dedicated server, restart with same mission and mods. | Server reaches `ARC_serverReady` again with no orphan-state errors. |
| P-3 | Loaded state matches saved state | After restart, compare key snapshots (active task id, queue size, intel-log count, civsub identities count) before / after restart. | All comparisons are equal or differ only by deterministic post-load housekeeping (document any deltas). |
| P-4 | CIVSUB identity persistence | Detain a civilian, save, restart, then re-query the same `civ_uid`. | Identity record exists with `status_detained=true`, correct `status_detainedDistrictId`, and original `passport_serial`. |
| P-5 | Orders / queue persistence | With at least 1 active order and 2 queued items, run save → restart → verify. | `ARC_pub_orders` count matches; `ARC_pub_queuePending` count matches. |

### 3.3 JIP late-join

| ID | Check | How to verify | Acceptance |
|---|---|---|---|
| J-1 | JIP during active task | With one active task assigned to a group, have a fresh client connect. | Client renders the active task in Operations tab without manual refresh; freshness banner shows current data. |
| J-2 | JIP during accepted incident | With an accepted incident in flight, JIP a fresh client. | Client sees correct `acceptedBy` group, correct `closeReady` state, correct `sitrepSent` flag. |
| J-3 | JIP during airbase clearance state | With at least 1 active clearance request and 1 queued flight, JIP a fresh client. | Airbase tab renders both rows correctly; clearance state matches server. |
| J-4 | JIP during pending civsub detention | With a detained civilian in custody pipeline, JIP a fresh client. | Civilian still appears as detained; ACE captive flag preserved; civsub_v1_pinned still true. |
| J-5 | JIP after resetAll | Run `ARC_fnc_tocRequestResetAll`, then JIP a fresh client. | Client renders empty-state cleanly for all tabs (no stale orders / tasks / queue items). |
| J-6 | Add-action JIP correctness | JIP into a session with active IED evidence add-action and CIV add-action targets. | Add-actions are present on the correct objects; not duplicated; not missing. |

### 3.4 Reconnect / respawn

| ID | Check | How to verify | Acceptance |
|---|---|---|---|
| R-1 | Same-player reconnect during active task | Player accepts task, disconnects, reconnects. | Active task assignment remains; player rejoins same group; no duplicate task entries. |
| R-2 | Player respawn during active incident | Player on accepted-incident group dies and respawns. | Group still owns the incident; SITREP submission still permitted from group. |
| R-3 | Player respawn after CASREQ in flight | Player who submitted CASREQ respawns mid-flight. | CASREQ row remains with correct submitter; pilot inbox preserved. |

### 3.5 Public snapshot recovery

| ID | Check | How to verify | Acceptance |
|---|---|---|---|
| S-1 | Snapshot freshness signal advances | Watch `ARC_pub_stateUpdatedAt`, `ARC_pub_ordersUpdatedAt`, `ARC_pub_queueUpdatedAt` over 5 minutes of activity. | All advance monotonically; no negative deltas. |
| S-2 | Snapshot does not exceed bounded size | At peak activity, log `count ARC_pub_intelLog`, `count ARC_pub_opsLog`, `count ARC_pub_queueTail`. | All under their documented caps; no unbounded growth. |
| S-3 | Public snapshot writers match ledger | Audit live RPT against `docs/architecture/State_Ownership_Ledger.md`. | No replicated key written by a function not listed in the ledger. |
| S-4 | Cadence suppression behaves correctly | Force rapid `ARC_fnc_statePublishPublic` calls. | `ARC_pub_stateLastPublishSuppressed` records cadence reasons; no flooding of the network. |

### 3.6 RemoteExec rejection behavior

| ID | Check | How to verify | Acceptance |
|---|---|---|---|
| RX-1 | Sender-owner mismatch is rejected | From a developer client, attempt to remoteExec a CIVSUB action with a forged `_actor` reference. | Server logs `[CIVSUB][SEC] ... denied: sender-owner mismatch`; action does not execute. |
| RX-2 | Privileged endpoint rejects non-approver | Non-OMNI / non-approver client triggers `ARC_fnc_devCompileAuditServer`. | Server logs `[ARC][SEC] unauthorized caller`; no audit report sent to client. |
| RX-3 | Non-allowlisted function call rejected | Attempt to remoteExec a function not in `CfgRemoteExec.Commands`. | Engine rejects; logged in RPT. |
| RX-4 | Debounced endpoint enforces cooldown | Trigger `ARC_fnc_devCompileAuditServer` twice within 15s. | Second invocation rejected with `Audit rejected (debounce)` log. |
| RX-5 | F-DEV-1 / F-CIV-2 remediation verified | Once the corresponding Mode I PRs land, repeat: forced debug toggle from non-admin → rejected; MDT-by-netId from non-TOC → rejected. | Both reject with structured `[ARC][SEC]` log; no global state flip. |

### 3.7 Full mod-stack RPT review

| ID | Check | How to verify | Acceptance |
|---|---|---|---|
| M-1 | No new ARC script errors | Diff the RPT against the most recent known-clean run. | No new `Error in expression`, `undefined variable` (in ARC code), or `Generic error` lines tagged with ARC files. |
| M-2 | Known noise is documented | Re-confirm the `UK3CB_MEE_O_AR` warnings (and any other documented mod-stack noise) match exactly the README §"Known RPT Noise" entries. | No undocumented warnings remain. |
| M-3 | Mod-stack version captured | Record exact mod versions used for this validation pass in `tests/TEST-LOG.md`. | Versions logged. |

---

## 4) Execution procedure

For each validation pass:

1. Confirm §2 prerequisites are true. If not, stop.
2. Record build SHA, mission version, mod-stack versions, and tester identity.
3. Execute §3.1 → §3.7 in order. Do **not** skip ahead — D and P must pass before J/R/S have meaning.
4. For each row, write `PASS` / `FAIL` / `BLOCKED` to `tests/TEST-LOG.md` with date, SHA, and observed evidence.
5. Any `FAIL` opens a bounded Mode A (or Mode J for ops-only) PR. Do not progress to release with open `FAIL` rows.
6. Any `BLOCKED` row stays blocked until the dependency is available.

---

## 5) Release-candidate gate

The mission is **release-candidate** when:

- All §3 rows are `PASS` against the same head SHA.
- `tests/TEST-LOG.md` reflects this run with full evidence.
- No new code lands between the validation pass and the release-candidate tag without re-running at minimum the affected sections.

Any code change after validation invalidates the affected section. Use judgement: a docs-only change does not invalidate D-1; a state-publisher change invalidates §3.1, §3.5, and any J-row that touches the affected snapshot.

---

## 6) Out-of-scope

- Performance benchmarks under load (covered by a separate Mode D performance pass).
- External playtester recruitment (gated on this matrix being green).
- Single-player / Eden preview validation (use existing `tests/TEST-LOG.md` flow).

---

## 7) Change log

### v1.1 — 2026-05-10

- Added Sprint 5 diagnostics guidance: use `ARC_fnc_devDiagnosticsSnapshot` counters (players/AI/groups, CIVSUB registries, traffic lists, SitePop, convoy index, leads/threads/orders/queue, IED/VBIED device records, snapshot ages) as pre-check evidence before dedicated/JIP execution.
- Remaining gap unchanged: all §3 rows still require dedicated server + JIP runtime validation and cannot be closed via static/container checks.

### v1.0 — 2026-05-08

- Initial issuance. Captures the seven validation sections required before release-candidate declaration. Cross-linked from Architecture Plan §6 (Phase 5) and Pre-Dedicated Audit §5.
