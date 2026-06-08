# Farabad COIN v0 - Intel Quality Coupling Contract v1

**Version:** 1.0
**Date:** 2026-06-08
**Status:** Planning spec
**Mode:** F - Documentation-Only Changes
**Layer:** L9 Intel / S2
**Scope:** Planning contract only. No runtime behavior changes.

## Purpose

Intel quality should be an explicit output of district posture, recent conduct, source quality, time, terrain, and threat pressure. It should not be guessed by UI code or hidden inside task text.

This contract defines the fields and ownership rules for future lead confidence and uncertainty metadata.

## Authority

| Item | Contract |
|---|---|
| Owner layer | L9 Intel / S2 |
| Owner subsystems | Intel / TASKENG bridges |
| Writer authority | Server only |
| UI role | Read-only consumer |
| Persistence | Follow lead/thread persistence rules if fields become stored |

## Planned fields

| Field | Meaning |
|---|---|
| `confidence` | Bounded value or band such as `LOW`, `MED`, `HIGH`, `UNKNOWN` |
| `timeliness` | Fresh, delayed, stale, or unknown |
| `sourceType` | Bounded label such as civilian, report, sensor, follow-up, or unknown |
| `precision` | Grid/location precision band |
| `districtReliability` | Derived reliability band, not raw hidden state |
| `uncertaintyNote` | Short operator-facing explanation |
| `derivedInputs` | Bounded list of nonsecret inputs used |
| `freshness` | Updated-at/stale-after metadata |

## Inputs

| Input family | Owner |
|---|---|
| District posture | CIVSUB |
| Government posture | Government / GREEN, when implemented |
| Network pressure | OPFOR Network / Threat, when implemented |
| Threat records | Threat Synthesis |
| Player reports | TASKENG / SITREP / Intel handlers |
| Terrain context | World Registry |
| Time context | Time / Tempo Policy |

## Rules

1. Intel owns confidence and uncertainty labels.
2. UI displays confidence; it does not derive it.
3. Hidden state must be filtered before public exposure.
4. Low confidence should create ambiguity, not false certainty.
5. Confidence metadata should travel with leads when they become tasks.

## Validation before implementation

- Static hidden/public exposure review.
- Lead lifecycle smoke with confidence metadata.
- JIP lead visibility check.
- Console stale/unknown display check.
- Dedicated RPT review if confidence events are logged.
