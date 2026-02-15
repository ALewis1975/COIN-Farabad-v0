# Farabad COIN Project Dictionary (Single-Source)

**Version:** 1.0  
**Status:** Authoritative reference for naming, concepts, and contracts across the Farabad COIN project

---

## 1. Purpose

This document defines a **single-source dictionary** for the Farabad COIN mission. It standardizes terminology, component names, architectural language, UI concepts, Helpers, subsystem names, identifiers, and conventions. All future development, documentation, UI labels, logs, and handoff materials should conform to this dictionary unless explicitly superseded.

---

## 2. Source-of-Truth Artifacts

### Mission Design Guide
- **Meaning:** Top-level intent and mission-wide rules
- **Status:** Locked
- **Notes:** Defines the command cycle, engineering rules, and authoritative references

### Authoritative ORBATs
- **Meaning:** Unit names, callsigns, and ownership
- **Status:** Locked
- **Notes:** Non-negotiable for UI labels, task ownership, and logs

### Locked Baselines
- **Meaning:** Implementation contracts (schemas, state machines, keys)
- **Status:** Locked
- **Examples:** CASREQ v1, CIVSUBv1

### Planning Specifications
- **Meaning:** Forward design intent; not fully implemented
- **Status:** Planning-only
- **Examples:** AIRBASESUB, IED/VBIED/Suicide

---

## 3. Mission Spine Terminology

### TOC (Tactical Operations Center)
- **Meaning:** HQ node that issues tasks and receives SITREPs
- **Status:** Locked

### Mobile S3 / TAC CP
- **Meaning:** Forward tasking node when TOC is not primary
- **Status:** Locked

### Task
- **Meaning:** Executable mission order with objective and success criteria
- **Status:** Locked

### Lead
- **Meaning:** Actionable intelligence artifact that must convert into a Task
- **Status:** Locked

### SITREP
- **Meaning:** Structured report that closes the operational loop and gates follow-ons
- **Status:** Locked

### Follow-on Decision
- **Meaning:** TOC-directed outcome after SITREP
- **Values:** RTB, Hold, Proceed
- **Status:** Locked

### Role Gating
- **Meaning:** Only authorized leadership roles may accept tasks or submit SITREPs
- **Status:** Locked

### Proximity Gating
- **Meaning:** SITREP submission requires presence within the task objective area
- **Status:** Locked

---

## 4. Architecture Language (Engineering Rules)

### Single-Writer
- **Meaning:** Server owns all persistent state
- **Status:** Locked

### Consumers Never Guess
- **Meaning:** Clients consume explicit snapshots only
- **Status:** Locked

### Delta Bundle
- **Meaning:** Atomic event envelope with metadata and bounded payload
- **Status:** Locked

### Stable Identifiers
- **Meaning:** Use stable IDs for all persistence and references
- **Status:** Locked

### Versioned Persistence
- **Meaning:** Persist subsystem state with schema versioning
- **Status:** Locked

### Logging
- **Meaning:** Log all critical lifecycle transitions
- **Status:** Locked

---

## 5. UI Language

### Farabad Console
- **Meaning:** Station-aware UI shell for all command and control
- **Status:** Locked

### Stations
- **TOC Station:** HQ tasking and oversight  
- **Tower Station:** Airfield and clearance control  
- **Field Station:** Unit-level status and requests

### Standard Tabs (v1)
- Dashboard  
- Tasking  
- SITREP  
- Intel / Leads

### Tower Tabs
- Airfield Ops  
- Clearances

### Field Tabs
- Unit Net

---

## 6. Helpers (Canonical UI Components)

Helpers are reusable, context-sensitive UI components. They do not create new world actions.

### Assigned Task Helper (ATH)
- **Meaning:** Displays current task context, state, distance, and next gate
- **Location:** Right contextual pane

### Lead Promotion Helper (LPH)
- **Meaning:** Assists in converting a Lead into a Task with validation

### SITREP Helper (SRH)
- **Meaning:** Enforces required SITREP structure and completeness

### CIVSUB Annex Helper (CAH)
- **Meaning:** Auto-filled SITREP annex with district influence deltas

### CASREQ Helper (CRH)
- **Meaning:** Manages CAS request inbox, dialogue, and lifecycle actions

