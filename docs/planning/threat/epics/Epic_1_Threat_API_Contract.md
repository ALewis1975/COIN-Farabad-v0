# Epic 1 — Threat API and Contract Completion

## Scope
Complete planned API surface and shared event/schema contract, centered on:
- `ARC_fnc_threatCreateFromLead`
- `ARC_fnc_threatEmitEvent`

## Status framing
- **Implemented:** `threatCreateFromTask`, `threatUpdateState`, `threatOnAOActivated`, `threatOnIncidentClosed`, `threatDebugSnapshot`.
- **Missing:** `threatCreateFromLead`, `threatEmitEvent` (baseline optional/deferred APIs).
- **Partially implemented:** Event semantics exist in pockets but no explicit subsystem event contract.

## Deliverables
1. API contract spec (inputs, outputs, idempotency, authority, logging).
2. Event envelope spec (event names, payload schema, revision metadata, producer/consumer ownership).
3. Registration and allowlist planning notes (`CfgFunctions`, `CfgRemoteExec` if needed).
4. Backward-compat strategy for existing callers.

## PR-sized work packages (future implementation)
- **E1-WP1:** Author API contract doc and lifecycle map.
- **E1-WP2:** Add `threatCreateFromLead` with server-only, idempotent lead consumption rules.
- **E1-WP3:** Add `threatEmitEvent` and bounded event buffer/dispatch semantics.
- **E1-WP4:** Integrate event emissions at create/state/close/cleanup transitions.

## Dependencies
- Inputs from baseline spec and current threat function inventory.
- Must complete before Epic 3 (UI feed) and Epic 7 (operator observability) finalize.

## Acceptance criteria
- Public threat API table includes required/optional/deprecated functions.
- Lead-driven creation contract is explicit on dedupe and ownership.
- Event envelope is versioned and consumable by UI/ops tooling.
- Logging and security expectations are documented for each API.

## Validation & evidence requirements
- Static: changed-file compat scan + sqflint for touched SQF.
- Behavioral: server-authoritative lead->threat creation + event emission trace in RPT.
- Dedicated/JIP: late-join consumers receive correct threat state/event-derived view.

## Non-goals
- No new threat-family behavior in this epic (handled in Epic 4).
- No persistence migration work beyond contract notes (Epic 5).
