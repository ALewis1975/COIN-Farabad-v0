# Farabad COIN — UI/Dialogue + Air Ops + CASREQ Contracts (Thread Extract)

**Date:** 2026-01-02  
**Scope:** Consolidated notes and specifications captured in this chat thread, in order (top → bottom).  
**Project context:** Farabad COIN (ARMA 3), 2011-era joint base and COIN environment.

---

## 1) Parallel development: UI/Dialogue system + subsystems

### 1.1 Why parallel UI work is not only “appropriate” but desirable
A unified dialogue/UI layer becomes the **control surface** for the mission’s command cycle and all connected subsystems. Designing it in parallel prevents “integration tax” from:
- scattered `addAction`s / ACE interaction sprawl
- inconsistent flows and permissions
- duplicated state and desync edge cases

### 1.2 Core stance
**One entry point, many capabilities**
- Prefer a small number of world interactions (e.g., *Open TOC Console*, *Open Tower Console*).
- Do everything else in the UI (tabs/forms), not via new actions in the world.

**Server is the single writer**
- Authoritative state is server-side.
- Clients submit requests.
- Server validates and publishes updates.

**Build UI against stable contracts**
- Subsystems expose stable interfaces early, even if logic starts stubbed.

### 1.3 “Farabad Console” (station-aware dashboard concept)
A single dialog/display shell with:
- Header: station (TOC / Tower / Field), user role, time
- Left nav tabs
- Main pane: tables/forms
- Right pane: details + contextual actions

#### Suggested v1 tabs
**Shared**
- Dashboard (ops picture, deltas, incidents)
- Tasking (list + state, accept/transfer/close gates)
- SITREP (structured form: Who/Where/When + LACE + Enemy + CIV/GREEN + Requests + Recommendation)
- Intel / Leads (promote lead → task)

**Tower**
- Airfield Ops (runway status, ramp status, movement snapshot)
- Clearances (taxi/hold short/line up/takeoff/landing/cancel)

**Field**
- Unit Net (status + sustainment requests + last SITREP/task context)

### 1.4 Queueing model example (Tower)
Air movements should be treated as a **service queue + state machine**.

**Movement record (recommended)**
- movementId, type (TAXI/TAKEOFF/LANDING)
- callsign, aircraftNetId
- priority (PLAYER_HIGH / AI_NORMAL)
- state (REQUESTED → QUEUED → CLEARED → EXECUTING → COMPLETE; or CANCELLED/EXPIRED)
- constraints (runway, spacing, slot windows)

**Priority rule**
- Players get priority without deleting the ecosystem:
  - player preempts before an AI is cleared/executing
  - once an AI is executing, players wait to the next safe decision point (unless you add a tower “abort” tool)

**Tower UI should show**
- runway state and reservations
- queue (next 5)
- your request status + position
- cancel button
- optional tower-only “hold AI / expedite AI”

---

## 2) Pilot tactics, techniques, and procedures (TTPs) + base ecosystem

### 2.1 Ground-cycle TTPs (ramp is gameplay)
**Service requests + time-based turns**
- Request: Refuel / Rearm / Repair / Loadout Change / Avionics Reset
- “Quick turn” vs “full service”

**Ramp management**
- Tow aircraft, enforce parking plan, clear disabled aircraft
- Use crash crane and service vehicles for recovery

**Air logistics**
- Cargo staging, airlift, and airdrop as a first-class sustainment lever

**Loadout discipline**
- Presets + governance (inventory + ROE implications)

### 2.2 In-flight TTPs (aircrew as part of the C2 loop)
**Aerial refueling (scheduled service)**
- Request tanker slot, track availability, plan recovery windows

**ISR reporting pipeline**
- ISR observations generate structured reports and feed leads/tasks

**Blue Force Tracking / air-ground picture**
- Shared SA reduces fratricide and voice overload

**Radio discipline**
- Routine actions move to UI; voice reserved for conflicts/emergencies

