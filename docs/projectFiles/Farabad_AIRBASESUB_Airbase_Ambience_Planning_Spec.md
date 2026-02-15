# Farabad COIN — Airbase Ambience Sub-System (Planning Spec)

**Status:** Planning-only (no mission files generated in this step)  
**Date:** 2026-01-02  
**Scope:** Ambient airbase operations for Joint Base Farabad: continuous arrivals/departures, AI/Player tower hybrid control, pilot clearance requests, and TOC awareness hooks.  
**Setting:** 2011-era joint hub (USAF host installation, Army tenants) consistent with the Farabad project’s BLUFOR ORBAT.

---

## 0) v1 locks from the development thread (non-negotiable)

1. **No Guardpost / Holster features** in this subsystem (reserved for a later base-security module).
2. **Ambient unit animations:** only Bohemia’s ambient animation function and its terminate/cleanup counterpart (no custom `switchMove` loops, no `plamove`-dependent stacks).  
3. **Tower Assist AI anchor:** an AI unit in the Farabad Tower group exists and is assigned the editor variable name `FarabadTower_LA`.
4. **Player controllers only control player units.** Controllers influence AI tower behavior through policy/override controls, not through direct AI group command.
5. **Continuous traffic:** as long as at least one player is active in-mission, **ambient arrivals and departures continue** (virtual schedule never “runs out”).
6. **Use existing editor layers for unit ORBATs** (no changes to those layers as part of this subsystem).
7. **Role identifiers (v1):**
   - Local Controller: `farabad_tower_lc`
   - Watch Supervisor / CIC: `farabad_tower_ws_ccic`
8. **Airbase bubble center marker (v1):** `mkr_airbaseCenter`
9. **Comms visibility:** AI/ATC text output is visible **only within the airbase bubble**.
10. **Rotary-wing parity:** helicopters taxi, take off, and land through the **same clearance workflow** as fixed-wing aircraft (same request types, same queue/arbitration, same state model).

---

## 1) Why AIRBASESUB exists

Farabad’s mission design calls for a base that “feels alive” through **flightline activity** and other world-simulation behaviors, while keeping the overall system stable through cleanup, persistence discipline, and predictable control surfaces. AIRBASESUB provides the airfield portion of that “World Simulation” layer.

AIRBASESUB is responsible for:
1. Maintaining a **continuous virtual flight schedule** (arrivals/departures) while players are active.
2. Producing a **clearance and sequencing model** that works with:
   - player controllers (LC and WS/CCIC),
   - AI tower (via `FarabadTower_LA`),
   - player pilots requesting taxi/takeoff/landing.
3. Spawning/despawning **physical aircraft and crew** only when relevant (airbase bubble active), while continuing the **virtual** schedule at all times.

---

## 2) Hard constraints from Farabad architecture (how we avoid breaking the mission)

### 2.1 Cleanup and performance discipline
Farabad uses a despawn/cleanup bubble philosophy to protect performance and reduce state drift. AIRBASESUB must not depend on permanently-existing aircraft outside the player relevance bubble.

**Implication:** “continuous traffic” must be achieved with a **virtual schedule** that can advance even when physical aircraft are not spawned.

### 2.2 Convoy routing separation
The base convoy system routes convoys to `North_Gate` and keeps them off the airfield surface to protect flightline simulation and reduce AI pathfinding failures.

**Implication:** AIRBASESUB must treat the runway/taxiway surface as a **protected space** and avoid introducing ground-vehicle ambient behavior that can spill onto the airfield surface.

### 2.3 Single-writer principle (server authority)
State changes (schedule advancement, runway locks, clearance decisions, spawn/despawn) should be server-authoritative. Clients can request clearances, but they do not commit schedule/state.

---

## 3) Subsystem boundaries (what we are building)

Think in four layers.

### A) Virtual Traffic Model Layer (always-on while players exist)
Owns:
- flight generation (tenant pools, cadence, variability)
- schedule advancement
- flight records and lifecycle states (virtual-first)

