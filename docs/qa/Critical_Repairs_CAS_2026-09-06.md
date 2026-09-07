# Critical repairs: compact CASREQ and SHADOW input

Plan recorded before implementation, 2026-09-06. Scope: audit F11–F14 and CAS portions of F25/F28. User authorized critical repairs. Dedicated MP, JIP and persistence required; server is sole campaign writer, clients request and render snapshots. No HC or world-spawn responsibility is added.

## Authority and boundaries

Read in precedence order: Prompting & Integration Playbook, locked Mission Design Guide v0.4, Dictionary v1.1, Farabad ORBAT, then `Farabad_UI_CASREQ_Thread.md` section **4.8 Shipped compact CASREQ v1 baseline (authoritative)** and current audited source. The earlier full JSON planning schema is not implemented. Existing Open/Decide/Execute/Close and full-record delta bundle remain the lifecycle APIs. SHADOW keeps its current independent role gate and queue intake.

CAS owns server authorization, compact record mutations, retention, complete inbox publication and client forms. TOC/queue leadership and the actual editor `jtac` slot can control requests; existing authorized field leadership can create. Named JTAC identity transfers only through a server EntityRespawned handler, never through a rifleman classname grant. Approval selects a live player-occupied configured attack aircraft; server derives crew UIDs. Assigned crew must occupy an attack aircraft to execute. Controllers may recover legacy requests without assignment. Requester can abort their own request; controllers can abort any active request. No client can request TIMEOUT.

## State, idempotency and persistence contract

Keep v1 compact top-level record keys and pairs arrays. OPENED message gains server-derived requester UID and bounded request token; APPROVED message gains server-derived crew UIDs and aircraft variable/label. No persisted object references. Existing optional `airbase_availability` remains. OPEN -> APPROVED or DENIED; APPROVED -> EXECUTING; EXECUTING -> CLOSED/COMPLETE with nonempty BDA notes; any active state -> CLOSED/ABORT by requester/controller; server expiry -> CLOSED/TIMEOUT. Repeating the same applied action returns success without mutation; conflicting/out-of-order transitions fail. Terminal records cannot reopen. Approval/execute preserve AIRBASE checks, while an assigned airborne aircraft remains eligible without being counted as parked/ready.

Existing `casreq_v1_enabled`, `casreq_v1_version=1`, `casreq_v1_records`, `casreq_v1_open_index`, `casreq_v1_closed_index`, `casreq_v1_seq` remain. Add backward-compatible scalar `casreq_v1_archived_completed=0` under v1 for aggregate CLOSED/COMPLETE count when terminal detail expires. No new record schema. Initialization preserves valid loaded records and reconstructs indexes. Maximum 20 newly admitted active requests, 3 per requester; existing legacy overflow remains until expiry and blocks admission. Retain at most 100 terminal records; archive completed counts exactly once on removal. Cap messages at 16; nine-line exactly nine whitelisted scalar fields, each text <=240 except remarks <=500. Decision/close notes <=500. Request tokens <=96 and scoped to requester UID; replay idempotency lasts while the bounded retained record exists. Server submission cooldown 10 seconds. Active requests expire 2 hours after their last valid transition. No transition extends expiry on a rejected replay. Sequence exhaustion fails closed instead of reusing an ID.

Clock fields remain `created_at`, `updated_at`, `closed_at`, `messages[].at`; AIRBASE snapshot `updatedAt`/asset `availableAt` remain informational. Parent integrates save/load clock rebasing. Transient `ARC_casreq_lastMaintenanceAt` and per-unit submission time reset on restart. Reset clears stores, aggregate, revision, inbox, delta and maintenance timestamp.

## API, initialization and observations

New internal helpers: `casreqCan`, `casreqTransition` (pure guarded compact mutation), `casreqMaintain`, `casreqInboxPublish`, `casreqCompletedCount`; client helpers: `casreqInput`, `casreqClientInbox`, `casreqInboxAction`. Only existing Open/Decide/Execute/Close become client-to-server RPCs, authenticated through the shared sender validator. Decide adds optional aircraft object after existing parameters; Open adds optional request token. No internal helper is remote allowlisted. A bounded server inbox `ARC_pub_casreqInbox` carries version, revision, timestamp and complete record snapshots; old `ARC_pub_casreqBundle` retains per-event full snapshot. Rebuild inbox after load and each mutation, and in existing parent-owned public-state/tick path. No duplicate scheduler. Console INTEL tools opens the inbox and existing CAS entry points use the shared text form. Escape/Cancel submits nothing. Details render as plain text.

