# Epic 5 — Threat Persistence / Reset / Migration / Restart Hardening

## Scope
Harden threat persistence contracts and reset/migration behavior, including schema/versioning notes and restart invariants.

## Status framing
- **Implemented:** threat subsystem stores persistent data and version keys.
- **Partially implemented:** explicit migration/reset hardening and documented invariants across expanded schema.
- **Validation-only:** restart durability and migration replay proof.

## Deliverables
1. Threat state schema/version document (required vs optional fields).
2. Migration matrix (from previous versions to current, idempotency rules).
3. Reset/rebuild procedure contract (admin/operator-safe).
4. Restart invariants checklist for threat, economy, and virtual pool stores.

## PR-sized work packages (future implementation)
- **E5-WP1:** Schema/version documentation refresh aligned to runtime.
- **E5-WP2:** Migration helper/harness updates with test vectors.
- **E5-WP3:** Reset/rebuild hardening with bounded-state guarantees.
- **E5-WP4:** Restart persistence verification package.

## Dependencies
- Inputs from Epic 2 lifecycle contract and Epic 4 normalized family schema.
- Must complete before Epic 6 closure can be marked complete.

## Acceptance criteria
- Threat schema versioning is explicit and maintained.
- Migration replay is safe and idempotent.
- Reset path leaves no orphaned or contradictory threat/economy/pool state.

## Validation & evidence requirements
- Static migration validators pass.
- Controlled restart tests confirm deterministic state recovery.
- Dedicated/JIP evidence confirms late join snapshot correctness after restart.

## Non-goals
- New threat behavior features outside persistence/recovery concerns.
