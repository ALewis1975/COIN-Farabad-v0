![Task Force Redfalcon Banner](pics/tf_redfalcon_banner.jpg)

# Farabad COIN (2011)

**A persistent, multiplayer counterinsurgency mission for Arma 3**

---

## Overview

Farabad COIN is a persistent multiplayer counterinsurgency mission set in a fictionalized Takistan area of operations (AO) during the 2011 Operation New Dawn era. The mission centers on a realistic command cycle where players must plan, execute, report, and receive follow-on orders—mirroring real military operations.

**Mission Spine:**
Task → Execute → Report → Follow-on Decision

Players experience a living joint operational environment where their actions have lasting consequences, influence drives intelligence quality, and disciplined presence creates positive feedback loops in the population.

---

## Key Features

### 🎯 Mission Command & Control
- **Task/Lead Engine (TASKENG):** Structured mission orders with acceptance gating, role-based permissions, and state tracking
- **SITREP System:** ACE/LACE-driven reporting that closes operational loops and gates follow-on missions
- **TOC & Mobile S3:** Command post operations with running estimate and METT-TC-driven decision making
- **Farabad Console:** Unified station-aware UI for all command and control functions

### 👥 Population & Influence (CIVSUBv1)
- **District-Based Influence Model:** Three-axis system (RED/WHITE/GREEN) tracking insurgent control, civilian sentiment, and governance legitimacy across 20 named districts (D01 "Farabad" → D20 "Taran Fringes")
- **Virtual Population:** Statistical modeling of ~5,800 civilians across 20 districts without spawning thousands of AI
- **Persistent Identity Layer:** Tracks civilians players interact with through interrogations, aid, detentions
- **Delta Bundle Integration:** Structured events feed the influence model and task generation

### 💥 Threat System
- **Threat v0 + IED Phase 1:** Network-driven insurgent cells with recordkeeping and lifecycle tracking
- **IED Package:** Suspicious object spawning with full cleanup discipline and logging
- **Persistent Threat Records:** Server-authoritative tracking with stable IDs (THR:Dxx:000123)

### ✈️ Air Operations
- **CASREQ v1:** Structured close air support request workflow with role gating and pilot inbox
- **Airbase Ambience (AIRBASESUB):** Virtual arrival/departure schedule with hybrid ATC
- **Tower Control:** Clearance management for taxi, takeoff, and landing operations

### 🚛 Sustainment & Logistics
- **Convoy System:** Route security missions with proper cleanup and bubble-based despawn
- **Unit Status Tracking:** Equipment, casualties, ammo, and liquids constrain operational tempo
- **Resupply Workflow:** Integrated with SITREP system and follow-on decisions

### 🏘️ Site Population (SitePop)
- **Dynamic NPC Presence:** Proximity-triggered and task-triggered spawn system populating buildings and patrol rings at named sites
- **Template-Driven:** Site templates in `data/farabad_site_templates.sqf` define group composition per site type (market, checkpoint, camp, etc.)
- **LAMBS Integration:** Uses LAMBS garrison/camp functions for realistic NPC behavior on activation
- **Lockout & Grace Periods:** Prevents despawn flicker and repeated spawning during active player contact

### 🏥 Medical Tracking
- **Casualty Accounting:** Server-side EntityKilled handler tracks BLUFOR and civilian casualties against persistent `baseMed` / `civCasualties` counters
- **Influence Coupling:** Civilian casualties feed back into the CIVSUBv1 influence model (population sentiment)
- **CASEVAC Integration:** Medical snapshots available to CASREQ and SITREP workflows

### 🌍 Living Base Environment
- **Joint Base Farabad:** Modeled after Joint Base Balad with USAF host installation
- **Ambient Activity:** Gate control, patrol routines, service functions
- **World Time Controller:** Dynamic time acceleration with synchronized broadcast

---

## Architecture

