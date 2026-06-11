# RPT Test Harness Follow-up

Created during the 2026-06-11 RPT remediation pass.

## Remaining direct runner cleanup

The production-side guard in this PR protects console-triggered test runs by enabling `ARC_TEST_mode` and `ARC_TEST_tocDryRun` while `tests/run_all.sqf` executes. A follow-up edit should still clean up the runner directly:

- replace direct `missionNamespace setVariable ["remoteExecutedOwner", ...]` calls with explicit owner arguments
- replace `createVehicle ["Logic", ...]` with `createGroup sideLogic` plus `createUnit ["Logic", ...]`, or use the active player object when available
- update `ARC_TEST_fnc_varRestore` to restore saved nil values without referencing an undefined `_v`
- update `UT-DIAG-001` to expect the public pairs-array payload used by `ARC_fnc_statePublishPublic`

This note exists because the console runner is a large single-file suite and should be patched as a full-runner change rather than partially rewritten through the PR body.
