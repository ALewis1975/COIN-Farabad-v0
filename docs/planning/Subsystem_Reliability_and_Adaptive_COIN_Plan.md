# Subsystem Reliability and Adaptive COIN Plan

**Date:** 2026-05-14
**Mode:** F — Documentation-Only Changes
**Status:** Planning and execution contract
**Scope:** Reliability sweeps and adaptive enemy/population behavior planning only. No runtime behavior changes are introduced by this document.

---

## 1) Purpose

This plan expands the Phase 4 reliability sweep in `docs/architecture/Architecture_Plan_2026-05-08.md` into an executable PR sequence. It also defines the next adaptive COIN behavior track: threat activity, IED/VBIED/ambush pressure, and intel quality should be driven by district posture and network state, not by disconnected random spawning.

The intent is to keep reliability proof and new adaptive behavior separate:

1. **Reliability sweeps first:** prove existing lifecycle loops and record failures as bounded follow-up tasks.
2. **Adaptive COIN behavior second:** strengthen the threat economy only after the existing system is observable, stable, and validated.

---

## 2) Guardrails

- Preserve the server-authoritative single-writer model.
- Clients remain requesters/read-only snapshot consumers.
- Do not add new RemoteExec endpoints as part of reliability sweeps.
- Do not mix implementation changes into validation-only PRs.
- Do not claim dedicated/JIP readiness from static review alone.
- Keep every follow-up PR in a single primary mode under `AGENTS.md`.
- Keep adaptive threat behavior COIN-network-driven: district posture, influence, threat records, recent incidents, and intel quality are inputs; random spawn chance alone is not sufficient.

---

## 3) Workstream A — Subsystem reliability sweeps

Each sweep produces a checklist, runtime notes, RPT excerpts if available, and a PASS / FAIL / BLOCKED entry in `tests/TEST-LOG.md`.

### A1 — AIRBASE / CASREQ

**Goal:** prove the air operations lifecycle from request through clearance, execution, and cleanup.

Acceptance focus:

- AIRBASE arrival/departure queues advance without stalls.
- Taxi, runway lock, emergency, hold, release, and cancel paths remain server-authoritative.
- CASREQ open / decide / execute / close paths remain role-gated and snapshot-visible.
- Airbase UI snapshots remain fresh enough for operators to explain current state.
- Failures become bounded Mode A or Mode J follow-up tasks.

Deferred runtime proof:

- Dedicated fresh start.
- JIP after active airbase queue state exists.
- Reconnect during pending clearance or active CASREQ.

### A2 — SitePop / Prison

**Goal:** prove named-site population and prison-specific interactions under the intended mod stack.

Acceptance focus:

- Existing marker anchors, including rectangle markers, resolve consistently.
- Spawn/despawn lockouts prevent flicker during active contact.
- Prison staffing uses expected 3CB classes or logs clear dependency failures.
- Detainee, sheriff handoff, and prison incident paths remain server-mediated.
- LAMBS fallback behavior is explicit when optional functions are unavailable.

Deferred runtime proof:

- Local MP prison interaction smoke.
- Dedicated SitePop activation/deactivation smoke.
- JIP after active site state exists.

### A3 — CIVSUB / Threat / IED

**Goal:** prove population, influence, threat records, and IED lifecycle coupling.

Acceptance focus:

- CIVSUB deltas update district posture through server-owned state.
- Threat records remain stable pairs-array records and do not require client inference.
- IED / VBIED / suicide bomber lifecycle events produce visible threat evidence and cleanup.
- Threat economy snapshots explain allow/deny outcomes.
- No attack or IED path bypasses protected-zone checks.

Deferred runtime proof:

- Full mod-stack CIVSUB sampling run.
- Threat scheduler run with multiple district postures.
- IED evidence/disposal flow with JIP observer.

### A4 — TASKENG / SITREP / follow-on orders

**Goal:** prove the command cycle that defines the mission spine.

Acceptance focus:

