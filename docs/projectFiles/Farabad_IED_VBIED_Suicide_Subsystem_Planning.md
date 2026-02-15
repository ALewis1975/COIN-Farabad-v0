# Farabad COIN — IED / VBIED / Suicide Bomber Sub-System (Planning Spec)

**Status:** Planning-only (no mission files generated)  
**Scope:** Design + integration plan for a future subsystem to layer into *Farabad COIN*  
**Context:** 2011-era COIN, Takistan AO  

**Design anchors / references (project files):**
- Farabad COIN Mission Design Guide fileciteturn0file3  
- Farabad OPFOR & CIV ORBAT fileciteturn0file0  
- Farabad BLUFOR ORBAT fileciteturn0file1  
- Ambient Dev Mods preset (ACE / EODS+ / etc.) fileciteturn0file2  

---

## Safety / abstraction note

This document describes **gameplay and mission-system abstractions** (threat records, event states, tasks/leads, pacing governors).  
It does **not** describe real-world explosive construction or real-world tactics. Anything “trigger” or “device” related below is intended as an **in-mission mechanic abstraction**.

---

## 1) What this sub-system must achieve in Farabad COIN

### Player experience goals
1. **Make routes and patterns matter** (MSR discipline, route clearance, checkpoint drills, spacing, overwatch).
2. **Create counter-play, not coin-flip deaths**: detection cues, intel warnings, and tactical mitigation options.
3. **Feed the existing COIN loops**:
   - Better security + good conduct → better intel → more precise interdictions → fewer successful attacks.
   - Sloppy/heavy-handed conduct → worse intel → more attacks/recruitment → harder AO. fileciteturn0file3  

### Simulation goals (mission-level)
- Treat insurgent violence like a **cell/network behavior**, not a constant front line spawn. fileciteturn0file3  
- Anchor threat authorship to OPFOR concepts: **TIM IED facilitation cell + VBIED element + urban support** (not a standing “IED army”). fileciteturn0file0  

### Hard technical constraints (Farabad standards)
- **Persistence-safe** (no ghost threats, no duplicate spawns, clean recovery/reset). fileciteturn0file3  
- **Cleanup/despawn discipline** (no lingering objects/AI outside player bubble). fileciteturn0file3  
- **Integrates with Task/Lead/SITREP gating + logging**. fileciteturn0file3  

---

## 2) Sub-system boundaries (what we are building)

Think in four layers:

### A) Threat “economy” layer (when/where threats can happen)
District/village **risk state** + an **attack budget** that controls:
- Event frequency
- Threat type availability (IED vs VBIED vs Suicide)
- Cooldowns and “breathing” after interdictions fileciteturn0file3  

### B) Event generation layer (select a specific event)
Chooses:
- Event type (IED/VBIED/Suicide)
- Target pattern (convoy, foot patrol, checkpoint, base gate, market, shura, etc.)
- Emits a structured **event contract** (ThreatRecord)

### C) Execution layer (spawn/behavior/trigger/counterplay)
In-world artifacts, server-authoritative:
- Emplaced IED objects + abstract trigger behavior
- VBIED vehicles + driver behavior
- Suicide bomber AI + approach/detonation rules

### D) Resolution + COIN feedback layer (world changes)
- Generates tasks/leads
- Applies influence deltas (RED/WHITE/GREEN)
- Writes logs
- Optional narrative effects (market closes, checkpoint compromised, etc.)

---

## 3) Threat types: intended gameplay behavior

### 3.1 Emplaced IEDs (primary, frequent threat)
**Role in COIN:** route denial + tempo disruption + psychological pressure.

**Spawn modes**
1. **Pre-placed but dormant**: created in state, spawned/armed only when players approach.
2. **Event-placed**: created shortly before a likely patrol/convoy uses a route.

**Trigger families (game abstraction)**
- CONTACT / PROXIMITY / REMOTE / TIMED (abstract)

**Counterplay requirements**
- Detectable through procedure + tooling (not purely visual luck).
- Supports controlled use of decoys/duds (tension without constant frustration).

**Mod leverage**
- The active mod preset includes **ACE** and **EODS+ 2.0**, which can be leveraged for EOD interaction scaffolding. fileciteturn0file2  

**Integration hook**
When an IED is:
- discovered,
- detonated,
- rendered safe,  
the sub-system emits a structured incident result that the Task/Lead engine can turn into follow-on work.

