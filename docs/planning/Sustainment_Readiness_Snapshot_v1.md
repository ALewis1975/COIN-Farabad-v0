# Farabad COIN v0 - Sustainment Readiness Snapshot v1

**Version:** 1.0
**Date:** 2026-06-08
**Status:** Planning spec
**Mode:** F - Documentation-Only Changes
**Layer:** L11 Sustainment / S4
**Scope:** Planning contract only. No runtime behavior changes.

## Purpose

This document defines a future server-owned sustainment snapshot for reporting, follow-on recommendations, command views, and Console VM consumers.

The snapshot should prevent S3 and UI code from guessing support posture from scattered medical, logistics, convoy, and report state.

## Authority

| Item | Contract |
|---|---|
| Owner layer | L11 Sustainment / S4 |
| Owner subsystems | Logistics / Medical / Command support bridges |
| Writer authority | Server only |
| UI role | Read-only consumer |
| Persistence | Prefer derived snapshot unless later baseline requires persistence |

## Planned fields

| Field | Meaning |
|---|---|
| `schema` | `sustainment_readiness_v1` |
| `builtAtServerTime` | Server build time |
| `unitId` | Optional unit/group linkage |
| `taskId` | Optional task linkage |
| `supportPosture` | Bounded support state |
| `medicalPosture` | Bounded medical state |
| `mobilityPosture` | Bounded mobility state |
| `resupplyPosture` | Bounded resupply state |
| `transportPosture` | Bounded movement/support state |
| `requestsOpen` | Bounded count/list of active support requests |
| `freshness` | Updated-at and stale-after metadata |
| `recommendationHints` | Bounded hints for S3, not automatic decisions |

## Rules

1. Sustainment owns support-readiness meaning.
2. S3 consumes sustainment constraints but does not own support state.
3. UI displays stale/unknown state instead of inferring readiness.
4. Physical support assets must respect Runtime Boundary policy when implemented.
5. This document does not authorize code changes.

## Validation before implementation

- Static writer audit.
- Hosted MP support request smoke.
- JIP reconstruction after support state exists.
- Reconnect behavior check.
- Dedicated restart if any support state becomes persisted.