- Task acceptance, execution, SITREP, closeout, and follow-on orders complete without orphaned state.
- Unit status, queue, orders, lead pool, and public snapshots remain consistent.
- TOC role gates remain enforced for privileged actions.
- Rebuild/reset paths do not leave ghost tasks or stale addActions.

Deferred runtime proof:

- End-to-end hosted MP command-cycle smoke.
- Dedicated restart after active or recently closed task.
- JIP during active task and after follow-on order emission.

### A5 — Logistics / Medical / World ambience

**Goal:** prove supporting systems do not degrade long-running operations.

Acceptance focus:

- Convoy spawn/tick/cleanup paths complete without abandoned groups or vehicles.
- Medical casualty accounting updates through the single broadcast path.
- CASEVAC requests remain sender-bound and role/state appropriate.
- World gate and base ambience systems initialize from expected mission data.
- Ambient systems respect protected zones and do not interfere with command-critical state.

Deferred runtime proof:

- Long-running hosted MP smoke.
- Dedicated world-init and gate behavior smoke.
- JIP after convoy, medical, or world ambience state changes.

---

## 4) Workstream B — Adaptive enemy/population behavior

This workstream starts after Workstream A has either passed or converted failures into bounded implementation tasks.

### B1 — Threat economy strengthening

Goal:

- Make threat activity explainable through risk, budget, cooldown, escalation tier, district posture, and recent player behavior.

Acceptance focus:

- Scheduler allow/deny decisions remain visible in the threat economy snapshot.
- Attack budgets and cooldowns prevent constant spawn pressure.
- Escalation tiers gate higher-impact events.
- Denied events are logged with a stable reason taxonomy.

### B2 — District-posture-driven attacks

Goal:

- Tie attacks, ambushes, IEDs, VBIEDs, and suicide bomber pressure to district posture rather than isolated random checks.

Acceptance focus:

- High RED / low GREEN / low WHITE conditions increase insurgent opportunity.
- Better governance and civilian sentiment reduce hostile opportunity or improve warning quality.
- Recent heavy-handed actions can increase grievance-driven risk.
- Recent effective operations can suppress cell capacity or delay attacks.

### B3 — Intel quality coupling

Goal:

- Make intel quality an output of population trust, recent conduct, threat pressure, and district stability.

Acceptance focus:

- Cooperative districts produce more precise or earlier warnings.
- Hostile or intimidated districts produce vague, delayed, or misleading reports.
- Intel quality affects lead fidelity without giving clients authority over threat state.
- Console and diary outputs explain uncertainty without exposing hidden raw scheduler internals.

### B4 — COIN-network event selection

Goal:

- Select hostile events from a network model: active cells, facilitators, district posture, previous incidents, and opportunity windows.

Acceptance focus:

- Event selection considers cell capacity and recent disruption.
- Protected zones remain hard exclusions unless explicitly overridden by mission design.
- Repeated events in the same district are bounded by cooldowns and budgets.
- Follow-on leads can emerge from successful disruption or evidence collection.

---

## 5) Recommended PR sequence

1. **Mode J:** AIRBASE / CASREQ reliability sweep evidence.
2. **Mode J:** SitePop / Prison reliability sweep evidence.
3. **Mode J:** CIVSUB / Threat / IED reliability sweep evidence.
4. **Mode J:** TASKENG / SITREP / follow-on reliability sweep evidence.
5. **Mode J:** Logistics / Medical / World ambience reliability sweep evidence.
6. **Mode I or A:** Security/bug fixes discovered by sweeps.
7. **Mode B:** Threat economy strengthening implementation.
8. **Mode B:** District-posture-driven attack selection.
9. **Mode B:** Intel quality coupling.
10. **Mode B:** COIN-network event selection and follow-on lead coupling.

---

## 6) Done criteria for this planning slice

- Reliability sweep scope is split by subsystem family.
- Adaptive behavior is separated from validation-only work.
- Acceptance criteria distinguish static review, hosted/local MP, dedicated, and JIP proof.
- Future implementation remains server-authoritative and district/network-driven.
- Runtime gaps remain explicit instead of being treated as completed by documentation.
