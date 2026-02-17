# Migrated Subsystem Verification Record

Purpose: track parity checks requested for migrated subsystems and provide copy/paste-ready `Tests Run` metadata for PRs.

## Subsystems in this verification pass

- CIVSUB persistence migration (`ARC_fnc_civsubPersistMigrateIfNeeded`)
- FARABAD logger dual-write path (`ARC_fnc_farabadLog`)

> Note: TASKENG migration baseline exists in docs, but no TASKENG migration implementation was located in `functions/` during this pass.

## Verification requirements

For each migrated subsystem, verify:

1. Same control-flow outcomes as before migration (logging remains side-effect free for gameplay flow).
2. Expected key events still appear in RPT under default config.
3. Extension-off and extension-on paths both execute without runtime errors.

## Commands executed in repository environment

### Static discovery (executed)

1. `rg -n "MIGRATE|migrate|schema_rev|PersistMigrate" functions | head -n 200`
   - Result: Found CIVSUB migration entrypoints only.
2. `rg -n "taskeng_v0_schema_rev|TASKENG_MIGRATE|taskeng_v0_thread_store|active_incident_refs|lead_linkage|generation_buffers" functions docs/projectFiles | head -n 200`
   - Result: TASKENG migration data exists in docs; no matching runtime migration implementation found in `functions/`.
3. `rg -n "ARC_fnc_farabad(Info|Warn|Error|Log)" functions | sed -n '1,220p'`
   - Result: FARABAD logger core helpers found in `functions/core/`.

### Runtime execution (not run in this environment)

Arma runtime + RPT stream are unavailable in this container, so live execution gates could not be performed here.

- Not run: `[] execVM "tests/run_all.sqf";`
  - Reason: requires Arma mission runtime.
- Not run: `missionNamespace setVariable ["FARABAD_log_toRPT", true, true]; missionNamespace setVariable ["FARABAD_log_toExtension", false, true];`
  - Reason: requires Arma mission runtime.
- Not run: `missionNamespace setVariable ["FARABAD_log_toRPT", true, true]; missionNamespace setVariable ["FARABAD_log_toExtension", true, true]; missionNamespace setVariable ["FARABAD_log_extensionName", "<extName>", true];`
  - Reason: requires Arma runtime + configured extension.

## PR `Tests Run` metadata block (copy/paste)

```md
Tests Run:
- `rg -n "MIGRATE|migrate|schema_rev|PersistMigrate" functions | head -n 200` → PASS (CIVSUB migration entrypoints located)
- `rg -n "taskeng_v0_schema_rev|TASKENG_MIGRATE|taskeng_v0_thread_store|active_incident_refs|lead_linkage|generation_buffers" functions docs/projectFiles | head -n 200` → PASS (TASKENG migration baseline found in docs; no runtime code hit in functions)
- `rg -n "ARC_fnc_farabad(Info|Warn|Error|Log)" functions | sed -n '1,220p'` → PASS (logger helpers located)
- `[] execVM "tests/run_all.sqf";` → Not run (Arma runtime unavailable in CI/container)
- `missionNamespace setVariable ["FARABAD_log_toRPT", true, true]; missionNamespace setVariable ["FARABAD_log_toExtension", false, true];` → Not run (Arma runtime unavailable)
- `missionNamespace setVariable ["FARABAD_log_toRPT", true, true]; missionNamespace setVariable ["FARABAD_log_toExtension", true, true]; missionNamespace setVariable ["FARABAD_log_extensionName", "<extName>", true];` → Not run (Arma runtime + extension unavailable)
```
