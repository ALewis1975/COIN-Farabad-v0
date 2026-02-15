# Farabad COIN — Prompting & Integration Playbook (Project Standard)

**Status:** Project standard (use in every development thread)  
**Applies to:** All Farabad COIN systems work (SQF, UI, persistence, MP/JIP, subsystems)  
**Goal:** Prevent system drift, regressions, duplicated work, and “it works locally but breaks in MP/JIP” failures.

---

## Why this exists

When a mission gets layered, the biggest risk isn’t a single bug — it’s **systems drifting out of alignment**.

“Vibe coding” works early. Once AI logic, tasks/leads, persistence, triggers, UI, and MP locality interact, you must start prompting like a **technical director**:

- Define authority and execution order before code  
- Demand explicit contracts between subsystems  
- Require observability (logs + snapshots)  
- Enforce “patch, not rewrite” discipline  
- Prove integration with acceptance tests

This file is the playbook to do that.

---

## Absolute guardrails (Farabad non‑negotiables)

Use these as constraints in *every* plan and patch.

### Authority and interfaces
- **Server is single-writer** for persistent and campaign state.
- **Clients submit requests**; server validates, mutates state, and publishes updates.
- **Consumers never guess:** UIs and consumers must be driven by explicit snapshots, not inferred state.

### Integration bus and contracts
- Prefer **structured event envelopes** / delta bundles (one event → one bounded envelope) for cross-system integration.
- Use **stable IDs** and canonical keys (no “friendly name” keys).
- Persist state with **schema versioning** and a **reset persistence** workflow.

### Reliability and lifecycle
- Everything must be safe in **dedicated MP**.
- **JIP must reconstruct state** (from server snapshots).
- All record stores must be **bounded** (caps/TTLs) to avoid unbounded growth.
- **Log critical lifecycle transitions** with timestamp, actor, object ID, and location (grid/marker).
- Respect cleanup / despawn discipline (bubble-based; do not assume long-lived world entities).

### Development discipline
- **Extend existing systems; do not create parallel systems** unless explicitly deprecating the old one.
- **Refactor, don’t rewrite** unless you are explicitly authorized to rewrite.
- **Minimal diffs only:** do not reformat or reorganize unrelated code.

> **Operational note:** Turn off OneDrive sync for the mission folder. Sync conflicts and rollbacks are a recurring source of “regressions” and duplicate work.

---

## How to use this file in every project thread

When a thread asks for a plan or code, it must:
1. **Declare execution context** (MP/dedicated/JIP/locality/HC).
2. **Anchor sources of truth** (which baselines/specs/dictionary are authoritative).
3. **Require a system contract** (owned keys, public API, events, persistence keys).
4. **Require integration hooks** (call points into existing systems).
5. **Require a state model** (states, transitions, guards, idempotency).
6. **Require debugging and observability** (logs + debug snapshot).
7. **Require patch discipline** (allowed files list, minimal diffs).
8. **Require acceptance tests** (dedicated MP + JIP + persistence + cleanup).

If a request does not include these, treat it as incomplete and rewrite the prompt to include them.

---

## Prompting workflow: Plan → Patch → Verify

### Phase 1: PLAN (design authority; no code)
Deliverables:
- Responsibilities and boundaries
- Execution order (init → runtime → sync → cleanup → persistence/JIP restore)
- State machine (states, transitions, guards)
- Contract (owned keys, public functions, events/delta bundles)
- Hook points (where this integrates into existing code)
- Logging and debug snapshot fields
- Acceptance tests

### Phase 2: PATCH (minimal changes; code)
Deliverables:
- Minimal diffs only
- Only touch authorized files
- No unrelated refactors

### Phase 3: VERIFY (prove integration)
Deliverables:
- 10-minute smoke test plan for dedicated MP + JIP
- “Expected logs / snapshots” list (what success looks like)
- Regression risks + how to detect them

---

## Mandatory context block (paste into most prompts)

Copy/paste and fill:

