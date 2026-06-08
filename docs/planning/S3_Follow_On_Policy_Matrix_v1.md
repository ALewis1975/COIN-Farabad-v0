# Farabad COIN v0 - S3 Follow-On Policy Matrix v1

**Version:** 1.0
**Date:** 2026-06-08
**Status:** Planning spec
**Mode:** F - Documentation-Only Changes
**Layer:** L10 Operations / S3
**Scope:** Planning contract only. No runtime behavior changes.

## Purpose

S3 follow-on decisions should consume explicit inputs instead of relying on scattered UI state or implicit task text. This matrix defines the planning contract for RTB, Hold, Continue (next-task), and support-oriented recommendations.

## Authority

| Item | Contract |
|---|---|
| Owner layer | L10 Operations / S3 |
| Owner subsystems | TASKENG / SITREP / Command |
| Writer authority | Server only |
| UI role | Shows recommendations and reasons, but does not decide |
| Persistence | Follow task/order persistence rules if implemented |

## Decision inputs

| Input | Owner layer | Required behavior |
|---|---|---|
| Task outcome | L10 Operations / S3 | Must be explicit in task/SITREP state. |
| Unit status | L7 BLUFOR Footprint | Consume server-owned read model or existing public snapshot. |
| Sustainment state | L11 Sustainment / S4 | Consume explicit readiness snapshot when available. |
| Intel confidence | L9 Intel / S2 | Low confidence should bias toward Hold, recon, or further reporting. |
| Threat posture | L8 Threat Synthesis | Consume threat records/economy, not hidden internals. |
| District posture | L4 Civilian / Population | Consume CIVSUB snapshot/delta summary. |
| Time / tempo | L2 Time / Tempo Policy | Consume canonical policy, not subsystem mirrors. |
| Terrain context | L1 World Registry | Consume stable world/location IDs. |

## Recommendation matrix

| Condition | Preferred recommendation | Reasoning |
|---|---|---|
| Objective complete, status good, confidence sufficient, support adequate | Continue (next task) | Next task or lead may be appropriate. |
| Objective complete, status degraded, support constrained | RTB or resupply | Refitting protects mission tempo and continuity. |
| Objective complete, local posture unstable, threat unresolved | Hold | Presence, security, or observation may be required. |
| Intel confidence low or source uncertain | Hold / investigate | Avoid overcommitting on weak information. |
| Support request open or medical/logistics state unclear | Hold / support | Resolve support state before new commitment. |
| Runtime policy degraded | Hold / reduce ambience | Preserve mission spine and avoid expanding pressure. |

## Rules

1. Matrix output is a recommendation, not an automatic player-facing order unless S3 server logic issues it.
2. Every recommendation should include a bounded reason code.
3. Missing inputs should produce stale/unknown reasoning, not fabricated certainty.
4. UI may display recommendations but must not issue follow-ons locally.
5. Any implementation must log transition and reason codes.

## Planned reason codes

| Code | Meaning |
|---|---|
| `FOLLOWON_PROCEED_READY` | Inputs support follow-on movement/tasking. |
| `FOLLOWON_RTB_REFIT` | Status or sustainment recommends RTB/refit. |
| `FOLLOWON_HOLD_SECURITY` | Local posture recommends hold/security. |
| `FOLLOWON_HOLD_INTEL_LOW` | Intel confidence is too low for clean progression. |
| `FOLLOWON_HOLD_SUPPORT_OPEN` | Support or recovery request remains open. |
| `FOLLOWON_HOLD_RUNTIME_DEGRADED` | Runtime policy recommends reduced pressure. |
| `FOLLOWON_UNKNOWN_INPUTS` | Required inputs are stale or missing. |

## Validation before implementation

- Static source ownership review for every input.
- Hosted MP command-cycle smoke.
- SITREP -> recommendation -> follow-on display proof.
- JIP after follow-on recommendation exists.
- Dedicated restart if recommendation state becomes persisted.
