# U.S. Army Doctrine References Used in Farabad COIN

**Project:** COIN_Farabad (Farabad AO)  
**Scope:** This file lists **only** the *official U.S. Army doctrine publications explicitly cited by the project* and describes how each is applied in the mission’s design and gameplay systems.

**Primary source within project:** `Farabad_COIN_Mission_Design_Guide.md` (References section)

---

## How to maintain this file (update policy)

When you introduce a new doctrinal concept *as a design requirement* (ex: a required report format, a CP process, a COIN principle you’re enforcing), do all of the following:

1. Add the reference (publication number + title + official URL) to:
   - `Farabad_COIN_Mission_Design_Guide.md` → “References (URLs)”
   - **This file** → “Referenced doctrine” list below
2. Add a short “Applied in Farabad COIN” explanation (what system(s) it informs).
3. Update the **Traceability matrix** so a new developer can see what mechanics depend on what doctrine.
4. Add an entry to the **Change log** (bottom).

Rule of thumb: if it’s used to justify a mechanic (gating, permissions, required reporting, escalation model), it belongs here.

---

## Referenced doctrine

### ADP 6-0 — Mission Command
**Official URL (as cited):**  
https://armypubs.army.mil/epubs/DR_pubs/DR_a/ARN34403-ADP_6-0-000-WEB-3.pdf

**Applied in Farabad COIN**
- **Mission orders via “Task → Action → Report → Decision → Follow-on.”** The mission loop enforces that higher issues tasks/leads, subordinate leaders accept and execute, then report before receiving follow-on direction. This is the core design spine for disciplined initiative and commander-driven tempo.
- **Commander’s intent and leader permissions.** Only defined leadership roles can accept tasks / submit SITREPs (company/platoon/squad leadership), keeping decision authority aligned to command echelons rather than every individual player.
- **Shared understanding through standard reporting.** The SITREP structure and “running estimate” expectation for the TOC exist so the HQ can maintain situational understanding and issue appropriate follow-ons.

**Implementation notes**
- Treat “TOC / S3” as mission command nodes. If players bypass reporting, the system should block task stacking and force a return to mission-command rhythm.

---

### ADP 5-0 — The Operations Process
**Official URL (as cited):**  
https://armypubs.army.mil/epubs/DR_pubs/DR_a/ARN18126-ADP_5-0-000-WEB-3.pdf

**Applied in Farabad COIN**
- **Plan–Prepare–Execute–Assess is implemented as a game loop.** Tasks and leads represent planning outputs; acceptance and movement represent preparation; execution is the objective; SITREP is the primary assessment mechanism; and follow-on orders are the updated plan.
- **METT-TC-driven follow-ons.** The TOC’s follow-on decision is explicitly tied to unit status and METT‑TC, not just “next objective.” This is why LACE/ACE is embedded into the SITREP payload and why task gating exists.

**Implementation notes**
- “Assessment” needs to matter mechanically: if the unit is low on ammo/casualties/high risk, the TOC (or rules engine) should bias RTB/hold rather than endless proceed-chains.

---

### ATP 6-0.5 — Command Post Organization and Operations
**Official URL (as cited):**  
https://armypubs.army.mil/epubs/DR_pubs/DR_a/pdf/web/ATP%206-0_5%20%28final%29.pdf

**Applied in Farabad COIN**
- **TOC / Main CP + optional TAC CP (mobile S3).** The project explicitly models a TOC and an optional forward tasking node, with responsibilities like maintaining a running estimate, issuing tasks, receiving SITREPs, and pacing escalation.
- **Battle rhythm through state transitions.** Task state lifecycle (offered → accepted → in progress → pending SITREP → closed) functions like a simplified CP workflow that prevents “everything happening at once.”

**Implementation notes**
- You can treat the task system UI and logs as CP “boards” and “products.” Keep them reliable, visible, and hard to desync.

---

### FM 3-24 — Counterinsurgency
**Official URL (as cited):**  
https://armypubs.army.mil/epubs/DR_pubs/DR_a/pdf/web/fm3_24.pdf