### Authority Model (Server-Authoritative)
```
┌─────────────────────────────────────────────────────────────┐
│ DEDICATED SERVER (Single Writer)                            │
│  • ARC_STATE (persistent state)                             │
│  • ARC_pub_state (replicated snapshot)                      │
│  • All mutations through ARC_fnc_stateSet                   │
└─────────────────────────────────────────────────────────────┘
                          ↓ replicates
┌─────────────────────────────────────────────────────────────┐
│ CLIENTS (Read-Only Consumers)                               │
│  • Read ARC_pub_* variables only                            │
│  • Submit requests via RPC (ARC_fnc_rpcValidateSender)      │
│  • Never mutate authoritative state                         │
└─────────────────────────────────────────────────────────────┘
```

**Core Principles:**
- **Single-Writer:** Server owns all persistent/shared state; clients request actions
- **Consumers Never Guess:** UIs driven by explicit snapshots, not inferred state
- **Delta Bundles:** Structured event envelopes for cross-system integration
- **Stable Identifiers:** District IDs (D01-D20), Threat IDs (THR:Dxx:000123), CASREQ IDs (CAS:Dxx:000001)

### Entry Points
- **`initServer.sqf`:** Server bootstrap and configuration overrides
- **`initPlayerLocal.sqf`:** Client bootstrap with server-ready gate
- **`config/CfgFunctions.hpp`:** ARC function registry (494+ functions)

### Subsystems
```
functions/
├── core/          # State management, logging, roles, lifecycle
├── ui/            # Farabad Console (7 tabs + painters)
├── command/       # Task/Lead/SITREP workflow
├── civsub/        # Population, influence, identity, traffic
├── threat/        # Threat recordkeeping and IED system
├── ied/           # IED-specific handlers and interactions
├── intel/         # Intelligence logging and lead generation
├── ops/           # Operational tempo and patrol logic
├── logistics/     # Convoy and sustainment systems
├── medical/       # Casualty tracking and medical influence feedback
├── sitepop/       # Dynamic site NPC presence (proximity/task-triggered)
├── ambiance/      # Airbase operations and world simulation
└── world/         # Location registry and world utilities
```

---

## Getting Started

### Prerequisites

**Required Mods:**
- ACE3 (interaction framework, medical, field rations)
- CBA_A3 (common scripting framework)
- 3CB Factions (Takistan civilians, TNP, TNA, insurgents)
  - **3CB UK Factions – TKP sub-mod is required** for KarkanakPrison armed guard staffing (`UK3CB_TKP_B_*` classes). If absent, prison guard sites will not spawn armed guards correctly.
  - 3CB UK Factions – TKA sub-mod provides Afghan National Army classes used in allied patrol compositions.
- RHS USAF (U.S. Army and USAF assets)
- CUP Terrains Core (Takistan map)

**Optional Mods (degraded behavior if absent):**
- **LAMBS Danger** — used by SitePop for `lambs_danger_fnc_camp` and `lambs_danger_fnc_garrison` AI behaviors at active sites. If absent, the subsystem falls back to vanilla loiter waypoints. Gameplay still functions but AI site behavior is less realistic.
- **Police Extended** (`Expansion_Mod_Police`) — required for lightbar activation on police patrol vehicles (`Patrol_01`, etc.). If absent, lightbar scripts log a warning and skip silently; patrol vehicles still spawn.

**Known RPT Noise (not mission code defects):**
- `UK3CB_MEE_O_AR` / `UK3CB_MEE_O_AR_01` — approximately 18 `WARN/tick` entries per session may appear in RPT. This is a classname mismatch between the 3CB version in the mod preset and the class registered in `ARC_opforPatrolUnitClasses`. The engine silently skips the missing class; spawns still occur using other classes in the pool. To suppress, either update the class name to match your installed 3CB version or remove `UK3CB_MEE_O_AR_01` from `ARC_opforPatrolUnitClasses` in `initServer.sqf`.

