# Console Tab Migration Plan

## Objective
Migrate console tabs from the legacy rendering path to the new tab framework in a controlled, reversible sequence that minimizes operator disruption and allows per-tab rollback.

---

## 1) Tab Sequence and Dependencies

### Migration order (recommended)
1. **Overview tab**
2. **Operations tab**
3. **Intel tab**
4. **Logistics tab**
5. **Communications tab**
6. **Admin/Settings tab**

### Why this order
- Start with lower-risk, high-visibility tabs to validate the framework quickly.
- Move to tabs with moderate write operations after state synchronization is proven.
- Leave critical control/configuration surfaces until the framework and telemetry are stable.

### Dependency map
- **Shared shell/layout** → prerequisite for all tabs.
- **Navigation state store** → prerequisite for cross-tab routing and deep links.
- **Read model adapters** → prerequisite for read-heavy tabs (Overview, Intel).
- **Write command adapters** → prerequisite for write-heavy tabs (Operations, Logistics, Communications).
- **Permission/role guard integration** → prerequisite for Admin/Settings.
- **Telemetry + error budget dashboard** → prerequisite before first canary and before each tab promotion.

### Hard dependency gates
- No tab enters canary without:
  - parity checks passing against legacy output,
  - alerting configured for tab-specific failure modes,
  - a validated one-command rollback path.

---

## 2) Proposed Feature Flag Names and Default States

| Flag | Purpose | Default | Notes |
|---|---|---|---|
| `console.tabs.framework.enabled` | Enables new tab framework shell | `false` | Global kill switch.
| `console.tabs.overview.v2` | Routes Overview to new implementation | `false` | First canary candidate.
| `console.tabs.operations.v2` | Routes Operations to new implementation | `false` | Requires command adapter readiness.
| `console.tabs.intel.v2` | Routes Intel to new implementation | `false` | Requires read model parity checks.
| `console.tabs.logistics.v2` | Routes Logistics to new implementation | `false` | Validate inventory mutation consistency.
| `console.tabs.comms.v2` | Routes Communications to new implementation | `false` | Verify outbound delivery metrics.
| `console.tabs.admin.v2` | Routes Admin/Settings to new implementation | `false` | Enable only after authz guard burn-in.
| `console.tabs.v2.readonly_mode` | Forces all v2 tabs to read-only fallback | `false` | Emergency safety brake.
| `console.tabs.v2.shadow_compare` | Enables shadow rendering + diff telemetry | `true` in non-prod, `false` in prod | Used during validation; optional prod sampling.

### Promotion policy
- For each per-tab flag:
  - `false` (off) → internal canary cohort → limited operator cohort → full rollout.
- `console.tabs.framework.enabled` remains off until first tab canary is ready.

---

## 3) Per-Tab Entry/Exit Criteria

### Standard entry criteria (applies to every tab)
- Legacy and v2 tab both render correctly in shadow mode.
- Contract tests for tab data model pass.
- Tab-specific SLO dashboard exists (latency, error rate, data mismatch).
- On-call and operator notification prepared.

### Standard exit criteria (applies to every tab)
- Error rate remains within agreed budget for 7 consecutive days.
- No unresolved P0/P1 incidents attributable to the tab migration.
- Operator feedback indicates no workflow blocker.
- Rollback drill for that tab successfully executed at least once.

### Tab-specific criteria

#### Overview
- **Entry:** dashboard cards and summary counters match legacy within accepted drift.
- **Exit:** p95 load time is equal or better than legacy; no stale summary incidents.

#### Operations
- **Entry:** command submission idempotency verified; audit trail parity confirmed.
- **Exit:** zero command-loss incidents; command acknowledgement latency within target.

#### Intel
- **Entry:** feed ordering, filters, and search parity validated against legacy snapshots.
- **Exit:** no high-severity relevance/regression reports from analyst cohort.

#### Logistics
- **Entry:** stock/movement state transitions pass reconciliation tests.
- **Exit:** no inventory divergence alerts for one full operating cycle.

#### Communications
- **Entry:** message compose/send/retry flows pass end-to-end and failover tests.
- **Exit:** delivery success and retry rates match or improve on legacy baseline.

#### Admin/Settings
- **Entry:** RBAC checks and protected actions validated in security regression suite.
- **Exit:** no unauthorized access or denied-valid-action incidents in production.