**Applied in Farabad COIN**
- **Population/influence is a primary terrain and outcome driver.** The mission’s influence model (RED/WHITE/GREEN) is meant to drive intel quality, enemy freedom of maneuver, and legitimacy—not just enemy spawns.
- **Insurgent threat as a network (cells/facilitators), not a standing front line.** OPFOR is designed as IED/guerrilla/urban-support cells with strategic facilitators; violence escalates/de-escalates based on player behavior and influence conditions.
- **Positive/negative COIN feedback loops are explicit tuning levers.** “Disciplined presence → better cooperation → better intel → more precise ops” is the intended success path; heavy-handed actions should generate the opposite effects.

**Implementation notes**
- Avoid turning the AO into constant patrol spam. When in doubt, tie violence to *conditions* (district risk, grievances, disruption of facilitation nodes) rather than time-only spawn loops.

---

### ATP 3-21.8 — Infantry Rifle Platoon and Squad
**Official URL (as cited):**  
https://armypubs.army.mil/epubs/DR_pubs/DR_a/ARN40007-ATP_3-21.8-000-WEB-1.pdf

**Applied in Farabad COIN**
- **Tactical fundamentals drive what players do between objectives.** The mission explicitly requires long halts, 360 security, consolidation, casualty treatment, and reorganization before reporting.
- **Standard tactical reporting conventions are baked into SITREP expectations.** The SITREP payload calls for an enemy summary in SALUTE style when relevant.
- **Role-based authority matches platoon/squad leadership.** The permission model (PL/PSG/SL) aligns task acceptance and reporting with the maneuver echelons that actually control small-unit actions.

**Implementation notes**
- The mission should reward good small-unit SOPs (security, detainee handling/SSE decisions, resupply discipline) by improving intel quality and reducing random escalation.

---

### FM 6-99 — Report and Message Formats
**Official URL (as cited):**  
https://armypubs.army.mil/epubs/DR_pubs/DR_a/ARN34470-FM_6-99-000-WEB-1.pdf

**Applied in Farabad COIN**
- **SITREP as a required, structured report—not a chat message.** The project’s SITREP payload fields (who/where/when, task result, ACE/LACE, enemy SALUTE-style, CIV/GREEN, requests, recommendation) are designed as a game-ready version of doctrinal reporting discipline.
- **Logging and traceability.** The mission logs task acceptance and SITREP reporting identities and timestamps to support debriefing, continuity, and accountability.

**Implementation notes**
- Keep the SITREP fast to fill out but hard to omit. “No report → no follow-on” is the mechanic that makes the CP/mission-command model real.

---

## Traceability matrix (doctrine → mechanics)

| Mission design element | Doctrine anchor(s) | Where it shows up in project systems |
|---|---|---|
| Task → Action → Report → Decision → Follow-on loop | ADP 6-0, ADP 5-0 | Task/Lead engine + SITREP gating + TOC follow-on decision |
| TOC running estimate + pacing the AO | ATP 6-0.5, ADP 5-0 | TOC workflow, escalation control, RTB/Hold/Proceed outputs |
| Role-based authority (who can accept/report) | ADP 6-0, ATP 3-21.8 | Whitelist of CO/XO/1SG/PL/PSG/SL for accept + SITREP |
| SITREP payload structure + SALUTE-style enemy summary | FM 6-99, ATP 3-21.8 | SITREP UI/form design; “enemy” section; standardization |
| COIN influence and legitimacy modeling (RED/WHITE/GREEN) | FM 3-24 | District/village influence scores drive intel, risk, corruption |
| Insurgent activity as cells/facilitators; escalation ladder | FM 3-24 | Cell generation, safe houses/couriers, IED/ambush progression |
| “Assessment matters” (status drives follow-on) | ADP 5-0 | ACE/LACE in SITREP influences RTB vs Hold vs Proceed |

---

## Change log

- **2025-12-28:** Initial extraction and doctrine-to-mechanics mapping created from project design references.