---

### 3.2 VBIEDs (rare, high-consequence threat)
**Role in COIN:** punctuated escalation; forces checkpoint/overwatch discipline.

**Two VBIED patterns**
1. **Parked VBIED** (detonates when a target approaches)
2. **Driven VBIED** (attempts to breach a checkpoint / crash into a patrol base / hit a convoy halt)

**Fairness rules (non-negotiable)**
- VBIEDs must be **telegraphed** (intel hints + behavior cues + visible opportunity to react).
- VBIEDs must be **rare** and tied to escalation thresholds, not random spam.

**Where VBIED belongs in Farabad**
- Treat as a **specialized TIM threat** unlocked by the escalation ladder. fileciteturn0file3  
- Align to OPFOR “VBIED cell (low frequency, high consequence)” concept. fileciteturn0file0  

---

### 3.3 Suicide bomber (very rare, targeted threat)
**Role in COIN:** pressures crowd security and key-leader engagements; forces ROE discipline.

**Best-use scenarios**
- Markets, shuras, checkpoints, base-adjacent civilian areas.

**Counterplay**
- Overwatch, standoff, access control, escalation-of-force, partnered presence, controlled entry points.

---

## 4) Integration into Farabad COIN architecture

### 4.1 Fit inside the system-of-systems
Farabad treats “Threat System” as a core subsystem with feedback loops. fileciteturn0file3  
This module should be a **child** of Threat System (not a standalone random spawner).

### 4.2 Use Task/Lead/SITREP as the control surface
Farabad’s spine is: **task → action → SITREP → follow-on**. fileciteturn0file3  
So the threat module should:
- **Emit** leads/tasks
- **Consume** SITREPs/outcomes to modulate future threat generation

### 4.3 ORBAT-aware “who does what” hooks
**BLUFOR anchors** fileciteturn0file1  
- **THUNDER (1-73 CAV):** MSR control / route security ownership
- **SHADOW (RQ-7):** overwatch / pattern detection / route recon
- **SHERIFF (MPs):** detainees + evidence handling + post-blast cordons
- **SENTRY (USAF SF):** base gate posture; VBIED gate drills
- **REDFALCON maneuver:** cordon/search, raids, partnered presence

**Host-nation** fileciteturn0file0  
- **TNP:** checkpoints can be effective or compromised → directly affects success probabilities.
- **TNA:** limited QRF/perimeter support when escalation spikes.

**OPFOR (TIM network)** fileciteturn0file0  
- IED and urban support cells are the “authors” of most events; guerrilla cells exploit incidents with harassment/ambush when appropriate.

### 4.4 Persistence + cleanup rules
- Persist **threat records** (type/pos/state), not necessarily live objects.
- Respawn objects when players return if the threat is still active.
- Always obey Farabad cleanup radius discipline. fileciteturn0file3  

---

## 5) Tasks and leads the module should generate

### 5.1 Lead types (intel outputs)
- **IED Warning Lead** (route likely “hot”)
- **Trigger Man Pattern Lead** (command detonation suspected)
- **Facilitator Node Lead** (components / staging linked to district)
- **VBIED Watch Lead** (suspicious vehicle patterns)
- **Suicide Threat Advisory** (crowd event threatened)

### 5.2 Task types (operational outputs)
- **Route Clearance**
- **Cordon & Search**
- **Checkpoint Establish / Reinforce**
- **SSE / Evidence Collection**
- **Facilitator Raid / Safehouse Search**

These map cleanly into Farabad’s accept/execute/SITREP gate. fileciteturn0file3  

---

## 6) COIN feedback mapping (how outcomes change the AO)

Farabad aims to track district values: **RED influence**, **WHITE sentiment**, **GREEN legitimacy**. fileciteturn0file3  

**If BLUFOR interdicts/defuses cleanly**
- RED ↓, WHITE ↑, GREEN ↑

**If BLUFOR response is heavy-handed / causes collateral**
- WHITE ↓, RED ↑, GREEN ↓

**If an attack succeeds**
- Short-term WHITE often dips (fear), but disciplined response prevents long-term spiral.

---

## 7) Implementation roadmap (phased)

### Phase 0 — Interface + state model (no content)
- Threat record schema
- “Emit lead/task” interface
- Logging spec for transitions

### Phase 1 — Emplaced IED v1 (reliable core)
- Emplaced IED events tied to district risk
- Detection/defusal loop leveraging existing mod interactions
- Post-event lead generation (basic)

