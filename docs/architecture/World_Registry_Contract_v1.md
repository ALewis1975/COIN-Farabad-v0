# Farabad COIN v0 - World Registry Contract v1

**Version:** 1.0  
**Date:** 2026-06-08  
**Status:** Planning contract  
**Mode:** F - Documentation-Only Changes  
**Layer:** L1 Terrain / World Registry  
**Scope:** Defines the foundation contract for terrain, locations, districts, routes, anchors, protected zones, objective index, and spatial lookup ownership. No runtime behavior changes.

---

## 0) Truth status

This document defines a planning contract and consumer pattern. It does not move world code or change terrain behavior.

| Claim type | Status |
|---|---|
| World Registry as ecosystem layer | Branch-local until parent ecosystem stack merges |
| Existing world/objective index behavior | Current source contains world indexing functions, but this document does not re-audit all consumers |
| Runtime behavior proof | Not claimed |

---

## 1) Purpose

World Registry owns spatial truth. Other systems should not independently reinvent terrain facts when they need named locations, district membership, roads, sites, anchors, routes, spawn candidates, protected zones, or objective value.

The registry should provide stable lookup surfaces for:

- District geometry and IDs.
- Named locations and settlement anchors.
- Terrain sites and key infrastructure.
- Road/route/convoy references.
- Airbase and protected-zone anchors.
- SitePop/Prison/world ambience anchors.
- Objective index scores and tiers.
- Safe spatial metadata for UI overlays.

---

## 2) Authority

| Item | Contract |
|---|---|
| Owner layer | L1 Terrain / World Registry |
| Owner subsystem | World |
| Writer authority | Server-owned derived registry state |
| Client role | Read-only through public snapshot, map overlay data, or Console VM if exposed |
| Persistence | None by default. Registry should be derived from mission data at startup. |
| UI authority | None. UI may display location facts, not define them. |

---

## 3) Registry families

| Family | Examples | Ownership rule |
|---|---|---|
| Named locations | towns, sites, compounds, task anchors | World owns stable ID, display name, position, radius/type where known. |
| Districts | D01-D20 and sentinel handling | CIVSUB owns population values; World owns geometry/spatial membership. |
| Terrain sites | transmitters, hospitals, fuel stations, bridges, roads | World owns lookup and derived metadata. |
| Protected zones | airbase, no-spawn zones, sensitive base areas | World owns spatial exclusion truth; consumers respect it. |
| Routes | convoy links, road nodes, gate routes, airbase taxi anchors when applicable | World/Airbase ownership must be explicit per route family. |
| Objective index | score, tier, ranked list | World owns computation; TASKENG consumes result. |
| Spawn/site anchors | SitePop, Prison, CIVLOC, ambience anchors | World owns marker validity and position resolution. Producing subsystem owns behavior. |

---

## 4) Planned read model

Recommended read model name: `ARC_worldRegistry_v1`.

Recommended fields:

| Field | Type | Meaning |
|---|---|---|
| `schema` | string | `ARC_worldRegistry_v1` |
| `version` | array | `[1,0,0]` |
| `builtAtServerTime` | number | Server build time |
| `locations` | array/map | Bounded named-location records |
| `districts` | array/map | District spatial metadata, not CIVSUB population state |
| `zones` | array/map | World zones and protected-zone metadata |
| `terrainSites` | array/map | Key infrastructure and site metadata |
| `routes` | array/map | Route IDs and endpoint/link metadata where authored |
| `objectiveIndex` | map | Objective score/tier by location ID |
| `rankedObjectives` | array | Ranked objective location IDs |
| `anchorIssues` | array | Bounded missing/invalid anchor diagnostics |

This read model should expose spatial facts, not internal engine objects or unbounded scans.

---

## 5) Consumers

| Consumer | Allowed use |
|---|---|
| CIVSUB | Resolve district geometry and active districts. CIVSUB owns population state, not geometry. |
| Threat / IED | Resolve protected zones, terrain opportunities, district ID, and task/lead spatial context. |
| TASKENG / SITREP | Select objectives, validate proximity, and display stable spatial facts. |
| SitePop / Prison | Resolve anchors and deny behavior when anchors are missing. |
| Airbase / CASREQ | Consume airbase anchors and protected-zone context where world-owned. |
| Logistics | Resolve routes, gates, convoy anchors, and cleanup context. |
| UI / Console VM | Display map overlays and location facts from public/VM data only. |

---

## 6) Lookup rules

1. Consumers should use stable IDs before display names.
2. Human-readable names are labels, not persistence keys.
3. Missing anchors must log explicit warnings and deny dependent behavior rather than guessing.
4. District geometry and CIVSUB population state must remain distinct.
5. Protected-zone checks must run before physical manifestation of ambient or threat behavior.
6. UI map overlays should consume bounded registry summaries, not raw internal registries.

---

## 7) Failure mode

If the registry or a required anchor is missing:

1. Dependent physical behavior should deny or degrade safely.
2. The producer logs a bounded warning with marker/location ID.
3. UI shows missing/unknown state rather than inventing a location.
4. TASKENG should avoid selecting unresolved objectives unless explicitly authored as unresolved.
5. Threat and ambience should not bypass protected-zone checks.

---

## 8) Validation requirements

| Validation | Required evidence |
|---|---|
| Static marker audit | Required markers/anchors resolve by stable ID/name. |
| Hosted MP | Objective index and site anchors resolve in representative scenarios. |
| Dedicated fresh start | Registry builds without blocking mission spine. |
| JIP | Late client sees public/VM spatial summaries where exposed. |
| Protected-zone proof | Threat, ambience, and logistics respect exclusions. |
| RPT review | Missing anchor warnings are bounded and actionable. |

---

## 9) Implementation non-goals

- Do not rescan the whole world continuously.
- Do not persist derived spatial caches unless a later spec requires it.
- Do not expose raw object handles to UI.
- Do not move subsystem behavior into World just because it consumes terrain.
- Do not use display names as persistence keys.

---

## 10) Next implementation task

Audit consumers of world locations, zones, protected zones, objective index, SitePop anchors, prison anchors, convoy gates, and airbase anchors. Decide which consumers need direct service calls, public snapshots, or Console VM summaries before code refactor.
