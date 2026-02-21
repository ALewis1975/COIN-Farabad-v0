# Copilot Instructions for COIN-Farabad-v0 (SQF / Arma 3)

## 1) Runtime context and authority model
- Language/runtime: SQF on Real Virtuality 4 (Arma 3 mission environment).
- Treat the **dedicated server as the single authority** for persistent/shared mission state.
- Clients are read-only for authoritative state: clients may request actions, never finalize global state.
- Apply state changes only on server-side execution paths (`isServer`/server-owned handlers), then replicate to clients.
- Keep ownership explicit: document where each variable is written, and avoid multi-writer logic.

### Namespace ownership rules

| Namespace | Written from | Replicated? | Purpose |
|---|---|---|---|
| `missionNamespace setVariable [k, v, true]` | Server only | Yes (all clients) | Shared mission state |
| `missionNamespace setVariable [k, v, false]` | Server only | No | Server-local scratch |
| `uiNamespace setVariable` | Client only | Never | Local UI state only |
| `object setVariable [k, v, true]` | Object owner | Yes | Per-object replicated state |
| `private _varName` | Anywhere | Never | Function-local only |

Never write to `missionNamespace` from a client without server mediation.

---

## 2) SQF language conventions (required patterns)

### Parameter handling
- Always use `params` with type guards and defaults:
  ```sqf
  params [
      ["_grp", grpNull, [grpNull]],
      ["_role", "", [""]],
      ["_opts", [], [[]]]
  ];
  ```
- Never use bare `_this select 0` without a guard.

### Variable declaration
- Always declare locals with `private _varName` before use.
- Never use undeclared variables; check RPT for `undefined variable` warnings.

### Early-exit guard ordering (top of every function)
```sqf
if (!isServer) exitWith { false };               // authority guard first
if (isNull _grp) exitWith { false };             // null checks second
if (!(_role isEqualType "")) exitWith { false };  // type checks third
// logic follows
```

### Type checking
- Use `isEqualType`: `_x isEqualType []`, `_x isEqualType ""`, `_x isEqualType 0`
- Do NOT use `typeName _x == "ARRAY"` etc.

### Array indexing
- Use `select` with bounds guards, not `#` operator (sqflint compat).
- Use `_arr # _i` only where sqflint compat is confirmed acceptable; prefer `_arr select _i`.

### Boolean short-circuit guards
```sqf
if (_condition && { _expensiveCheck }) then { ... };  // braced second operand = lazy evaluation
```

### Function return values
- The last evaluated expression is the return value; use `exitWith { value }` for early returns.

---

## 3) Networking / `remoteExec` rules

- **Always use named functions** for `remoteExec` — never anonymous code blocks:
  ```sqf
  // CORRECT
  [_arg] remoteExec ["ARC_fnc_myFunction", 2];
  // WRONG - do not do this
  [_arg] remoteExec [{ ... }, 2];
  ```
- **Target parameter conventions:**
  - `2` = server
  - `0` = all clients (including server if `hasInterface`)
  - `owner _unit` = specific client machine
  - `-owner _unit` = all except that client
- **JIP flag** (`true`/`false` fourth param): set `true` only for object-bound persistent actions (hold actions, objective markers). Default `false`.
- **`remoteExecCall`** (blocking) for client→server RPCs where return value matters; `remoteExec` (non-blocking) for fire-and-forget.
- **Server-side remoteExec receivers must validate sender identity:**
  ```sqf
  if (!isServer) exitWith { false };
  if (!isNil "remoteExecutedOwner") then {
      private _reo = remoteExecutedOwner;
      if (_reo > 0 && { (owner _actor) != _reo }) exitWith {
          diag_log format ["[ARC][SEC] %1 denied: sender-owner mismatch reo=%2 actorOwner=%3",
              "ARC_fnc_yourFunction", _reo, owner _actor];
          false
      };
  };
  ```
- All remoteExec-able functions must be in `CfgRemoteExec` allowlist (see `docs/security/RemoteExec_Hardening_Plan.md`).

---

## 4) Function naming and registration

