# Development State Assessment and Task Plan — 2026-04-04

**Repository:** `ALewis1975/COIN-Farabad-v0`
**Assessment branch/head used:** `copilot/assess-development-state` @ `5b74c68` (pre-edit baseline)
**Purpose:** Replace guesswork with an evidence-based snapshot of current development state and a non-stale task plan.

---

## 1. Evidence used

Authoritative repo sources reviewed for this pass:

- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/README.md`
- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/projectFiles/Farabad_COIN_Mission_Design_Guide_v0.4_2026-01-27.md`
- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/AGENTS.md`
- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/.github/pull_request_template.md`
- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/tests/TEST-LOG.md`
- Current source files under `functions/`, `data/`, `mission.sqm`, and `docs/reference/`
- Existing runtime evidence in `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/serverRpts/`

Assessment rule for this document:

- **Current source / mission data beats old notes**
- **Fresh runtime evidence beats static inference**
- If no fresh runtime exists, classify the item as **runtime-unverified**, not fixed

---

## 2. Current-head assessment summary

### Current source state

- AIRBASE arrival defaults are already remapped to existing AEON markers.
- `data/paths/taxiPath_UH_60M_01.sqf` now contains capture data, but its header still claims the path is empty.
- `plane_despawn` is now on-map in `mission.sqm`.
- `fn_prisonEvalIncident.sqf` already handles `prison_holding_area` as a rectangle marker correctly.
- `fn_sitePopBuildGroup.sqf` still uses `getMarkerType` for anchor existence, so rectangle markers like `prison_holding_area` still fail anchor resolution.
- `mission.sqm` still lacks the named `ARC_barrier_*` / `ARC_guardpost_*` Eden objects required by `fn_worldGateBarrierInit.sqf`.

### Assessment conclusion

The main remaining gap is **not code discovery**. It is **fresh runtime verification** against the current head, plus one confirmed open SitePop anchor bug and one confirmed open world-data gate setup gap.

---

## 3. Static validation results captured in this pass

| Check | Command | Result | Notes |
|---|---|---|---|
| State migrations | `python3 scripts/dev/validate_state_migrations.py` | PASS | 3 scenarios |
| Marker index validation | `python3 scripts/dev/validate_marker_index.py` | PASS | all modes passed |
| Test-log placeholder guard | `bash scripts/dev/check_test_log_commits.sh` | PASS | passed after adding `rg` to PATH |
| AIRBASE planning checks | `bash tests/static/airbase_planning_mode_checks.sh` | PASS | passed |
| CASREQ snapshot checks | `bash tests/static/casreq_snapshot_contract_checks.sh` | PASS | passed |
| Repo whitespace check | `git diff --check` | PASS | clean at assessment time |
| Targeted compat scan | `python3 scripts/dev/sqflint_compat_scan.py --strict ...` | FAIL (pre-existing) | existing `trim`, `isNotEqualTo`, `#` patterns remain in `fn_airbaseBuildRouteDecision.sqf` and `fn_airbaseTick.sqf` |
| Targeted sqflint | `sqflint -e w ...` | WARN (pre-existing) | `fn_sitePopBuildGroup.sqf` warns on `_this`; `fn_worldGateBarrierInit.sqf` warns on unused `_guardObj` |

### Runtime validation status

- **Local MP smoke:** BLOCKED in this container
- **Dedicated server smoke:** BLOCKED in this container
- **JIP / reconnect / respawn checks:** BLOCKED in this container

Use the existing server RPTs only as **last-known runtime evidence**, not as proof of current-head behavior.

---

## 4. Verified issue ledger

