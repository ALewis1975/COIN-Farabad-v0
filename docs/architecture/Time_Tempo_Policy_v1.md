# Farabad COIN v0 - Time / Tempo Policy v1

**Version:** 1.0  
**Date:** 2026-06-08  
**Status:** Planning contract  
**Mode:** F - Documentation-Only Changes  
**Layer:** L2 Time / Tempo Policy  
**Scope:** Defines canonical ownership for time-of-day phase, activity windows, tempo hints, and consumer behavior. No runtime behavior changes.

---

## 0) Truth status

This document defines a planning contract. It does not change `ARC_fnc_dynamicTodRefresh`, CIVSUB activity variables, or any runtime scheduler.

| Claim type | Status |
|---|---|
| Time / Tempo Policy as ecosystem layer | Branch-local until parent ecosystem stack merges |
| Runtime implementation change | Not implemented by this document |
| Runtime behavior proof | Not claimed |

---

## 1) Purpose

Time / Tempo Policy owns canonical temporal context for the mission. Other systems may consume or mirror time policy, but they should not define it independently.

The policy should answer:

- Is the AO in day, night, or peak activity posture?
- Which systems may run normal, reduced, or disabled physical activity?
- Which traffic/civilian/airbase/threat windows are open?
- What tempo hints should S3 and UI display?
- Which compatibility variables exist only for migration?

---

## 2) Authority

| Item | Contract |
|---|---|
| Owner layer | L2 Time / Tempo Policy |
| Owner subsystem | Core |
| Writer authority | Server computes and publishes canonical policy |
| Client role | Read-only through replicated policy or Console VM section |
| Persistence | None by default. Derived from mission time and config. |
| UI authority | None. UI displays time policy and stale/unknown status only. |

---

## 3) Planned read model

Recommended read model name: `ARC_timePolicy_v1`.

Recommended fields:

| Field | Type | Meaning |
|---|---|---|
| `schema` | STRING | `ARC_timePolicy_v1` |
| `version` | ARRAY | `[1,0,0]` |
| `builtAtServerTime` | NUMBER | Server build time |
| `dayTime` | NUMBER | Current mission dayTime |
| `phase` | STRING | `DAY`, `NIGHT`, `PEAK`, or `UNKNOWN` |
| `profile` | STRING | `STANDARD`, `LOW_VIS`, `HIGH_VIS`, or `UNKNOWN` |
| `activityWindows` | HASHMAP | Named windows and open/closed state |
| `canSpawnCivil` | BOOL | Compatibility field for civilian physical activity |
| `canSpawnTraffic` | BOOL | Policy hint for traffic physical activity |
| `canSpawnAirbase` | BOOL | Policy hint for airbase ambience |
| `canSpawnThreat` | BOOL | Policy hint for threat physical manifestation |
| `canSpawnOps` | BOOL | Policy hint for operations ambience |
| `tempoHint` | STRING | `NORMAL`, `LOW`, `HIGH`, or `UNKNOWN` |
| `derivedFrom` | STRING | Config source / compatibility note |
| `staleAfterS` | NUMBER | UI freshness hint |

This read model should remain compact and policy-oriented. It should not become a scheduler registry.

---

## 4) Canonical ownership rule

Time policy owns canonical phase/window decisions.

Consumers may keep compatibility mirrors temporarily, but those mirrors are not source of truth. For example, CIVSUB-facing activity variables may continue to exist while consumers migrate, but Core time policy should own the phase calculation after the contract is implemented.

---

## 5) Consumers

| Consumer | Allowed use |
|---|---|
| CIVSUB | Adjust civilian sampling, contact availability, rumor/lead timing, and traffic posture. |
| Threat / IED | Adjust event opportunity windows and visibility/context rules while respecting threat budgets. |
| Airbase / CASREQ | Adjust ambience windows without blocking command-critical CASREQ state. |
| TASKENG / S3 | Use tempo hints for task pacing and follow-on recommendations. |
| Logistics / Medical | Use time as context only, not as sole readiness driver. |
| SitePop / Prison | Adjust noncritical ambience windows where appropriate. |
| Console VM | Display current time policy and stale/unknown status where useful. |

---

## 6) Configuration ownership

| Config family | Owner | Notes |
|---|---|---|
| Night start/end | L2 Time / Tempo Policy | Should live in Core time policy config after migration. |
| Morning/evening peak windows | L2 Time / Tempo Policy | Should not be CIVSUB-owned long term. |
| Night allowances by family | L2 owner with consumer-specific defaults | Time owns policy surface; subsystem owner owns final behavior. |
| Temporary compatibility mirrors | Original subsystem during migration | Must be labeled as mirrors, not canonical policy. |

---

## 7) Failure mode

If time policy is missing or stale:

1. Consumers use safe defaults.
2. UI shows unknown/stale time policy.
3. Physical ambience should not expand based on missing policy.
4. Command-critical state should remain available.
5. No client may compute and publish canonical time policy.

---

## 8) Validation requirements

| Validation | Required evidence |
|---|---|
| Static ownership review | Time policy writer is server-owned and consumers do not define canonical phase. |
| Hosted MP | Day/night/peak transitions refresh policy and consumers tolerate changes. |
| Dedicated fresh start | Time policy initializes before dependent schedulers require it. |
| JIP | Late client sees policy or clear stale/unknown state. |
| Compatibility check | CIVSUB mirrors remain aligned until migration completes. |
| RPT review | Phase changes and stale/missing policy warnings are bounded. |

---

## 9) Implementation non-goals

- Do not rewrite all consumers in one PR.
- Do not remove compatibility mirrors until parity is proven.
- Do not make time policy a gameplay-authoritative decision engine by itself.
- Do not let clients compute authoritative policy.
- Do not use time policy to bypass runtime-budget constraints.

---

## 10) Migration path

1. Document current time policy producers and consumers.
2. Add a Core-owned `ARC_fnc_timePolicyGet` or equivalent wrapper with behavior parity.
3. Keep existing `ARC_dynamic_tod_*` state compatible during transition.
4. Convert CIVSUB to consume the wrapper first.
5. Convert Threat, Airbase, Ops, and UI one subsystem at a time.
6. Remove higher-layer canonical ownership only after hosted/dedicated/JIP evidence.

---

## 11) Next implementation task

Audit current consumers of `ARC_dynamic_tod_*`, CIVSUB activity windows, traffic windows, airbase windows, and threat windows. Then propose a Mode C wrapper PR that preserves behavior while making Core the canonical Time / Tempo Policy owner.
