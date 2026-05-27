# Dedicated Server Activation Plan — 2026-05-27

**Status:** Active. Track 1 (security validator fix + observability stub) and
Track 5.2 (sync script SHA verification) and tooling scaffolding land with this
PR. Tracks 2 and 4 are server-admin owned and follow this PR.

## Context

On 2026-05-27 the Farabad COIN mission was first deployed to a dedicated
Armahosts Windows VPS. The TOC "Generate Next Incident" button surfaces

> "Requested next incident: pending server decision."
> *(8s later)* "No server decision received yet. Check TOC/OPS panel for
> latest incident-generation status."

without ever publishing `ARC_pub_nextIncidentResult`. The same screenshot also
shows an empty TOC Queue.

Forensic of `serverRpts/ArmA3Server_x64_2026-05-27_07-27-28.rpt` shows the
server is silently denying every operator-driven TOC RPC after
`ARC_serverReady = true`, all with the same reason:

```
SECURITY: ARC_fnc_tocRequestNextIncident invoked without RemoteExec context
(remoteExecutedOwner missing).
event=TOC_NEXT_INCIDENT_SECURITY_DENIED reason=MISSING_REMOTE_CONTEXT
```

Same line repeats for `ARC_fnc_tocRequestForceIncident`,
`ARC_fnc_intelQueueDecide`, `ARC_fnc_missionScoreGenerate`, and others.

## Root cause

`ARC_fnc_rpcValidateSender` re-reads `remoteExecutedOwner` from its own scope
via `isNil "remoteExecutedOwner"`. Per BIS engine semantics,
`remoteExecutedOwner` is set as a **local** variable on the directly
remoteExec'd function's top frame and does **not** propagate into nested
`call` frames — least of all on dedicated, where this is observably the
failure mode. Result:

1. Client `remoteExec` is delivered → server enters the handler.
2. Handler `call`s the validator. The validator sees `remoteExecutedOwner` as
   nil.
3. Validator returns `false` (because the handler passed
   `_requireRemoteContext = true`).
4. Handler `exitWith`s before ever publishing
   `ARC_pub_nextIncidentResult` / `ARC_pub_nextIncidentLastDenied` (the deny
   notification path is gated on `_owner > 0`, which is also nil).
5. Client's 8-second waitloop times out → operator sees the second toast.

## Five-track plan

### Track 1 — Unblock the command cycle (P0, code)

| Step | Owner | Status |
|------|-------|--------|
| Add optional `_callerOwner` 6th param to `ARC_fnc_rpcValidateSender`; treat the explicitly-passed owner as authoritative; only fall back to scope read when sentinel `-1` is passed | this PR | ✅ |
| Update all server-side callers of `ARC_fnc_rpcValidateSender` (~38 files) to capture `remoteExecutedOwner` at the outer remoteExec frame and pass it explicitly as the 6th arg | this PR | ✅ |
| Confirm `ARC_fnc_tocRequestNextIncident` already publishes `ARC_pub_nextIncidentResult` on the security-denied path when `_owner > 0` (no change needed; with Track 1 the owner is now reliably > 0) | this PR | ✅ |

**Acceptance:** Re-run `docs/qa/Dedicated_JIP_Validation_Matrix.md` §3.1 D-1
(TOC Next Incident on dedicated). Operator sees the green "Server approved
your request…" toast, RPT shows `TOC_NEXT_INCIDENT_OK_GENERATED` or
`OK_REHYDRATED`. Zero `MISSING_REMOTE_CONTEXT` deny entries on
operator-driven RPCs. Log to `tests/TEST-LOG.md`.

### Track 2 — Lock the mod stack (P0, server admin)

The matrix's prereq §2 says any modline change invalidates prior PASS results.
Today's RPT shows the live stack ≠ the documented one.

| Step | Owner |
|------|-------|
| Adopt `docs/projectFiles/Ambient_Dev_Mods_2026-04-01.html` as the canonical preset; remove every "Skipped loading of addon" target (Vietnam/SOG, WS/LXWS, GM, CSLA, Aegis, SPE/SPEX, Atlas, RKSL, RH_DE, EF, CFP, ACRE, etc.) from the Armahosts `-mod=` line | server admin |
| Resolve `Expansion_Mod_Police` `Missing ';'` parse errors by upgrading or removing that mod build | server admin |
| Pin versions in `docs/operations/Server_ModLine.md`: the exact `-mod=` string, server keys, ACE/CBA/3CB/RHS/CUP versions | server admin |