- **Namespace prefix**: all mission functions use `ARC_fnc_` (e.g. `ARC_fnc_civsubInteractDetain`).
- **File naming**: `functions/<subsystem>/fn_<camelCaseName>.sqf` → registers as `ARC_fnc_<camelCaseName>`.
- **Registration**: every new function must be added to `config/CfgFunctions.hpp` before it can be called as `ARC_fnc_*`.
- **Never call a function before it is guaranteed compiled** — respect bootstrap order (`initServer.sqf` → bootstrap → subsystem inits).
- **Server-only functions**: add `if (!isServer) exitWith {};` as the very first line.
- **Client-only functions**: add `if (!hasInterface) exitWith {};` as the very first line.

---

## 5) Logging conventions

Always use structured `diag_log` with the module prefix:
```sqf
diag_log format ["[ARC][INFO] ARC_fnc_myFunction: message val=%1", _val];
diag_log format ["[ARC][WARN] ARC_fnc_myFunction: unexpected state var=%1", _var];
diag_log format ["[ARC][SEC] ARC_fnc_myFunction: security violation reo=%1 actor=%2", _reo, name _actor];
diag_log format ["[CIVSUB][SEC] ARC_fnc_civsubXxx: sender-owner mismatch"];
```
- Never use bare `diag_log "message"` without context.
- Never silently swallow errors — always log on authority or replication mismatch.

---

## 6) sqflint compat — banned constructs and approved workarounds

Before writing or editing SQF, consult `docs/qa/SQFLINT_COMPAT_GUIDE.md`.

| Banned | Use instead |
|---|---|
| `findIf { ... }` | `forEach` + `_forEachIndex` + `exitWith` |
| `trim _value` (direct) | `private _trimFn = compile "params ['_s']; trim _s"; [_value] call _trimFn` |
| `fileExists _path` (direct) | Wrap in compiled helper |
| `_map getOrDefault [k, d]` (method form) | `[_map, k, d] call getOrDefault` |
| `toUpperANSI` | `toUpper` |
| `#` array indexing | `select` with bounds guard |

Run the compat scanner before `sqflint`:
```
python3 scripts/dev/sqflint_compat_scan.py --strict <changed .sqf files>
sqflint -e w <changed .sqf files>
```

---

## 7) Test framework conventions

Tests live in `tests/` and run via `tests/run_all.sqf` (server-side unless testing client-local behavior).

Use the provided test helpers — do NOT use raw `diag_log` comparisons:
```sqf
// Assert a boolean condition
[(_result isEqualTo expectedValue), "TEST_ID", "description", []] call ARC_TEST_fnc_assert;

// Assert type
[_result, "TEST_ID", "description", [typeName ""]] call ARC_TEST_fnc_assertType;

// Measure timing
["TEST_ID", "description", { [] call ARC_fnc_myExpensiveFunction }] call ARC_TEST_fnc_measure;

// Isolate state across tests
private _snap = [["myVar_a", "myVar_b"]] call ARC_TEST_fnc_varSnapshot;
// ... test body ...
[_snap] call ARC_TEST_fnc_varRestore;
```

---

## 8) External knowledge sources — consult before writing SQF or config

When writing, reviewing, or reasoning about SQF code or Arma 3 config, agents MUST use these authoritative external references — not general programming knowledge or assumptions.

### Primary references (check these first)

| Source | URL | Use for |
|---|---|---|
| **BI Community Wiki (BIC)** | https://community.bistudio.com/wiki/ | SQF command syntax, locality rules, `BIS_fnc_*`, config classes (`CfgFunctions`, `CfgRemoteExec`, `description.ext`), event handler names |
| **Multiplayer Scripting (BIC)** | https://community.bistudio.com/wiki/Multiplayer_Scripting | Locality model, global vs. local effect, JIP, remoteExec targeting — **read before touching any networked code** |
| **CfgRemoteExec reference** | https://community.bistudio.com/wiki/Arma_3:_CfgRemoteExec | Allowlist syntax, `mode`/`jip` settings, security surface |
| **ACE3 documentation** | https://ace3.acemod.org/ | ACE interaction framework, medical variables, captive/handcuff state, field rations |
| **ACE3 source (GitHub)** | https://github.com/acemod/ACE3 | ACE function signatures, variable names (`ACE_isUnconscious`, `ACE_captives_isHandcuffed`), add-action API |
| **CBA_A3 wiki** | https://github.com/CBATeam/CBA_A3/wiki | `CBA_fnc_waitUntilAndExecute`, per-frame handlers, extended event handlers |
| **sqflint (GitHub)** | https://github.com/SkaceKamen/sqflint | Linter flags, known false positives, `--help` |