```text
CONTEXT
- Mission type: Dedicated MP
- JIP: REQUIRED (must reconstruct state)
- Headless clients: (none | present; describe duties)
- Authority: server is single-writer; clients request only
- UI: client-side and snapshot-driven (“consumers never guess”)
- Cleanup: bubble-based despawn; do not assume long-lived world entities

SOURCES OF TRUTH
- Mission Design Guide: authoritative cross-cutting rules
- Project Dictionary: naming, IDs, key conventions
- Subsystem baseline/spec: (name the exact file; baseline vs planning matters)
- ORBAT (if relevant): unit/callsign/ownership references must match

DELIVERABLES
- First: integration contract + state model + execution order (no code)
- Then: minimal patch (no rewrites, no reformatting)
- Then: verification checklist (dedicated + JIP + persistence + cleanup)

CONSTRAINTS (MUST HOLD)
- stable IDs, versioned persistence, bounded stores
- lifecycle logs + debug snapshot
- idempotent (safe to call twice; safe across save/load; safe for JIP)
```

---

## System contract checklist (required before coding)

Before code, require explicit answers:

### Owned state
- What `missionNamespace` keys does this system **own**?
- What keys does it **read only**?
- What persistent blob key(s) does it use? What schema version?

### Public API
- What functions are public and stable?
- What functions are internal helpers only?

### Events / delta bundles
- What events does it emit?
- What snapshots are included so consumers do not infer anything?
- What are the bounds (max messages, max history, TTLs)?

### Side effects
- What world entities are spawned?
- How are they registered for cleanup?
- What happens on mission restart / persistence reload?

### Locality and timing
- What machine runs what code (server, client, HC)?
- What is the init order? What is safe on JIP?

---

## Required state model (state machine discipline)

Every subsystem must define:
- Enumerated states (INIT, STAGING, ACTIVE, FAILSAFE, CLEANUP, etc.)
- Allowed transitions
- Guard conditions
- Idempotency rules (calling twice does not duplicate spawns/handlers/logs)
- Failure states and recovery rules (no silent failure)

If a state transition occurs, it must:
- update timestamps (if applicable)
- increment revision counters (if applicable)
- emit logs (and events, if applicable)

---

## Debugging and observability (mandatory)

If it’s not debuggable, it’s not finished.

Every system should include:
- Structured `diag_log` / OPS log events for lifecycle transitions
- A single debug toggle, e.g. `missionNamespace setVariable ["<subsystem>_<ver>_debug", true, true];`
- A `*_DebugSnapshot` function that returns:
  - counts by state
  - last event
  - a bounded list of open records/IDs
- Optional markers/visualization for dev/admin only (if appropriate)

---

## Patch discipline (how we stop regression and rewrites)

### Rules for code changes
- **List allowed files**. Only modify those files.
- **Output minimal diffs**. Do not reformat.
- **Do not introduce new architecture** unless explicitly requested.
- Prefer “add a small wrapper/hook” over “rewrite the core loop.”
- If something already exists, **extend it** rather than build a parallel version.

### Duplication traps to actively prevent
- Duplicate schedulers/ticks
- Duplicate `addAction` / ACE interactions
- Duplicate event handlers
- Duplicate persistence loads/saves
- Duplicate “debug globals” and ad-hoc flags

Your patch must explicitly say how it avoids these.

---

## Acceptance tests (required per patch)

Every patch must ship with pass/fail checks for:

### Multiplayer correctness
- Dedicated MP: correct authority (server writes state, clients do not)
- JIP: state reconstructs from server snapshot; no missing UI state
- Respawn: no duplicated handlers/actions

### Persistence correctness
- Save/load: no duplicate records/spawns; schema version handled
- Reset persistence: clean empty state; no ghost tasks/records

### Cleanup correctness
- Leaving bubble triggers cleanup; re-entering restores from record state
- No orphaned objects/groups; all worldRefs cleared