### Phase 2 — IED + ambush coupling (optional)
- “Complex attack” package: IED → harassment → break contact
- Event-driven, budget-limited

### Phase 3 — VBIED v1 (rare escalation)
- Parked VBIED first, then driven VBIED
- Strong telegraphing and cooldown governors

### Phase 4 — Suicide bomber v1 (very controlled)
- 1–2 scenario templates only (market / checkpoint)
- Strong safeguards to avoid unfair “spawn on top of you”

### Phase 5 — Full COIN coupling
- Influence-sensitive targeting and intel quality
- Meaningful “facilitator disruption” reduces future event rates

---

## 8) Observability and debugging

- Server-only debug view: active threats by district, budgets, cooldown timers
- Admin-only “force spawn” controls for testing
- Structured logs for every state transition

---

## 9) Decisions to lock down early (scope control)

1. Global vs per-task spawn bubble / despawn radius. fileciteturn0file3  
2. Interaction framework preference (ACE-first vs EODS+-first) given mod stack. fileciteturn0file2  
3. Base gate VBIED frequency policy (must be rare).
4. Evidence/SSE depth (“case file” system vs simple leads).
5. Attribution rules (do we model explicit cell identities like COBRA/VIPER in intel messaging?). fileciteturn0file0  

---

# 10) Threat Record Schema

A **persistence-first, server-authoritative** record representing one insurgent “threat event contract” (IED/VBIED/Suicide) across its whole lifecycle, even if the physical objects despawn/respawn.

## 10.1 Core ThreatRecord (single record, type-specific subfields)

```yaml
ThreatRecord:
  # Identity / persistence
  threatId: string
  version: int
  createdAt: datetime
  createdBy: enum                  # SYSTEM | GM | DEBUG
  seed: int

  # Classification
  threatType: enum                 # IED | VBIED | SUICIDE
  threatSubtype: enum              # type-specific (see below)
  escalationTier: int              # 0..n (violence ladder)
  priority: int                    # 1..5

  # Geography / gating
  districtId: string
  villageId: string|null
  location:
    posATL: [x,y,z]
    grid: string
    nearestRoadId: string|null
    markerRef: string|null
  area:
    objectiveRadiusM: int
    despawnRadiusM: int
    exclusionRadiusM: int

  # State machine
  state: enum                      # PLANNED | STAGED | ACTIVE | DISCOVERED | INTERDICTED | DETONATED | FAILED | EXPIRED | CLEANED
  stateTimestamps:
    stagedAt: datetime|null
    activeAt: datetime|null
    discoveredAt: datetime|null
    interdictedAt: datetime|null
    detonatedAt: datetime|null
    resolvedAt: datetime|null
    cleanedAt: datetime|null

  # Attribution (insurgent network model)
  suspectedActor:
    actorType: enum                # TIM_CELL | CRIMINAL | UNKNOWN
    cellCallsign: enum|null        # COBRA, VIPER, ALPHA, etc.
    confidence: float              # 0.0..1.0
  cellLink:
    cellId: string|null
    courierNodeId: string|null
    safehouseNodeId: string|null

  # Intent / target profile
  targetProfile:
    intendedTarget: enum           # CONVOY | FOOT_PATROL | CHECKPOINT | BASE_GATE | MARKET | SHURA | OTHER
    intendedVictim: enum           # BLUFOR | GREENFOR | CIV | MIXED
    intendedUnitHint: string|null
    timeWindow:
      earliest: datetime|null
      latest: datetime|null

  # Execution parameters (game abstract)
  execution:
    triggerFamily: enum            # CONTACT | PROXIMITY | REMOTE | TIMED
    complexity: int                # 1..5
    concealment: int               # 0..3
    packageCount: int
    hasSecondaryAttack: bool
    rules:
      minStandoffM: int|null
      maxPursuitSeconds: int|null
      abortIfCivDensityHigh: bool

  # Telegraphing / counterplay
  telegraphing:
    intelLevel: int                # 0..3
    cuesEnabled: bool
    warningLeadIds: [string]
    suspiciousActorTag: string|null

  # World entities (ephemeral; may be empty if despawned)
  worldRefs:
    spawned: bool
    spawnedAt: datetime|null
    objectsNetIds: [string]
    vehiclesNetIds: [string]
    unitsNetIds: [string]
    groupsNetIds: [string]

  # Outcomes
  outcome:
    result: enum                   # NONE | DEFUSED | DETONATED | DRIVER_DETAINED | BOMBER_NEUTRALIZED | OTHER
    casualties:
      bluforKIA: int
      bluforWIA: int
      greenKIA: int
      greenWIA: int
      civKIA: int
      civWIA: int
    damage:
      vehiclesDestroyed: int
      vehiclesDamaged: int
      structuresDamagedScore: int  # 0..100
    notes: string|null

  # COIN effects
  influence:
    redDelta: int
    whiteDelta: int
    greenDelta: int
    applied: bool
    appliedAt: datetime|null

  # Task/Lead integration
  intelOutputs:
    leadIds: [string]
    caseFileId: string|null
  taskingOutputs:
    taskIds: [string]
    owningHQ: enum                 # TOC | MOBILE_S3 | other
    suggestedOwnerUnit: string|null
  sitrep:
    sitrepRequired: bool
    sitrepSubmitted: bool
    sitrepId: string|null
    reportedBy:
      unitCallsign: string|null
      leaderRole: string|null
      playerUid: string|null
    reportedAt: datetime|null

  # Cooldowns / governors
  governor:
    districtCooldownUntil: datetime|null
    globalCooldownUntil: datetime|null
    suppressSameRouteUntil: datetime|null
    maxFollowOnTasks: int

  # Audit / logging
  audit:
    lastUpdatedAt: datetime
    lastUpdatedBy: enum            # SYSTEM | GM | DEBUG
    logRefs: [string]
```