### 2.3 What Farabad Towers should be doing
- Publish “ATIS-like” status: runway/pattern/closures/ramp freeze
- Manage a unified queue for arrivals/departures/emergencies/AI ambient flights
- Deconflict base airspace and procedural blocks (stack/corridors)
- Emergency playbook: declared emergency, runway blocked, base attack posture

### 2.4 What Base Mayor (and related groups) should be doing
Base Mayor becomes the **economic governor** of base operations:
- fuel/ammo/spares + throughput
- work orders as tasks (runway FOD sweep, crash recovery, resupply staging)
- coordinate with Security Forces and MPs for incidents/detainees
- tie “soft power” support missions into district influence where desired

### 2.5 Recommended “forms/dashboard” screens
**Pilot-facing**
- Flight Plan + Clearance Request
- Service Ticket (queue position + ETA)
- AIRREP

**Tower/Approach**
- Airfield Status Board
- Movement Queue
- Airspace Deconfliction

**Mayor**
- Airfield Services Dashboard
- Work Orders

---

## 3) CAS system: ground-to-air “dialogue” workflow

### 3.1 Design goal
A structured CAS request flow (CASREQ) that:
- replaces ad-hoc markers + voice-only coordination with a consistent workflow
- gives pilots a cockpit-friendly CAS page (“inbox” + details + two-way updates)
- tracks clearance state (Hold / Cleared Hot / Abort)
- logs outcomes for SITREP and campaign systems

### 3.2 Roles and permissions (recommended)
**Can create CAS request**
- JTAC/TACP
- CO/XO, PL/PSG (optionally SL for emergency TIC)

**Can set Cleared Hot / Cleared to Engage**
- JTAC/TACP only by default
- optional CO/XO fallback when no JTAC online (ruleset gated)

### 3.3 CAS lifecycle (state machine overview)
CASREQ lifecycle states:
- DRAFT (client-side) → SUBMITTED → ACKNOWLEDGED → ASSIGNED → INBOUND/ON STATION → CLEARED → ENGAGED → COMPLETE → CLOSED
Terminal/failure:
- ABORTED, CANCELLED, EXPIRED

CASREQ has two channels:
- structured fields (9-line inspired payload)
- short “dialogue thread” for updates and acknowledgements

### 3.4 Pilot-facing CAS page (concept)
- CAS Inbox: priority, requester, age, distance, status
- Details: target/friendlies/mark/restrictions/comms/linked task
- Dialogue thread: short updates + preset quick replies
- Actions: acknowledge, accept/assign, check-in/inbound, request clarification, submit BDA

---

# 4) FARABAD CASREQ v1 — Data Contract + State Machine

**Document status:** locked v1 baseline (implementation planning)  
**Date:** 2026-01-02  
**Scope:** CAS request object + server-emitted delta bundles + state transition tables (CASREQ-only).

## 4.1 System rules (hard constraints)

### 4.1.1 Single-writer (server authoritative)
- Only the **server** creates/updates CASREQ records and emits CASREQ delta bundles.
- Clients only submit **requests** (create/update/assign/clearance/message/etc). Server validates and applies.

### 4.1.2 Consumers never guess
- Every CASREQ delta bundle includes a **full `casreq_snapshot`** (bounded; see §4.5.4).
- UI/consumers must never infer missing fields or reconstruct state from partial events.

### 4.1.3 Role gating
- Creation and control actions are restricted to authorized leadership and specialist roles.
- Clearance authority defaults to JTAC/TACP as primary.

---

## 4.2 Global state (missionNamespace) — exact keys

