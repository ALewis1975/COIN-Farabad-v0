# Farabad COIN Mission: CIVSUB v1 Development Baseline

**Document status:** locked v1 baseline for implementation planning  
**Date:** 2026-01-02  
**Scope:** CIVSUBv1 (civilian subsystem) + identity layer + district influence plumbing. No new mission files generated in this step.

## 1. Why CIVSUB exists

CIVSUB is the layer that makes Farabad feel populated, human, and reactive without spawning thousands of AI. It does three things:

1. Models the civilian population as a district-level virtual population (statistical).
2. Provides a persistent identity layer for civilians the players actually touch (interrogate, aid, detain, etc.).
3. Emits structured “delta bundles” so the Influence Model and Task/Lead engine can respond cleanly.

This integrates with the mission’s architecture where tasks drive actions, actions drive reports (SITREPs), and the TOC issues follow-on work. The mission design guide explicitly expects a district-level influence model and a set of cooperating subsystem modules. 【331:13†Farabad_COIN_Mission_Design_Guide.md†L35-L44】

---

## 2. Hard constraints from the Farabad COIN architecture

These constraints shape CIVSUB implementation boundaries.

### 2.1 Simulation bubble and cleanup discipline

The mission uses an automated cleanup system that despawns units and groups beyond 1000m from players to control performance. 【331:13†Farabad_COIN_Mission_Design_Guide.md†L65-L73】

Implication for CIVSUB: Physical civilians are a sample of the virtual population and will appear only inside the player bubble. Persistence must not depend on long-lived world AI existing.

### 2.2 District influence as a first-class system

The design guide defines a district-based influence model with three axes.

- RED influence (insurgent penetration/control)
- WHITE sentiment (civilian trust in coalition)
- GREEN legitimacy (host-nation governance legitimacy)

It also defines that these variables drive lead generation, intel quality, escalation, and attack probability. 【331:13†Farabad_COIN_Mission_Design_Guide.md†L35-L44】

### 2.3 Convoys and systemic sustainment

Convoys are routed from North_Gate, use intermediate routing waypoints, and get cleaned up by despawn rules. 【331:13†Farabad_COIN_Mission_Design_Guide.md†L46-L54】

Implication for CIVSUB: Civ “needs” should connect to the Sustainment/Logistics systems later, but CIVSUBv1 keeps this bounded with a minimal district food and water index and a few aid interactions.

### 2.4 Persistence standards

The design guide calls for a global state get/set layer to support persistence and to prevent task stacking or failure loops. 【331:13†Farabad_COIN_Mission_Design_Guide.md†L74-L82】

Implication for CIVSUB: CIVSUB state must be serialized cleanly as one blob (districts + known identities + crime DB).

---

## 3. Reference forces (ORBAT summary)

### 3.1 BLUFOR (players)

The BLUFOR ORBAT defines 2nd Brigade Combat Team (2BCT), 82nd Airborne Division, with Task Force REDFALCON centered on 2-325 AIR, and a player-centric focus on Charlie Company (C/2-325 AIR). 【332:11†Farabad_BLUFOR_ORBAT_82ABN_USAF_2011.md†L1-L44】

### 3.2 USAF presence

The ORBAT also references 451st Air Expeditionary Wing (451 AEW) and a security-force footprint at Joint Base Farabad. 【332:11†Farabad_BLUFOR_ORBAT_82ABN_USAF_2011.md†L45-L59】

### 3.3 OPFOR/CIV baseline

The OPFOR/CIV ORBAT defines host-nation and civilian components including Takistan National Police (TNP), Takistan National Army (TNA), and the baseline civilian framework for the AO. 【334:1†Farabad_OPFOR_CIV_ORBAT_2011.md†L11-L75】

CIVSUBv1 does not hard-code faction logic beyond:
- Gov and Green actors (TNP/TNA/government)
- Insurgent and Red networks
- Civilian and White population behavior

---

## 4. Mod stack assumptions relevant to CIVSUB

From the current launcher preset, the mission environment includes (at minimum) a large mod stack with core dependencies and gameplay frameworks. 【351:13†Ambient_Dev_Mods_2025-12-25.html†L82-L95】

For CIVSUBv1 design, the key assumptions are:
- ACE3 (interaction framework, medical, and field rations/water)
- CBA_A3 (eventing, settings, common scripting patterns)
- Optional identity support via GRAD Passport (not in the preset file, but treated as a candidate dependency)

