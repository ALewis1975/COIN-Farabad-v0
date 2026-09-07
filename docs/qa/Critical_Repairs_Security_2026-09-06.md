# Critical security repairs — contract and verification

Mode I. Plan written before production edits. Base: `0151396c811939aa45a1190510d32605f18f4c7f`; branch `repair/critical-review-2026-09-06`. The user authorized all critical review repairs. This lane owns F01-F03 only.

## Execution and authority

Dedicated MP; JIP and respawn required. The server remains the sole campaign/world-state writer. Clients submit bounded requests with the engine's actual remote owner. No client, including a headless client with owner zero, receives implicit authority. Local server calls are trusted only when the engine reports local execution; optional caller-owner arguments are trusted test seams only under server-local `ARC_TEST_mode`. Hosted player self-calls remain valid, but still pass endpoint role checks. No persistent schema/key changes, new schedules, handlers or world actions are introduced.

Sources read in order: AGENTS, Playbook, Mission Design Guide, Dictionary, ORBAT, RemoteExec hardening plan and Threat/IED/VBIED/Suicide locked execution contracts. The hardening plan's historical server-to-client allowlisting advice is superseded for the code-bearing hold-action entry by the documented engine rule that server-origin remote execution is unrestricted. This change preserves server-origin object-keyed JIP delivery.

## Request contract and state model

Ingress -> capture `remoteExecutedOwner` and `isRemoteExecuted` directly -> validate actual owner against a real player object -> endpoint permission/object/current-task checks -> rate/idempotency guard -> mutation -> existing snapshot/log publication. A denied state exits the function before any operational mutation. Authorization blocks return a Boolean consumed by a function-scope rejection; an inner `exitWith` must not accidentally permit continuation.

`ARC_fnc_rpcValidateSender` retains its six arguments and Boolean result. The engine owner takes precedence over any passed value. Local-only test owner injection cannot override a live RPC. Existing local server call paths are explicitly separated from remote clients; the validator never infers that a remote call is trusted from membership in `allPlayers`.

IED/VBIED client detonation retains the existing one-ID API: server resolves sender from engine owner, requires membership of the accepting group and a nonexpired DET_IN_PLACE approval for that task/group, and binds the requested ID to the current server-owned device. Local automatic triggers still require the matching current device; rendered-safe and one-shot checks remain. Suicide detonation is server-internal, removed from the client allowlist, and verifies the active bomber/threat/task association before touching one-shot state or world objects. Threat spawn/cleanup ownership and server-owned association variables are coordinated with the simulation lane.

`BIS_fnc_holdActionAdd` loses client allowlist access; the existing server-origin call and its object JIP key remain unchanged. No arbitrary code RPC is added. Ephemeral notifications remain non-JIP. CAS config additions are integrated by the parent after coordination.

## Allowed files

Behavior/security edits:

- `config/CfgRemoteExec.hpp`
- `functions/core/fn_rpcValidateSender.sqf`
- `functions/core/fn_tocRequestResetAll.sqf`
- `functions/core/fn_tocRequestSave.sqf`
- `functions/core/fn_tocRequestRebuildActive.sqf`
- `functions/core/fn_tocRequestCivsubReset.sqf`
- `functions/core/fn_tocRequestCivsubSave.sqf`
- `functions/core/fn_tocRequestAirbaseResetControlState.sqf`
- `functions/core/fn_tocRequestPublicBroadcast.sqf`
- `functions/core/fn_tocRequestRefreshIntel.sqf`
- `functions/core/fn_tocRequestShowLeads.sqf`
- `functions/core/fn_tocRequestAcceptIncident.sqf`
- `functions/core/fn_devToggleDebugMode.sqf`
- `functions/core/fn_devCompileAuditServer.sqf`
- `functions/core/fn_devDiagnosticsSnapshot.sqf`
- `functions/core/fn_uiConsoleQAAuditServer.sqf`
- `functions/core/fn_uiConsoleTestRunServer.sqf`
- `functions/core/fn_uiCoverageAuditServer.sqf`
- `functions/core/fn_missionScoreGenerate.sqf` (authorization section only)
- `functions/core/fn_execObjectiveComplete.sqf`
- `functions/medical/fn_medicalCasevacRequest.sqf`
- `functions/ied/fn_iedServerDetonate.sqf`
- `functions/ied/fn_vbiedServerDetonate.sqf`
- `functions/ied/fn_suicideBomberOnDetonate.sqf`
- `functions/ied/fn_iedServerRequestDisposition.sqf`

Capture-only normalization (replace variable-name tests of an engine command with direct engine context/owner; preserve existing endpoint contracts):