```text
# Enable + versioning
casreq_v1_enabled = true
casreq_v1_version = 1                # CASREQ schema version (breaking changes bump this)
casreq_v1_campaign_id = "GUID"       # stable per campaign/save

# Storage
casreq_v1_records = HashMap          # casreq_id -> CASREQ_Record
casreq_v1_open_index = Array         # list of casreq_id (OPEN/ASSIGNED/IN_PROGRESS/PENDING_CLOSE)
casreq_v1_closed_index = Array       # optional bounded list of closed ids for UI history

# ID / sequencing
casreq_v1_seq = 0                    # incrementing int for casreq_id generation (per campaign)

# Scheduler (expiry)
casreq_v1_tick_s = 10                # tick cadence for TTL/expiry checks
casreq_v1_default_ttl_s = 1800       # 30 minutes unless specified
casreq_v1_max_open_per_requester = 1 # anti-spam

# Bounds
casreq_v1_max_messages = 40          # per request (bounded)
casreq_v1_max_message_len = 240      # chars
```

---

## 4.3 Enums (locked v1)

```text
CASREQ_STATE:
  OPEN
  ASSIGNED
  IN_PROGRESS
  PENDING_CLOSE
  CLOSED
  CANCELLED
  EXPIRED

CAS_PRIORITY:
  ROUTINE
  TIC
  EMERGENCY

CAS_CONTROL_TYPE:
  TYPE_1
  TYPE_2
  TYPE_3

CLEARANCE_STATE:
  HOLD
  CLEARED_HOT
  CLEARED_TO_ENGAGE
  ABORT

AIR_PHASE:
  NONE
  CHECKIN
  HOLDING
  INBOUND
  ATTACK
  EGRESS
  RTB

MARK_TYPE:
  NONE
  LASER
  SMOKE
  IR_POINTER
  STROBE
  TALKON

WEAPONS_POLICY:
  ANY
  GUNS_ONLY
  NO_ROCKETS
  NO_HE
  NO_BOMBS
  RESTRICTED

CLOSEOUT_RESULT:
  SUCCESS
  UNABLE
  NO_JOY
  ABORTED
  CANCELLED
```

---

## 4.4 CASREQ_Record schema (exact JSON shape)

```json
{
  "v": 1,
  "casreq_id": "CAS:D01:000001",
  "campaign_id": "GUID",
  "rev": 1,

  "created_ts": 0.0,
  "updated_ts": 0.0,

  "district_id": "D01",
  "area": {
    "target_pos": [0.0, 0.0, 0.0],
    "target_grid": "",
    "target_radius_m": 150,
    "friendlies_pos": [0.0, 0.0, 0.0],
    "friendlies_grid": "",
    "closest_friendlies_m": 0,
    "bearing_friendlies_to_target_deg": 0
  },

  "request": {
    "priority": "ROUTINE",
    "control_type": "TYPE_2",
    "danger_close": false,

    "target_desc": "",
    "target_type_hint": "",
    "target_count_est": 0,
    "target_motion": { "moving": false, "dir_deg": 0, "speed_kph_est": 0 },

    "mark": {
      "type": "NONE",
      "laser_code": "",
      "smoke_color": "",
      "remarks": ""
    },

    "restrictions": {
      "weapons_policy": "ANY",
      "final_attack_heading": { "enabled": false, "min_deg": 0, "max_deg": 0 },
      "min_alt_agl_m": { "enabled": false, "value": 0 },
      "no_fire_markers": [],
      "notes": ""
    },

    "timing": {
      "asap": true,
      "desired_tot_ts": null,
      "ttl_s": 1800,
      "expires_ts": 0.0
    },

    "comms": {
      "primary": { "net_name": "", "freq_mhz": 0.0 },
      "alternate": { "net_name": "", "freq_mhz": 0.0 },
      "remarks": ""
    },

    "attachments": {
      "linked_task_id": "",
      "linked_lead_id": "",
      "free_text": ""
    }
  },

  "participants": {
    "requester": {
      "type": "PLAYER",
      "uid": "",
      "unit_net_id": "",
      "side": "BLUFOR",
      "group_net_id": "",
      "unit_callsign": "",
      "leader_role": ""
    },

    "controller": {
      "assigned": false,
      "type": "",
      "uid": "",
      "unit_net_id": "",
      "side": "",
      "group_net_id": "",
      "unit_callsign": "",
      "leader_role": ""
    },

    "supported_unit_callsign": "",

    "assigned_flight": {
      "assigned": false,
      "flight_callsign": "",
      "aircraft_net_id": "",
      "aircraft_type": "",
      "crew_uids": []
    }
  },

  "status": {
    "state": "OPEN",
    "air_phase": "NONE",
    "clearance_state": "HOLD",

    "state_ts": {
      "open_ts": 0.0,
      "assigned_ts": null,
      "in_progress_ts": null,
      "pending_close_ts": null,
      "closed_ts": null,
      "cancelled_ts": null,
      "expired_ts": null
    },

    "acks": {
      "requester_ack": { "ack": false, "ts": null },
      "controller_ack": { "ack": false, "ts": null },
      "pilot_ack": { "ack": false, "ts": null },

      "danger_close_ack": {
        "required": false,
        "requester_ack": false,
        "controller_ack": false,
        "pilot_ack": false,
        "ts": null
      }
    }
  },

  "dialogue": {
    "messages": [
      {
        "msg_id": "CASMSG:000001",
        "ts": 0.0,
        "from": { "uid": "", "unit_callsign": "", "role": "" },
        "kind": "FREE|PRESET",
        "text": "",
        "tags": []
      }
    ]
  },

  "engagement": {
    "weapons_released": false,
    "weapons_summary": "",
    "bda": {
      "submitted": false,
      "submitted_ts": null,
      "submitted_by_uid": "",
      "effects_observed": "",
      "remaining_threat": "",
      "collateral_notes": ""
    }
  },

  "closeout": {
    "entered": false,
    "result": "",
    "summary": "",
    "entered_ts": null,
    "entered_by_uid": ""
  },

  "audit": {
    "last_updated_by": { "type": "SYSTEM|PLAYER", "uid": "" },
    "log_refs": []
  }
}
```