ACE interaction actions are implemented via ACE’s interaction menu framework. citeturn1search8  
ACE provides Field Rations (food and water mechanics) that we can leverage as the items powering aid interactions. citeturn1search9  

---

## 5. Population planning baseline and district clustering

### 5.1 Total population assumption (planning)

For CIVSUBv1 planning we lock:
- Total civilian pool: approximately 5,800 civilians available to the virtual population model.

This is a planning value (not a claim about the “true” population).

### 5.2 District clusters (v1)

We cluster the AO into 20 districts for influence and scheduler logic. District IDs are stable keys (D01..D20).

Below: district populations normalized to sum to 5,800, alongside the raw estimate from the clustering dataset (sum 6,327), and geometric metadata.

| District   |   PlanPop_5800 |   RawEstPop_6327 |   ResBldgCount |   CentroidX |   CentroidY |   Radius_m |
|:-----------|---------------:|-----------------:|---------------:|------------:|------------:|-----------:|
| D01        |           2089 |             2279 |            392 |      4580.8 |      5317.7 |        995 |
| D02        |           1601 |             1746 |            248 |      8407.3 |      2825.1 |       1862 |
| D03        |            286 |              312 |             45 |      8703   |      7263.9 |        734 |
| D04        |            248 |              270 |             35 |      4615.2 |      9257.5 |       1744 |
| D05        |            236 |              258 |             36 |      9572.8 |      9134.3 |        430 |
| D06        |            224 |              244 |             42 |       304.3 |      5417.5 |       1395 |
| D07        |            200 |              218 |             29 |      1968.4 |      4898.6 |        495 |
| D08        |            159 |              173 |             33 |      2351   |       829.4 |       1673 |
| D09        |            157 |              171 |             30 |       150.7 |      7700.9 |        491 |
| D10        |            128 |              140 |             18 |      8856   |      5986.2 |        198 |
| D11        |            121 |              132 |             18 |      9080.9 |     10455.1 |        145 |
| D12        |            115 |              126 |             19 |      4014.9 |      3673.6 |        576 |
| D13        |             49 |               53 |              7 |      7516.3 |      8643.4 |         37 |
| D14        |             38 |               42 |              7 |      7187.4 |      2621   |       2298 |
| D15        |             34 |               37 |              5 |      9726.7 |      3953.8 |         47 |
| D16        |             28 |               31 |              4 |     10114   |      9383.7 |         41 |
| D17        |             27 |               30 |              5 |       255.4 |      6349.4 |        266 |
| D18        |             25 |               27 |              5 |       451.3 |      8677.6 |        256 |
| D19        |             21 |               23 |              3 |      8106   |      6840.3 |         10 |
| D20        |             14 |               15 |              3 |      4251.9 |      2959.6 |         83 |

Notes:
- District centroids and radii come from the clustering output used for planning.
- District names (settlement names) are intentionally deferred; v1 uses stable IDs.

---

## 6. CIVSUB v1 architecture (lean but immersive)

### 6.1 Two-layer model: virtual vs physical

Virtual population layer (server authoritative)
- Lives entirely as district state variables and identity records
- Drives influence, lead rates, and reactive contact probabilities

Physical population layer (spawned civilians inside player bubble)
- Spawns within the mission’s cleanup/AI bubble constraints
- Each physical civ is a handle into the virtual layer via civ_uid
- If despawned, their identity and relationship history remains

### 6.2 CIVSUB Event Bus (delta bundles)

Everything CIVSUB does funnels into a single structured output: delta bundles.

Consumers:
- Influence model (district W/R/G updates and decay)
- Task/Lead engine (ambient lead creation, intel confidence, follow-on cues)
- Threat subsystems (IED/VBIED, intimidation, reprisals)

---

## 7. CIVSUB v1 state variables (exact)

### 7.1 Global state (missionNamespace)

- civsub_v1_enabled (bool)
- civsub_v1_seed (int) random seed for deterministic generation
- civsub_v1_tick_s = 60 (int) seconds
- civsub_v1_scheduler_s = 300 (int) seconds
- civsub_v1_districts (hashmap: district_id → district_state)
- civsub_v1_identities (hashmap: civ_uid → civ_identity_record)
- civsub_v1_crimedb (hashmap: key → crime_record)
- civsub_v1_version = 1

### 7.2 District state (per district_id)

All values are floats unless stated.