See `docs/projectFiles/Ambient_Dev_Mods_2026-04-01.html` for the complete mod preset.

**Development Tools:**
- Arma 3 Tools (for mission editing)
- Python 3.11+ with sqflint (`pip install sqflint`)
- Git

### Installation

1. Clone this repository to your Arma 3 missions folder:
   ```bash
   cd "Documents/Arma 3/missions/"
   git clone https://github.com/ALewis1975/COIN-Farabad-v0.git
   ```

2. Load required mods through Arma 3 Launcher

3. Open mission in Eden Editor or host a multiplayer session

### First Run

1. **Multiplayer Setup:** This mission requires a server (dedicated or hosted)
2. **Slot Selection:** Primary player company is REDFALCON 3 (Charlie Company, 2-325 AIR)
3. **Command Roles:** Company CO, XO, 1SG, or Platoon Leaders can accept tasks and submit SITREPs
4. **Access Console:** Interact with TOC terminal or command vehicle to open Farabad Console

---

## Development

### Workflow

This project follows a strict development workflow defined in `AGENTS.md` and enforced through PR templates:

**Branch Model:**
- `main` — authoritative integration/release branch (protected)
- `dev` — active staging/integration branch
- `work/*` — feature branches

**PR Requirements:**
Every PR must declare:
- **Mode:** A-J (Bug Fix, Feature, Refactor, Performance, Test, Docs, CI, Dependencies, Security, Operations)
- **Scope:** Allowed files/directories
- **Acceptance Criteria:** Specific validation requirements
- **Tests Run:** Commands + results or "Not run" + justification
- **Risk Notes:** What could break
- **Rollback:** How to revert safely

### Local Validation (Required Before Merge)

```bash
# 1. SQF parser-compat preflight (run before lint)
python3 scripts/dev/sqflint_compat_scan.py --strict initServer.sqf functions/path/to/changed_file.sqf

# 2. Syntax check (SQF linting)
python -m pip install --upgrade pip
pip install sqflint
sqflint -e w initServer.sqf
sqflint -e w functions/path/to/changed_file.sqf

# 3. Config validation
# CI workflow includes automated delimiter balance checks

# 4. Local MP Testing
# - Host local multiplayer session
# - Test with at least one client
# - Verify state replication
# - Check RPT logs for errors
```

### Deferred Validations (Dedicated Server Required)

These checks require a true dedicated server environment:
- Persistence durability across server restarts
- Join-in-progress (JIP) synchronization
- Late-client state recovery
- Respawn/reconnect edge cases

Update `tests/TEST-LOG.md` after each validation pass.

### Safe Mode Operations (Operator Procedure)

Use safe mode when runtime stability is degraded and you need a controlled recovery posture.

1. Set `ARC_safeModeEnabled = true` in `initServer.sqf` (or mission override) before mission start.
2. Restart/initialize the server and confirm RPT entries tagged `[ARC][SAFE MODE]`.
3. Observe stabilization while essentials remain active (state publish, TOC console, SITREP workflow).
4. Re-enable subsystems incrementally in this order:
   - `civsub_v1_traffic_enabled = true`
   - `ARC_iedPhase1_siteSelectionEnabled = true` and `ARC_vbiedPhase3_enabled = true`
   - `airbase_v1_ambiance_enabled = true`
5. Set `ARC_safeModeEnabled = false` once the mission is stable.

This staged return-to-service keeps command/control online while reducing nonessential spawning pressure.

### Coding Standards

**Authority Model (Hard Requirements):**
- Server is single writer for persistent state
- Clients submit requests; never mutate global state
- All state changes through `ARC_fnc_stateSet`
- UI reads from `ARC_pub_*` variables only
- RPC validation with `ARC_fnc_rpcValidateSender`

**Red-Flag Patterns (Prohibited):**
- Client-side mutation of `missionNamespace` variables
- Remote execution without sender validation
- Multiple writers for replicated variables
- UI handlers applying global state changes directly
- Silent failures without logging