## 10.2 Type-specific subtypes (recommended enums)

**IED**
- IED_EMPLACED_SINGLE
- IED_EMPLACED_CHAIN
- IED_REMOTE_DETONATED
- IED_DUD_OR_DECOY

**VBIED**
- VBIED_PARKED
- VBIED_DRIVEN_TO_CHECKPOINT
- VBIED_DRIVEN_TO_BASE_GATE

**Suicide**
- SB_MARKET_APPROACH
- SB_CHECKPOINT_APPROACH
- SB_SHURA_APPROACH

---

# 11) Event-to-Task/Lead Mapping Table

Conventions:
- **Lead** = actionable intel artifact; must be promoted to task before execution. fileciteturn0file3  
- **Task** = mission order accepted by authorized leaders; closed by SITREP. fileciteturn0file3  

## 11.1 IED mapping

| Event / transition | Leads emitted | Tasks emitted | Suggested owner | SITREP |
|---|---|---|---|---|
| IED: PLANNED → STAGED | IED Warning Lead (route hot, confidence from intelLevel) | Usually none; optional Route Recon (low-risk) | THUNDER ROUTE / SHADOW fileciteturn0file1 | No |
| IED: ACTIVE → DISCOVERED | Device Pattern Lead; possible COBRA attribution (low confidence) fileciteturn0file0 | Route Clearance; SSE Collection (optional) | THUNDER / EOD enablers; SHERIFF if detainees fileciteturn0file1 | Yes |
| IED: ACTIVE → DETONATED | Post-Blast Follow-up Lead; Facilitator Node Lead (if evidence) | Cordon & Search; SSE / Site Security; optional casualty recovery | REDFALCON maneuver; SHERIFF; SHADOW fileciteturn0file1 | Yes |
| IED: DISCOVERED → INTERDICTED | Component Trace Lead; Repeat Location Lead | Facilitator Hunt / Raid; optional overwatch interdiction | SHADOW + REDFALCON + THUNDER fileciteturn0file1 | Yes |
| IED: ACTIVE → FAILED/EXPIRED | Optional residual lead | Usually none | TOC | No |

## 11.2 VBIED mapping

| Event / transition | Leads emitted | Tasks emitted | Suggested owner | SITREP |
|---|---|---|---|---|
| VBIED: PLANNED → STAGED | VBIED Watch Lead; Checkpoint Advisory | Checkpoint Establish / Reinforce | THUNDER; SENTRY for base gates; TNP partnered fileciteturn0file1 fileciteturn0file0 | Yes (if task issued) |
| VBIED: ACTIVE → DISCOVERED | Vehicle Origin Lead; Urban Support Lead | Interdiction (stop/search); optional traffic control | THUNDER/SENTRY; SHERIFF (detention) fileciteturn0file1 | Yes |
| VBIED: DISCOVERED → INTERDICTED | Facilitator Node Lead; VBIED cell attribution lead | Raid: staging site; detainee transfer | REDFALCON + SHERIFF + SHADOW fileciteturn0file1 | Yes |
| VBIED: ACTIVE → DETONATED | Network escalation lead; Copycat risk lead | Mass casualty + site security; cordon; optional base defense posture | SENTRY + REDFALCON + LIFELINE fileciteturn0file1 | Yes |