- id (string) example D01
- centroid ([x,y]) from clustering dataset
- radius_m (float) from clustering dataset
- pop_total (int) planning population (PlanPop_5800)
- W_EFF_U (0..100) WHITE sentiment (trust/cooperation)
- R_EFF_U (0..100) RED influence (insurgent control/penetration)
- G_EFF_U (0..100) GREEN legitimacy (gov legitimacy)
- W_BASE_U, R_BASE_U, G_BASE_U (0..100) baselines (defaults below)
- food_idx (0..100) district food availability (abstract)
- water_idx (0..100) district water availability (abstract)
- fear_idx (0..100) fear/pressure index (used only for civ cooperation shaping)
- cooldown_nextLead_ts (float serverTime)
- cooldown_nextAttack_ts (float serverTime)
- last_player_touch_ts (float serverTime) last time district was active

Default baselines (v1)
- W_BASE_U = 45
- R_BASE_U = 55
- G_BASE_U = 35

Scenario can override these per district in init.

### 7.3 Identity state (persisted only when touched)

A civ becomes touched when any CIVSUB interaction happens (papers, aid, detained, harmed, crime-hit, etc.). Touched identities persist.

Key: civ_uid (string)

Fields:
- civ_uid (string, stable)
- first_name (string)
- last_name (string)
- sex (M or F)
- dob_iso (string YYYY-MM-DD)
- nationality (string)
- home_district_id (string)
- home_pos ([x,y,z]) or building ref (string)
- occupation (string)
- background (string short bio)
- passport_serial (string)
- passport_expires_iso (string YYYY-MM-DD)
- passport_isPassport (bool) true=passport, false=local ID
- flags (array of strings) example WANTED, ASSOCIATED_TIM
- wanted_level (int 0..3)
- seen_by (hashmap: playerUID → first_seen_ts, last_seen_ts, count)
- last_interaction_ts (float serverTime)

---

## 8. Update tick and scheduler (exact)

### 8.1 Tick rate

- CIVSUB tick: every 60 seconds (server-side)
- Responsibilities:
  - Apply influence decay toward baseline
  - Apply slow drift on food/water/fear (bounded)
  - Recompute derived metrics (optional cached values)

### 8.2 Influence decay per tick (exact)

For each district, once per tick:

- W_EFF_U = clamp( W_EFF_U + (W_BASE_U - W_EFF_U) * 0.0020 , 0, 100 )
- R_EFF_U = clamp( R_EFF_U + (R_BASE_U - R_EFF_U) * 0.0010 , 0, 100 )
- G_EFF_U = clamp( G_EFF_U + (G_BASE_U - G_EFF_U) * 0.0015 , 0, 100 )

This is the only decay mechanism in v1. Event effects persist for hours but fade back toward baseline.

### 8.3 District scheduler cadence (exact)

- Scheduler run: every 300 seconds (5 minutes), server-side
- Per district it can:
  1. Generate at most 1 ambient lead per district per hour
  2. Trigger at most 1 reactive red contact per district per 30 minutes
  3. Emit at most 1 ambient civilian rumor per district per 30 minutes (optional; can be disabled)

Cooldowns:
- lead_cooldown_s = 3600
- attack_cooldown_s = 1800
- rumor_cooldown_s = 1800

### 8.4 How scheduler probabilities work (exact)

Compute these first (see Section 12 for mapping):
- p_lead_hour
- p_red_attack_hour

Convert hourly probabilities to per-tick using:
- p_tick = 1 - (1 - p_hour)^(scheduler_s / 3600)

Then:
- If serverTime >= cooldown_nextLead_ts and rand() < p_lead_tick, emit one lead and set cooldown_nextLead_ts = serverTime + 3600.
- If serverTime >= cooldown_nextAttack_ts and rand() < p_attack_tick_eff, emit one reactive attack and set cooldown_nextAttack_ts = serverTime + 1800.

---

## 9. District active definition (exact, v1)

District active is a simple proximity test.

- dist = minDistance(allPlayers, district.centroid)
- District is active if dist <= (district.radius_m + 200)

Active multiplier:
- m_active = 1.5 if active, else 1.0

This multiplier applies only to reactive red contact probability (not to caps/cooldowns).

So:
- p_attack_tick_eff = clamp(p_attack_tick_base * m_active, 0, 1)

---

## 10. Delta bundle contract (exact)

### 10.1 Envelope schema