Does not own:
- physical spawning
- UI specifics (only provides data/events)

### B) Clearance and Control Layer (AI + player hybrid)
Owns:
- pilot request queue (TAXI, TAKEOFF, LAND)
- tower mode switching (AI-only vs Hybrid)
- arbitration policy (runway/ground movement priority)
- role-based permissions

Does not own:
- direct AI piloting micro-control (except through controlled execution steps in Execution Layer)

### C) Execution Layer (physical simulation inside the bubble)
Owns:
- spawn/despawn aircraft and crew
- taxi/takeoff/landing sequences
- runway/taxi locks
- ambient crew idles (BIS ambient anim only)

Does not own:
- base security posture logic (deferred)

### D) Observability + Integration Layer
Owns:
- debug views (admin/dev)
- structured logging
- event emission for TOC/GUI integration

---

## 4) Authority model (who decides)

### 4.1 Ultimate decision maker (virtual)
For AIRBASESUB, the “ultimate decision maker” is the **Tower Watch Supervisor / CIC** role. In practice:
- If a player occupies `farabad_tower_ws_ccic`, that player is the acting CIC.
- If no player occupies CIC, the AI tower (via `FarabadTower_LA`) acts as CIC proxy under the same policy.

### 4.2 Control roles (v1)
- **WS/CCIC** (`farabad_tower_ws_ccic`): can approve/deny player requests and set tower policy toggles (hold/resume ambient departures, reserve runway windows, etc.).
- **Local Controller (LC)** (`farabad_tower_lc`): can approve/deny player requests but cannot change global tower policy unless WS/CCIC absent (optional rule).

### 4.3 Pilot role (v1)
- Any player acting as aircraft pilot can request:
  - taxi clearance
  - takeoff clearance
  - landing clearance  
  for fixed-wing and rotary-wing aircraft (parity requirement).

### 4.4 TOC stakeholders (v1)
- **Army Aviation LNO**: can request a priority slot (request, not authority).
- **USAF JTAC/TACP (RAVEN)**: can request a priority slot and view inbound/outbound status to deconflict CAS timing with base traffic.

(These requests are processed as “priority slot requests” inside AIRBASESUB and must be approved/denied by CIC policy.)

---

## 5) Contracts (data structures and events)

### 5.1 FlightRecord (virtual-first, persistence-safe)
A FlightRecord exists whether or not a physical aircraft exists.

```yaml
FlightRecord:
  flightId: string
  seed: int
  category: enum        # FIXED_WING | ROTARY
  direction: enum       # ARRIVAL | DEPARTURE
  callsignRoot: string  # REACH | TEXACO | TIGER | HAWG | etc. (config)
  callsignFull: string
  airframePoolId: string
  scheduleTs: float     # serverTime, intended event time
  priority: int         # 0 normal | 1 priority | 2 emergency
  state: enum           # see Section 6
  bubbleRequired: bool  # if true, must wait for airbase bubble to execute physically
  physical:
    spawned: bool
    vehicleNetId: string|null
    crewNetIds: [string]
  clearances:
    taxi: enum          # NONE|REQUESTED|GRANTED|DENIED
    takeoff: enum
    landing: enum
  timestamps:
    createdAt: float
    spawnedAt: float|null
    airborneAt: float|null
    landedAt: float|null
    despawnedAt: float|null
  notes: string|null
```

### 5.2 PilotRequest
```yaml
PilotRequest:
  requestId: string
  requestType: enum     # TAXI | TAKEOFF | LANDING
  pilotNetId: string
  vehicleNetId: string
  category: enum        # FIXED_WING | ROTARY
  requestedAt: float
  status: enum          # PENDING | APPROVED | DENIED | TIMEOUT_TO_AI | CANCELLED
  reason: string|null
  linkedFlightId: string|null   # if the request binds to a FlightRecord
```

