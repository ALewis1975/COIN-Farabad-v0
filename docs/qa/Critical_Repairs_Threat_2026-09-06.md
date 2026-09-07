# Critical threat lifecycle repairs — contract before patch

Date: 2026-09-06. Base: `0151396c811939aa45a1190510d32605f18f4c7f`.
Authorization: user requested completion of critical repairs identified in the comprehensive review. This repairs existing shipped behavior; no new expansion types or gameplay are authorized here. The contradictory planning/locked document headers are retained as a separate governance matter.

## Execution context and authority

Dedicated multiplayer, JIP required. Server alone owns record state, admission, worker reservations, world registration and cleanup. Clients consume existing snapshots and request authorized actions. These actors remain server-local; HC transfer is not added. Persistent records survive restart; script handles and world entities do not. Parent integration owns clock rebasing, core save/load/reset and CfgFunctions registration.

Read before implementation: AGENTS, Playbook, Mission Design Guide, Dictionary, Threat v0/IED P1 baseline, existing VBIED/SB execution locks, and ORBAT. Inspected audited baseline spawn ticks, exec init/tick/cleanup, threat record creation/state/closure, scheduler, cleanup queue and existing tests.

## Allowed files

- `functions/ied/fn_vbiedSpawnTick.sqf`
- `functions/ied/fn_vbiedDrivenSpawnTick.sqf`
- `functions/ied/fn_suicideBomberSpawnTick.sqf`
- `functions/core/fn_execInitActive.sqf`
- `functions/core/fn_execTickActive.sqf`
- `functions/core/fn_execCleanupActive.sqf`
- `functions/core/fn_cleanupTick.sqf` (narrow current-task lifetime compatibility guard)
- `functions/threat/fn_threatRuntimeIsCurrent.sqf` (new internal predicate)
- `functions/threat/fn_threatRegisterWorld.sqf` (new internal registration hook)
- `functions/threat/fn_threatMaintenanceTick.sqf` (new bounded maintenance called by existing scheduler)
- `functions/threat/fn_threatSchedulerTick.sqf`
- `functions/threat/fn_threatScheduleEvent.sqf`
- `functions/threat/fn_threatMarkCleanedByLabel.sqf`
- `functions/threat/fn_threatIedCleanupSync.sqf`
- `functions/threat/fn_threatUpdateState.sqf`
- `functions/threat/fn_threatOnIncidentClosed.sqf`
- `functions/threat/fn_threatOnAOActivated.sqf`
- `tests/critical_threat_lifecycle.sqf` (isolated opt-in engine regression harness)
- `tests/static/critical_threat_lifecycle_checks.py` (control-flow/source contract checks)
- This document.

No edits to source mirrors, mission.sqm, detonation RPC endpoints, core persistence, initServer, or CfgFunctions by this owner. Other repair owners coordinate those hooks. No commits or deployment.

## Contract and state model

Existing APIs and ThreatRecord v0 remain authoritative. New internal predicate checks nonempty stable task/threat IDs, active incident kind, acceptance/close-ready status, and a nonterminal matching threat. Admission additionally enforces canonical district tier (VBIED >=2, SB >=3); unresolved district denies rather than silently bypassing. Ongoing already-armed monitoring continues if posture later drops; admission gates govern spawning/rearming.

Parked VBIED: unarmed -> admitted/armed exactly once -> detection/window monitoring on every execution tick -> safe or detonated -> existing incident close/cleanup. `ARC_vbiedCooldownSeconds` gates admission/rearm only, not detection. Clear per-incident safe/alert/window/pause fields in the existing cleanup/init lifecycle. No replacement trigger or second monitor.

Driven VBIED: idle -> pending reservation `[taskId,threatId]` synchronously before the existing delayed worker -> revalidate identity, reservation, enable/TOD/tier/fairness at wake -> registered live actor -> monitor -> resolved/cancelled/cleaned. A new task or cleanup invalidates the reservation and terminates the old worker. Failed admission clears reservation for that task; expired records cannot spawn. Same-kind replacement is distinguished by stable task/threat IDs.