Every CIVSUB event emits exactly one delta bundle.

```json
{
  "v": 1,
  "event_id": "D01:170000.123:ABC123",
  "ts": 170000.123,
  "district_id": "D01",
  "pos": [4580.8, 5317.7, 0.0],
  "source": {
    "system": "CIVSUB",
    "module": "IDENTITY|AID|SECURITY|VIOLENCE|SCHEDULER",
    "event": "SHOW_PAPERS|CHECK_PAPERS|CRIME_DB_HIT|AID_WATER|CIV_KILLED|LEAD_AMBIENT|ATTACK_REACTIVE"
  },
  "actor": {
    "type": "PLAYER|AI",
    "uid": "7656119...",
    "unit_net_id": "123:45",
    "side": "BLUFOR"
  },
  "target": {
    "civ_uid": "CIV:D01:000123",
    "unit_net_id": "456:78"
  },
  "payload": {},
  "effects": ["EFFECT_ID_1","EFFECT_ID_2"],
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

### 10.2 Rule: single-writer

Only the server emits delta bundles and updates district state. Clients only request interactions.

### 10.3 Rule: consumers never guess

If the Task/Lead engine needs a hint, CIVSUB must include it in lead_emit.seed (home position, suspected network, etc.). No consumer does inference in v1.

---

## 11. Influence weights (exact, locked v1)

### 11.1 Effect table

Each event produces one or more effect IDs. Each effect ID maps to an exact W/R/G delta.

| Effect ID | ΔW | ΔR | ΔG | Notes |
|---|---:|---:|---:|---|
| WHITE_TRUST_MICRO_GAIN | +0.25 | -0.05 | +0.10 | Respectful cooperation |
| WHITE_TRUST_SMALL_GAIN | +1.00 | -0.25 | +0.25 | Help without coercion |
| WHITE_TRUST_MED_GAIN | +2.00 | -0.50 | +0.50 | Visible aid/justice |
| WHITE_TRUST_HARD_LOSS | -2.50 | +1.25 | -0.75 | Coercive or abusive conduct |
| CIV_CASUALTY_LOSS | -5.00 | +2.50 | -2.50 | Civilian death attributed to BLUFOR |
| GOV_LEGIT_SMALL_GAIN | +0.25 | -0.25 | +1.00 | Working with lawful channels |
| RED_DISRUPTION_SMALL | +0.10 | -1.00 | +0.25 | Removing a node, small disruption |
| RED_DISRUPTION_MED | +0.25 | -2.50 | +0.75 | Disrupting a cell materially |
| FEAR_SPIKE | -0.50 | +0.50 | -0.25 | Fear increases insurgent coercion |

### 11.2 Event → effect mapping (exact)

| CIVSUB event | Effects emitted |
|---|---|
| SHOW_PAPERS (cooperative) | WHITE_TRUST_MICRO_GAIN |
| CHECK_PAPERS (non-coop, no hit) | WHITE_TRUST_HARD_LOSS |
| CHECK_PAPERS (non-coop, hit) | GOV_LEGIT_SMALL_GAIN + RED_DISRUPTION_SMALL |
| CRIME_DB_HIT (confirmed + detained) | GOV_LEGIT_SMALL_GAIN + RED_DISRUPTION_MED |
| AID_WATER (delivered) | WHITE_TRUST_MED_GAIN |
| AID_RATIONS (delivered) | WHITE_TRUST_MED_GAIN |
| MED_AID_CIV (treated or stabilized) | WHITE_TRUST_SMALL_GAIN |
| CIV_KILLED (attributed BLUFOR) | CIV_CASUALTY_LOSS |
| INTIMIDATION_EVENT (red coercion observed) | FEAR_SPIKE |

### 11.3 Applying weights (exact)

When a delta bundle is emitted:
- CIVSUB sums the effect deltas into influence_delta.
- It immediately updates W_EFF_U, R_EFF_U, G_EFF_U with the delta (clamped 0..100).
- Then normal tick decay handles drift over time (Section 8.2).

---

## 12. Mapping influence → outputs (exact, piecewise-linear)

We compute two scores per district.

- S_COOP = clamp( 0.55*W_EFF_U + 0.35*G_EFF_U - 0.70*R_EFF_U , 0, 100 )
- S_THREAT = clamp( 1.00*R_EFF_U - 0.35*W_EFF_U - 0.25*G_EFF_U , 0, 100 )

### 12.1 Civilian cooperation probability

Piecewise-linear curve on S_COOP:
- If S_COOP <= 20: p_coop = 0.15
- If 20 < S_COOP < 80: p_coop = 0.15 + (S_COOP-20)*(0.70/60)
- If S_COOP >= 80: p_coop = 0.85

### 12.2 Lead generation chance (ambient, per hour)

Piecewise-linear curve on S_COOP:
- If S_COOP <= 30: p_lead_hour = 0.05
- If 30 < S_COOP < 80: p_lead_hour = 0.05 + (S_COOP-30)*(0.30/50)
- If S_COOP >= 80: p_lead_hour = 0.35

### 12.3 Intel confidence (0..1)

Linear blend (bounded):
- intel_conf = clamp( 0.20 + 0.006*S_COOP - 0.004*S_THREAT , 0.10, 0.90 )

### 12.4 Red attack probability (reactive, per hour)

Piecewise-linear on S_THREAT:
- If S_THREAT <= 20: p_red_attack_hour = 0.03
- If 20 < S_THREAT < 80: p_red_attack_hour = 0.03 + (S_THREAT-20)*(0.22/60)
- If S_THREAT >= 80: p_red_attack_hour = 0.25

Then apply district active multiplier (Section 9) at tick time.

---

## 13. CIV identity system (CIVSUB + GRAD Passport)

### 13.1 Why we do not need photos

CIVSUBv1 does not store or process actual photos. Biometrics is represented by a deterministic civ_uid plus a crime DB index.

If the mission later wants photos, a camera mod can layer on top (example: Hate’s Digital Camera exists on Workshop). citeturn0search3

### 13.2 GRAD Passport baseline

GRAD Passport provides ID cards and passports shown and checked via ACE interactions, and supports a set of grad_passport_* variables stored on the unit. citeturn2view0turn3view0

It defines:
- Show ID Card interaction (self or target)
- Check ID Card interaction with conditions (unconscious, handcuffed, or surrendering). citeturn2view0

### 13.3 What lives where (schema split)

Lives in CIVSUB (authoritative, persistent)
- Full identity record (structured fields, history, flags, crime DB linkage)
- Per-player seen_by ledger
- Home, background, and bad-actor linkage

Lives in GRAD Passport vars (presentation + interoperability)
- Display fields for the ID card/passport UI (names, DOB, expiry, serial, etc.)

### 13.4 Mapping contract: CIV identity → grad_passport_* vars (exact)

GRAD Passport available properties include:
grad_passport_firstName, grad_passport_lastName, grad_passport_dateOfBirth, grad_passport_street, grad_passport_city, grad_passport_expires, grad_passport_serial, grad_passport_nationality, grad_passport_reason, grad_passport_isPassport, grad_passport_picture, grad_passport_signature. citeturn3view0

Formatting rules (locked v1)
- DOB display: DD.MM.YYYY (zero-padded)
- Expiry display: DD.MM.YYYY (zero-padded)
- Serial: FRB-11-XXXXXX (6 digits, zero-padded)
- Street: street_name and house_number (house number 1–299)
- City: if district has no human name yet, use Farabad District Dxx

Field mapping

| CIVSUB field | GRAD Passport var | Rule |
|---|---|---|
| first_name | grad_passport_firstName | direct |
| last_name | grad_passport_lastName | direct |
| dob_iso | grad_passport_dateOfBirth | format to DD.MM.YYYY |
| street_address | grad_passport_street | direct |
| city | grad_passport_city | direct |
| passport_expires_iso | grad_passport_expires | format to DD.MM.YYYY |
| passport_serial | grad_passport_serial | direct |
| nationality | grad_passport_nationality | direct |
| passport_reason | grad_passport_reason | short string 32 chars max |
| passport_isPassport | grad_passport_isPassport | bool |
| none | grad_passport_picture | empty string in v1 |
| none | grad_passport_signature | last_name and last 3 of serial |

Serial generation uses GRAD’s helper if desired (grad_passport_fnc_generateSerial exists), but CIVSUB may generate serials independently as long as format is respected. citeturn4view0

---

## 14. ACE interactions (exact, v1)

We implement two ACE interactions on civilians (target interaction menu):
1. CIVSUB: Show Papers (cooperative)
2. CIVSUB: Search & Check Papers (non-cooperative)

We rely on ACE interaction menu framework for these actions. citeturn1search8

### 14.1 Interaction 1: Show Papers (cooperative)

Preconditions
- target is civilian
- target not fleeing, or random roll passes
- uses district p_coop

Delta bundle emitted (exact)
- source.module = IDENTITY
- source.event = SHOW_PAPERS
- payload:
  - cooperative = true
  - shown = ID
  - passport_serial
  - name = first and last
- effects = WHITE_TRUST_MICRO_GAIN
- influence_delta = effect sum

### 14.2 Interaction 2: Search & Check Papers (non-cooperative)

Preconditions
- target is civilian
- target is in a compliant state: unconscious, handcuffed, or surrendering (mirrors GRAD Passport Check ID Card intent). citeturn2view0

Delta bundle emitted when executed (no hit)
- source.module = IDENTITY
- source.event = CHECK_PAPERS
- payload:
  - cooperative = false
  - method = SEARCH
  - passport_serial
  - hit = false
- effects = WHITE_TRUST_HARD_LOSS

Delta bundle emitted when executed (crime DB hit)

A separate bundle is emitted for the hit so consumers do not need branching logic.

1) CHECK_PAPERS bundle with hit=true and effects:
- effects = GOV_LEGIT_SMALL_GAIN and RED_DISRUPTION_SMALL

2) CRIME_DB_HIT bundle
- source.event = CRIME_DB_HIT
- payload:
  - passport_serial
  - hit = true
  - wanted_level
  - charges array of strings
- effects = GOV_LEGIT_SMALL_GAIN and RED_DISRUPTION_MED
- lead_emit.emit = true
- lead_emit.lead_type = LEAD_DETAIN_SUSPECT
- lead_emit.confidence = intel_conf
- lead_emit.seed includes:
  - subject_civ_uid
  - home_pos
  - linked_network = RED

---

## 15. Bounded integration with ACE rations and water

ACE Field Rations exists and models food and water consumption; CIVSUBv1 uses the same item ecosystem as the delivery token for aid effects. citeturn1search9

### 15.1 Aid interactions (optional but supported in v1)

- CIVSUB: Provide Water
- CIVSUB: Provide Rations

These actions:
- remove one unit of water or food item from player inventory
- increment district water_idx or food_idx by a small amount (bounded)
- emit AID_WATER or AID_RATIONS delta bundle
- apply WHITE_TRUST_MED_GAIN

This gives immediate immersion without simulating individual hunger/thirst for thousands of civilians.

---

## 16. Integration with Task/Lead engine (contract)

### 16.1 Lead emission rules (exact)

CIVSUB emits leads only in two cases:
1. Scheduler ambient leads (source.event = LEAD_AMBIENT)
2. Crime DB hit leads (source.event = CRIME_DB_HIT with lead_emit.emit=true)

The Task/Lead engine:
- owns lead lifecycle and conversion into tasks
- consumes CIVSUB delta bundles as inputs
- writes task IDs back into its own store (CIVSUB does not own task persistence)

### 16.2 How deltas interact with the Task/Lead state machine

- Task completion and SITREP closure update W/R/G via their own delta bundles.
- CIVSUB does not gate task progression; it changes probabilities and injects leads.

This matches the design guide expectation that influence variables shape lead and escalation. 【331:13†Farabad_COIN_Mission_Design_Guide.md†L35-L44】

---

## 17. Open items and missing pieces (to lock next)

The mission design guide flags several design questions that affect subsystem integration. 【331:13†Farabad_COIN_Mission_Design_Guide.md†L83-L98】

To complete CIVSUB integration cleanly, we previously identified the following items as needing explicit locks (now resolved in Appendix A):

1. District naming: map D01..D20 to settlement names for narrative flavor.
2. Initial district baselines: whether W/R/G baselines vary by district at mission start.
3. Attribution rules: how we decide civ killed attributed to BLUFOR vs OPFOR vs unknown.
4. Detention pipeline: where detainees go (TNP handoff, holding, release) and what tasks get generated.
5. Crime DB seeding: exact number of bad actors and how they map to insurgent cells in the OPFOR network.
6. SITREP integration detail: how CIVSUB contributions appear in SITREP summaries (fields and thresholds).
7. Persistence serialization format: JSON string, profileNamespace, or external DB approach.

Appendix A hard-locks defaults for all seven items so CIVSUBv1 is execution-ready.

## Appendix A — CIVSUBv1 Hard-Locked Defaults (Execution-Ready)

This appendix **closes the last open decisions** called out in the baseline spec.  
If any item in this appendix changes, bump `CIVSUB_SCHEMA_VERSION` and treat it as a **breaking change** for persistence and balancing.

### A.1 District IDs and naming (canonical vs display)

**LOCKED:**
- Canonical district identifier: `districtId` ∈ `{D01..D20}` (two digits, zero-padded).
- Canonical persistence key: `districtKey = districtId` (never use “friendly names” as keys).
- Default UI label: `districtDisplayName = format ["%1 (GR %2)", districtId, centroid_grid6]`.
- Optional UI-only alias map: `districtAliasMap` is allowed, but **must not** affect keys, persistence, or influence math.

**Default district display labels (v1):**

| districtId | districtDisplayName (default) | centroid_grid6 | est_pop |
|---|---|---:|---:|
| D01 | D01 (GR 45053) | 45053 | 2279 |
| D02 | D02 (GR 84028) | 84028 | 1746 |
| D03 | D03 (GR 87072) | 87072 | 312 |
| D04 | D04 (GR 46092) | 46092 | 270 |
| D05 | D05 (GR 95091) | 95091 | 258 |
| D06 | D06 (GR 3054) | 3054 | 244 |
| D07 | D07 (GR 19048) | 19048 | 218 |
| D08 | D08 (GR 23008) | 23008 | 173 |
| D09 | D09 (GR 1077) | 1077 | 171 |
| D10 | D10 (GR 88059) | 88059 | 140 |
| D11 | D11 (GR 90104) | 90104 | 132 |
| D12 | D12 (GR 40036) | 40036 | 126 |
| D13 | D13 (GR 75086) | 75086 | 53 |
| D14 | D14 (GR 71026) | 71026 | 42 |
| D15 | D15 (GR 97039) | 97039 | 37 |
| D16 | D16 (GR 101093) | 101093 | 31 |
| D17 | D17 (GR 2063) | 2063 | 30 |
| D18 | D18 (GR 4086) | 4086 | 27 |
| D19 | D19 (GR 81068) | 81068 | 23 |
| D20 | D20 (GR 42029) | 42029 | 15 |
|

### A.2 Initial influence baselines (start-of-campaign defaults)

**LOCKED (applies to every district unless a scenario explicitly overrides for narrative reasons):**
- `W_BASE_U = 45`  (civilian sentiment / cooperation)
- `R_BASE_U = 55`  (insurgent intimidation / control)
- `G_BASE_U = 35`  (host-nation legitimacy / governance)

**Also locked:**
- `W_TEMP_U = 0`, `R_TEMP_U = 0`, `G_TEMP_U = 0` at campaign start.
- `W_EFF_U = W_BASE_U`, `R_EFF_U = R_BASE_U`, `G_EFF_U = G_BASE_U` at campaign start.

### A.3 Civilian harm attribution rule (who “owns” the grievance)

**LOCKED: author attribution uses only Arma’s provided causality handles (bounded, reliable).**

When a civilian is killed or wounded (ACE medical state transition to “dead”/“incap”):
1) Let `_instigator` be the event-provided instigator (preferred).
2) Else use `_killer`.
3) Else set `attrib_side = "UNKNOWN"`.

Then map to `attrib_side`:
- `BLUFOR` → `"BLUFOR"`
- `OPFOR` → `"OPFOR"`
- anything else (civilian/independent/logic/null) → `"OTHER"` or `"UNKNOWN"` (if null)

And set `attrib_conf`:
- `1.00` if `_instigator` exists
- `0.70` if only `_killer` exists
- `0.30` otherwise

**Downstream rule (locked):**
- If `attrib_side="BLUFOR"`, emit `CIV_CASUALTY_BLAME_BLUFOR` (and the corresponding influence deltas/weights already defined in the main spec).
- If `attrib_side="OPFOR"`, emit `CIV_CASUALTY_BLAME_OPFOR`.
- If `attrib_side in {"OTHER","UNKNOWN"}`, emit `CIV_CASUALTY_BLAME_UNKNOWN` (lighter effect).

### A.4 Detention pipeline v1 (release vs SHERIFF handoff)

**LOCKED: CIVSUBv1 supports exactly two detainee outcomes. No courts, no long-term prison simulation.**

Outcome A — **Release on scene**
- Used when: the unit clears the civilian (no crime DB hit or the commander overrides).
- CIVSUB effect: small trust recovery in the district (already defined by weights table under the “fair treatment” events).

Outcome B — **Handoff to SHERIFF holding**
- Used when: there is a crime DB hit (or unit decides detention is justified).
- Receiving authority: **Military Police / detainee pickup** represented by the SHERIFF callsign in the BLUFOR ORBAT callsign registry.【102:16†Farabad_BLUFOR_ORBAT_82ABN_USAF_2011.md†L45-L53】
- CIVSUB does **not** simulate transport. Players physically do it, but CIVSUB only needs a deterministic “handoff happened” marker.

**LOCKED marker convention (v1):**
- Primary detainee handoff point marker name: `mkr_SHERIFF_HOLDING`
- Handoff radius: `25m` (player must be within 25m to confirm handoff)

**LOCKED state changes (identity record):**
- On detention decision: `status.detained = true`, `status.detainedAt = now`, `status.detainedDistrictId = currentDistrictId`
- On release (if previously detained): `status.detained = false`, `status.releasedAt = now`
- On handoff: `status.detained = true`, `status.handedOff = true`, `status.handedOffAt = now`, `status.handedOffTo = "SHERIFF"`

### A.5 Crime DB seed (v1 size and composition)

**LOCKED total seed size:** `30` persons-of-interest (POIs)
- `6` high-value targets (HVT)
- `24` associates / facilitators

**LOCKED initial status:**
- all start as `AT_LARGE`
- none start as `CONFIRMED_DEAD` or `IN_CUSTODY`

**LOCKED placement rule (district assignment):**
- Assign each POI a `homeDistrictId` by **population-weighted random selection** using `district.pop_share_pct` as weights.
- Use a deterministic seed per campaign (`campaignSeed`) so distribution stays stable across saves/loads.

**LOCKED minimum crime DB categories (enum):**
- `IED_FACILITATOR`
- `OPS_PLANNER`
- `FINANCE_LOGISTICS`
- `URBAN_SUPPORT`
- `WEAPONS_SMUGGLER`
- `CELL_MEMBER`

(You can extend categories later, but v1 must ship with at least these.)

### A.6 SITREP integration (what CIVSUB contributes)

**LOCKED: every SITREP submission includes a CIVSUB annex.**  
This aligns with the mission’s recommended SITREP payload including CIV/GREEN changes and detainee pickup requests.【189:12†Farabad_COIN_Mission_Design_Guide.md†L49-L62】

**CIVSUB annex fields (v1):**
- `districtId` (the task’s owning district)
- `W_start, W_end, dW`
- `R_start, R_end, dR`
- `G_start, G_end, dG`
- `civ_cas_kia`, `civ_cas_wia`
- `crime_db_hits` (count)
- `detentions_initiated` (count)
- `detentions_handed_off` (count)
- `aid_events` (count)  
  (Aid can be “food/water” later; for v1, it is a generic counter driven by ACE supply events already defined in the delta system.)

**LOCKED inclusion thresholds (keep SITREPs readable):**
- Always include casualty counts and crime DB hits if non-zero.
- Include influence deltas only if `abs(dW) >= 2` or `abs(dR) >= 2` or `abs(dG) >= 2`.

### A.7 Persistence format (what is saved, where, and how)

**LOCKED persistence mechanism:** `profileNamespace` JSON blob (server-authoritative).

**LOCKED keys:**
- `FARABAD_CIVSUB_V1_STATE` (stringified JSON)
- `FARABAD_CIVSUB_V1_VERSION` (string, e.g. `"1.0.0"`)
- `FARABAD_CIVSUB_V1_CAMPAIGN_ID` (string GUID)

**LOCKED save cadence:**
- Autosave every `300s` (5 minutes)
- Force-save on:
  - SITREP submission
  - mission end / server shutdown handler
  - manual “Reset Persistence” workflow (writes a clean empty state)

**LOCKED saved content scope (bounded):**
- All district state (W/R/G base + temps + cooldowns + counters)
- Crime DB (30 POIs + their status history)
- Only “touched” identity records (i.e., civilians that have been interacted with, checked, detained, or referenced in leads)

**Hard cap (locked):**
- Keep at most `500` touched identity records in persistence; evict oldest-by-lastSeen when exceeding cap.

---

### Appendix A closeout

With the locks above, **CIVSUBv1 has no remaining open design decisions** required for implementation and integration testing.