### 5.3 PrioritySlotRequest (TOC)
```yaml
PrioritySlotRequest:
  slotId: string
  requestedByNetId: string
  requestedByRole: enum  # AVIATION_LNO | JTAC_TACP | OTHER
  vehicleNetId: string|null
  desiredWindowStart: float
  desiredWindowEnd: float
  priorityLevel: int      # 1 priority | 2 emergency
  status: enum            # PENDING | APPROVED | DENIED | EXPIRED
  decisionBy: string|null # CIC netId or "AI"
```

### 5.4 Airbase Event Bus (for GUI + logging)
AIRBASESUB emits events in a single envelope format so consumers do not infer state.

```yaml
AirbaseEvent:
  v: 1
  eventId: string
  ts: float
  source:
    system: "AIRBASE"
    module: "SCHEDULER|ATC|EXECUTION|DEBUG"
    event: enum
  payload: {}
  tags: []
```

**Event enum (v1 minimum):**
- `FLIGHT_SCHEDULED`
- `FLIGHT_STATE_CHANGED`
- `FLIGHT_SPAWNED`
- `FLIGHT_DESPAWNED`
- `RUNWAY_STATE_CHANGED`
- `CLEARANCE_REQUESTED`
- `CLEARANCE_GRANTED`
- `CLEARANCE_DENIED`
- `PRIORITY_SLOT_REQUESTED`
- `PRIORITY_SLOT_DECIDED`

---

## 6) State model

### 6.1 TowerMode
- `AI_AUTOMATION`: AI tower handles all decisions.
- `PLAYER_HYBRID`: players exist in tower roles; AI continues schedule, but player ops take priority and CIC can toggle policy.

**v1 default:** `PLAYER_HYBRID` (fallback to `AI_AUTOMATION` when no tower players exist).

### 6.2 RunwayState
- `OPEN`
- `RESERVED` (reserved for a specific aircraft/request)
- `OCCUPIED_TAKEOFF`
- `OCCUPIED_LANDING`
- `CLOSED` (reserved for later incidents; v1 may omit)

RunwayState fields:
- `state`
- `ownerId` (flightId or requestId)
- `untilTs` (auto-release timestamp)
- `queue` (ordered list of requestIds / flightIds)

### 6.3 Flight lifecycle states (virtual-first)
**Departure**
- `SCHEDULED_VIRTUAL`
- `READY_VIRTUAL`
- `WAITING_FOR_BUBBLE`
- `SPAWNED_PHYSICAL`
- `TAXI_REQUESTED`
- `TAXI_GRANTED`
- `TAXIING`
- `HOLD_SHORT`
- `TAKEOFF_REQUESTED`
- `TAKEOFF_GRANTED`
- `DEPARTING`
- `AIRBORNE`
- `COMPLETED_VIRTUAL`

**Arrival**
- `SCHEDULED_VIRTUAL`
- `INBOUND_VIRTUAL`
- `WAITING_FOR_BUBBLE`
- `SPAWNED_PHYSICAL`
- `LAND_REQUESTED`
- `LAND_GRANTED`
- `LANDING`
- `ROLLOUT`
- `TAXI_TO_RAMP`
- `ARRIVED`
- `DESPAWN_PENDING`
- `COMPLETED_VIRTUAL`

**Parity rule (rotary-wing):**
Rotary-wing flights use the *same request/approval states* (TAXI/TAKEOFF/LAND), even if their execution uses helipad geometry. The clearance workflow stays identical.

---

## 7) Scheduling logic (virtual vs physical)

### 7.1 Definitions
- **Players active:** at least one human player connected and active in mission (configurable; v1 default uses `count allPlayers > 0`).
- **Airbase bubble:** a radius around marker `mkr_airbaseCenter` that defines when the physical layer is allowed to spawn/animate airfield traffic.

Recommended v1 bubble:
- `bubble_radius_m = 1000` (match general mission bubble discipline)
- Optional hysteresis:
  - enter at 1000m, exit at 1200m (reduces spawn/despawn churn)