## 11.3 Suicide bomber mapping

| Event / transition | Leads emitted | Tasks emitted | Suggested owner | SITREP |
|---|---|---|---|---|
| SB: PLANNED → STAGED | Suicide Threat Advisory; Crowd Control Advisory | Overwatch/Presence; optional access control | REDFALCON + SHADOW + TNP fileciteturn0file1 fileciteturn0file0 | Yes (if task issued) |
| SB: ACTIVE → DISCOVERED | Urban Support Lead; Pattern Lead | Intercept/Detain; Area Clear | SHERIFF + REDFALCON + TNP fileciteturn0file1 fileciteturn0file0 | Yes |
| SB: DISCOVERED → INTERDICTED | Safehouse Lead; Courier Lead | Targeted Raid; SSE | REDFALCON + SHADOW fileciteturn0file1 | Yes |
| SB: ACTIVE → DETONATED | Retaliation risk lead; Recruitment pressure lead | Mass casualty response; cordon/search; stabilization task (governance) | REDFALCON + LIFELINE + TNP/TNA fileciteturn0file1 fileciteturn0file0 | Yes |

---

## 11.4 Minimal output objects (for clean integration)

### Lead (minimum)
- leadId, sourceThreatId, leadType, location + radius, confidence, suspectedActor + confidence, expiresAt, discoveredBy (optional)

### Task (minimum)
- taskId, sourceThreatId, taskType, objective + radius, owningHQ, suggestedOwnerUnit, successCriteria, state, acceptedBy, sitrepRequired

---

## 11.5 Guardrails (stop spam / ghost content)

1. **One primary follow-on task per threat at a time**  
   Enforce via `governor.maxFollowOnTasks`; if active task exists, emit leads only. fileciteturn0file3  

2. **Every detonation or interdiction creates a SITREP requirement**  
   Threats “resolve” campaign-wise only when SITREP closes the chain. fileciteturn0file3  

3. **Attribution is probabilistic**  
   Start low, improve through SSE/detainees/patterns (COBRA/VIPER confidence grows). fileciteturn0file0  

4. **Suggested owners are ORBAT-consistent**  
   THUNDER routes; SHADOW ISR; SHERIFF detainees; SENTRY gates; REDFALCON cordon/raids. fileciteturn0file1  

---

# 12) State Transition Matrix (allowed transitions)

**Recommended states:** PLANNED → STAGED → ACTIVE → (DISCOVERED → INTERDICTED) or DETONATED, with FAILED/EXPIRED as controlled ends, then CLEANED.

| From → To | Trigger | Guards / Preconditions | Emits (Lead/Task) | Modifies (record + AO) |
|---|---|---|---|---|
| PLANNED → STAGED | Governor schedules | Not in cooldown; not near players; escalation tier allows type fileciteturn0file3 | Optional advisory lead (intelLevel≥1) | state=STAGED; stagedAt; fix contract params; init suspectedActor; log |
| STAGED → ACTIVE | Window opens / players enter | Player within activation envelope; budget valid | Usually none | state=ACTIVE; spawn worldRefs; enforce task cap; log |
| STAGED → EXPIRED | Window closes | No activation by timeWindow.latest | None | state=EXPIRED; resolvedAt; short cooldown; log |
| ACTIVE → DISCOVERED | Device/vehicle/person identified | Not detonated/interdicted; credible discovery | Pattern/origin leads + low-conf attribution lead | state=DISCOVERED; intelLevel↑; sitrepRequired if task issued; log |
| ACTIVE → DETONATED | Trigger met | Fairness rules met (telegraphing opportunity) | Post-blast leads + site security/cordon tasks | state=DETONATED; outcome; influence; cooldowns; tasks; sitrepRequired; log |
| ACTIVE → FAILED | Clean attempt failure | Avoid silent fail | Optional residual lead | state=FAILED; resolvedAt; cleanup worldRefs; short cooldown; log |
| ACTIVE → EXPIRED | Cell stands down | Abort rules trip | Optional residual lead | state=EXPIRED; resolvedAt; cleanup; cooldown; log |
| DISCOVERED → INTERDICTED | Defuse/detain/neutralize | Action completes | Facilitator/node leads; optional raid/detainee tasks | state=INTERDICTED; outcome.result; positive influence if clean; suspectedActor.conf↑; sitrepRequired; log |
| DISCOVERED → DETONATED | Not stopped | Last-chance guardrails | Same as ACTIVE→DETONATED | state=DETONATED; outcome; influence; cooldowns; sitrepRequired; log |
| INTERDICTED → CLEANED | Cleanup cycle | SITREP submitted + leave radius/timer fileciteturn0file3 | None | Despawn worldRefs; cleanedAt; history-only; log |
| DETONATED → CLEANED | Cleanup cycle | SITREP submitted + leave radius/timer | None | Despawn worldRefs; cleanedAt; log |
| FAILED/EXPIRED → CLEANED | Cleanup cycle | Timer or distance | None | Despawn worldRefs; cleanedAt; log |