---

## 4) Rollback Conditions and Operator Playbook

### Immediate rollback triggers
- Any P0 incident linked to migrated tab behavior.
- P1 incident persisting beyond agreed mitigation window.
- Error-rate spike above tab-specific threshold for 15+ minutes.
- Data integrity mismatch beyond allowed tolerance.
- Critical operator workflow blocked with no immediate workaround.

### Rollback levels
1. **Tab-level rollback**
   - Set affected `console.tabs.<tab>.v2=false`.
   - Keep framework enabled for unaffected tabs.
2. **Framework-level rollback**
   - Set `console.tabs.framework.enabled=false`.
   - Returns all tabs to legacy path.
3. **Safety mode rollback**
   - Set `console.tabs.v2.readonly_mode=true` as interim containment while routing is corrected.

### Operator playbook (runbook)

#### A. Detection
- Confirm alert source (tab, region, environment).
- Correlate with recent flag changes and deploy timeline.
- Capture failing request IDs/session IDs.

#### B. Containment
- Execute tab-level rollback first (lowest blast radius).
- If multi-tab symptoms persist, execute framework-level rollback.
- Announce incident state in operator channel with current flag states.

#### C. Verification
- Validate legacy tab availability and core workflows.
- Monitor key metrics for recovery (error rate, latency, task completion).
- Confirm incident stabilization for at least two measurement windows.

#### D. Communication
- Send operator update: issue summary, rollback action, current impact.
- Record timeline in incident tracker including flag changes.
- Provide interim guidance/workarounds if any partial degradation remains.

#### E. Recovery and re-entry
- File corrective action items (bugfix, guardrail, test gap).
- Require fresh canary for the impacted tab before re-promotion.
- Do not re-enable tab flag until exit criteria are re-baselined.

### Post-rollback artifacts
- Incident report with root cause hypothesis and confirmed impact.
- Before/after metric snapshots.
- Updated test plan covering the escaped failure mode.
- Decision log entry for next promotion attempt.

---

## 5) Mandatory Sprint Ticket and PR Scope Declaration

Every sprint ticket and every PR tied to tab migration work must include a dedicated section titled exactly:

`## Scope of visible UI impact`

This section is required even when there is no visible UI change.

### Required content (ticket + PR)
- **Visually affected tabs:** explicit list of tabs whose rendered UI changes in this work item (for example, `OPS only`).
- **Visually unchanged tabs:** explicit list of tabs that remain visually unchanged (for example, `DASH`, `CMD`).
- **Impact summary:** one sentence describing what a user will notice (or stating `No visible UI change`).

### Copy/paste template
```md
## Scope of visible UI impact
- Visually affected tabs: <list or "None">
- Visually unchanged tabs: <list>
- Impact summary: <one sentence>
```

### Review rule
- If this section is missing or incomplete in either the sprint ticket or the PR body, the item is considered **not ready** and cannot proceed to merge review.

---

## Appendix: Suggested Rollout Cadence
- **Week 1 / Sprint 1:** **UI shell overhaul (visible)** + Overview canary.
  - Run VM/spec hardening in parallel as a non-visible workstream so shell migration and architecture hardening advance together.
- **Week 2:** Operations and Intel staged rollout.
- **Week 3:** Logistics and Communications staged rollout.
- **Week 4:** Admin/Settings rollout after security sign-off.

Adjust cadence based on incident volume, operator feedback, and error-budget consumption.

---

## 6) Mandatory Player-Visible Deliverable Per Sprint

Each sprint must include at least one player-visible console deliverable.

### Sprint-level requirement
- Every sprint plan must name at least one visible console change that a player can confirm in-game.
- If a sprint is mostly architecture, VM, or spec hardening, pair it with a bounded visible UI increment in the same sprint.

### Screenshot evidence requirement
- Evidence must include at least one screenshot per impacted tab for the sprint deliverable.
- Screenshots must be attached in both:
  1. the sprint ticket, and
  2. the PR description.
- If multiple tabs are impacted, include one screenshot from each impacted tab state.

### Evidence checklist (required)
- Impacted tab list matches the `## Scope of visible UI impact` declaration.
- Each impacted tab has screenshot proof captured from the updated build.
- Caption each screenshot with tab name and short note of visible change.
- If no screenshot is attached for an impacted tab, the sprint item is not ready for merge review.
