# Pre-Dedicated Mission Completion Audit — 2026-04-06

**Repository:** `ALewis1975/COIN-Farabad-v0`  
**Purpose:** Establish the canonical “feature-complete before dedicated/JIP” ledger so dedicated-server spend is used for integration validation, not basic feature discovery.

---

## 1) Release posture

This project should not move into paid dedicated-server/JIP testing or external playtester recruitment until it reaches a **pre-dedicated release-candidate** state.

For this repo, **feature-complete** means:

1. Intended v1 subsystem scope is explicitly identified.
2. Each subsystem is classified as one of:
   - `complete`
   - `partially implemented`
   - `blocked by mission data`
   - `runtime-only unverified`
3. Confirmed code defects and confirmed Eden/mission-data blockers are separated.
4. Static validation is current for the touched systems.
5. Dedicated/JIP is reserved for replication, ownership, persistence, reconnect, respawn, and late-join proof.

This audit is the canonical completion ledger for that gate.

---

## 2) Source-of-truth split

### Locked implementation baselines

Use these as the primary definition of intended system scope:

- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/projectFiles/Farabad_TASKENG_SITREPSYS_v1_Baseline.md`
- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/projectFiles/Farabad_CIVSUBv1_Development_Baseline (1).md`
- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/projectFiles/Farabad_THREAT_v0_IED_P1_Baseline_regen.md`
- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/projectFiles/Farabad_UI_CASREQ_Thread.md`
- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/projectFiles/Farabad_AIRBASESUB_Airbase_Ambience_Planning_Spec.md`
- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/projectFiles/Farabad_COIN_Mission_Design_Guide_v0.4_2026-01-27.md`

### Planning / execution control docs

- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/architecture/Architecture_and_Readiness_Plan.md`
- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/planning/Task_Decomposition.md`
- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/qa/Development_State_Assessment_2026-04-04.md`

This audit supersedes mixed “what is left?” reasoning spread across those documents by collapsing it into one subsystem board.

---

## 3) Completion board

| Subsystem | Status | Evidence of implemented scope | Most important open gap | Gap type |
|---|---|---|---|---|
| Core / state / persistence | runtime-only unverified | Server-authoritative state/public snapshot contract is documented in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/qa/Company_Command_Dedicated_Server_Static_QA_Plan.md:13-31`; company command snapshots publish from `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/functions/core/fn_publicBroadcastState.sqf:511-512` | Persistence durability, reconnect, and late-join recovery still require dedicated proof | dedicated/JIP validation |
| TASKENG / SITREP / TOC | runtime-only unverified | Command nodes seed from `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/functions/core/fn_companyCommandInit.sqf:76-133`; state keys and JIP visibility requirements are documented in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/qa/Company_Command_Dedicated_Server_Static_QA_Plan.md:18-31,67-90` | End-to-end live SITREP / follow-on / reconnect behavior still needs runtime closure | dedicated/JIP validation |
| CIVSUB | runtime-only unverified | CIVSUB is enabled and persisted in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/initServer.sqf:199-202`; intended v1 scope is locked in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/projectFiles/Farabad_CIVSUBv1_Development_Baseline (1).md` | Needs live verification against the intended mod stack, not more speculative code work | dedicated/JIP validation |
| Threat / IED / VBIED | runtime-only unverified | Threat/IED scope is locked in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/projectFiles/Farabad_THREAT_v0_IED_P1_Baseline_regen.md`; coupling audit exists in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/qa/IED_Threat_Economy_Coupling_Audit.md` | Needs fresh live proof for threat economy, spawn/disposal flow, and post-incident linkage | dedicated/JIP validation |
| AIRBASE / CASREQ | runtime-only unverified | Arrival/taxi defaults point to existing AEON markers in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/functions/ambiance/fn_airbaseInit.sqf:64-107,134-141`; current source status is already tracked as “code-fixed, runtime-unverified” in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/qa/Development_State_Assessment_2026-04-04.md:73-74` | Dedicated smoke must confirm route-marker errors are gone and live airbase flow still works | dedicated/JIP validation |
| SitePop / Prison | runtime-only unverified | Current anchor resolution accepts any existing marker via `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/functions/sitepop/fn_sitePopBuildGroup.sqf:68-81`; prison/sitepop verification remains an explicit runtime task in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/qa/Development_State_Assessment_2026-04-04.md:115-124` | Needs live verification of prison interactions, staffing, and mod-dependent faction availability | dedicated/JIP validation |
| World / base ambience | blocked by mission data | Gate system requires named Eden objects in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/functions/world/fn_worldGateBarrierInit.sqf:8-15,44-58` | `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/mission.sqm` still has no `ARC_barrier_*` or `ARC_guardpost_*` matches | mission data / Eden |
| UI / console tabs | runtime-only unverified | Dashboard and Ops VM flags are enabled in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/initServer.sqf:103-110`; command tab VM path exists but remains opt-in in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/functions/ui/fn_uiConsoleCommandPaint.sqf:105-113` | Dedicated parity decision is still required for the command tab VM path before that flag should be enabled | dedicated/JIP validation |

---

## 4) Open blockers before dedicated-server spend

These are the only currently verified blockers that should stop “ready for dedicated” claims:

1. **World gate Eden prerequisites are still missing**
   - Required objects are defined in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/functions/world/fn_worldGateBarrierInit.sqf:8-15`.
   - `mission.sqm` currently contains no matching `ARC_barrier_*` or `ARC_guardpost_*` names.

2. **Fresh runtime evidence is still missing for most complete subsystems**
   - The repo already treats local MP, dedicated, JIP, reconnect, and respawn as deferred runtime checks in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/qa/Company_Command_Dedicated_Server_Static_QA_Plan.md:86-90`.
   - Those checks should stay deferred until the remaining code/content audit items are closed.

3. **The command-tab VM path is present but intentionally not enabled yet**
   - Ops/dashboard are enabled in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/initServer.sqf:109-110`.
   - Command tab defaults to legacy reads until dedicated parity testing is complete in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/functions/ui/fn_uiConsoleCommandPaint.sqf:105-113`.

---

## 5) “Done enough for dedicated” gate

Do not schedule dedicated/JIP or external playtest activity until all of the following are true:

- [ ] The completion board above has no remaining `blocked by mission data` subsystem.
- [ ] No active subsystem is missing a known intended v1 behavior in its locked baseline.
- [ ] Touched SQF/config paths are static-clean for compat/lint/validation.
- [ ] Console/operator workflows are documented well enough that missing behavior is not being confused with hidden feature flags.
- [ ] The release-candidate branch has a dedicated/JIP validation matrix prepared from current-head evidence, not stale logs.

---

## 6) Immediate execution queue

1. **Mission-data PR:** place and name the six required world-gate objects in Eden.
2. **Documentation pass:** treat this audit as canonical and cross-link it from readiness/planning entry points.
3. **Static completion pass:** keep compat, sqflint, marker/state validation, and RPC audits current as bounded fixes land.
4. **Release-candidate freeze:** once the board is clear of known code/content blockers.
5. **Dedicated/JIP validation:** only after the mission is feature-complete by this ledger.

---

## 7) Notes on superseded findings

- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/qa/Development_State_Assessment_2026-04-04.md:75` marked SitePop anchor resolution as a confirmed open bug.
- Current source now resolves anchors by `allMapMarkers` membership in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/functions/sitepop/fn_sitePopBuildGroup.sqf:68-81`.
- Treat the older SitePop-anchor finding as superseded unless a fresh runtime repro proves a different failure mode.
