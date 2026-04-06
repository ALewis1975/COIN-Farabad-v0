# AIR / TOWER UI Snapshot Contract v1

**Date:** 2026-04-06  
**Status:** Locked for implementation  
**Source of truth:** `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/architecture/AIR_TOWER_Vision_Architecture_Plan.md`

---

## 1) Publication model

The server publishes a normalized AIR/TOWER snapshot to:

- `missionNamespace getVariable ["ARC_pub_airbaseUiSnapshot", []]`
- `missionNamespace getVariable ["ARC_pub_airbaseUiSnapshotUpdatedAt", -1]`

The payload is a SQF key/value-pair array so it remains compatible with existing client readers:

```sqf
[
    ["v", 1],
    ["rev", 123],
    ["updatedAt", 456.7],
    ["freshnessState", "FRESH"],
    ["runway", [...]],
    ["alerts", [...]]
]
```

---

## 2) Top-level fields

| Key | Type | Required | Notes |
|---|---|---:|---|
| `v` | NUMBER | yes | Contract version, locked at `1` |
| `rev` | NUMBER | yes | Monotonic publish revision |
| `updatedAt` | NUMBER | yes | `serverTime` of last publish |
| `freshnessState` | STRING | yes | `FRESH`, `STALE`, or `DEGRADED` |
| `runway` | ARRAY | yes | Nested pair-array object |
| `alerts` | ARRAY | yes | Max 5 |
| `decisionQueue` | ARRAY | yes | Max 5 |
| `arrivals` | ARRAY | yes | Max 6 |
| `departures` | ARRAY | yes | Max 6 |
| `pendingClearances` | ARRAY | yes | Max 6 |
| `staffing` | ARRAY | yes | 3 lanes: tower, ground, arrival |
| `recentEvents` | ARRAY | yes | Max 8 |
| `clearanceHistory` | ARRAY | yes | Max 5 |
| `controllerTimeouts` | ARRAY | yes | Tower / ground / arrival timeouts |
| `automationDelays` | ARRAY | yes | Tower / ground / arrival fallback delays |
| `casTiming` | ARRAY | yes | AIR-facing CAS timing summary only |
| `debug` | ARRAY | no | Present only when debug mode is enabled |

---

## 3) Nested field definitions

### `runway`

| Key | Type | Notes |
|---|---|---|
| `state` | STRING | `OPEN`, `RESERVED`, `OCCUPIED`, `BLOCKED` |
| `ownerCallsign` | STRING | Empty string when unowned |
| `activeMovement` | STRING | `CLEAR`, `DEPARTING`, `LANDING`, `BLOCKED` |
| `holdState` | BOOL | `true` when departure hold is active |
| `age` | NUMBER | Seconds since last replicated update |

### `alerts[]`

Each row:

```sqf
[text, severity, sourceId]
```

- `severity`: `INFO`, `CAUTION`, `CRITICAL`
- `sourceId`: request id / flight id / subsystem token

### `decisionQueue[]`

Each row:

```sqf
[text, requestId, callsign, priority, type]
```

### `arrivals[]`

Each row:

```sqf
[flightId, callsign, category, phase, ageS, priority, status]
```

### `departures[]`

Each row:

```sqf
[flightId, callsign, category, state, ageS, priority, status]
```

### `pendingClearances[]`

Each row:

```sqf
[requestId, requestType, callsign, requestedAt, priority, decisionNeeded, ownerName, meta]
```

### `staffing[]`

Each row:

```sqf
[lane, mode, operatorName]
```

### `recentEvents[]`

Each row:

```sqf
[timestamp, label]
```

### `clearanceHistory[]`

Each row:

```sqf
[requestId, status, updatedAt, decidedBy, action]
```

### `controllerTimeouts`

| Key | Type |
|---|---|
| `tower` | NUMBER |
| `ground` | NUMBER |
| `arrival` | NUMBER |

### `automationDelays`

| Key | Type |
|---|---|
| `tower` | NUMBER |
| `ground` | NUMBER |
| `arrival` | NUMBER |

### `casTiming`

| Key | Type | Notes |
|---|---|---|
| `casreqId` | STRING | Empty when none |
| `rev` | NUMBER | CASREQ public revision |
| `district` | STRING | AIR-facing district reference only |
| `state` | STRING | AIR-facing CAS state only |

### `debug`

| Key | Type |
|---|---|
| `snapshotRev` | NUMBER |
| `snapshotAge` | NUMBER |
| `blockedRouteCount` | NUMBER |
| `blockedRouteReason` | STRING |
| `blockedRouteSource` | STRING |
| `blockedRouteTail` | ARRAY |
| `rawOwnerIds` | ARRAY |
| `routeValidation` | ARRAY |
| `casreqId` | STRING |
| `casreqRev` | NUMBER |
| `casreqDistrict` | STRING |
| `casreqState` | STRING |

---

## 4) Bounded defaults

| Collection | Max |
|---|---:|
| `alerts` | 5 |
| `decisionQueue` | 5 |
| `arrivals` | 6 |
| `departures` | 6 |
| `pendingClearances` | 6 |
| `recentEvents` | 8 |
| `clearanceHistory` | 5 |

---

## 5) R/A/G semantics

### Runway

- **Green:** `OPEN`
- **Amber:** `RESERVED` or departure hold active
- **Red:** `OCCUPIED`, `BLOCKED`, or emergency conflict

### Arrivals

- **Green:** no conflict, normal inbound sequencing
- **Amber:** holding, delayed, or awaiting tower decision
- **Red:** emergency, conflict, or runway unavailable

### Departures

- **Green:** normal sequencing
- **Amber:** backlog, active hold, or queue management required
- **Red:** blocked route, emergency conflict, or runway unavailable

### Tower mode

- **Green:** manned lane coverage or healthy automation
- **Amber:** auto fallback or timeout window warning
- **Red:** degraded snapshot or runway/queue conflict

### Alerts

- **Green:** none
- **Amber:** caution present
- **Red:** critical alert present

---

## 6) Freshness wording rules

- `Updated 8s ago` means freshness
- `State unchanged for 45m` means stability
- The UI must not conflate those two concepts

