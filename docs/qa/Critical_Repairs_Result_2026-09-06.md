# Critical repair result â€” 6 September 2026

Review baseline: `0151396c811939aa45a1190510d32605f18f4c7f` in ALewis1975/COIN-Farabad-v0. The authorized scope covers every P0/P1 review finding, plus four directly connected P2 fixes. The code is prepared in an isolated repair checkout; dedicated-server acceptance remains a release gate.

## Repair coverage

| Findings | Implemented correction | Verification focus |
|---|---|---|
| F01â€“F03 | Function-level authorization rejection; sender binding; current device/task association; remove client access to unrestricted suicide detonation and code-bearing action installation. | Rejection control flow, mutation tripwires, guard-removal negative controls; actual network identity still requires Arma. |
| F04, F06â€“F10 | Reject forbidden generation before state changes; collect order/case task IDs during reset; one parent-task owner; stable lead decay; preserve live orders at capacity; recreate accepted order views. | Same-age/cadence decay, admission outcomes, capacity/reference protection, stable task specifications and reset ID collection. |
| F05 | Versioned core/CIVSUB clock envelopes; freeze offline progression; preserve remaining budgets and copied records; quarantine unsupported formats; preserve accepted progress during world-object reconstruction. | Restart arithmetic, legacy handling, deep-copy isolation, repeated load, VBIED elapsed/pause carry and reconstruction guards. |
| F11â€“F14, F25, F28 | Connect existing CAS lifecycle to authenticated actions and editable input; publish a complete inbox; bind JTAC/aircrew capability; bound records, text, replay and retention; count completed sorties from the actual store. | Guarded transitions, cancellation/input paths, inbox and reset integration, retention/counting. |
| F15â€“F20, F24 | Keep armed parked-threat monitoring active; enforce tier admission; reserve and cancel delayed workers; correct spawn coordinates; register all actors for cleanup; expire latent records and prune only unreferenced cleaned history. | Identity, transition legality, cleanup convergence, bounded maintenance and reference retention. |
| F26 | Match copy/verifier exclusions and reject overlapping deployment roots. | Ten disposable actual-copy cases. |

## Compatibility and campaign handling

The existing record owners, stable IDs, compact CAS records, CIVSUB array serialization and thread tuple shapes remain. New clock metadata is independently versioned. Optional lifecycle and elapsed-duration fields have defaults; no planning-only subsystem is introduced. The known CIVSUB JSON/influence-math baseline drift remains explicit audit work, outside these critical repairs.

New saves use `persistenceClock = [1, savedServerTime, UTC, "FREEZE_OFFLINE"]`. Current legacy core saves migrate using the exact `s1RegistryUpdatedAt` save anchor. Much older unanchored core saves are preserved and loading/saving stops until a verified anchor is supplied or the operator explicitly resets. Legacy CIVSUB saves retain campaign data with bounded conservative cooldown migration. Each owner keeps one pre-clock backup; reset clears that backup and writes a clean campaign. Back up both profile stores before first deployment.

Minimal compatibility substitutions in touched SQF files allow the unchanged strict linter to analyze those files. The complete repository's existing unsupported shorthand outside this patch is not a new regression and has not been swept into this repair.

## Validation and release gate

All identified P0/P1 code repairs are implemented. Final local validation: 45/45 existing checks (including the final whitespace recheck); strict compatibility, lint and parsing pass for all 117 changed SQF files; 629 function registrations are consistent. Targeted tests pass: security 38 production cases plus five rejected mutants; command 23 cases plus one rejected mutant; CAS 25 transitions and 11 integration checks; clock 21; lead decay 12; threat 19 lifecycle and 20 reconstruction assertions plus 31 source checks. The deployment fixture passes all 10 cases. Executed commands and results are recorded in `tests/TEST-LOG.md`. SQF-VM tests execute pure production helpers or explicitly documented host adapters; neither result proves Arma networking, physics, scheduled execution, locality, UI rendering or dedicated persistence durability.

Before releasing, run the ten-minute smoke in `Critical_Repairs_2026-09-06.md` and the focused acceptance cases in its Security, Command, CAS and Threat annexes on a disposable dedicated campaign with two clients and JIP. Expect zero state changes after denied requests, one stable parent/order task, preserved remaining time after restart, a complete CAS inbox before any new mutation, no stale threat worker, and reset/cleanup snapshots without orphan references. Record actual RPT evidence before promoting the drafts.

## Remaining work outside critical scope

F21 civilian off-road fallback, F22 civilian slope thresholds, F23 identity eviction order and F27 ORBAT/metadata reconciliation remain P2 follow-up items. They are not claimed repaired. Main remains unchanged until the draft repairs are reviewed and merged; no live mission/profile was deployed by this task.

## Rollback

Review/publish changes as separate Mode G deployment, Mode I security and Mode A behavior commits. Revert the appropriate commit in reverse dependency order. Stop the server before rolling back runtime code; restore matching core and CIVSUB profile backups for clock/lifecycle rollback. Reverting the security changes restores the original exposure and should only occur in an isolated diagnostic copy. Keep OneDrive synchronization off the active mission directory.