---

## 4.5 CASREQ delta bundle contract (CASREQ_DeltaBundle v1)

### 4.5.1 Envelope schema (exact)
```json
{
  "v": 1,
  "event_id": "CAS:D01:000001:170000.123:ABC123",
  "ts": 170000.123,
  "district_id": "D01",
  "pos": [0.0, 0.0, 0.0],

  "source": {
    "system": "CASREQ",
    "module": "REQUEST|CONTROL|DIALOGUE|CLEARANCE|ENGAGEMENT|BDA|SYSTEM",
    "event": "CREATE|UPDATE|ASSIGN|UNASSIGN|CHECKIN|PHASE|CLEARANCE|MESSAGE|BDA_SUBMIT|CLOSEOUT|CLOSE|CANCEL|EXPIRE"
  },

  "actor": {
    "type": "PLAYER|AI|SYSTEM",
    "uid": "",
    "unit_net_id": "",
    "side": "BLUFOR",
    "callsign": ""
  },

  "target": {
    "casreq_id": "CAS:D01:000001",
    "requester_unit_callsign": "",
    "assigned_flight_callsign": ""
  },

  "payload": {
    "from_state": "",
    "to_state": "",
    "note": "",
    "casreq_snapshot": {}
  },

  "effects": [],
  "influence_delta": { "W": 0.0, "R": 0.0, "G": 0.0 },

  "lead_emit": {
    "emit": false,
    "lead_type": "",
    "lead_id": "",
    "confidence": 0.0,
    "seed": {}
  },

  "tags": []
}
```

### 4.5.2 Delta bundle rules (locked)
- `payload.casreq_snapshot` is always a **full CASREQ_Record**.
- `pos` is always `casreq_snapshot.area.target_pos`.
- `district_id` is always `casreq_snapshot.district_id`.

---

## 4.6 Role permissions (server-enforced)
- **CREATE/UPDATE/CANCEL:** JTAC/TACP, CO/XO/1SG, PL/PSG (optionally SL for emergency)
- **CLEARANCE:** JTAC/TACP primary (optional fallback policy)
- **ASSIGN/UNASSIGN:** controller role (JTAC/TACP)
- **CHECKIN/PHASE/BDA:** assigned flight crew (controller can admin-override for cleanup)

