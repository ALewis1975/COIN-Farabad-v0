# Epic 3 — Threat UI / TOC / S2 Surfacing Plan

## Scope
Define and stage operator-facing threat surfacing for TOC/S2/player-adjacent workflows using read-only snapshots/events.

## Status framing
- **Implemented:** backend snapshots/debug outputs exist.
- **Partially implemented:** TOC/S2 threat-focused views and event feed contracts.
- **Missing:** explicit operator actions/checklists for threat triage visibility.

## Deliverables
1. UX contract for threat list/detail/filter views.
2. Snapshot adapter contract and refresh cadence.
3. Event-to-UI mapping for create/update/close/cleanup/follow-on outcomes.
4. Role-based visibility and action boundaries (read-only vs admin tooling hooks).

## PR-sized work packages (future implementation)
- **E3-WP1:** Threat UI data contract (fields, filters, sorting, freshness).
- **E3-WP2:** TOC/S2 threat board integration plan with empty-state/error-state rules.
- **E3-WP3:** Event feed rendering plan and bounded history UX.
- **E3-WP4:** Operator runbook for triage/verification workflow.

## Dependencies
- Requires Epic 1 event/schema contract.
- Consumes lifecycle semantics from Epic 2.

## Acceptance criteria
- UI contract maps each displayed field to canonical source key.
- UI never writes authoritative threat state directly.
- Operator-facing threat status is understandable without debug logs.
- UX includes explicit stale/no-data handling.

## Validation & evidence requirements
- Static validation for touched UI/config/SQF files.
- Local MP smoke of TOC/S2 view rendering and refresh.
- Dedicated/JIP validation that late joiners get correct threat visibility.

## Non-goals
- Runtime threat generation logic changes (Epics 1/2/4/7).
