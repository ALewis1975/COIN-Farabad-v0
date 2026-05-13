# Threat Epic PR Templates (Docs-Only Planning Series)

Use one PR per epic with **Mode F (Documentation-Only)** and no runtime code changes.

## PR-E1
- **Title:** `docs(threat): Epic 1 planning - API and contract completion`
- **Body:**
  - Mode: F
  - Scope: `docs/planning/threat/epics/Epic_1_Threat_API_Contract.md`
  - Acceptance Criteria:
    - Epic 1 scope, dependencies, deliverables, and PR-sized work packages are explicit.
    - Implemented/partial/missing status is documented without runtime completion claims.
    - Validation/evidence requirements are explicit.
  - Tests Run: `Not run (docs-only planning artifact)`
  - Risk Notes: Mis-scoped future implementation if API boundaries are unclear.
  - Rollback: Revert this PR commit.

## PR-E2
- **Title:** `docs(threat): Epic 2 planning - IED suspicious-object lifecycle contract`
- **Body:**
  - Mode: F
  - Scope: `docs/planning/threat/epics/Epic_2_IED_Lifecycle_Contract.md`
  - Acceptance Criteria:
    - Lifecycle states/transitions and spawn-path contract planning are explicit.
    - Missing/partial/validation-only status is clear.
    - Dedicated/JIP/restart evidence gates are documented.
  - Tests Run: `Not run (docs-only planning artifact)`
  - Risk Notes: Lifecycle drift if spawn/cleanup ownership stays implicit.
  - Rollback: Revert this PR commit.

## PR-E3
- **Title:** `docs(threat): Epic 3 planning - TOC/S2/UI threat surfacing`
- **Body:**
  - Mode: F
  - Scope: `docs/planning/threat/epics/Epic_3_Threat_UI_Surfacing.md`
  - Acceptance Criteria:
    - UI data contract and operator-facing deliverables are explicit.
    - Read-only authority boundary is preserved.
    - Validation requirements include dedicated/JIP visibility checks.
  - Tests Run: `Not run (docs-only planning artifact)`
  - Risk Notes: UI/state coupling risks if write boundaries are not enforced.
  - Rollback: Revert this PR commit.

## PR-E4
- **Title:** `docs(threat): Epic 4 planning - threat family normalization`
- **Body:**
  - Mode: F
  - Scope: `docs/planning/threat/epics/Epic_4_Threat_Family_Normalization.md`
  - Acceptance Criteria:
    - Family matrix and normalization outcomes are explicit.
    - IED/VBIED/SUICIDE/non-IED consistency goals are documented.
    - Evidence requirements are listed.
  - Tests Run: `Not run (docs-only planning artifact)`
  - Risk Notes: Schema/behavior drift across families if normalization is deferred.
  - Rollback: Revert this PR commit.

## PR-E5
- **Title:** `docs(threat): Epic 5 planning - persistence reset migration hardening`
- **Body:**
  - Mode: F
  - Scope: `docs/planning/threat/epics/Epic_5_Persistence_Reset_Migration.md`
  - Acceptance Criteria:
    - Threat schema/version and migration/reset deliverables are explicit.
    - Restart invariants are defined.
    - Dependency on validation closure is clear.
  - Tests Run: `Not run (docs-only planning artifact)`
  - Risk Notes: Restart and migration regressions if persistence contracts stay implicit.
  - Rollback: Revert this PR commit.

## PR-E6
- **Title:** `docs(threat): Epic 6 planning - validation and evidence closure`
- **Body:**
  - Mode: F
  - Scope: `docs/planning/threat/epics/Epic_6_Validation_Evidence_Closure.md`
  - Acceptance Criteria:
    - Dedicated/JIP/restart validation matrix scope is explicit.
    - PASS/FAIL/BLOCKED evidence rules are defined.
    - No runtime completion claim without evidence.
  - Tests Run: `Not run (docs-only planning artifact)`
  - Risk Notes: False completion claims without proof artifacts.
  - Rollback: Revert this PR commit.

## PR-E7
- **Title:** `docs(threat): Epic 7 planning - threat economy operator tooling`
- **Body:**
  - Mode: F
  - Scope: `docs/planning/threat/epics/Epic_7_Threat_Economy_Operator_Tooling.md`
  - Acceptance Criteria:
    - Economy observability/tooling completion criteria are explicit.
    - Operator/admin boundaries are documented.
    - Validation requirements are explicit.
  - Tests Run: `Not run (docs-only planning artifact)`
  - Risk Notes: Operator blind spots if deny/cooldown reasons are not surfaced.
  - Rollback: Revert this PR commit.

## PR-E8
- **Title:** `docs(threat): Epic 8 planning - virtual opfor pool completion`
- **Body:**
  - Mode: F
  - Scope: `docs/planning/threat/epics/Epic_8_Virtual_OpFor_Pool_Completion.md`
  - Acceptance Criteria:
    - Virtual pool model/admin/debug deliverables are explicit.
    - Protected-zone/locality behavior evidence requirements are listed.
    - Dependencies on persistence/validation epics are explicit.
  - Tests Run: `Not run (docs-only planning artifact)`
  - Risk Notes: Locality/restart regressions without explicit closure.
  - Rollback: Revert this PR commit.