**Acceptance:** Fresh-start RPT has only the documented "Known RPT Noise"
lines from `README.md` §134-136 and zero `Skipped loading of addon` lines
for mods you expect to load.

### Track 3 — Sharpen the dedicated observability loop (P1)

| Step | Owner | Status |
|------|-------|--------|
| FARABAD dual-write logger sink (already documented; runtime-enable helper added) | this PR (helper only) | ✅ helper `tools/dev_deploy/enable_dual_write.sqf` |
| Surface `ARC_pub_nextIncidentLastDenied` to the operator UI as a client toast | follow-up | deferred |
| Add a server-diagnostics panel (Console_VM_v1 extension) reading `ARC_serverReady`, snapshot ages, last 10 `SECURITY_DENIED` events | follow-up | deferred |
| PowerShell RPT-tail script with the canonical `[ARC][SEC]\|MISSING_REMOTE_CONTEXT\|SECURITY_DENIED\|Error in expression` filter | this PR | ✅ `tools/dev_deploy/tail.ps1` |

**Acceptance:** From the dev workstation: restart the dedicated process,
exercise a TOC action, and read the new RPT lines through the tail script
without RDP.

### Track 4 — Walk the validation matrix (P1)

Gated on Track 1 + Track 2 landing. Run
`docs/qa/Dedicated_JIP_Validation_Matrix.md` §3.1 → §3.7 in order; log each
row in `tests/TEST-LOG.md`. Fail-rows open bounded Mode-A fixes.

### Track 5 — Source-of-truth pipeline (P2)

| Step | Owner | Status |
|------|-------|--------|
| Extend `tools/sync_mission_to_arma_profile.ps1` verified-file SHA list to also cover `initServer.sqf`, `functions/core/fn_rpcValidateSender.sqf`, `functions/core/fn_tocRequestNextIncident.sqf`, `config/CfgRemoteExec.hpp` | this PR | ✅ |
| Add `tools/dev_deploy/` scaffold (`clone.ps1`, `deploy.ps1`, `tail.ps1`, `enable_dual_write.sqf`) | this PR | ✅ |
| Build the mission as a `.pbo` via MakePbo in CI on commit-to-main and publish as a release artifact | follow-up | deferred |

## Development pattern on the Armahosts VPS

Hybrid local+remote, **edit locally, deploy to server, iterate against the
real dedicated process**:

1. Edit locally in VS Code with `scripts/dev/sqflint_compat_scan.py` and
   `sqflint` running.
2. On the VPS, install Git, then once: `tools/dev_deploy/clone.ps1`.
3. Each iteration: `tools/dev_deploy/deploy.ps1` (git pull + sync +
   SHA verify).
4. Restart the dedicated process from the Armahosts panel.
5. Tail the RPT from the dev workstation via
   `tools/dev_deploy/tail.ps1` (no RDP).
6. JIP coverage uses a second Steam profile joining after the server is up.

**Do not edit on the server.** Server-side edits diverge from the repo and
lose lint/CI. If you must hotfix on the box, push to a `work/hotfix/*` branch
and open a PR back to `dev`.

## Information needed from the user

To unblock Track 2 and exercise Track 4 against the live server:

1. **Server access** — Armahosts control-panel URL, admin account, RCON creds.
   At minimum: read live RPT, restart the dedicated process, edit `-mod=`.
2. **Exact modline** the server currently launches with (the RPT-derived
   guess is incomplete).
3. **Server folder layout** — path to `mpmissions\`, path to the RPT folder,
   FTP/WinSCP endpoint vs. control-panel file browser only.
4. **BattlEye policy** — on/off; allowed filter edits.
5. **Slot allocation** — smallest slot kit for JIP testing
   (1× CO seat with OMNI token + 1× rifle seat in another group).
6. **Persistence target** — live save folder vs. wipeable sandbox folder for
   Matrix §3.2 save/restart semantics.

## Risk / Rollback

Track 1 is backward-compatible: the validator's new 6th param is optional
with a sentinel default of `-1`. Callers that have not been migrated still
get the legacy scope-read fallback. The hosted-server self-call branch is
preserved.

Rollback: revert this PR; the prior behavior is restored exactly. No data
or save-format changes.