| ID | Area | Latest evidence | Current classification | What it means now | Next action |
|---|---|---|---|---|---|
| V1 | AIRBASE ambient inbound route markers | Old RPT shows `MISSING_ROUTE_MARKERS`; current source maps ARR defaults to AEON markers | **Code-fixed, runtime-unverified** | Do not plan more route-remap code until a fresh dedicated run says it still fails | Re-run dedicated AIRBASE smoke and confirm no new `MISSING_ROUTE_MARKERS` entries |
| V2 | UH-60 taxi path | Current source file contains captured data; old RPT still says empty taxi path | **Likely stale runtime evidence / runtime-unverified** | Treat the old disable log as stale until current-head runtime says otherwise | Run init/departure smoke and confirm `RW-UH60M-01` is no longer disabled |
| V3 | Prison holding-area anchor | `mission.sqm` marker is `RECTANGLE` with `type=""`; `fn_sitePopBuildGroup.sqf` still checks `getMarkerType` | **Confirmed open** | This is a real current-head code bug | Fix anchor existence check in SitePop |
| V4 | Prison incident holding-area logic | `fn_prisonEvalIncident.sqf` now uses marker position/size/dir for rectangle spawn | **Fixed in code, runtime-unverified** | Do not reopen this as a design issue | Validate breakout/incident flow in live prison smoke |
| V5 | World gate barrier init | `mission.sqm` has no required named barrier/guardpost objects; RPT shows `0 gates initialized` | **Confirmed open mission-data dependency** | This is not a logic mystery; prerequisites are absent | Eden task to place/name gate objects, then rerun smoke |
| V6 | `plane_despawn` location | `mission.sqm` now places `plane_despawn` on-map | **Fixed in world data** | The old off-map blocker is stale for current source | Verify manned FW departure/despawn behavior in live run |
| V7 | Prison / palace fallback staffing | Current templates keep only `UK3CB_TKP_B_*` / `UK3CB_TKA_B_*` pools, no vanilla fallback | **Environment/mod dependency** | Correct source now requires the intended 3CB factions to be present | Validate mod preset against live server and confirm expected faction spawns |
| V8 | LAMBS camp behavior | Code already falls back when `lambs_danger_fnc_camp` is missing | **Optional dependency / documentation gap** | Missing LAMBS is degraded behavior, not necessarily a code bug | Decide whether LAMBS Danger is required or optional and document it clearly |
| V9 | `HELMET_CITIZEN` loadout warnings | Only seen in RPT; not sourced from mission code during this pass | **External/mod dependency or stale runtime issue** | Do not create a mission-code task without a fresh repro path | Reproduce on current modset; if still present, trace to upstream/loadout source |
| V10 | `UK3CB_MEE_O_AR_01` / `G_Squares` findings | Present in old test log only; not found in current source search | **Likely stale or external until reproven** | Do not keep these as active coding tasks yet | Reproduce in current runtime before reopening |

---

## 5. Findings that should be treated as superseded

The following older QA findings should **not** drive current planning unless reintroduced by new evidence:

- Tower-role validation in `fn_airbaseSubmitClearanceRequest.sqf`
- Persistence error handling in `fn_stateSave.sqf`
- CIVSUB scheduler prerequisite guard in `fn_civsubSchedulerTick.sqf`
- Convoy authority/locality hardening in `fn_execSpawnConvoy.sqf`

These all have later static-validation entries in `tests/TEST-LOG.md` and current-source evidence showing they are already addressed.

---

## 6. Task plan grouped by risk and ownership

## Group 1 — Runtime blockers and truth-finding

### Task G1-T1 — Dedicated AIRBASE verification sweep
- **Mode:** J — Operations / Config / Data Maintenance
- **Scope:** `serverRpts/`, `tests/TEST-LOG.md`
- **Acceptance Criteria:**
  - Confirm ambient inbound no longer logs `MISSING_ROUTE_MARKERS`
  - Confirm `RW-UH60M-01` is not disabled at init
  - Confirm manned FW departures complete with current `plane_despawn`
  - Confirm RQ-4A still transitions into ISR loiter behavior
- **Tests Run:** Dedicated-server smoke with current branch/modset; attach RPT excerpts
- **Risk Notes:** Old runtime logs may be stale; this task closes the biggest evidence gap
- **Rollback:** No code rollback; revert only test-log notes if evidence was recorded incorrectly

### Task G1-T2 — Local MP prison/sitepop/civ-traffic smoke
- **Mode:** J — Operations / Config / Data Maintenance
- **Scope:** `serverRpts/`, `tests/TEST-LOG.md`
- **Acceptance Criteria:**
  - Reproduce or clear the `prison_holding_area` anchor warning
  - Verify prisoner CIVSUB interactions still work
  - Verify civ-traffic exclusion remains effective around the prison
- **Tests Run:** Hosted local MP smoke with ACE/3CB stack
- **Risk Notes:** Some findings only manifest with the full mod stack loaded
- **Rollback:** No code rollback; revert only inaccurate notes

## Group 2 — Confirmed mission-data / Eden fixes