---

# 13) One-glance state diagram (nodes + arrows)

```text
                    (A3) STAGED→EXPIRED
                ┌────────────────────────┐
                │                        v
(A1) PLANNED → [STAGED] --(A2)--> [ACTIVE] --(A5)--> [DETONATED] --(A11)--> [CLEANED]
   │              │                     │
   │              │                     ├──(A4)--> [DISCOVERED] --(A8)--> [INTERDICTED] --(A10)--> [CLEANED]
   │              │                     │                     └──(A9)--> [DETONATED]  --(A11)--> [CLEANED]
   │              │                     │
   │              │                     ├──(A6)--> [FAILED]   --(A12)--> [CLEANED]
   │              │                     │
   │              │                     └──(A7)--> [EXPIRED]  --(A12)--> [CLEANED]
   │
   └─────────────────────────────────────────────────────────────────────────────
```

---

# 14) A1–A12 reference block (compact Emits/Modifies)

```text
A1) PLANNED → STAGED  (governor schedules event window)
  EMITS:
    - [if intelLevel ≥ 1] Advisory/Watch Lead (type-specific):
      IED: "IED Warning (route hot)" | VBIED: "VBIED Watch / Checkpoint Advisory" | SB: "Suicide Threat Advisory / Crowd Control"
  MODIFIES:
    - state=STAGED; stagedAt=now
    - Fix contract: seed + targetProfile.timeWindow + execution.*
    - suspectedActor init: UNKNOWN (low conf) or low-confidence cell hint (e.g., COBRA/VIPER)
    - intelOutputs.leadIds[] append (if emitted)
    - audit/log append

A2) STAGED → ACTIVE  (players enter threat bubble and/or window opens)
  EMITS:
    - None (optional explicit warning lead only if intelLevel=3)
  MODIFIES:
    - state=ACTIVE; activeAt=now
    - Spawn worldRefs.*NetIds; worldRefs.spawned=true
    - Enforce anti-stacking: if maxFollowOnTasks reached ⇒ suppress new tasks (leads only)
    - audit/log append

A3) STAGED → EXPIRED  (window closes without activation)
  EMITS:
    - None
  MODIFIES:
    - state=EXPIRED; resolvedAt=now
    - Apply short cooldowns (districtCooldownUntil; optional globalCooldownUntil)
    - audit/log append

A4) ACTIVE → DISCOVERED  (identified pre-event: device/vehicle/person)
  EMITS:
    - Pattern/Origin Lead(s) + low-confidence attribution Lead (type-specific):
      IED: "Device Pattern / early Component Trace" | VBIED: "Vehicle Origin / staging indicators" | SB: "Bomber/Approach Pattern"
    - Optional immediate task ONLY if your rules allow (otherwise lead stays for TOC promotion)
  MODIFIES:
    - state=DISCOVERED; discoveredAt=now
    - telegraphing.intelLevel ↑ (for follow-on logic)
    - If any task issued ⇒ sitrepRequired=true
    - audit/log append

A5) ACTIVE → DETONATED  (trigger met; event succeeds)
  EMITS:
    - Post-blast Lead package (type-specific):
      IED: "Trigger-man area / repeat-location risk"
      VBIED: "Network escalation / copycat risk"
      SB: "Retaliation / fear spike risk"
    - Task package (suggested owners in parentheses):
      Core: "Site Security" + "Cordon & Search" (REDFALCON)
      Add-ons: "Mass Casualty Response" (LIFELINE) as needed; "Base Defense Posture" (SENTRY) if base gate
  MODIFIES:
    - state=DETONATED; detonatedAt=now
    - outcome.casualties + outcome.damage fill
    - influence deltas queued/applied (negative bias; tuned by collateral/discipline)
    - Strong cooldowns (district/global/route suppression)
    - taskingOutputs.taskIds[] append; sitrepRequired=true
    - audit/log append

A6) ACTIVE → FAILED  (clean failure: AI/pathing/timeout; avoid silent fail)
  EMITS:
    - Optional low-confidence residual Lead ("possible attempt / residual risk")
  MODIFIES:
    - state=FAILED; resolvedAt=now
    - Cleanup worldRefs now (or mark for cleanup) if spawned
    - Short cooldowns
    - audit/log append

A7) ACTIVE → EXPIRED  (cell stands down while active / abort rules trip)
  EMITS:
    - Optional low-confidence residual Lead
  MODIFIES:
    - state=EXPIRED; resolvedAt=now
    - Cleanup worldRefs if spawned
    - Cooldowns
    - audit/log append

A8) DISCOVERED → INTERDICTED  (defused / driver detained / bomber neutralized)
  EMITS:
    - Facilitator/Node Lead package (type-specific):
      IED: "Component Trace → Facilitator Node"
      VBIED: "Staging Site → Raid Lead"
      SB: "Safehouse/Courier Lead"
    - Optional follow-on tasks (subject to maxFollowOnTasks):
      "Raid/Targeted Search" (REDFALCON) and/or "Detainee Transfer" (SHERIFF)
  MODIFIES:
    - state=INTERDICTED; interdictedAt=now
    - outcome.result = DEFUSED | DRIVER_DETAINED | BOMBER_NEUTRALIZED
    - Positive COIN deltas if handled cleanly (WHITE↑, GREEN↑, RED↓)
    - suspectedActor.confidence ↑ if evidence/detainee (often COBRA/VIPER linkage)
    - Enforce task cap; if any task exists ⇒ sitrepRequired=true
    - audit/log append

A9) DISCOVERED → DETONATED  (identified but not stopped in time)
  EMITS:
    - Same as A5 (typically higher urgency wording in tasking)
  MODIFIES:
    - Same as A5 (often stronger negative deltas + longer cooldowns; tuning choice)
    - audit/log append

A10) INTERDICTED → CLEANED  (post-action cleanup)
  EMITS:
    - None
  MODIFIES:
    - Gate: sitrepSubmitted=true AND players outside despawn radius (or timer override)
    - Despawn all worldRefs.*NetIds; worldRefs.spawned=false
    - cleanedAt=now; record becomes history-only
    - audit/log append

A11) DETONATED → CLEANED  (post-blast cleanup)
  EMITS:
    - None
  MODIFIES:
    - Same cleanup gate as A10 (SITREP/timer/radius per your rules)
    - Despawn worldRefs.*NetIds; worldRefs.spawned=false; cleanedAt=now
    - audit/log append

A12) FAILED/EXPIRED → CLEANED  (cleanup after non-resolution end states)
  EMITS:
    - None
  MODIFIES:
    - Cleanup on timer/radius; despawn worldRefs if any; cleanedAt=now
    - audit/log append

GLOBAL RULES (apply to all arrows above):
  G1) Anti-stacking: if governor.maxFollowOnTasks reached ⇒ emit leads only until SITREPs close the chain.
  G2) Campaign resolution is SITREP-gated: detonations/interdictions may create immediate tactical tasks, but finalize strategic effects
      (influence severity, cooldown severity, follow-on unlocks) when sitrepSubmitted=true.
```

---

## Appendix — Why this fits Farabad’s mission philosophy

- It is **event-driven and network-driven**, not a constant front line. fileciteturn0file3  
- It routes everything through **tasks/leads and SITREPs**, preserving the “mission spine.” fileciteturn0file3  
- It cleanly assigns responsibility to existing **ORBAT units** and cell concepts (THUNDER/SHADOW/SHERIFF/SENTRY/REDFALCON; COBRA/VIPER/ALPHA). fileciteturn0file1 fileciteturn0file0  
- It respects **cleanup/persistence standards** to protect performance and prevent state drift. fileciteturn0file3  
