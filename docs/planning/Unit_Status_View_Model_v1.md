# Farabad COIN v0 - Unit Status View Model v1

**Version:** 1.0
**Date:** 2026-06-08
**Status:** Planning spec
**Mode:** F - Documentation-Only Changes
**Layer:** L7 BLUFOR Footprint
**Scope:** Planning contract only. No runtime behavior changes.

## Purpose

This document defines a future server-owned view model that can summarize unit posture for tasking, reporting, command views, and Console VM consumers.

## Authority

| Item | Contract |
|---|---|
| Owner layer | L7 BLUFOR Footprint |
| Owner subsystems | Core / Command / Logistics / Medical / Airbase |
| Writer authority | Server only |
| UI role | Read-only consumer |
| Persistence | Prefer derived snapshot unless a later baseline requires persistence |

## Planned fields

| Field | Meaning |
|---|---|
| `schema` | `unit_status_view_v1` |
| `builtAtServerTime` | Server build time |
| `unitId` | Stable unit or group identifier |
| `callsign` | Display callsign |
| `taskId` | Current task linkage if active |
| `posture` | Bounded status value |
| `locationSummary` | Bounded grid, marker, or area summary |
| `readinessSummary` | Bounded support and equipment summary |
| `freshness` | Updated-at and stale-after metadata |
| `recommendationHints` | Bounded hints for S3, not automatic decisions |

## Rules

1. This view model is server-owned.
2. UI displays the model but does not own it.
3. Unknown or stale data must be shown as unknown or stale.
4. S3 may consume hints, but server authority owns final decisions.
5. This document does not authorize code changes.

## Validation before implementation

- Static writer audit.
- Hosted MP smoke.
- JIP reconstruction.
- Reconnect and respawn check.
- Dedicated restart if any state becomes persisted.
