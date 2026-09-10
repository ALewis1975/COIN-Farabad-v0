# CIVSUB scene-retention hotfix: contract and validation

## Execution context and evidence

Mode A: bug fix. Base: c56f4e6a78267e4827201043b0a10dcf0fa2bb25.
Dedicated MP is the target; JIP must reconstruct server state. The September 9
RPT is hosted MP, not dedicated/JIP evidence. The patch runs on the server.
Clients continue to request interactions and render published snapshots.
No Windows files, deployment, settings, mod presets, or persistence resets.

The RPT records civilian deletions near ARC_inc_1 before AO_ACTIVATED, but does
not identify every removed civilian's spawn owner. This patch addresses the
confirmed source gaps; it does not claim that every removal had the same cause.
The existing scene spawners already tag local-support and overlay actors. Their
execution owner already records NetIds and performs immediate or deferred cleanup.

## Source hierarchy

Read the Project Playbook, Mission Design Guide v0.4, Dictionary v1.1, CIVSUBv1
locked baseline, and authoritative Farabad ORBAT before source changes. Main
still resolves to the reviewed base; no open PR existed during this check.
The June 30 protection-helper history includes interaction and HashMap fixes;
retain the compiled HashMap getter and interaction TTL behavior.

## Allowed files

- functions/civsub/fn_civsubCivIsProtected.sqf
- functions/civsub/fn_civsubCivCleanupTick.sqf
- functions/civsub/fn_civsubCivDespawnUnit.sqf
- functions/core/fn_cleanupTick.sqf
- tests/static/civsub_scene_retention_checks.py
- docs/qa/CIVSUB_Scene_Retention_2026-09-09.md

Scope expansion during source review: the local-support civilian reuse branch
retags actors but does not remove an old core cleanup entry. The core consumer
therefore also needs an active-task ownership check. Explicit force/reset keeps
its existing bypass; ordinary deferred cleanup must not delete reassigned actors.

Everything else is outside this slice. In particular: no mission.sqm, spawn
counts, caps, task state transitions, UI/toasts, RPCs, CfgFunctions, or mod changes.
The validation record below is specific to this patch; preserve the historical
canonical tests/TEST-LOG.md rather than replacing it with a partial retrieved copy.

## Ownership, state, and interfaces

CIVSUB owns sampler eviction. Identity registration alone does not transfer
active-task or deferred-cleanup actors to sampler eviction. TASKENG retains the
existing active task and execution NetId lists; core cleanup retains its queue,
delays, player-distance checks, and direct deletion path. Its ordinary consumer
now retains actors owned by the current task, including actors reused before an
old deferred entry expires. Explicit force retains the previous reset behavior.

Lifecycle: live -> queued -> revalidated -> deleted OR retained. Retained entries
leave the sampler queue and remain in the registry. They can become eligible
again on a later scan after protection ends. A queued entry is not permission
to delete an actor whose protection changed. Dead bodies remain for the existing
body workflow. Repeated calls must not double-delete or drop retained records.

Protect an actor through its existing ARC_localSupportTaskId or ARC_overlayTaskId
when that ID matches activeTaskId; after release, protect it while its exact
NetId remains in core cleanupQueue. Empty, malformed, or stale task tags alone
must not protect forever. Honor the explicit ARC_persistInAO flag. Preserve pin,
interaction TTL, captive, handcuffed, detained and handed-off protections.

Read-only keys: activeTaskId and cleanupQueue via stateGet; object task tags,
ARC_persistInAO, existing civilian flags/identity fields. Existing writers remain
unchanged. CIVSUB registry/queue shapes remain unchanged. Public function
signatures and BOOL return types remain unchanged. Despawn returns false when
it refuses deletion, and the caller must respect that result.

Persistent keys/schema: no change; CIVSUB v1 remains v1. No migration or reset.
New transient server-local diagnostic key: civsub_v1_civ_cleanup_snapshot.
Schema: [1, serverTime, registryCount, queueRemaining, protectedCount,
processedCount, deletedCount, retainedCount, samples]. samples has at most six
[key, outcome, civ_uid, localTaskId, overlayTaskId, grid] rows. This is a replaced
snapshot, not a growing history and not a replicated/persisted blob.

## Observability

Actual sampler deletion logs retain the existing DESPAWN OK prefix and include
serverTime, actor=SERVER, NetId, task tags, grid and connection source. A refused
queued deletion logs a RETAIN event with the same identifying context. No player
notification is emitted. Inspect civsub_v1_civ_cleanup_snapshot on the server.
Core deferred cleanup keeps its existing ARC_debugCleanup logging.