### 7.2 Always-on virtual scheduler
While players are active:
- scheduler generates new FlightRecords
- scheduler advances existing FlightRecords through virtual states
- scheduler emits events for TOC/GUI

When no players are active:
- scheduler pauses or slow-ticks (configurable), preserving state.

### 7.3 Physical execution gating
The system only spawns/animates physical aircraft when:
- bubble is active (a player is inside bubble), OR
- a pilot request requires it (pilot at base requesting clearance), OR
- an ATC controller is on-duty (tower roles occupied), OR
- a priority slot request is approved with an imminent window.

Otherwise:
- flight remains virtual (`WAITING_FOR_BUBBLE`) and the schedule continues to advance.

### 7.4 Cadence model (probabilistic, CIVSUB-style math)
We define hourly probabilities and convert to per-tick:

- `p_tick = 1 - (1 - p_hour)^(tick_s / 3600)`

**Example parameters (v1 defaults):**
- scheduler tick: `tick_s = 60`
- base hourly rates when bubble active:
  - `p_depart_hour_fw = 0.30` (about one FW departure per ~3 hours on average; adjust after testing)
  - `p_arrive_hour_fw = 0.30`
  - `p_depart_hour_rw = 0.25`
  - `p_arrive_hour_rw = 0.25`

Apply bubble multipliers:
- If bubble active: `m_bubble = 1.5`
- If bubble inactive: `m_bubble = 1.0` (virtual-only; physical waits)

Enforce cooldowns/caps:
- `cooldown_depart_s = 900` (15 min)
- `cooldown_arrive_s = 900`
- physical caps (Section 7.6)

### 7.5 Arbitration policy (runway/ground priority)
Default priority order:
1. Emergency (priorityLevel 2)
2. Player landing
3. Player takeoff
4. Approved TOC priority slot (if not already covered)
5. Ambient arrivals
6. Ambient departures

Policy must be applied consistently by:
- AI tower (when no controller exists)
- player CIC (when present)
- fallback timeout logic (when controller exists but does not respond)

### 7.6 Physical caps (v1 stability controls)
- Max physical aircraft simultaneously spawned under AIRBASESUB control:
  - fixed-wing: 2
  - rotary-wing: 2
- Max simultaneous taxiing aircraft: 1 (expand after testing)
- Max simultaneous “on final/landing” aircraft: 1

### 7.7 “Schedule never stops” rule (key requirement)
Even if no players are near the base:
- new flights are still scheduled virtually
- old flights still complete virtually
- the system maintains a rolling window so returning to base always reveals plausible activity

---

## 8) Role permissions and behaviors

### 8.1 Role detection (v1 lock)
Role detection uses editor variables:
- `farabad_tower_ws_ccic` identifies the acting CIC slot/unit.
- `farabad_tower_lc` identifies the LC slot/unit.

If multiple players match, select:
- WS/CCIC takes precedence for CIC
- LC as secondary controller

### 8.2 Controller permissions (v1)
**WS/CCIC**
- approve/deny pilot requests
- approve/deny TOC priority slot requests
- toggle “hold ambient departures” (policy toggle)
- reserve runway windows (timeboxed)
- clear runway lock (admin-like safety control, optionally restricted)

**LC**
- approve/deny pilot requests
- view schedule queue and runway state
- may act as CIC if WS/CCIC absent (optional v1 rule)

### 8.3 Pilot permissions (v1)
- pilots can submit TAXI/TAKEOFF/LANDING requests for their current aircraft
- pilots can cancel a pending request
- pilots can declare emergency (creates a priorityLevel 2 request and moves it to the top of the queue)

### 8.4 AI tower behavior (v1)
Anchored to `FarabadTower_LA`:
- emits comms only within airbase bubble
- processes pilot requests immediately when no ATC players exist
- in hybrid mode, applies:
  - “timeout to AI” if controllers do not respond in `controller_timeout_s` (default 60s)
  - “runway reservation” windows for player operations

