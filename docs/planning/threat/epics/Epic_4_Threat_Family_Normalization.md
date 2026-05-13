# Epic 4 — Threat Family Normalization (IED/VBIED/SUICIDE/non-IED)

## Scope
Normalize threat-family contracts so record shape, state transitions, and logging are consistent across IED/VBIED/SUICIDE and planned non-IED flows.

## Status framing
- **Implemented:** economy/lead code already references multiple families.
- **Partially implemented:** family-specific record and lifecycle contracts are not fully normalized/documented.
- **Missing:** explicit subtype/state matrix and closure semantics by family.

## Deliverables
1. Threat family matrix (type/subtype/state/event/log expectations).
2. Shared schema core + family extension schema notes.
3. Family-safe transition and closure rules.
4. Compatibility guardrails for older IED-only assumptions.

## PR-sized work packages (future implementation)
- **E4-WP1:** Publish family normalization design doc.
- **E4-WP2:** Standardize enum/constants and state transitions.
- **E4-WP3:** Normalize logs and deny reasons across families.
- **E4-WP4:** Add cross-family regression tests/checklists.

## Dependencies
- Epic 1 event/schema contract.
- Epic 2 lifecycle contract for IED baseline behavior.

## Acceptance criteria
- Family matrix is explicit and complete.
- Each family has documented create/update/close semantics.
- Shared tooling can consume records without ad hoc family branches.

## Validation & evidence requirements
- Static validation on changed SQF/config.
- Local MP smoke for at least one scenario per family.
- Dedicated/JIP/restart evidence for family-state persistence consistency.

## Non-goals
- Advanced doctrine tuning of insurgent behavior pacing (handled in gameplay balancing work).