### Airfield Queue Helper (AQH)
- **Meaning:** Displays taxi, takeoff, and landing queues for Tower

### Role and Permission Helper (RPH)
- **Meaning:** Shows detected role, allowed actions, and gating reasons

---

## 7. Core Subsystems

### TASKENG (Task and Lead Engine)
- **Meaning:** Owns task and lead lifecycle, gating, and promotion
- **Status:** Locked concept

### SITREPSYS
- **Meaning:** Structured reporting and follow-on gating
- **Status:** Locked concept

### CIVSUBv1
- **Meaning:** Civilian population and influence subsystem
- **Status:** Locked baseline

### CASREQ v1
- **Meaning:** Structured close air support request workflow
- **Status:** Locked baseline

### AIRBASESUB
- **Meaning:** Airbase ambience and ATC-like control system
- **Status:** Planning spec with v1 locks

### Threat System v0 + IED Phase 1
- **Meaning:** Threat recordkeeping and basic IED lifecycle
- **Status:** Locked baseline

### IED/VBIED/Suicide Expansion
- **Meaning:** Network-driven insurgent threat model
- **Status:** Planning spec

---

## 8. Identifier and Naming Conventions

### IDs
- **District ID:** D01–D20
- **Threat ID:** THR:Dxx:000123
- **CASREQ ID:** CAS:Dxx:000001

### missionNamespace Keys
- Pattern: `<subsystem>_<version>_<key>`
- Examples: `civsub_v1_*`, `casreq_v1_*`, `threat_v0_*`

### Markers
- `mkr_airbaseCenter` – airbase bubble center
- `mkr_SHERIFF_HOLDING` – detainee handoff point
- `North_Gate` – convoy routing constraint

---

## 9. ORBAT-Aligned Vocabulary

### BLUFOR Callsign Roots
- FALCON, REDFALCON, THUNDER, SHADOW, SHERIFF, BLACKFALCON, GRIFFIN, PEGASUS
- USAF roots: REDTAIL, MAYOR, FARABAD, SENTRY, LIFELINE, RAVEN
- Flying callsigns: REACH, TEXACO, TIGER, HAWG

### Host-Nation and Civilian
- **TNP:** Takistan National Police
- **TNA:** Takistan National Army
- **CIV:** Civilian population

### OPFOR Network
- **TIM:** Takistan Islamic Movement
- Cell labels: COBRA (IED), VIPER (guerrilla)

---

## 10. Deprecated and Retired Terms

This section captures legacy design language that appeared in early Farabad COIN discussions and prototypes. These terms are **intentionally deprecated** and must not be reintroduced into code, UI labels, logs, or formal documentation.

### Omni (Legacy Design Term)

**Historical usage:**
- Omni-console
- Omni-helper
- Omni-tasking
- Omni-awareness

**Original intent:**
The term "omni" was used as exploratory shorthand to describe global visibility, convenience access, or inferred context during early concept development.

**Reason for retirement:**
- Conflicts with the **Consumers Never Guess** rule
- Violates **role and station gating** principles
- Encourages god-objects and implicit inference
- Obscures subsystem ownership and authority

**Status:** Deprecated — do not use

**Canonical replacements:**
- Omni-console → Farabad Console with station context
- Omni-helper → Assigned Task Helper (ATH) + Role and Permission Helper (RPH)
- Omni-awareness → Dashboard tab with explicit queues
- Omni-tasking → TASKENG (explicit Lead → Task promotion)
- Omni-context → Explicit object selection (taskId, leadId, casreqId)

---

## 11. Design Evolution Note (Authoritative)

Farabad COIN intentionally evolved from exploratory, convenience-driven language to a **contract-driven architecture**. Early "omni" concepts helped define desired outcomes, but were replaced once subsystem boundaries, authority, and persistence rules were formalized.

This transition marks:
- Exploration → enforceable architecture
- Intuition → explicit contracts
- Convenience → correctness and auditability

All future design work must favor **explicit composition** over implicit aggregation.

---

## 12. Enforcement

This dictionary is the **authoritative naming and concept reference** for Farabad COIN. Any new subsystem, UI element, helper, log entry, or document must align with these definitions unless explicitly revised, versioned, and approved as a formal update to this file.