**Best Practices:**
- Use structured logging (`ARC_fnc_farabadLog`, `ARC_fnc_farabadWarn`, `ARC_fnc_farabadError`)
- Implement bounded stores with TTLs for history/messages
- Respect cleanup discipline (bubble-based despawn)
- Maintain idempotent operations
- Document state ownership explicitly

### Code Organization

```
COIN-Farabad-v0/
├── config/              # CfgFunctions, dialogs, HUD overlays
├── functions/           # 494+ SQF functions (73k LOC, 14 subsystems)
├── scripts/             # Utility scripts (world time, dev tools)
├── data/                # Compositions, paths, documentation
├── docs/                # Comprehensive project documentation
│   ├── projectFiles/    # Design guides, baselines, specs
│   ├── qa/              # Quality assurance reports
│   ├── planning/        # Sprint tickets and migration plans
│   ├── security/        # Security hardening documentation
│   └── perf/            # Performance analysis
├── tests/               # Test matrices and validation logs
├── initServer.sqf       # Server initialization
├── initPlayerLocal.sqf  # Client initialization
├── description.ext      # Mission configuration
└── mission.sqm          # Eden mission file
```

---

## ORBAT (Order of Battle)

### U.S. Army — 2nd Brigade Combat Team, 82nd Airborne Division

**Primary Player Unit:** Task Force REDFALCON (2-325 AIR)
- REDFALCON 3 (Charlie Company) — primary player company
- A/B/C Companies — maneuver elements
- Weapons Company — mortars, anti-armor, machine guns

**Supporting Units:**
- THUNDER (1-73 CAV) — Route security
- SHERIFF (MPs) — Detainee operations
- SHADOW (RQ-7) — ISR
- BLACKFALCON (2-319 AFAR) — Fires
- GRIFFIN (407 BSB) — Sustainment
- PEGASUS (82nd CAB) — Aviation

### U.S. Air Force — 332d Air Expeditionary Wing

**Airfield Operations:**
- FARABAD TOWER/GROUND — ATC
- FARABAD APPROACH — Radar control

**Support:**
- MAYOR — Base operations
- SENTRY — Security forces
- LIFELINE — Medical (Role III)
- RAVEN (14th ASOS) — JTAC/TACP

**Flying Units:**
- REACH (C-130/C-17) — Airlift
- TEXACO (KC-135) — Tanker
- TIGER (F-16C Viper, 97 EFS) — CAS
- HAWG (A-10C Thunderbolt II, 74th FS) — CAS
- HORIZON (RQ-4A Global Hawk) — Strategic ISR

### Host Nation
- **TNP:** Takistan National Police (partnered, variable reliability)
- **TNA:** Takistan National Army (limited presence)

### OPFOR
- **TIM:** Takistan Islamic Movement (decentralized insurgent network)
- Cells: COBRA (IED), VIPER (guerrilla), urban support

---

## Documentation

### Essential Reading

**Start Here:**
- `docs/projectFiles/Farabad_COIN_Mission_Design_Guide_v0.4_2026-01-27.md` — Mission intent, systems thinking, and cross-cutting standards
- `docs/projectFiles/farabad_project_dictionary_v_1.1.md` — Authoritative naming and concept definitions
- `AGENTS.md` — Development workflow and PR requirements

**Source of Truth:**
- `docs/projectFiles/Farabad_Source_of_Truth_and_Workflow_Spec.md` — Branch model and governance
- `docs/projectFiles/Farabad_ORBAT.md` — Complete order of battle
- `.github/copilot-instructions.md` — Runtime context and validation requirements