SB: validate geometry and admission -> registered live actor -> one tracked monitor. Geometry uses scalar coordinate selections before arithmetic. Every wake checks captured task/threat identity. Closing stops monitoring and hands existing actors to the cleanup owner.

World ownership: `threatRegisterWorld` attaches task/threat variables, fills existing `world.objects_net_ids`, `units_net_ids`, `groups_net_ids`, `spawned`, `cleanup_label`, registers every object with the existing cleanup queue immediately, and logs a world-spawn event. Existing active objective lifetime is preserved: a server-local `ARC_cleanupDeferTaskId` retains these actors only while that exact task remains current (including awaiting TOC closure). Actual closure clears the flag; original bubble cleanup then applies. Force/reset bypasses the guard. `execCleanupActive` invalidates workers first, then defers or immediately deletes only owned nonplayer actors. Queue callbacks remove the completed net ID and only transition CLEANED after all world references are gone. No new active-bubble task-failure or rehydration policy is introduced. Player protection remains mandatory.

Latent scheduler records: add backward-compatible `lifecycle_v=1`, `latent_expires_ts` to scheduler-owned records. TTL default 3600 seconds, bounded 300..21600; existing taskless CREATED records migrate from creation time. Maintenance runs within the existing scheduler tick (no new loop), expires only taskless ordinary records with no spawned world and then CLEANED, releasing district admission. It never reenables suppressed taskless FIELD leads or spawns entities. Bounded ordinary terminal history keeps the newest configured count and removes only fully CLEANED, unreferenced records; active records, live references and virtual pool records are protected. IDs remain monotonic; no ID reuse.

## Owned state and persistence

- Existing ARC_state fields: `activeVbied*`, `threat_v0_records`, open/closed indexes and existing threat world metadata. Existing ThreatRecord v0 is retained; optional `lifecycle_v=1` identifies new metadata.
- New transient missionNamespace keys: `threat_v0_drivenPending` array, `threat_v0_drivenWorker` script handle, `threat_v0_suicideWorker` script handle. Reset/cleanup clears them; never persisted. Existing net-ID/one-shot mirrors remain snapshot inputs.
- New tuning read: `ARC_threatLatentTtlS`, default 3600. No baseline key rename.
- New persisted timestamp: ThreatRecord `latent_expires_ts`, which parent rebases as a deadline alongside existing threat creation/state/world timestamps. Existing VBIED alert/pause/arm timestamps also require rebasing; `PauseAccum`/window duration are not absolute times.
- Daily economy reset uses persisted `threat_v0_budget_next_reset_ts` (deadline, initial value now + 86400); parent rebases remaining time across restart. The old reset-day integer is diagnostic only. A due deadline grants one reset and advances from now; offline time never grants catch-up budgets.

## Observability and verification

Logs include time, SYSTEM actor, stable task/threat ID and grid for pending, admission denial, cancellation, spawn, expiration, pruning and cleanup. Existing threat events/snapshots retain the same format. New tests must inspect outcomes and scope/order, not merely presence of log strings.

Ten-minute dedicated smoke: 0–2m parked arm then second-tick approach, countdown and EOD pause; 2–4m low/high/critical tier admission and repeated pending calls; 4–6m cancel pending and live same-kind replacement, no old detonation; 6–8m actor cleanup and empty world refs, JIP freshness; 8–10m short controlled latent expiry and save/load timestamp verification. Longer actual driving/terrain/HC/FPS verification remains a runtime gate.

Expected results: one reservation/vehicle per task; deny produces no actors; countdown updates continuously; no undefined coordinate error; no living orphan or late worker; cleanup does not announce CLEANED until the last reference disappears; taskless record releases its district at TTL; ordinary history stays bounded while virtual/live/task references survive.

Regression risks: altered tier denial may expose previously bypassed authoring faults; strict identity checks require the AO threat hook before spawn admission; cleanup must preserve players and not count still-live companions as cleaned; pruning must not invalidate an active consumer; save/load must clear transient workers before reconstruction. Bounded rollback is the exact allowed-file diff plus the optional metadata migration; old record fields remain readable, and new metadata can be ignored by the audited baseline. Do not roll back repaired lifecycle code against active new workers without restarting the mission.

## Validation results

