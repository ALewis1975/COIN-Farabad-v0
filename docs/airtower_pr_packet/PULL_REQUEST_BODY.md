## Summary

Adds a docs-only AIR / TOWER planning set that translates the recent audit work into an Arma-native execution roadmap.

Included documents:
- `docs/architecture/AIR_TOWER_Arma_Native_Audit_Matrix.md`
- `docs/architecture/AIR_TOWER_Arma_Native_Implementation_Matrix.md`
- `docs/architecture/AIR_TOWER_PR_BY_PR_BREAKDOWN.md`

## Why

The recent AIR / TOWER review established a strong military-operations UX direction, but the next execution phase also needs to account for Arma-native control types, map behavior, locality, RemoteExec hardening, and optional world overlays.

This PR locks that plan in writing before code work begins.

## Scope

Docs only. No runtime files changed.

## Acceptance Criteria

- The Arma-native audit matrix is documented
- The phase-by-phase implementation matrix is documented
- The PR-by-PR work breakdown is documented
- No runtime behavior changes are introduced

## Tests Run

Not run. Docs-only change.

## Risk Notes

Low. No code paths changed.

## Rollback

Revert this PR.