**Subsystem Baselines (Implementation Contracts):**
- `docs/projectFiles/Farabad_CIVSUBv1_Development_Baseline (1).md` — Population and influence system
- `docs/projectFiles/Farabad_UI_CASREQ_Thread.md` — Close air support request workflow
- `docs/projectFiles/Farabad_THREAT_v0_IED_P1_Baseline_regen.md` — Threat recordkeeping and IED system
- `docs/projectFiles/Farabad_TASKENG_SITREPSYS_v1_Baseline.md` — Task and SITREP engine

**Quality Assurance:**
- `docs/qa/QA_Audit_Executive_Summary.md` — Latest QA status (Score: 7.6/10, Production Ready)
- `docs/qa/Comprehensive_QA_Audit_2026-02-18.md` — Full audit report (425 files, ~57k LOC)
- `docs/qa/SQFLINT_COMPAT_GUIDE.md` — Compile helper reference and banned pattern mapping
- `tests/TEST-LOG.md` — Canonical validation log

**Architecture & Planning:**
- `docs/architecture/Architecture_and_Readiness_Plan.md` — System map, authority model, findings, and 4-phase forward plan
- `docs/planning/Task_Decomposition.md` — PR-sized work packages with dependency graph and acceptance criteria
- `docs/security/RemoteExec_Hardening_Plan.md` — RPC endpoint inventory and allowlist policy

### Marker Index

- **Purpose:** Keep a single reference of Eden/editor markers, alias mappings, and unresolved code references so mission data and scripted consumers stay aligned.
- **Regenerate command:** `python3 tools/generate_marker_index.py --sqm mission.sqm --out-md docs/reference/marker-index.md --out-json docs/reference/marker-index.json`
- **When to regenerate:** Rebuild the marker index after marker edits in Eden and after any direct `mission.sqm` marker changes.
- **Review guidance:** Treat unresolved references as follow-up work items unless they are explicitly documented as intentional legacy mappings.

**Development Resources:**
- `docs/projectFiles/Farabad_Prompting_Integration_Playbook_Project_Standard.md` — Prompting standards for AI-assisted development
- `docs/projectFiles/US_Army_Doctrine_References.md` — Doctrinal basis for mission design

---

## Mission Gameplay

### The Command Cycle

1. **TOC Issues Task/Lead**
   The Tactical Operations Center publishes mission orders or actionable intelligence

2. **Leader Accepts Mission**
   Company commanders, XOs, 1SGs, platoon leaders, or squad leaders accept via Farabad Console

3. **Unit Executes Objective**
   Maneuver to objective, execute mission, establish security, consolidate

4. **Submit SITREP**
   Structured situation report with:
   - Location and timestamp
   - Task outcome
   - ACE/LACE status (ammunition, casualties, equipment, liquids)
   - Enemy contact summary (SALUTE)
   - Civilian/host-nation impact
   - Resource requests
   - Recommendation (RTB, Hold, Proceed)

5. **TOC Issues Follow-On**
   Based on unit status and METT-TC:
   - **RTB** — Return to base for refit
   - **Hold** — Maintain position/security
   - **Proceed** — Continue to next objective

### Realism Constraints

- Units cannot pivot between objectives without reporting
- Sustainment matters: ammo, casualties, liquids, and equipment constrain tempo
- Intelligence quality reflects population influence and player conduct
- Enemy behaves as a network (cells/facilitators), not a standing front line

### COIN Feedback Loops

**Positive Loop (Success Path):**
Disciplined presence → Improved security → More cooperation → Better intel → Precise operations → Reduced insurgent freedom → Improved governance

**Negative Loop (Heavy-Handed Operations):**
Excessive force → Grievances → Less cooperation → Worse intel → Broader sweeps → More attacks → Harder AO

---

## Technical Details

### Language & Runtime
- **Scripting:** SQF (Real Virtuality 4 / Poseidon engine)
- **Target:** Arma 3 dedicated server multiplayer environment
- **Codebase:** ~530 SQF/HPP files, ~73,000 lines of code (14 subsystems, 494+ registered functions)

