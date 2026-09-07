# Critical command-cycle repairs — contract first

Mode A behavior repair following the Mode I security lane, authorized by the user request to complete critical repairs. Written before command edits. Dedicated MP, JIP/respawn, server single-writer, persisted records survive process restart; BIS task objects are reconstructed views. No mission.sqm changes. Read Playbook/DesignGuide/Dictionary/ORBAT first, then TASKENG/SITREPSYS baseline/state matrix/snapshot baseline, TASKENG migration and hierarchy stub, then current mission implementations.

## Boundaries and controlled compatibility

F04: Generate is allowed only after sender, existing TOC approver role, and pending-order/RTB policy checks. A blocked request may publish denial diagnostics but cannot change suspension, backlog, leads or task counters. Success requires a true incidentCreate result. No command-cycle state or result tuple changes.

F06: Reset collects task IDs from orders before clearing records/counters, plus known legacy CASE aliases. Client purge clears the ATH focus only when it references a deleted ID. Reset clears the parent lane's persistence-clock quarantine/snapshot keys. No broad deletion of unrelated tasks.

F07: The current mission attaches children to ARC_case IDs and updates `threads`; the hierarchy stub's independent CASE namespace and claim of canonical thread-store ownership are only partially implemented. This repair explicitly retains the working production thread tuple/ARC_case path and makes taskengEnsureParentCaseTask a compatibility adapter to it. The adapter stops writing task-ID strings into the rev4 map of thread tuples. Existing malformed string values are repaired from corresponding authoritative thread records without changing the rev4 value contract. Existing unused CASE aliases are deleted through explicit known thread IDs. This is a bounded deprecation of the duplicate creator, not implementation of the broader v00 architecture. Full canonical-store migration remains separate audit work. Rollback restores the previous adapter files; it would restore duplicate artifacts and requires private testing.

F09: Issuance must reserve capacity before incrementing orderCounter or mutating state. Evict oldest terminal history only (COMPLETED/CANCELED/FAILED), never ISSUED/ACCEPTED or the active pending-closeout reference. All-live capacity returns a logged refusal. Evicted terminal task artifacts are deleted explicitly. Record and snapshot shapes remain seven-slot tuples.

F10: RTB/HOLD acceptance and rehydration use one renderer driven by stored data, never a second acceptance call. Renderer validates accepted state, stable ID, group and destination; creates only missing task views. Startup/join/tick retry when groups become available. No status, timestamps, counters, lead consumption, closeout or acceptance events are replayed. Current focus is server-origin, bounded to eligible group members; repeated maintenance creates no extra tasks or notification loops.

## Exact edit allowlist and API

Existing files: `functions/core/fn_tocRequestNextIncident.sqf`, `functions/core/fn_resetAll.sqf`, `functions/core/fn_clientPurgeArcTasks.sqf`, `functions/core/fn_taskengEnsureParentCaseTask.sqf`, `functions/core/fn_taskengMigrateSchema.sqf`, `functions/core/fn_taskEnsureThreadParent.sqf`, `functions/core/fn_incidentCreate.sqf` (outdated comment only), `functions/command/fn_intelOrderIssue.sqf`, `functions/command/fn_intelOrderAccept.sqf`, `functions/command/fn_intelOrderTick.sqf`, `functions/intel/fn_intelInitServer.sqf`, `initPlayerServer.sqf`.

New internal functions: `functions/command/fn_intelOrderReserveSlot.sqf` pure `[orders,cap,pendingId] -> [allowed,retained,evicted]`; `functions/command/fn_intelOrderTaskSpec.sqf` pure `[record] -> [] or [taskId,group,title,description,pos,type]`; `functions/command/fn_intelOrderEnsureTask.sqf` server renderer `[record,focus=false,joiner=objNull] -> BOOL`; `functions/command/fn_intelOrderRehydrate.sqf` server retry `[joiner=objNull] -> countCreated`; `functions/core/fn_resetOrderTaskIds.sqf` pure `[orders] -> taskIds`. Parent registers these in CfgFunctions. They are not client-allowlisted APIs.

No new persistent keys or schema versions. Existing live keys: tocOrders/orderCounter, taskeng_v0_thread_store revision4, threads. Reset clears `ARC_state_preClockV1` in missionProfileNamespace and local `ARC_persistenceClockBlocked`/`ARC_persistenceClockSnapshot`. Existing client ATH `ARC_uiFocusTask*` fields are cleared only by explicit purged IDs. No new loops/stores or public schema.

