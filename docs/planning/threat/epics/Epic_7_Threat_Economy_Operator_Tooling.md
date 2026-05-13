# Epic 7 — Threat Economy Operator Tooling and Observability

## Scope
Define operator/admin tooling and observability completion criteria for Threat Economy behavior.

## Status framing
- **Implemented:** economy scheduler/governor/risk/attribution/follow-on primitives.
- **Partially implemented:** operator-facing inspection and actionable observability.
- **Missing:** explicit completion criteria and operator runbooks.

## Deliverables
1. Economy observability contract (risk, budget, cooldown, deny reasons).
2. Operator/admin tooling plan (read-only dashboards, guarded controls).
3. Logging/event taxonomy for economy decisions.
4. Completion rubric tied to campaign tempo and safety constraints.

## PR-sized work packages (future implementation)
- **E7-WP1:** Publish economy telemetry field catalog + thresholds.
- **E7-WP2:** Add operator-facing snapshot/read models for economy state.
- **E7-WP3:** Add guarded admin diagnostics/reset controls where required.
- **E7-WP4:** Validate pacing/guardrails with scenario evidence.

## Dependencies
- Requires Epic 1 event/schema boundaries and Epic 3 surfacing contracts.
- Benefits from Epic 4 family normalization consistency.

## Acceptance criteria
- Operators can explain why an event was/was not scheduled.
- Deny reasons and cooldown/risk constraints are visible and auditable.
- Admin controls are explicit, bounded, and role-gated.

## Validation & evidence requirements
- Static checks for any touched SQF/config/UI.
- Runtime evidence for scheduler decisions and guardrail behavior.
- Dedicated/JIP evidence that observability surfaces remain consistent for late join.

## Non-goals
- Rebalancing all campaign-level threat economy parameters by default.
