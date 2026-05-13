# Epic 6 — Threat Validation and Evidence Closure (Dedicated/JIP/Restart/Tests)

## Scope
Close validation debt for threat lifecycle, economy, and virtual pool behavior with explicit evidence in canonical logs/matrices.

## Status framing
- **Implemented:** partial static checks and ad hoc local smoke coverage.
- **Missing:** complete dedicated/JIP/restart closure evidence package.
- **Validation-only:** this epic converts existing behavior into proven behavior.

## Deliverables
1. Threat validation matrix (local MP, dedicated, JIP, restart, reconnect).
2. Step-by-step test procedures and expected outcomes.
3. Evidence updates in `tests/TEST-LOG.md` and related QA matrices.
4. Closure report mapping each threat contract to proof artifacts.

## PR-sized work packages (future implementation)
- **E6-WP1:** Build threat-specific validation matrix and test scripts/checklists.
- **E6-WP2:** Execute local MP smoke evidence pass.
- **E6-WP3:** Execute dedicated + JIP + restart validation pass.
- **E6-WP4:** Publish closure summary and unresolved risk ledger.

## Dependencies
- Depends on Epic 5 persistence/restart hardening for final sign-off.
- Consumes acceptance criteria from Epics 1–4, 7, and 8.

## Acceptance criteria
- Every critical threat path has PASS/FAIL/BLOCKED evidence rows.
- BLOCKED entries include owner/date/required environment.
- No runtime-completion claim is made without matching evidence.

## Validation & evidence requirements
- Mandatory update to `tests/TEST-LOG.md` for each pass.
- Dedicated/JIP tests include late join and reconnect edge cases.
- Restart tests include save/load and in-flight lifecycle edges.

## Non-goals
- Introducing new runtime threat features.