### 8.5 Comms visibility (v1 lock)
ATC text output is visible only to players **inside the airbase bubble**.

---

## 9) Ambient ground crew behaviors (v1)

### 9.1 Allowed animation system (v1 lock)
Use only:
- `BIS_fnc_ambientAnim` to start
- `BIS_fnc_ambientAnim__terminate` to stop/cleanup

### 9.2 Crew lifecycle rules
- Crew idle animations must terminate cleanly before:
  - boarding
  - reassignment
  - despawn
- Avoid long-running animation loops that desync in MP.

---

## 10) Integration notes

### 10.1 Interaction with TOC / GUI work
AIRBASESUB should provide a clean read-only data surface plus a priority request interface:
- next arrivals/departures list (callsign, category, state, ETA/ETD)
- runway state (open/reserved/occupied + owner)
- pending pilot clearances
- pending TOC priority slot requests

The forthcoming GUI design doc can consume AirbaseEvent envelopes rather than polling scattered variables.

### 10.2 Persistence and reset workflows
Persist (server):
- FlightRecords rolling window (bounded)
- RunwayState and active queue
- outstanding PilotRequests and PrioritySlotRequests (bounded)

Reset persistence should:
- clear runway locks
- clear queues
- mark any spawned aircraft owned by AIRBASESUB as despawn candidates
- rebuild the schedule window deterministically from seed

### 10.3 Interaction with convoys and ground traffic
AIRBASESUB must not introduce ground traffic that violates the base convoy routing rule (keep convoys to North_Gate and off airfield surfaces).

---

## 11) Observability and debugging (v1)

### 11.1 Admin/dev tools
- Toggle debug mode (server-only)
- Force schedule next flight (virtual)
- Force spawn next flight (physical, bubble required unless override)
- Clear runway lock
- Dump scheduler state to log

### 11.2 Debug views (minimal)
- Marker/text near `mkr_airbaseCenter` showing:
  - runway state
  - next 3 virtual flights
  - active requests count (pilot + TOC)
  - physical aircraft count (fw/rw)

### 11.3 Logging (structured)
Log every:
- clearance request + decision (who, what, when)
- runway lock acquisition + release
- flight spawn + despawn
- state transitions (FlightRecord)

---

## 12) Implementation roadmap (phased)

### Phase 0 — State + scheduler + events (no physical spawns)
- implement FlightRecord and request queues
- implement virtual scheduler cadence and cooldowns
- emit AirbaseEvents for TOC/GUI

### Phase 1 — Physical execution in bubble (fixed-wing first, then rotary parity)
- spawn/despawn physical aircraft based on bubble gating
- implement taxi/takeoff/landing sequences
- implement runway lock + queue

### Phase 2 — Hybrid ATC (player controllers)
- role detection via `farabad_tower_ws_ccic` / `farabad_tower_lc`
- manual approve/deny flow
- timeout-to-AI fallback

### Phase 3 — TOC priority slot request tool
- implement request/approval path
- integrate with the GUI data feed

---

## 13) Open items (to lock later, but not required to draft v1)

1. Exact aircraft pool definitions (mod classes per tenant pool).
2. Exact taxi route definitions and how to unify “rotary taxi” behavior with the parity requirement while keeping pathing reliable.
3. Whether “CLOSED runway” incidents ever occur in v1 (likely v2).
4. Whether AIRBASESUB ever emits tasks/leads (default v1: no).

---

## Sources (public URLs)

BIS ambient animation terminate reference (community thread; use as a quick pointer to the terminate function name/usage):
- https://forums.bohemia.net/forums/topic/157286-how-to-make-ai-playing-animations/

US Army doctrine references included in the Farabad project design guide (context for C2 and reporting loops):
- https://armypubs.army.mil/epubs/DR_pubs/DR_a/ARN34403-ADP_6-0-000-WEB-3.pdf
- https://armypubs.army.mil/epubs/DR_pubs/DR_a/ARN18126-ADP_5-0-000-WEB-3.pdf
