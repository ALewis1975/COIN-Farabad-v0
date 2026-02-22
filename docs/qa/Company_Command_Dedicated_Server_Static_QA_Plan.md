# Company Command / Snapshot Planning + Static QA Plan

## Scope
- Mission-static verification only (no Arma runtime dependency).
- Focus areas:
  1. Server single-writer guarantees
  2. Alpha/Bravo commander task generation
  3. Player-support vs independent operation balancing
  4. JIP snapshot visibility

## Acceptance Criteria

### 1) Server single-writer guarantees
- `ARC_STATE` writes remain server authoritative through `ARC_fnc_stateSet`/`ARC_fnc_stateGet` call flow; clients consume replicated snapshots only.
- Public snapshot writes (`ARC_pub_state`, `ARC_pub_stateUpdatedAt`) are only performed in server-gated publish paths.
- Bootstrap preserves server-owned initialization sequence (`stateLoad` -> command init/ticks -> publish hooks -> loops).

### 2) Alpha/Bravo commander task generation
- Company command bootstrap seeds exactly two command nodes (`COMPANY_ALPHA`, `COMPANY_BRAVO`) with expected commander labels/tokens.
- Virtual-ops tick path remains active from server bootstrap and updates/creates node-linked ops records.
- Company tasking and virtual ops are included in public snapshots for client visibility.

### 3) Player-support vs independent operation balancing
- Weighted op selection logic includes explicit `PLAYER_SUPPORT` and `INDEPENDENT_SHAPING` behaviors.
- Deconfliction rules apply when player task activity is in/near the same zone.
- Metadata captures balancing inputs (`playerTaskActive`, district/thread pressure, deconfliction mode).

### 4) JIP snapshot visibility
- Client startup waits for `ARC_pub_state` availability and reacts to `ARC_pub_stateUpdatedAt` changes.
- Client also reacts to company command snapshot timestamps (`ARC_pub_companyCommandUpdatedAt`).
- Server publishes `ARC_pub_companyCommand` and timestamp from the same publish cycle as core public snapshot.

## Static Verification Steps (No Runtime Required)

Run from repo root:

1. Verify server bootstrap sequencing and publish hook calls.
```bash
rg -n "ARC_fnc_stateLoad|ARC_fnc_companyCommandInit|ARC_fnc_companyCommandTick|ARC_fnc_companyCommandVirtualOpsTick|ARC_fnc_publicBroadcastState|ARC_fnc_incidentLoop" functions/core/fn_bootstrapServer.sqf
```
Expected: all listed calls present in server bootstrap flow.

2. Verify server-only public snapshot writes and guardrails.
```bash
rg -n "if \(!isServer\) exitWith|ARC_pub_state|ARC_pub_stateUpdatedAt|ARC_pub_companyCommand|ARC_pub_companyCommandUpdatedAt" functions/core/fn_statePublishPublic.sqf functions/core/fn_publicBroadcastState.sqf
```
Expected: non-server early exit + replicated writes in publish functions only.

3. Verify Alpha/Bravo seed model.
```bash
rg -n "COMPANY_ALPHA|COMPANY_BRAVO|REDFALCON 2|REDFALCON 3|Alpha Commander|Bravo Commander" functions/core/fn_companyCommandInit.sqf
```
Expected: both command nodes seeded with stable IDs/callsigns/labels.

4. Verify balancing logic and deconfliction pathways.
```bash
rg -n "PLAYER_SUPPORT|INDEPENDENT_SHAPING|QRF_STANDBY|deconflict|playerTaskActive|districtRisk|threadPressure" functions/core/fn_companyCommandVirtualOpsTick.sqf
```
Expected: weighted balancing + deconfliction branches are present.

5. Verify JIP snapshot watchers on client bootstrap.
```bash
rg -n "ARC_pub_state|ARC_pub_stateUpdatedAt|ARC_pub_companyCommandUpdatedAt|addPublicVariableEventHandler|JIP" initPlayerLocal.sqf
```
Expected: initial wait + event-driven refresh hooks for state/company snapshots.

## Expected State Keys

### Authoritative server state keys (`ARC_STATE` payload)
- `companyCommandNodes`
- `companyCommandTasking`
- `companyCommandCounter`
- `companyCommandLastTickAt`
- `companyVirtualOps`
- `companyVirtualOpsCounter`
- `companyVirtualOpsLastRollupAt`

### Public replication keys (mission namespace)
- `ARC_pub_state`
- `ARC_pub_stateUpdatedAt`
- `ARC_pub_companyCommand`
- `ARC_pub_companyCommandUpdatedAt`
- `ARC_pub_stateSchema`
- `ARC_consoleVM_meta`

## Dedicated-Server-Only Validation (Deferred)
The following checks remain **BLOCKED** without a true dedicated server run:
- Persistence durability across restart (company command + virtual ops continuity)
- JIP late-client snapshot consistency during active virtual-ops changes
- Ownership/reconnect edge cases for command-task updates

## Safe Rollback (Mission Fallback)
If operators need to quickly stabilize mission behavior:

1. **Disable scheduler init hooks** in `functions/core/fn_bootstrapServer.sqf` by temporarily commenting out:
   - `[] call ARC_fnc_companyCommandTick;`
   - `[] call ARC_fnc_companyCommandVirtualOpsTick;`
   - (optional broader scheduler rollback) `[] call ARC_fnc_incidentLoop;` and `[] call ARC_fnc_execLoop;`

2. **Disable registry/public publish hooks** in the same file by temporarily commenting out:
   - `[] call ARC_fnc_publicBroadcastState;`
   - `[] call ARC_fnc_intelBroadcast;`
   - `[] call ARC_fnc_leadBroadcast;`
   - `[] call ARC_fnc_threadBroadcast;`

3. Keep `[] call ARC_fnc_stateLoad;` intact so mission can still boot with persisted core state.

4. Re-enable hooks one-by-one after verification in dedicated environment.

> Rollback should be reverted immediately after incident mitigation to restore normal commander tasking and client snapshot fidelity.
