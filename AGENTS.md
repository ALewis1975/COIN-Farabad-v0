# AGENTS.md — Project Agent Operating Doctrine (AOD)

## Required PR metadata
Every PR description MUST include:
- Mode: A | B | C | D | E | F | G | H | I | J
- Scope: list of allowed files/dirs
- Acceptance Criteria: bullets
- Tests Run: commands + results (or "Not run" + why)
- Risk Notes: what could break
- Rollback: how to revert safely

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
