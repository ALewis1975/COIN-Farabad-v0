# Epic 8 — Virtual OpFor Pool Completion and Documentation

## Scope
Complete virtual OpFor pool documentation/admin/debug package and close operational behavior evidence gaps.

## Status framing
- **Implemented:** virtual pool init/tick runtime paths and integration with threat flows.
- **Partially implemented:** explicit operator/admin docs, debug tooling contract, and completion criteria.
- **Validation-only:** dedicated/JIP/restart/locality safety proof package.

## Deliverables
1. Virtual pool model doc (states, transitions, caps, protected-zone interactions).
2. Debug/admin observability plan (snapshot fields and interpretation guide).
3. Integration notes with threat economy and incident lifecycle.
4. Evidence plan for despawn/materialization/locality correctness.

## PR-sized work packages (future implementation)
- **E8-WP1:** Publish virtual pool architecture + state model.
- **E8-WP2:** Define and expose operator/debug snapshot package.
- **E8-WP3:** Validate protected-zone and incident-coupled behaviors.
- **E8-WP4:** Execute dedicated/JIP/restart locality validation pass.

## Dependencies
- Align event/schema assumptions with Epic 1.
- Coordinate persistence expectations with Epic 5 and validation closure with Epic 6.

## Acceptance criteria
- Pool state transitions are documented and observable.
- Materialization/despawn behavior is predictable and bounded.
- Protected-zone and locality constraints are explicit and verified.

## Validation & evidence requirements
- Static checks on changed files.
- Runtime smoke in local MP for pool transitions.
- Dedicated/JIP/restart evidence for locality-safe behavior and late-join correctness.

## Non-goals
- Full insurgent doctrine redesign outside pool lifecycle/observability scope.