### Internal project references (authoritative for this mission)

| Source | Path | Use for |
|---|---|---|
| **Project dictionary** | `docs/projectFiles/farabad_project_dictionary_v_1.1.md` | Canonical naming for all systems, IDs, and concepts |
| **Mission design guide** | `docs/projectFiles/Farabad_COIN_Mission_Design_Guide_v0.4_2026-01-27.md` | System intent, cross-cutting standards, design rationale |
| **sqflint compat guide** | `docs/qa/SQFLINT_COMPAT_GUIDE.md` | Banned SQF constructs and approved workarounds for this repo |
| **RemoteExec hardening plan** | `docs/security/RemoteExec_Hardening_Plan.md` | Allowlist policy, RPC surface, sender validation requirements |
| **Subsystem baselines** | `docs/projectFiles/Farabad_*.md` | Implementation contracts per subsystem (CIVSUB, CASREQ, THREAT, TASKENG, AIRBASESUB) |
| **Army doctrine refs** | `docs/projectFiles/US_Army_Doctrine_References.md` | Doctrinal basis for mission mechanics (ADP 6-0, FM 3-24, etc.) |

### Key lookup patterns

When in doubt about a SQF command, **always** verify on the BIC wiki:
- **Locality**: where can this run? (server / any / local effect only)
- **Return value**: what does it return? (many commands return `Nothing`)
- **Scheduled vs. unscheduled**: does this command require a scheduled environment (`spawn`/`execVM`)? Can it be used in `call`?
- **JIP behaviour**: does this command or event fire for JIP clients?

When using ACE3 variables, **verify current variable names** in the ACE3 source — they change between ACE versions and assumptions from older missions may be wrong.

---

## 9) Required local validation before merge

Run this minimum flow locally before merging:
- **Compat + lint pass**
  - `python3 scripts/dev/sqflint_compat_scan.py --strict <changed files>`
  - `sqflint -e w <changed files>`
- **Compile audit**
  - Verify mission scripts compile without SQF syntax/runtime load errors.
  - Check RPT/log output for undefined variables, missing functions, and script errors.
- **Local multiplayer checks**
  - Host local MP session (dedicated-like or hosted) with at least one client.
  - Exercise changed gameplay paths and networked interactions.
  - Confirm state replication and no authority violations (server writes, clients consume).

---

## 10) Deferred checks (must run in dedicated server + JIP environment)

These are not complete in basic local runs and must be validated separately:
- Dedicated server persistence/ownership behavior over longer sessions.
- Join-in-progress (JIP) synchronization for all changed state/UI.
- Late-client recovery for in-flight events and mission variables.
- Respawn/reconnect edge cases where state reinitialization can diverge.

---

## 11) Required test-log update

- After each validation pass, append/update the repo test log at:
  - `tests/TEST-LOG.md`
- Include:
  - Date/time, branch/commit, scenario, commands/steps, observed result.
  - Status label per check:
    - `PASS` (validated and clean)
    - `FAIL` (reproducible issue)
    - `BLOCKED` (environment unavailable, e.g., no dedicated/JIP rig)

---

## 12) Red-flag patterns — never do these

- Client-side mutation of authoritative mission state (`missionNamespace`/global vars) without server mediation.
- Remote execution paths that allow clients to self-authorize privileged actions.
- Multiple writers for the same replicated variable without explicit arbitration.
- UI/event handlers directly applying global state changes instead of server requests.
- Silent failure patterns (missing log/assert on authority or replication mismatch).
- Anonymous code blocks passed to `remoteExec` (use named `ARC_fnc_*` functions only).
- Functions not registered in `CfgRemoteExec` being called via `remoteExec`.
- Using `#` indexing, `findIf`, direct `trim`/`fileExists`, or `toUpperANSI` (sqflint compat violations).