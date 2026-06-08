# Farabad COIN v0 - Runtime Boundary Policy v1

**Version:** 1.0  
**Date:** 2026-06-08  
**Status:** Planning contract  
**Mode:** F - Documentation-Only Changes  
**Layer:** L0 Runtime Boundary  
**Scope:** Defines the runtime boundary policy contract for player count, scheduler budget, AI/vehicle pressure, cleanup pressure, degraded mode, and validation context. No runtime behavior changes.

---

## 0) Truth status

This document defines a planning contract only. It does not assert that `ARC_runtimePolicy_v1` currently exists in code.

| Claim type | Status |
|---|---|
| Runtime Boundary layer exists as an ecosystem concept | Branch-local until parent ecosystem stack merges |
| Runtime policy implementation | Not implemented by this document |
| Runtime behavior proof | Not claimed |

---

## 1) Purpose

Runtime Boundary is the foundation layer that prevents ambient systems from competing with the mission spine. It provides a common policy surface for systems that schedule, spawn, despawn, clean up, or degrade behavior under server pressure.

It should answer these questions:

- How many players are active?
- Which districts or bubbles are active?
- Are scheduler budgets normal, reduced, or locked down?
- Are AI/group/vehicle pressures within safe limits?
- Is safe mode or degraded mode active?
- What should nonessential ambience do under load?
- What runtime facts should be recorded with validation evidence?

---

## 2) Authority

| Item | Contract |
|---|---|
| Owner layer | L0 Runtime Boundary |
| Owner subsystem | Core / QA |
| Writer authority | Server only |
| Client role | Read-only if exposed through public snapshot or Console VM diagnostics |
| Persistence | None by default. Runtime policy should be derived after mission start. |
| UI authority | None. UI may display runtime status, not change gameplay state directly. |

---

## 3) Planned read model

Recommended read model name: `ARC_runtimePolicy_v1`.

Recommended fields:

| Field | Type | Meaning |
|---|---|---|
| `schema` | string | `ARC_runtimePolicy_v1` |
| `version` | array | `[1,0,0]` |
| `builtAtServerTime` | number | Server time at build |
| `serverMode` | string | `HOSTED`, `DEDICATED`, or `UNKNOWN` |
| `safeMode` | bool | Whether safe mode posture is active |
| `degradedMode` | string | `NONE`, `LIGHT`, `HEAVY`, or `LOCKDOWN` |
| `playerCount` | number | Current active player count |
| `activeDistricts` | array | District IDs active under player bubble policy |
| `aiPressureBand` | string | `LOW`, `MED`, `HIGH`, or `UNKNOWN` |
| `vehiclePressureBand` | string | `LOW`, `MED`, `HIGH`, or `UNKNOWN` |
| `schedulerBudgetBand` | string | `NORMAL`, `REDUCED`, `MINIMAL`, or `LOCKED` |
| `spawnPolicy` | hash/map | Per-family allow/reduce/deny guidance |
| `cleanupPolicy` | hash/map | Cleanup radius, delay, and conservative fallback hints |
| `jipPosture` | string | `NORMAL`, `RECOVERY`, or `UNKNOWN` |
| `notes` | array | Bounded diagnostic notes |

This read model should remain compact. It should not become a live dump of every unit, group, vehicle, or scheduler.

---

## 4) Consumers

| Consumer | Allowed use |
|---|---|
| CIVSUB / CIVTRAF / CIVLOC | Reduce or pause physical civilians, traffic, or location NPCs under degraded policy. |
| Threat / IED / advanced threat variants | Gate nonessential event pressure and physical manifestation when runtime budget is reduced. |
| Airbase / CASREQ | Reduce ambience without breaking command-critical CASREQ state. |
| SitePop / Prison | Reduce site population pressure while preserving server-mediated interactions. |
| Logistics / Medical | Keep command-critical sustainment state online; reduce noncritical ambience where needed. |
| TASKENG / SITREP / Command | Preserve mission spine and expose runtime constraints to operators. |
| Console VM / diagnostics | Display runtime status and stale/degraded warnings. |

---

## 5) Policy bands

| Band | Meaning | Default guidance |
|---|---|---|
| `NORMAL` | Server pressure acceptable. | All enabled systems may run within their own caps. |
| `REDUCED` | Some pressure exists. | Reduce ambient schedulers before command-critical systems. |
| `MINIMAL` | High pressure exists. | Keep mission spine, snapshots, SITREP, medical, and essential task state. Pause nonessential ambience. |
| `LOCKED` | Recovery posture. | No new nonessential physical activity. Preserve state, cleanup, and operator visibility. |

---

## 6) Failure mode

If runtime policy is missing or stale:

1. Consumers use conservative defaults.
2. New ambience should reduce rather than expand.
3. Mission spine must remain available where possible.
4. UI should show runtime policy as unknown/stale.
5. No client may fabricate runtime policy locally.

---

## 7) Validation requirements

| Validation | Required evidence |
|---|---|
| Static review | No new client-authoritative runtime writes. |
| Hosted MP | Runtime policy reflects player count and safe/degraded posture. |
| Dedicated fresh start | Runtime policy initializes without blocking mission spine. |
| JIP | Late client receives fresh-enough runtime status or clear stale state. |
| Reconnect | Reconnected client does not mutate runtime authority. |
| Full mod-stack RPT | Degraded policy logs are clear and bounded. |

---

## 8) Implementation non-goals

- Do not build a full performance profiler in v1.
- Do not expose raw unit/group/vehicle dumps to UI.
- Do not let runtime policy mutate gameplay state from clients.
- Do not use runtime policy to hide real state bugs.
- Do not block command-critical flows solely because ambience degraded.

---

## 9) Next implementation task

Create a Mode C or Mode B implementation plan for a compact server-owned `ARC_runtimePolicy_v1` publisher only after the World Registry and Time / Tempo Policy contracts are accepted.