## Acceptance gates

Retain local-support and overlay actors during approach, execution, and pending
SITREP. At closure, defer to core cleanup and respect its player bubble. After
release with no remaining owner or explicit protection, ordinary sampler eviction
must still work. Verify stale queue entries, late interaction/captivity, dead
bodies, stale tags, repeated cleanup, and the six-entry processing bound.

Use a dedicated server and separate client; join during an active task and after
closure. Verify no client writes, duplicate scene, or missing reconstructed
ownership. Save/restore in an isolated existing test profile; no destructive live
reset. Follow the approved reset test only on a disposable campaign.

## Ten-minute smoke test

| Window | Action | Pass evidence |
|---|---|---|
| 0-2 min | Start identified candidate; create Crowd Control / Mediation outside the objective area. | Correct build and one scene; record task-owned NetIds. |
| 2-5 min | Accept and approach through several sampler ticks. | Required tagged actors remain; no DESPAWN OK for those NetIds. |
| 5-7 min | Interact, finish objective and submit SITREP. | Interaction protection survives stale queue; task-specific server report receipt. |
| 7-9 min | TOC closes and issues follow-on; stay inside cleanup bubble. | One close/follow-on sequence; task actors survive core deferral. |
| 9-10 min | Leave bubble and inspect after configured delay. | Core cleanup removes released actors; registry/queues converge. |

Observe longer configured grace periods separately. Dedicated/JIP, restart,
concurrent clients, and notification delivery remain separate runtime gates.

## Rollback and risks

Revert this one patch commit and redeploy the identified prior build. No schema
rollback or reset required. Do not deploy over a live mission and infer runtime
state migration. Protection can increase retained live AI to the existing task
budgets; check both ordinary ambient evictions and eventual core cleanup. This
patch does not repair other lifecycle owners or prove all actors in the RPT were
task-owned. Keep OneDrive sync disabled for the mission workspace when deploying.

## Validation record

Base/branch: c56f4e6a78267e4827201043b0a10dcf0fa2bb25 /
fix/civsub-scene-retention-2026-09-09 (candidate working tree).

| Check | Result | Scope |
|---|---|---|
| Original Git blob SHA comparison | PASS | Four production inputs match the pinned GitHub blobs exactly. |
| `python3 tests/static/civsub_scene_retention_checks.py` | PASS: 28 tests | 11 source guards and 17 decision-model tests; NOT SQF execution. |
| Same test script with `FARABAD_ROOT` pointing to the unchanged source fixture | Expected FAIL: 7 failures, 2 errors | Nine source guards expose missing baseline protections/diagnostics; missing-guard errors are expected assertions via lookup. |
| Canonical `scripts/dev/sqflint_compat_scan.py --strict` on the four changed SQF files | PASS | Scanner content verified against Git blob 92e6fae1946c53ec64c4dbe229ef490914ad7509; no known parser-compat patterns. |
| `git diff --check` | PASS | No whitespace errors in candidate diffs. |
| Python byte compilation of the new test file | PASS | Test script syntax only. |
| `sqflint -e w` | BLOCKED locally | sqflint is not installed; network/package installation is unavailable. Check repository CI before merge. |
| Hosted Arma playtest | BLOCKED | No Arma runtime in this environment. |
| Dedicated MP, JIP, scene reuse, cleanup, persistence restart/reset | BLOCKED | Requires operator-run tests on an isolated, identified candidate. |

The local workspace is a verified source fixture, not a full checkout. No claim
of whole-repository regression coverage. Runtime confirmation is a merge/deploy
gate, not a result inferred from static passes.

## Evidence references

- Uploaded Arma3_x64_2026-09-09_21-51-27.rpt, lines 53818-53918: scene population,
  acceptance, and early near-objective despawns. Not every removed civ is proven
  to belong to a task.
- functions/ops/fn_opsSpawnLocalSupport.sqf: per-object and group task tags, scene
  civilian reuse, NetId return, explicit persistence flag.
- functions/world/fn_worldSpawnOverlayApply.sqf: overlay task tags and NetId return.
- functions/core/fn_execCleanupActive.sqf and fn_cleanupRegister.sqf: existing
  ownership handoff to core deferred cleanup.
- functions/civsub/fn_civsubCivConnect.sqf and fn_civsubCivCapsEnforce.sqf: shared
  registry attachment and existing protection-helper integration.

All source references use the pinned base above. Main and the user's deployed
mission remain unchanged until a separate merge/deployment decision.