### State Management
- **Authority:** Dedicated server is single writer for all persistent state
- **Persistence:** Server-side `profileNamespace` with schema versioning
- **Replication:** Server publishes snapshots to `ARC_pub_*` variables
- **Client Role:** Request actions via validated RPC handlers
- **JIP Support:** Late-joining clients reconstruct from server snapshots

### Performance & Reliability
- **Bubble-Based Spawning:** AI and vehicles spawn only near players
- **Cleanup Discipline:** Automatic despawn beyond 1000m radius
- **Bounded Stores:** History and message systems use caps and TTLs
- **Logging:** Comprehensive lifecycle tracking for debugging and audit

### Quality Assurance Status

**Latest Audit (2026-02-18):**
- **Overall Score:** 7.6/10 (Production Ready)
- **Syntax Quality:** 425 files analyzed, 143 clean passes, 236 modern SQF (parser limitations)
- **Authority Model:** 9/10 (Excellent compliance)
- **GUI Integration:** 8.5/10 (7 tabs verified, proper data flow)
- **Priority Fixes:** 2 P0 + 1 P1 + 1 HIGH (identified and tracked)

---

## Console Tabs

The Farabad Console provides unified access to all command functions:

1. **DASH (Dashboard):** Operational picture, incident status, queue summary, unit readiness
2. **INTEL (S2):** Intelligence log, CIVSUB district status, lead management, S2 tools
3. **OPS (S3):** Three-pane layout for incidents, orders, and leads with accept/SITREP/follow-on actions
4. **AIR:** Airbase status, flight queues, runway control, tower operations
5. **HANDOFF:** Return-to-base debrief and enemy prisoner of war processing
6. **CMD:** Incident workflow management, queue statistics, TOC actions
7. **BOARDS:** Read-only operational snapshot for situational awareness
8. **HQ / ADMIN:** Headquarters admin tools, diagnostics (compile audit, QA audit, debug toggle, coverage map, diagnostics snapshot)

---

## Contributing

### Before Making Changes

1. **Read Documentation:**
   - `AGENTS.md` for PR requirements
   - `docs/projectFiles/Farabad_COIN_Mission_Design_Guide_v0.4_2026-01-27.md` for system intent
   - `.github/copilot-instructions.md` for validation requirements

2. **Understand Authority Model:**
   - Never mutate `ARC_STATE` from client code
   - Use `ARC_fnc_stateSet` for all state changes
   - Validate RPC senders with `ARC_fnc_rpcValidateSender`

3. **Check Existing Systems:**
   - Extend existing systems; don't create parallel implementations
   - Prefer minimal diffs over broad refactors
   - Maintain backward compatibility

### Development Workflow

```bash
# 1. Create work branch from dev
git checkout dev
git pull
git checkout -b work/your-feature-name

# 2. Make minimal changes

# 3. Validate locally
python3 scripts/dev/sqflint_compat_scan.py --strict functions/path/to/your_file.sqf
pip install sqflint
sqflint -e w functions/path/to/your_file.sqf
git diff --check

# 4. Test in local multiplayer
# - Host MP session with at least one client
# - Exercise changed code paths
# - Check RPT logs for errors

# 5. Update test log
# Add entry to tests/TEST-LOG.md with:
# - Date, commit, scenario
# - Commands/steps executed
# - Result (PASS/FAIL/BLOCKED)

# 6. Create PR following AGENTS.md template
git push origin work/your-feature-name
```

### PR Template Requirements

Use `.github/pull_request_template.md` which requires:
- **Mode:** One of A-J from AGENTS.md
- **Scope:** Explicit file/directory list
- **Acceptance Criteria:** Measurable success conditions
- **Tests Run:** What you validated
- **Risk Notes:** What might break
- **Rollback Plan:** How to safely revert

---

## Known Limitations