Lifecycle logs contain time, actor, request ID, action and target grid; inbox supplies bounded debug records and counts. Server hints report denied inputs/transitions; UI waits for authoritative snapshot changes rather than claiming success locally. No spawned entities means no new bubble cleanup owner.

## Exact allowed files

- `functions/casreq/fn_casreqInitServer.sqf`
- `functions/casreq/fn_casreqBuildId.sqf`
- `functions/casreq/fn_casreqAirbaseAvailability.sqf` (plan amendment before edit: refresh CAS aircraft references from AIRBASE runtime after its existing delete/recreate cleanup, so authority does not depend on permanent world objects)
- `functions/casreq/fn_casreqSnapshotGet.sqf`
- `functions/casreq/fn_casreqBroadcastDelta.sqf`
- `functions/casreq/fn_casreqOpen.sqf`
- `functions/casreq/fn_casreqDecide.sqf`
- `functions/casreq/fn_casreqExecute.sqf`
- `functions/casreq/fn_casreqClose.sqf`
- `functions/casreq/fn_casreqClientSubmit.sqf`
- `functions/casreq/fn_casreqJtacPrefill.sqf`
- `functions/casreq/fn_casreqCan.sqf`
- `functions/casreq/fn_casreqTransition.sqf`
- `functions/casreq/fn_casreqMaintain.sqf`
- `functions/casreq/fn_casreqInboxPublish.sqf`
- `functions/casreq/fn_casreqCompletedCount.sqf`
- `functions/casreq/fn_casreqInput.sqf`
- `functions/casreq/fn_casreqClientInbox.sqf`
- `functions/casreq/fn_casreqInboxAction.sqf`
- `functions/command/fn_intelShadowLeadBridge.sqf`
- `functions/ui/fn_uiConsoleClickPrimary.sqf`
- `functions/ui/fn_uiConsoleIntelPaint.sqf`
- `functions/ui/fn_uiConsoleOpsPaint.sqf`
- `config/CfgDialogs.hpp`
- `tests/casreq_critical_repairs.sqf`
- `tests/static/casreq_critical_repairs.py`
- `tests/static/lane_c_contract_checks.sh` (plan amendment before edit: assert the live operator-facing AIRBASE denial path instead of the removed historical log wording)
- `docs/qa/Critical_Repairs_CAS_2026-09-06.md`

Parent-owned integration (requested, not edited by this owner): CfgFunctions registrations, CfgRemoteExec Decide/Execute/Close allowlist (security owner), stateInit/resetAll aggregate defaults/reset, publicBroadcastState maintenance/inbox hook, missionScoreGenerate schema-aware completed count, save/load clock registry, TEST-LOG. No changes to shared tests/run_all.sqf.

## Acceptance and bounded rollback

Automated: production pure transition SQF harness covers order guards, success/idempotence/conflicting terminal actions, COMPLETE requiring BDA, record copy preservation and bounded messages. Static integration harness checks named-role gate, real forms/cancellation, RPC production paths, full inbox, bounds and scorer hook. These do not substitute for engine execution.

Ten-minute isolated dedicated smoke: (0–2m) real JTAC and leadership submit two edited requests; same-class ordinary rifleman and spoofed caller are denied, cancel produces no new record. (2–4m) controller approves one for HAWG crew and denies the other; unrelated crew cannot execute; assigned crew executes and completes with BDA. Duplicate submissions/transitions leave counts unchanged. (4–6m) abort another request as requester; SHADOW form edits reach existing queue and cancellation does not. (6–8m) save/restart and JIP before any new mutation: both inbox/history and aggregate scores reconstruct, then respawn JTAC and assigned crew. (8–10m) in disposable state set old updated_at to exercise TIMEOUT; fill history to 101 to verify retention/aggregate, reset and JIP empty. Check exact snapshot states, edited text, requester/crew metadata, indexes and `[ARC][CASREQ]` logs with ID/actor/time/grid.

Runtime gate: Arma dedicated/JIP/UI execution is unavailable in this workspace; leave these checks explicitly runtime-unverified until performed. Main risks: UI dimensions on scaled displays, specialist respawn identity, aircraft availability and snapshot refresh. Detect in smoke above. Rollback only this bounded CAS/UI file set plus parent integration; retain compact records and archive scalar in saves (older code ignores additional scalar/message metadata). Do not downgrade a save schema or erase campaign state.
