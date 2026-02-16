# Inline Comment Reconciliation

## Backlog
- FAR-201 — Add machine-readable inline comment export intake pipeline.
- FAR-202 — Add reviewer-owner mapping conventions for reconciliation tracking.
- FAR-203 — Add CI verification script for comment-resolution evidence checks.

## Reconciliation Table

| Comment ID | File Path | Line Anchor | Reviewer Concern | Decision | Owner | Due Sprint | Verification Command |
|---|---|---|---|---|---|---|---|
| _None yet_ | _TBD_ | _TBD_ | Inline reviewer comments have not been provided/exported yet, so reconciliation cannot be completed. | Pending | Review Lead | Sprint TBD | `rg -n "inline comment|review" docs/artifacts` |

## Accepted Comments
No accepted comments yet. When comments are accepted, each row above must include a linked implementation ticket from the backlog section (for example, `FAR-201`).

## Rejected Comments
No rejected comments yet. When a comment is rejected, add a concise rationale and approver directly in the corresponding table row (for example: `Rejected — out of scope for this PR (Approver: @name)`).
