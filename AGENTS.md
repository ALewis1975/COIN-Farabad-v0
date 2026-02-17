# AGENTS.md — Project Agent Operating Doctrine (AOD)

## Scripting Language
SQF a/k/a Real Virtuality 4 by Bohemia Interactive. Additionally known as Poseidon. "Poseidon" is the internally used name of the Real Virtuality engine, used to drive all Bohemia Interactive games from Operation Flashpoint to Arma 3.

## Required PR metadata
Every PR description MUST include:
- Mode: A | B | C | D | E | F | G | H | I | J
- Scope: list of allowed files/dirs
- Acceptance Criteria: bullets
- Tests Run: commands + results (or "Not run" + why)
- Risk Notes: what could break
- Rollback: how to revert safely

## Mode legend (enforceable definition)
Choose exactly one primary mode per PR. If work spans multiple modes, split into multiple PRs.

### Mode A — Bug Fix (behavior correction)
- Purpose: fix incorrect behavior without changing intended product scope.
- Allowed: minimal code changes to correct logic defects; targeted tests.
- Disallowed: feature additions, broad refactors, schema redesign.

### Mode B — Feature Delivery (new capability)
- Purpose: introduce user-visible or system-visible functionality.
- Allowed: implementation + tests + required docs for the feature.
- Disallowed: unrelated cleanups or incidental architecture rewrites.

### Mode C — Safe Refactor (no behavior change)
- Purpose: improve code structure/readability/maintainability only.
- Allowed: internal code motion/renaming/extraction with behavior parity.
- Required: parity checks proving no intended behavior change.
- Disallowed: opportunistic refactors outside declared scope.

### Mode D — Performance Optimization
- Purpose: improve latency, throughput, memory, or operational cost.
- Allowed: targeted performance changes with before/after evidence.
- Required: benchmark or profiling output in PR notes.
- Disallowed: opportunistic refactors unrelated to the optimization.

### Mode E — Test-Only Changes
- Purpose: add/fix/improve automated tests only.
- Allowed: test files, fixtures, and test harness updates.
- Disallowed: production logic changes except test seams explicitly listed.

### Mode F — Documentation-Only Changes
- Purpose: clarify or update written guidance/specs/runbooks.
- Allowed: docs, diagrams, comments (non-functional).
- Disallowed: executable behavior changes.

### Mode G — Build/CI/Tooling
- Purpose: adjust pipelines, scripts, linting, formatting, or dev tooling.
- Allowed: CI config and tooling scripts needed for reliability.
- Disallowed: product feature work mixed into tooling PRs.

### Mode H — Dependency / Version Management
- Purpose: add, remove, pin, or upgrade dependencies/runtime versions.
- Allowed: manifest/config updates and compatibility fixes directly required.
- Required: compatibility/risk notes for major upgrades.
- Disallowed: unrelated feature or refactor work.

### Mode I — Security Hardening
- Purpose: remediate vulnerabilities or reduce attack surface.
- Allowed: authz/authn hardening, input validation, secret handling, policy fixes.
- Required: threat/risk summary and verification steps.
- Disallowed: unrelated non-security improvements.

### Mode J — Operations / Config / Data Maintenance
- Purpose: environment configuration, migrations, or operational reliability tasks.
- Allowed: config defaults, migration scripts, rollout/rollback mechanics.
- Required: explicit deployment/rollback procedure.
- Disallowed: unrelated product development.

## Mode selection rules
- If the PR changes runtime behavior for users/operators, default to A or B unless it is explicitly a security item (I).
- If the PR changes only tests/docs/tooling/dependencies, use E/F/G/H respectively.
- If a change could reasonably fit multiple modes, pick the mode that represents the highest risk surface and explain why in PR notes.

## Global constraints
- Do not perform opportunistic refactors in Modes C or D.
- Do not change public interfaces unless the PR explicitly lists the interface changes.
- Do not modify files outside the declared Scope.
- If a change requires touching more files, stop and request scope expansion in PR text.

## No-touch paths (edit for your repo)
- vendor/
- dist/
- build/
- *.lock
- generated/
- mission.sqm (example: protect critical manifests)

## Review focus
When reviewing, prioritize:
1) correctness and regressions
2) state ownership / single-writer assumptions
3) error handling and edge cases
4) test coverage gaps
5) performance red flags

## Severity rubric
- P0: data loss, security, crash, broken build
- P1: incorrect behavior, likely regression, missing tests for changed logic
- P2: maintainability, style, low-risk improvements

## Project Execution Context
- **Core entry points:** `initServer.sqf` (server bootstrap/config), `initPlayerLocal.sqf` (client bootstrap/watchers), and `config/CfgFunctions.hpp` (ARC function registry).
- **Current test environment constraint:** container/CI validation is limited to static review; gameplay/network behavior can be smoke-checked in local MP preview/hosted MP, but authoritative persistence/JIP behavior still requires a true dedicated server run.
- **Canonical test log:** update `tests/TEST-LOG.md` after each validation pass with command/step, result (`PASS`/`FAIL`/`BLOCKED`), and context.
- **Authority reminder:** keep server as single writer for shared state (`ARC_STATE`, `ARC_pub_state`, `ARC_pub_stateUpdatedAt`); clients request actions and render replicated state.
- **Deferred until dedicated server is available:** persistence durability across restarts, JIP snapshot correctness, late-client recovery for in-flight events, and reconnect/respawn ownership edge cases.