### Static Analysis
- `sqflint` produces false positives on valid modern SQF constructs; see `docs/qa/SQFLINT_COMPAT_GUIDE.md` for full pattern mapping
- All known CI-blocking patterns (`findIf`, `createHashMapFromArray`, `toUpperANSI`/`toLowerANSI`) have been resolved via compile helpers

### Container Environment
- CI pipeline limited to static checks only
- Runtime validation requires Arma 3 with dedicated server
- JIP, persistence, and network behavior must be validated outside CI

### Deferred Validations
Until dedicated server environment is available:
- Persistence durability over restarts
- JIP snapshot correctness
- Late-client recovery for in-flight events
- Reconnect/respawn edge cases

---

## Quality & Standards

### Code Quality Score: 7.6/10 (B+)

**Strengths:**
- ✅ Excellent server-as-authority pattern (9/10)
- ✅ Comprehensive RPC validation throughout
- ✅ Strong state isolation (pub vs. private variables)
- ✅ Robust defensive programming (type checks, nil guards)
- ✅ Well-structured UI integration
- ✅ Clear module boundaries across 14 subsystems
- ✅ All sqflint CI-blocking patterns resolved (Phase 1 complete)
- ✅ 62 automated unit test assertions in test harness

**Remaining Priority Fixes:**
1. CfgRemoteExec allowlist (P1) — ~80 lines in `description.ext`
2. Unbounded state array caps (P2) — ~15 lines
3. Guard post AllUnits optimization (P2) — ~10 lines

See `docs/qa/QA_Audit_Executive_Summary.md` for details.

---

## Security

### RemoteExec Hardening
- All client→server requests validated with `ARC_fnc_rpcValidateSender`
- Role-based access control for privileged actions
- Tower authorization checks for airfield operations
- Three-tier gating: console → tab → action → server

### Red-Flag Prevention
- No client-side authoritative state mutation
- No self-authorization of privileged actions
- Explicit logging of all critical transitions
- Bounded stores prevent unbounded growth

---

## License

This mission is a community project for Arma 3. Check repository for specific licensing terms.

---

## Credits

**Mission Author:** [7CAV] MAJ.Lewis.A

**Development Approach:**
Contract-driven architecture with AI-assisted development following strict governance and validation standards.

**Doctrinal Foundation:**
- ADP 6-0 (Mission Command)
- ADP 5-0 (Operations Process)
- ATP 6-0.5 (Command Post Operations)
- FM 3-24 (Counterinsurgency)

See `docs/projectFiles/US_Army_Doctrine_References.md` for complete citations.

---

## Support & Contact

- **Repository:** https://github.com/ALewis1975/COIN-Farabad-v0
- **Issues:** Use GitHub Issues for bug reports and feature requests
- **Documentation:** All design documents in `docs/projectFiles/`

---

## Version History

**Current:** v0 (Development)
- Initial implementation of core systems
- CIVSUBv1 baseline complete — district influence model with 20 named districts (D01 "Farabad" → D20 "Taran Fringes")
- CASREQ v1 baseline complete
- Threat v0 + IED Phase 1 baseline complete
- Farabad Console with 8 tabs operational
- Phase 1 stabilization complete: all sqflint CI blockers resolved, CIVSUB isNil bugs fixed, diagnostics tools added
- SitePop subsystem added: proximity/task-triggered NPC presence at named sites (LAMBS garrison/camp integration)
- Medical subsystem added: server-authoritative casualty tracking with CIVSUBv1 influence feedback
- Airbase expanded: RQ-4A Global Hawk (HORIZON11) added to asset roster with Eden-assigned crew
- Production-ready with Phase 2 hardening pending (CfgRemoteExec allowlist completion, array caps)

See `tests/TEST-LOG.md` for detailed validation history.

---

**Last Updated:** 2026-04-04
**Mission Type:** Persistent Multiplayer COIN Sandbox
**Max Players:** 79
**Map:** Takistan (CUP Terrains)
**Era:** 2011 Operation New Dawn