- `functions/ambiance/fn_airbaseCancelClearanceRequest.sqf`
- `functions/ambiance/fn_airbaseMarkClearanceEmergency.sqf`
- `functions/ambiance/fn_airbaseRequestCancelQueuedFlight.sqf`
- `functions/ambiance/fn_airbaseRequestClearanceDecision.sqf`
- `functions/ambiance/fn_airbaseRequestHoldDepartures.sqf`
- `functions/ambiance/fn_airbaseRequestPrioritizeFlight.sqf`
- `functions/ambiance/fn_airbaseRequestQueueParkedAsset.sqf`
- `functions/ambiance/fn_airbaseRequestReleaseDepartures.sqf`
- `functions/ambiance/fn_airbaseRequestSetLaneStaffing.sqf`
- `functions/ambiance/fn_airbaseSubmitClearanceRequest.sqf`
- `functions/command/fn_intelOrderAccept.sqf`
- `functions/command/fn_intelOrderCompleteRtbEpw.sqf`
- `functions/command/fn_intelOrderCompleteRtbIntel.sqf`
- `functions/command/fn_intelQueueDecide.sqf`
- `functions/command/fn_intelQueueSubmit.sqf`
- `functions/command/fn_intelTocIssueLead.sqf`
- `functions/command/fn_intelTocIssueOrder.sqf`
- `functions/civsub/fn_civsubContactReqAction.sqf`
- `functions/civsub/fn_civsubContactReqSnapshot.sqf`
- `functions/civsub/fn_civsubInteractCheckPapers.sqf`
- `functions/civsub/fn_civsubInteractDetain.sqf`
- `functions/civsub/fn_civsubInteractEndSession.sqf`
- `functions/civsub/fn_civsubInteractHandoffSheriff.sqf`
- `functions/civsub/fn_civsubInteractOrderStop.sqf`
- `functions/civsub/fn_civsubInteractRelease.sqf`
- `functions/civsub/fn_civsubInteractShowPapers.sqf`
- `functions/civsub/fn_civsubRunMdtByNetId.sqf`
- `functions/core/fn_startdispSubmitAndAccept.sqf`
- `functions/core/fn_tocReceiveSitrep.sqf`
- `functions/core/fn_tocRequestCloseIncident.sqf`
- `functions/core/fn_tocRequestCloseoutAndOrder.sqf`
- `functions/core/fn_tocRequestForceIncident.sqf`
- `functions/core/fn_tocRequestLogIntel.sqf`
- `functions/core/fn_tocRequestNextIncident.sqf` (capture only; command-cycle repair separate)
- `functions/ied/fn_iedCollectEvidence.sqf`
- `functions/logistics/fn_recruitSpawnRequest.sqf`
- `functions/logistics/fn_recruitClientAddActions.sqf`
- `functions/logistics/fn_execSpawnConvoy.sqf`
- `functions/logistics/fn_execTickConvoy.sqf`

Verification files: this document, `tests/security_rejection_behavior.sqf`, `tests/static/security_rejection_flow_checks.py`. Parent owns state/reset implementations, CfgFunctions, run_all and TEST-LOG; no edits by this lane. Parent must normalize the separate internal-only publicBroadcastState guard. CAS agent owns its handler capture changes. Additional nontrivial defects discovered in a capture-only file require an explicit plan amendment before behavior edits.

### Pre-edit scope amendment

Inspection confirmed the same nested sender rejection in the listed CIVSUB contact/interaction handlers, `intelQueueSubmit`, `intelOrderCompleteRtbEpw`, `intelOrderCompleteRtbIntel`, `intelTocIssueLead`, `intelTocIssueOrder`, and `iedCollectEvidence`. Their allowlist-authorized mutation paths need a function-scope sender guard, including rejection of null remote actors; these are necessary F01 repairs and are promoted from capture-only to security behavior scope. The existing role/proximity/domain checks stay unchanged. For already-correct top-level helper consumers, the helper's direct engine read is sufficient; avoid incidental capture-only churn unless required for an endpoint's own owner/response logic.

## Observability and tests

Reuse existing event-specific `[ARC][SEC]`/OPS denial logs and the bounded ten-entry `ARC_pub_securityDenials` snapshot; log timestamp, owner, requested task/device and rejection reason for new association checks. Do not publish success or consume approval/one-shot state on rejection. Reuse idempotency guards after identity/association validation.