### Observability
- Logs include object ID + grid + actor
- Debug snapshot reflects correct counts and IDs

---

## Prompt templates (use these verbatim)

### Template A — AUDIT MODE (stop duplicates before coding)
Use when you suspect you’ve built the same thing twice.

```text
AUDIT MODE. No new code.
Goal: detect duplication/regression risk before coding.
Context: Dedicated MP; JIP required; server single-writer; UI snapshot-driven.

Inputs: file tree + pasted implementations below.

Task:
1) Identify overlapping responsibilities and duplicate state/handlers/schedulers.
2) Propose the smallest consolidation plan (one owner per concept).
3) Output a patch plan only (no code), listing exact files/functions to delete/keep/change.
4) List regression risks + acceptance tests.

Constraints: stable IDs, bounded stores, versioned persistence, logging, cleanup discipline.
```

### Template B — DESIGN MODE (technical director)
Use when starting a new subsystem or major change.

```text
DESIGN MODE (no code yet).
Context: Dedicated MP; JIP required; server is single-writer; UI is snapshot-driven.

Goal: Design subsystem X.

Deliver:
1) Layered design: init → runtime → network sync → cleanup/fail-safe → persistence/JIP restore → observability
2) State machine: states, transitions, guards, idempotency rules
3) System contract: owned keys, read-only keys, public API, emitted events/delta bundles (bounded)
4) Integration hook points: name exact call sites into existing systems
5) Acceptance tests: dedicated MP + JIP + persistence + cleanup
```

### Template C — PATCH MODE (minimal diff only)
Use when you already know what must change.

```text
PATCH MODE. Minimal diffs only.
Authoritative spec: [name baseline doc]. Do not invent new schema.
Allowed files:
- path/file1.sqf
- path/file2.sqf
Disallowed: everything else.

Constraints:
- server single-writer; clients request only
- consumers never guess (events include snapshots)
- stable IDs; dictionary naming rules
- versioned persistence; bounded stores
- logs for lifecycle transitions
- idempotent across repeated calls + restart + JIP

Deliver:
1) Unified diffs per file
2) Verification checklist (what to see in logs / debug snapshots)
```

### Template D — REGRESSION CHECK MODE (after a patch)
Use immediately after code changes.

```text
REGRESSION CHECK MODE.
Given the patch + file tree:
- What could this break? (authority, persistence, cleanup, task gating, UI)
- Any new duplicate keys/handlers/schedulers introduced?
- Any violations of single-writer or consumers-never-guess?
- Provide a 10-minute smoke test plan with expected logs/snapshots.
```

### Template E — EXECUTION ORDER DIAGRAM (timing bug prevention)
Use for anything that touches init, tasks, UI, or persistence.

```text
Describe exact execution order from:
mission start → initServer/initPlayerLocal/postInit → player spawn/respawn → JIP join → system activation → end condition.
For each step: which machine executes it (server/client/HC) and what state it requires/produces.
```

---

## “Golden prompt footer” (paste at the end of most requests)

```text
HARD RULES
- Extend existing systems; do not create parallel systems.
- Minimal diff; do not reformat unrelated code.
- Server is single-writer; clients request only.
- Consumers never guess; include explicit snapshots.
- Stable IDs; versioned persistence; bounded stores; lifecycle logging.
- Idempotent across multiple calls + save/load + JIP.
- Include a verification checklist (dedicated + JIP + persistence + cleanup).

OPERATIONAL NOTE
- Ensure pasted code/files come from the mission folder actually used by the server.
- Disable OneDrive sync for the mission directory to avoid silent rollbacks.
```

---

## Final reminder

If you feel “we keep redoing the same work,” it’s almost always one of:
- No explicit source of truth (baseline vs planning spec confusion)
- No contracts (globals and side effects collide)
- No patch discipline (refactors become rewrites)
- No observability (can’t prove what ran where)
- OneDrive sync conflicts (silent regressions)

Use this playbook to force clarity and stop the loop.