---

## 4.7 State transitions — CASREQ_STATE

| From → To | Trigger (`source.event`) | Key guards | Actor allowed |
|---|---|---|---|
| (none) → OPEN | CREATE | requester role allowed; anti-spam unless emergency | requester |
| OPEN → ASSIGNED | ASSIGN | controller assigned; flight exists; not expired | controller |
| ASSIGNED → OPEN | UNASSIGN | not expired | controller |
| ASSIGNED → IN_PROGRESS | CHECKIN | flight assigned; actor is crew; not expired | flight crew |
| IN_PROGRESS → PENDING_CLOSE | CLOSEOUT | closeout entered; not expired | flight crew or controller |
| PENDING_CLOSE → CLOSED | CLOSE | controller assigned; closeout entered | controller |
| OPEN/ASSIGNED/IN_PROGRESS/PENDING_CLOSE → CANCELLED | CANCEL | not terminal | requester or controller |
| OPEN/ASSIGNED/IN_PROGRESS/PENDING_CLOSE → EXPIRED | EXPIRE | `now >= expires_ts` | SYSTEM |

Terminal states: `CLOSED`, `CANCELLED`, `EXPIRED`

---

## 4.8 CLEARANCE_STATE transitions

| From → To | Trigger | Guards | Actor allowed |
|---|---|---|---|
| HOLD → CLEARED_HOT | CLEARANCE | controller assigned; danger-close acks if required | controller |
| HOLD → CLEARED_TO_ENGAGE | CLEARANCE | controller assigned; danger-close acks if required | controller |
| CLEARED_* → HOLD | CLEARANCE | controller assigned | controller |
| ANY → ABORT | CLEARANCE | controller assigned | controller |
| ABORT → HOLD / CLEARED_* | CLEARANCE | controller assigned; DC acks if required | controller |

Danger-close gate (locked):
- if `danger_close=true`, block CLEARED_* until requester/controller/pilot DC acks are true.

---

## 4.9 AIR_PHASE transitions

Allowed if idempotent or one of:
- CHECKIN → HOLDING → INBOUND → ATTACK → EGRESS → HOLDING
- ANY → RTB

---

# 5) FARABAD CASREQ v1 — Client→Server Request Schemas

## 5.1 Common request envelope (CASREQ_ClientRequest v1)

```json
{
  "v": 1,
  "req_id": "CASREQ_REQ:170000.123:ABC123",
  "ts": 170000.123,

  "op": {
    "system": "CASREQ",
    "action": "CREATE|UPDATE|ASSIGN|CLEARANCE|MESSAGE|BDA|CLOSEOUT|CANCEL|CHECKIN|PHASE"
  },

  "actor": {
    "type": "PLAYER",
    "uid": "7656119...",
    "unit_net_id": "123:45",
    "side": "BLUFOR",
    "group_net_id": "123:67",
    "callsign": "REDFALCON 3-1",
    "leader_role": "PL"
  },

  "target": {
    "casreq_id": "",
    "district_id": "",
    "pos": [0.0, 0.0, 0.0]
  },

  "payload": {},

  "client": {
    "ui_name": "FARABAD_CAS_UI",
    "ui_ver": 1,
    "locale": "en",
    "meta": {}
  },

  "tags": []
}
```

**Global rule (success):** server validates, mutates exactly one CASREQ record, emits exactly one delta bundle containing a full snapshot.

---

## 5.2 CREATE payload