F05 integration addendum, planned before patch: when the existing missing-object recursion rebuilds an accepted execution package for the same stable task, capture and restore its translated execution start/deadline/arrival/hold/activation progress around that physical reconstruction. New task/initial acceptance remains fresh. For the same parked VBIED kind, retain admitted device identity, safe/alert/pause/window state and `activeVbiedElapsedBeforeLoad` (new persisted duration, default 0, clock v1 helper owned by root). Rebind the new vehicle into the existing threat record on its next monitor tick; never reuse an old world object. The monitor adds the elapsed carry to its countdown, resets it for a new unalerted arm and cleanup, and retains it for physical reconstruction. Tests inspect capture/restore ordering and execute that source block against a controlled reconstruction stub, alongside root's clock carry tests.

Terminal reconstruction guard: `activeIncidentCloseReady` is the authoritative completed/failed awaiting-SITREP flag (there is no `activeObjectiveDone` state key). `execInitActive` must return before construction when set, matching the execution tick guard, so restart does not recreate a neutralized objective or replay completion/evidence effects. Existing IED evidence state is untouched.

Implemented the allowed threat lifecycle changes. The existing scheduler now retires at most 20 latent records and reconciles at most 20 terminal records per admitted tick. Fully CLEANED ordinary history retains the newest `threat_v0_closed_max` eligible records (default 200, upper bound 2000), preserving current task/threat, nested lead/queue metadata references and all virtual-pool records. Completion metadata is committed only by the successful CLEANED transition. Closure stops workers before releasing their registered actors; player occupants are preserved even in immediate objective cleanup.

Verification performed on 2026-09-06:

- 18 owned SQF files (17 production files and the engine harness) passed SQF-VM parse-only.
- All 18 passed `sqflint 0.3.2 -e w` and the strict repository compatibility scanner. New helpers use the existing `forEach`/`exitWith` lookup convention; no CI rules were relaxed.
- `python tests/static/critical_threat_lifecycle_checks.py --sqfvm ../sqfvm-runtime/sqfvm_windows_x64/sqfvm.exe`: 31 control-flow/source checks and 19 SQF lifecycle assertions passed. Actual stateGet/stateSet, runtime identity, cleanup convergence, legal transitions and maintenance functions execute against fixtures. Assertions cover same-kind replacement rejection, unaccepted/close-ready/expired rejection, old negative-clock latent expiry, future/task-linked/virtual preservation, open-index release, cleanup idempotency, oldest-first pruning and nested consumer reference protection. A further 20 SQF assertions execute the actual physical-rebuild preservation block with only the physical constructor stubbed: accepted same-task reconstruction retains deadline/hold/device identity/elapsed carry; new task, unaccepted task, task replacement during construction and failed construction do not restore stale state. The completed-awaiting-SITREP guard is checked before construction. The three integration files passed strict compatibility, sqflint and diff checks again after these changes.
- The VM runner explicitly adapts unsupported host operations: server role and clock are fixed fixture inputs; grid formatting becomes `str`; trim is an identity operation for whitespace-free inputs; snapshot restoration is local; external intel/event/debug sinks are inert. Production helper control flow and record mutations remain the tested source. These adapters do not validate engine physics, scheduling, networking, world-object deletion or remote authority.
- Owned-file `git diff --check` passed. No source-mirror, mission.sqm, commit, push or deployment actions were performed.

The dedicated/JIP acceptance run remains necessary: parked second-tick detection and EOD pause; 20 execution ticks during the driven telegraph delay producing one worker/vehicle; cancellation before and after spawn followed by same-kind replacement; current-task lifetime retention outside the bubble; deferred/force cleanup with a player occupying a threat vehicle; and last-companion deletion before CLEANED (including next-frame null references). Save/load must preserve budget/latent time remaining and clear all transient worker handles. No Arma runtime session has been claimed.

Opt-in engine data harness: on an idle development server after startup, set `ARC_criticalRepairTestsEnabled=true` and execute `tests/critical_threat_lifecycle.sqf`. Expect `[ARC][TEST][THREAT] SUMMARY pass=19 fail=0`. It creates no world actors or explosives and restores campaign state and published threat snapshots after its atomic fixture block. Lifecycle test events may still appear in the development RPT.
