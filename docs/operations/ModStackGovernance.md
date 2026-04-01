# Mod Stack Governance — COIN-Farabad-v0

**Owner:** Mission Commander / Server Operator
**Status:** LOCKED — see Decision 6 (§16)
**Last Updated:** 2026-04-01 (preset updated)

---

## Purpose

This document defines the governance process for changes to the Farabad v0 mod stack. All sessions
must be launched with the approved mod preset. Changes to the mod list require Mission Commander
approval and must be recorded here before any session using the modified stack.

This document locks **Design Decision 6 from Mission Design Guide §16**:
> *The mod stack for Farabad v0 is fixed. No additional mods may be added or removed without
> Mission Commander approval, documented in docs/operations/ModStackGovernance.md.*

---

## Required Mods (Standard Stack)

| Mod | Steam Workshop ID | Role |
|-----|------------------|------|
| CBA_A3 | 450814997 | Scripting framework prerequisite |
| ACE3 | 463939057 | Medical system, interactions, captive state |
| ACRE2 | 751965892 | Radio communications |
| RHSUSAF | 843577117 | US Army assets (vehicles, uniforms, equipment) |
| RHSAFRF | 843425103 | OPFOR assets (ANA/insurgent proxies) |
| RHSGREF | 843593391 | Additional faction assets |
| RHSSAF | 843632231 | Additional faction assets |
| 3CB Factions | 1673456286 | Civilian/insurgent factions (Takistan) |
| CUP Terrains - Core | 583496184 | Takistan terrain base |
| Global Ops Terrains | 2917444360 | Additional terrain assets |
| KAT - Advanced Medical | 2020940806 | Extended medical system (ACE3 extension) |
| LAMBS_Danger.fsm | 1858075458 | AI behaviour improvement |
| Zeus Enhanced | 1779063631 | Zeus game master tools |

---

## Launcher Preset

The approved launcher preset is located at:
```
docs/projectFiles/Ambient_Dev_Mods_2026-04-01.html
```
Import by dragging the file onto the Arma 3 Launcher window, or via MODS → PRESET → IMPORT.

---

## Update Process

1. **Propose**: Mission Commander submits a written proposal (PR comment or message) naming the mod,
   reason for addition/removal, and which sessions it affects.
2. **Review**: At least one other senior operator reviews for compatibility and mission design impact.
3. **Approve**: Mission Commander formally approves and updates this document.
4. **Distribute**: Updated preset (`launcher/Farabad_v0.html`) is distributed to all participants
   before the session using the new stack.
5. **Record**: This document is updated with the change entry in the Changelog section below.

---

## CI / Automated Enforcement

There is **no automated CI enforcement** of the mod preset at this time. Compliance is enforced
through this document and the session briefing process. A pre-session checklist item should verify
mod stack compliance before server launch.

---

## Changelog

| Date | Change | Approved By | Notes |
|------|--------|-------------|-------|
| 2026-04-01 | Initial governance document created | Mission Commander | Locked per Design Guide §16 Decision 6 |
| 2026-04-01 | Modset updated to 65-mod authorised stack; preset regenerated as Ambient_Dev_Mods_2026-04-01.html; removed 6x6 ATV and Wildfire; added Animated Smoke Effects, RKSL RQ7/UAV Shelter, RKSL Common Library, K9 Companion, Pinned Down Surrender, and others per Mission Commander directive | Mission Commander | Full list in docs/projectFiles/Ambient_Dev_Mods_2026-04-01.html |