```json
{
  "district_id": "D01",
  "area": {
    "target_pos": [0.0, 0.0, 0.0],
    "target_grid": "",
    "target_radius_m": 150,
    "friendlies_pos": [0.0, 0.0, 0.0],
    "friendlies_grid": ""
  },
  "request": {
    "priority": "ROUTINE",
    "control_type": "TYPE_2",
    "danger_close": false,

    "target_desc": "",
    "target_type_hint": "",
    "target_count_est": 0,
    "target_motion": { "moving": false, "dir_deg": 0, "speed_kph_est": 0 },

    "mark": { "type": "NONE", "laser_code": "", "smoke_color": "", "remarks": "" },

    "restrictions": {
      "weapons_policy": "ANY",
      "final_attack_heading": { "enabled": false, "min_deg": 0, "max_deg": 0 },
      "min_alt_agl_m": { "enabled": false, "value": 0 },
      "no_fire_markers": [],
      "notes": ""
    },

    "timing": { "asap": true, "desired_tot_ts": null, "ttl_s": 1800, "expires_ts": 0.0 },

    "comms": {
      "primary": { "net_name": "", "freq_mhz": 0.0 },
      "alternate": { "net_name": "", "freq_mhz": 0.0 },
      "remarks": ""
    },

    "attachments": { "linked_task_id": "", "linked_lead_id": "", "free_text": "" }
  },

  "preferences": {
    "auto_assign_controller": true,
    "preferred_controller_callsign": "",
    "auto_assign_flight": false,
    "preferred_flight_callsign": ""
  },

  "note": ""
}
```

---

## 5.3 UPDATE payload

```json
{
  "casreq_id": "CAS:D01:000001",
  "expected_rev": 1,

  "mask": { "area": true, "request": true, "supported_unit_callsign": false },

  "patch": {
    "area": {
      "target_pos": [0.0, 0.0, 0.0],
      "target_grid": "",
      "target_radius_m": 150,
      "friendlies_pos": [0.0, 0.0, 0.0],
      "friendlies_grid": ""
    },
    "request": {
      "priority": "ROUTINE",
      "control_type": "TYPE_2",
      "danger_close": false,
      "target_desc": "",
      "target_type_hint": "",
      "target_count_est": 0,
      "target_motion": { "moving": false, "dir_deg": 0, "speed_kph_est": 0 },
      "mark": { "type": "NONE", "laser_code": "", "smoke_color": "", "remarks": "" },
      "restrictions": {
        "weapons_policy": "ANY",
        "final_attack_heading": { "enabled": false, "min_deg": 0, "max_deg": 0 },
        "min_alt_agl_m": { "enabled": false, "value": 0 },
        "no_fire_markers": [],
        "notes": ""
      },
      "timing": { "asap": true, "desired_tot_ts": null, "ttl_s": 1800, "expires_ts": 0.0 },
      "comms": {
        "primary": { "net_name": "", "freq_mhz": 0.0 },
        "alternate": { "net_name": "", "freq_mhz": 0.0 },
        "remarks": ""
      },
      "attachments": { "linked_task_id": "", "linked_lead_id": "", "free_text": "" }
    },
    "supported_unit_callsign": ""
  },

  "note": ""
}
```

---

## 5.4 ASSIGN payload

```json
{
  "casreq_id": "CAS:D01:000001",
  "expected_rev": 1,

  "assignment": {
    "action": "ASSIGN|UNASSIGN",
    "flight_callsign": "HAWG 11",
    "aircraft_net_id": "456:78",
    "aircraft_type": "A-10C",
    "crew_uids": ["7656119..."],
    "notes": ""
  },

  "note": ""
}
```

---

## 5.5 CLEARANCE payload

```json
{
  "casreq_id": "CAS:D01:000001",
  "expected_rev": 2,

  "clearance": {
    "to": "HOLD|CLEARED_HOT|CLEARED_TO_ENGAGE|ABORT",
    "reason": "",
    "remarks": ""
  },

  "note": ""
}
```

---

## 5.6 MESSAGE payload (dialogue + acks)