Automated checks: run source-flow regression checks for top-level rejection propagation (including negative fixtures), existing RPC owner-capture and RemoteExec/security contract checks, compilation/lint checks supported by the host, and a new engine harness that exercises production reset/save/rebuild dry-run seams with denial/authorized/mismatched-owner cases without overriding engine identifiers or mutating a real campaign. The engine harness is BLOCKED until run in Arma; do not report static checks as dedicated proof.

10-minute dedicated smoke after backup: 0-2 min hosted/dedicated ordinary and approver clients, sender diagnostics; 2-4 min ordinary/spoofed dry-run save/reset/rebuild requests must leave counters/state unchanged and one authorized request succeeds; 4-6 min repeated broadcast is throttled and denied diagnostics/test/admin actions do nothing; 6-8 min instrumented harmless detonation tests reject wrong/stale IDs and unapproved/expired/wrong-group senders without consuming state; 8-10 min genuine server VBIED hold action appears once for existing/JIP clients and cleans up with its object. Follow with real approved/local IED/VBIED/SB paths on a disposable mission, never a live campaign.

Regression risks: hosted self-calls, nested server callbacks preserving remote context, stale object IDs after cleanup, and server-origin JIP delivery. Acceptance requires local/internal positive cases as well as denials. No persistence migration is needed. Rollback is a bounded revert of this lane's commit while keeping the server private; reverting would restore known destructive exposure and is not a live-release remedy.

Official semantics: [exitWith](https://community.bistudio.com/wiki/exitWith), [remoteExecutedOwner](https://community.bistudio.com/wiki/remoteExecutedOwner), [isRemoteExecuted](https://community.bistudio.com/wiki/isRemoteExecuted), [CfgRemoteExec](https://community.bistudio.com/wiki/Arma_3:_CfgRemoteExec), [holdActionAdd](https://community.bistudio.com/wiki/BIS_fnc_holdActionAdd).

## Verification results, 2026-09-06

- PASS: structural scope analysis of 38 production sender guards, with a nested-exit negative control and client code-surface check.
- PASS: 18 cases execute the actual reset/save/rebuild wrapper bodies under SQF-VM v2026.04.03. Explicit generated fixture substitutions model unsupported engine context/notification commands; dependency stubs measure mutation callbacks. Cases cover sender denial, permission denial, remote test-flag/owner override resistance, authorized remote, trusted local, and local dry-run paths. The original scope failure is reproduced by removing each result guard: all three mutants fail the same suite. This is a control-flow test, not proof of engine sender identity.
- PASS: SQF-VM parse-only on all 40 changed production SQF files and the new engine harness; no parser errors.
- PASS: existing RPC owner-capture contract discovers 62 callers and accepts every six-argument call.
- PASS: `git diff --check` (line-ending notices only).
- BLOCKED_RUNTIME: nine production dry-run cases in `tests/security_rejection_behavior.sqf`, true remote owner/spoof/hosted paths, actual world detonation association, and server-origin hold-action JIP. Arma is unavailable here. The separate static/VM passes do not satisfy dedicated MP release acceptance.

Run the local checks with `python tests/static/security_rejection_flow_checks.py --sqfvm <path-to-sqfvm.exe>`. Existing `vbied_suicide_lock_contract_checks.sh` must be updated by the parent to assert the new server-internal suicide handler contract instead of requiring its removed client allowlist entry. Simulation-lane registration supplies both object association fields before publishing driven/SB mirrors; its monitors now invoke the endpoints locally.

### Final security handoff

The RTB(INTEL/EPW) endpoints also needed their existing pair getter to return its found value, selection rejection to reach function scope, and the documented destination/recorded-arrival gate to run before mutation. These remain Mode I endpoint-security corrections. The same security Python suite now executes 20 additional extracted production lookup/selection/proximity cases, including positive on-site and privileged recorded-arrival paths; both removed-selection-guard mutants fail. Final security count: **38 production VM cases, five rejected guard-removal mutants, 38 structural endpoint checks**. The VM fixtures explicitly model unsupported engine distance/context/transport and do not prove actual network identity or world effects.

Existing observability checks now verify each reason classification and the shared bounded recorder; disposition checks verify sender binding, group comparison and function-level rejection rather than an obsolete comment. The internal `publicBroadcastState` function remains server-only and absent from the client allowlist; the parent removes its obsolete context guard so validated upstream RPCs can publish synchronously.

Final combined lane validation: **58/58 changed SQF inputs pass strict compatibility, warning-sensitive sqflint and SQF-VM parse-only**; `git diff --check` passes. Evidence: `repairs/evidence/security-command-final-validation.json` outside the mission checkout. Dedicated/JIP/restart/world acceptance remains BLOCKED_RUNTIME. No engine PASS is claimed.