### Task G2-T1 — Place and name world gate objects
- **Mode:** J — Operations / Config / Data Maintenance
- **Scope:** `mission.sqm`, regenerated marker/object reference artifacts if applicable, `tests/TEST-LOG.md`
- **Acceptance Criteria:**
  - `ARC_barrier_north/main/south` and `ARC_guardpost_north/main/south` exist in mission data
  - `worldGateBarrierInit` initializes expected gates in RPT
- **Tests Run:** Eden placement review + dedicated smoke
- **Risk Notes:** `mission.sqm` is a high-conflict file; keep this PR isolated
- **Rollback:** Revert the single Eden PR if gate behavior regresses

## Group 3 — Confirmed bounded code defects

### Task G3-T1 — Fix SitePop anchor existence for rectangle markers
- **Mode:** A — Bug Fix
- **Scope:** `functions/sitepop/fn_sitePopBuildGroup.sqf`, `tests/TEST-LOG.md`
- **Acceptance Criteria:**
  - Rectangle markers like `prison_holding_area` resolve as valid anchors
  - Missing-marker warning no longer appears for existing rectangle anchors
  - Legacy point-marker behavior remains unchanged
- **Tests Run:** Compat scan + sqflint on changed file + local/dedicated smoke
- **Risk Notes:** Affects every anchored SitePop group; regression risk is cross-site spawn placement
- **Rollback:** Revert the function change

## Group 4 — Deferred validation-only tasks

### Task G4-T1 — JIP / reconnect / respawn validation sweep
- **Mode:** J — Operations / Config / Data Maintenance
- **Scope:** `tests/TEST-LOG.md`
- **Acceptance Criteria:**
  - JIP clients receive correct AIRBASE, prison, and public-state snapshots
  - Reconnect/respawn does not break authority, ownership, or pending AIRBASE state
- **Tests Run:** Dedicated multiplayer session with late join
- **Risk Notes:** Repo guidance explicitly treats these as required deferred checks
- **Rollback:** No code rollback; record failures as new bounded tasks

## Group 5 — Cleanup / documentation / dependency clarification

### Task G5-T1 — Clarify optional vs required mod/runtime dependencies
- **Mode:** F — Documentation-Only Changes
- **Scope:** `README.md`, relevant docs under `docs/`, `tests/TEST-LOG.md`
- **Acceptance Criteria:**
  - LAMBS Danger requirement/optionality is explicit
  - Required 3CB sub-factions for prison/palace staffing are explicit
  - Known upstream/loadout warnings are separated from mission-code defects
- **Tests Run:** Static doc review
- **Risk Notes:** Reduces future false-positive bug reports and bad task planning
- **Rollback:** Revert doc-only PR

### Task G5-T2 — Clean stale comments and stale assessment references
- **Mode:** F — Documentation-Only Changes
- **Scope:** `data/paths/taxiPath_UH_60M_01.sqf`, stale QA docs if intentionally updated, `tests/TEST-LOG.md`
- **Acceptance Criteria:**
  - UH-60 taxi-path file header matches actual file contents
  - Any superseded assessment note clearly points readers to newer evidence
- **Tests Run:** `git diff --check`
- **Risk Notes:** Cosmetic only, but helps prevent stale planning
- **Rollback:** Revert doc/comment cleanup PR

---

## 7. Recommended execution order

1. **G1-T1 Dedicated AIRBASE verification sweep**
2. **G3-T1 SitePop rectangle-anchor bug fix**
3. **G1-T2 Local MP prison/sitepop/civ-traffic smoke**
4. **G2-T1 World gate Eden/object PR**
5. **G4-T1 JIP / reconnect / respawn validation**
6. **G5-T1 / G5-T2 documentation cleanup**

This order minimizes churn:

- verify current AIRBASE state before reopening AIRBASE coding tasks
- fix the one confirmed current-head SitePop bug
- separate Eden/object work from SQF logic work
- keep validation-only and docs-only PRs isolated

---

## 8. Bottom line

Current planning should be built around these facts:

1. **The repo already contains several fixes that older QA notes still describe as open**
2. **One SitePop anchor bug is confirmed open in current source**
3. **One world-gate content prerequisite gap is confirmed open in mission data**
4. **AIRBASE and several prison/sitepop findings now need fresh runtime proof more than new code**

The next meaningful step is a **fresh runtime status sweep on the current head**, followed by small, single-mode PRs that match the metadata and scope rules in `AGENTS.md`.