```json
{
  "casreq_id": "CAS:D01:000001",
  "expected_rev": 0,

  "message": {
    "client_msg_id": "CASMSGCLI:170000.123:ABC123",
    "kind": "FREE|PRESET",
    "preset_id": "",
    "text": "",
    "tags": []
  },

  "acks": {
    "set_requester_ack": false,
    "set_controller_ack": false,
    "set_pilot_ack": false,

    "set_danger_close_ack_requester": false,
    "set_danger_close_ack_controller": false,
    "set_danger_close_ack_pilot": false
  },

  "note": ""
}
```

---

## 5.7 BDA payload

```json
{
  "casreq_id": "CAS:D01:000001",
  "expected_rev": 3,

  "engagement": {
    "weapons_released": false,
    "weapons_summary": ""
  },

  "bda": {
    "submitted": true,
    "effects_observed": "",
    "remaining_threat": "",
    "collateral_notes": ""
  },

  "note": ""
}
```

---

## 5.8 CLOSEOUT payload

```json
{
  "casreq_id": "CAS:D01:000001",
  "expected_rev": 4,

  "closeout": {
    "action": "ENTER|FINALIZE",
    "result": "SUCCESS|UNABLE|NO_JOY|ABORTED|CANCELLED",
    "summary": "",
    "require_bda_if_weapons_released": true
  },

  "note": ""
}
```

---

## 5.9 CANCEL payload

```json
{
  "casreq_id": "CAS:D01:000001",
  "expected_rev": 2,

  "cancel": {
    "reason_code": "REQUESTER_CANCEL|CONTROLLER_CANCEL|DUPLICATE|BAD_DATA|NO_ASSETS|NO_LONGER_REQUIRED|OTHER",
    "reason_text": ""
  },

  "note": ""
}
```

---

# 6) Pilot workflow requests — CHECKIN + PHASE

## 6.1 CHECKIN (ASSIGNED → IN_PROGRESS)

**Action:** `op.action = "CHECKIN"`

```json
{
  "casreq_id": "CAS:D01:000001",
  "expected_rev": 2,

  "checkin": {
    "flight_callsign": "HAWG 11",
    "aircraft_net_id": "456:78",

    "pos": [0.0, 0.0, 0.0],
    "grid": "",

    "set_pilot_ack": true,
    "set_danger_close_ack_pilot": false,

    "remarks": ""
  },

  "note": ""
}
```

**Key server guards**
- record exists; not terminal
- `rev == expected_rev`
- actor is assigned flight crew (server validates)
- allowed states: `ASSIGNED` (normal), `IN_PROGRESS` (idempotent)

**Server effects**
- sets `pilot_ack`
- optionally sets danger-close pilot ack
- sets `air_phase=CHECKIN`
- transitions to `IN_PROGRESS` if currently `ASSIGNED`
- emits delta bundle: `source.event=CHECKIN`

---

## 6.2 PHASE (air_phase changes)

**Action:** `op.action = "PHASE"`

```json
{
  "casreq_id": "CAS:D01:000001",
  "expected_rev": 3,

  "phase": {
    "to": "HOLDING",
    "pos": [0.0, 0.0, 0.0],
    "grid": "",
    "remarks": ""
  },

  "note": ""
}
```

Allowed `phase.to` (v1):
- `CHECKIN` (usually set via CHECKIN)
- `HOLDING`, `INBOUND`, `ATTACK`, `EGRESS`, `RTB`

**Key server guards**
- record exists; not terminal
- `rev == expected_rev`
- actor is assigned flight crew or controller
- strict allowed transitions:
  - CHECKIN→HOLDING→INBOUND→ATTACK→EGRESS→HOLDING
  - ANY→RTB
  - idempotent allowed

**Server effects**
- only updates `status.air_phase`
- emits delta bundle: `source.event=PHASE`

---

## Appendix A — Local project references (for implementation alignment)
- `Farabad_COIN_Mission_Design_Guide.md`
- `Farabad_BLUFOR_ORBAT_82ABN_USAF_2011.md`
- `Farabad_OPFOR_CIV_ORBAT_2011.md`
- `Farabad_CIVSUBv1_Development_Baseline (1).md`