Tests/docs: this plan, `tests/command_critical_regression.sqf`, `tests/static/command_critical_flow_checks.py`. Parent owns CfgFunctions, shared TEST-LOG/run_all/bootstrap, persistence and lead decay files. No commits/push by this lane.

## Acceptance, evidence and risks

Run pure admission/task-spec/task-ID collection tests in SQF-VM and production next-incident control-flow fixtures with mutation tripwires; include negative controls. Parse edited SQF and run existing relevant static contracts. Report exact executed coverage, never static results as Arma proof.

10-minute disposable dedicated smoke: 0-2 min pending ISSUED and ACCEPTED RTB Generate denials preserve suspension/backlog/leadPool/counter and show one denial; 2-4 min accepted RTB/HOLD survive full process restart with original task IDs/positions and no acceptance/closeout replay; 4-6 min late join gets the same group task exactly once; 6-8 min threaded incidents share one parent, then reset removes accepted order and CASE/ARC_case aliases and clears ATH; 8-10 min cap filled with live orders rejects cleanly, mixed terminal history evicts only terminal task IDs. Inspect logs `INCIDENT_GEN_BLOCKED`, `TOC_ORDER_CAPACITY_DENIED`, `TOC_ORDER_REHYDRATED`, `TASKENG_PARENT_ALIAS_REMOVED`, reset deletedTasks. Confirm fresh issuance after reset and normal approved Generate still work.

Arma runtime unavailable: dedicated/JIP/task-framework acceptance remains BLOCKED_RUNTIME. Main risks are join timing/group changes, old malformed map values, unrecognized historical task IDs and disposal of terminal task views; preserve explicit IDs and retry via existing maintenance.

### Integration amendment, before final edits

Reset also clears the CAS lane's archived completion aggregate, inbox, local inbox signature/submission cooldowns and maintenance timestamp; clear driven-threat admission reservations. Add these explicit reset keys to the existing resetAll allowlist without changing their owner/schema. The registered shared renderer may refresh an existing task's group ownership on join using BIS_fnc_setTask, preserving its ID/state. Existing incident focus takes precedence during restoration.

Mechanical compatibility substitutions in already-edited files are required by existing CI: replace shorthand indexing with select, typed string inequality with !=, use compile wrappers for unsupported parser commands, and remove unused bindings only. No workflow or gate weakening. Extend the test-file allowlist to `tests/static/dedicated_observability_contract_checks.sh` and `tests/static/threat_ied_lifecycle_contract_checks.sh`: replace obsolete direct-log-call/comment matches with explicit reason-to-common-emitter checks and the executable structural rejection-flow suite.

The final same-file inspection also found that both `intelOrderCompleteRtbIntel` and `intelOrderCompleteRtbEpw` discarded pair lookup results and their selection/proximity denials returned only from nested scopes. Their existing security edit scope includes repairing the lookup, propagating selection rejection, and enforcing the documented destination/arrivedAt condition before completion/EPW movement. Preserve normal on-site completion and privileged remote completion only after recorded arrival. Add actual extracted production-block VM tests for lookup, override permission/status/purpose and distance/arrival gates.

## Final validation and handoff

PASS: 17 pure production-helper cases cover live/terminal/pending-reference admission, clean full-capacity refusal, immutable inputs, explicit reset task IDs and accepted RTB/HOLD task descriptors. PASS: six actual NextIncident production-flow cases cover ISSUED/RTB denial with zero mutation, policy override, normal generation, creator failure and active-task rehydration. Removing the policy result guard fails the same suite. Fixtures substitute only engine/dependency boundaries and unsupported trim on whitespace-free test tokens.

PASS: combined security/command 58-file strict compatibility, warning-sensitive sqflint and SQF-VM parse-only validation; diff whitespace check passes. The Mode I RTB corrections and their additional 20 cases ship in the independent security suite. Parent owns final reset/CAS/threat integration and CfgFunctions registration.

BLOCKED_RUNTIME: actual BIS task recreation/ownership, restart/JIP parity, ATH focus/cleanup and campaign smoke tests. These require the disposable dedicated server matrix above. The adapter stops new duplicate CASE creation, removes known aliases and reconciles malformed string mirror entries to existing rev4 tuple records; full v00 canonical-store migration remains outside this compatibility repair.
