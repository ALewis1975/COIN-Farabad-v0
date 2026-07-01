# Farabad Imagery-to-Marker Audit — 2026-07-01

**Status:** Static audit complete; no runtime mission logic changed.  
**Repository state audited:** `main` at `da5206d4e616d604fe95353968560206003af4e4` (`Add imagery pack and update mission layout`).  
**Scope:** `data/Imagery/*` reference imagery, current marker/location contracts, and affected placement-audit surfaces.  
**Out of scope:** Runtime SQF changes, missionNamespace state changes, persistence migrations, object placement edits, image asset renames, generated marker-index edits.

---

## 1. Execution context declaration

- **Mission type:** Dedicated MP.
- **JIP:** Required. This audit does not add JIP state, but all recommendations preserve snapshot-driven/JIP reconstruction rules.
- **Authority:** Server remains single-writer for campaign/runtime state. Imagery is documentation/reference material only.
- **Locality:** No locality changes. Any future placement/runtime patch must keep server-authoritative mutation and client request-only behavior.
- **Persistence:** No new persistence blob, schema version, or reset workflow in this audit.
- **Cleanup/despawn:** Images must not be treated as proof that spawned entities live forever; future placement changes must remain bubble-aware and persist records, not objects.
- **Patch discipline:** This branch adds one QA document only.

---

## 2. Sources of truth applied

1. `docs/projectFiles/Farabad_Prompting_Integration_Playbook_Project_Standard.md` — workflow, single-writer authority, consumers-never-guess, patch discipline.
2. `docs/projectFiles/Farabad_COIN_Mission_Design_Guide_v0.4_2026-01-27.md` — mission spine, system-of-systems architecture, persistence/logging rules.
3. `docs/projectFiles/farabad_project_dictionary_v_1.1.md` — canonical subsystem language, stable IDs, marker/key naming rules.
4. `docs/projectFiles/Farabad_ORBAT.md` — BLUFOR/TNP/TNA/USAF ownership and callsign authority.
5. `docs/projectFiles/Farabad_AIRBASESUB_Airbase_Ambience_Planning_Spec.md` — AIRBASE runtime contract and protected airfield behavior.
6. `docs/reference/marker-index.md` / `docs/reference/marker-index.json` — generated marker inventory. Must be regenerated after `mission.sqm` edits before final coordinate validation.
7. `data/farabad_world_locations.sqf`, `data/farabad_world_zones.sqf`, `data/farabad_marker_aliases.sqf`, `data/farabad_site_templates.sqf` — canonical world/site contracts consumed by mission systems.

---

## 3. Imagery pack inventory

Commit `da5206d4e616d604fe95353968560206003af4e4` added or moved these imagery assets:

- `data/Imagery/Farabad_City.png`
- `data/Imagery/Farabad_City_2.png`
- `data/Imagery/Farabad_International_Airport.png`
- `data/Imagery/Farabad_International_Airport_2.png`
- `data/Imagery/Farabad_Terrain.png`
- `data/Imagery/Farabad_Terrain_2.png`
- `data/Imagery/Farabad_Terrain_3_mkrs.png`
- `data/Imagery/airbase_plain.png`
- `data/Imagery/embassy_and_ACoYHQ.png`
- `data/Imagery/military_outpost_log1_BCoyHQ.png`
- `data/Imagery/mine_mkr16.png`
- `data/Imagery/mines_mkr18-19.png`
- `data/Imagery/mosque_hotel_tnphq.png`
- `data/Imagery/oil_refinery.png`
- `data/Imagery/port.png`
- `data/Imagery/presidential_palance.png`
- `data/Imagery/prison.png`

**Connector limitation:** the GitHub connector returned binary metadata and blob SHAs for several new POI PNGs but did not expose decodable pixel payloads for visual inspection. This is therefore a **static imagery-to-contract audit**, not a pixel-level visual QA pass. A local Eden/image viewer pass is still required before treating object placement as validated.

---

## 4. System boundary

The imagery pack is a reference layer. It must not become a source of runtime state.

**Authoritative placement order remains:**

1. `mission.sqm` editor objects and markers.
2. Generated marker index (`docs/reference/marker-index.*`).
3. Canonical aliases and world data (`data/farabad_marker_aliases.sqf`, `data/farabad_world_locations.sqf`, `data/farabad_world_zones.sqf`).
4. Subsystem templates/functions (`data/farabad_site_templates.sqf`, AIRBASE functions, CIVSUB/Threat consumers).
5. Imagery as a sanity-check/reference layer only.

---

## 5. Findings

### F-01 — Imagery pack is useful and should be kept

The new files materially improve site-level review. The first three reference maps supported AO-level orientation; the expanded pack supports specific placement audits for the mosque/hotel/TNP HQ, prison, port, refinery, mines, embassy/A Co area, military outpost/B Co/logistics area, and airbase.

**Impact:** Positive. Better visual context should reduce technically valid but visually poor marker/object placement.

**Action:** Keep the imagery pack as `data/Imagery/*` reference material.

---

### F-02 — `mission.sqm` changed but generated marker docs were not listed in the imagery commit

The imagery commit also updated `mission.sqm` with Eden changes, refreshed location/highway markers, new/adjusted base objects and layers, and Landing Zone #B. The commit file list did not include regenerated `docs/reference/marker-index.md` or `docs/reference/marker-index.json`.

**Impact:** Medium. Any audit using `docs/reference/marker-index.*` may be using stale marker metadata after `mission.sqm` changed.

**Action:** Regenerate marker index before final placement validation:

```bash
python3 tools/generate_marker_index.py
```

Then review/commit `docs/reference/marker-index.md` and `docs/reference/marker-index.json` if they change.

---

### F-03 — Airbase imagery is high-value for AIRBASESUB and base-object validation

Relevant images:

- `Farabad_International_Airport.png`
- `Farabad_International_Airport_2.png`
- `airbase_plain.png`

Canonical references and consumers to audit:

- `mkr_airbaseCenter`
- `AEON_Right_270_Outbound`
- `AEON_Right_270_Outbound_Clear`
- `AEON_Taxi_Right_Egress`
- `AEON_Taxi_Right_Ingress`
- `mkr_arrivalRunwayStart`
- `mkr_arrivalRunwayStop`
- `mkr_arrivalRunwayTaxiOut`
- `mkr_arrivalSpawn`
- `Main_Gate`, `North_Gate`, `South_Gate`
- `arc_m_base_atc_tower`, `arc_m_base_atc_ground`, `arc_m_base_atc_approach`
- `arc_m_base_convoy_staging`
- `arc_rotary_pad_*`
- `marker_23` through `marker_32` for EPW/base/tower/hangar/base support labels

**Audit use:** runway/taxi geometry, protected movement surfaces, tower/ground/approach positions, flightline support placement, rotary pad placement, convoy separation, and Landing Zone #B placement.

**Action:** Do not change AIRBASE logic from imagery alone. Use imagery to validate marker/object positions, then patch only marker/object data with explicit AIRBASE acceptance tests if misplacements are found.

---

### F-04 — Mosque/hotel/TNP HQ imagery is high-value for CIVSUB/SitePop placement

Relevant image:

- `mosque_hotel_tnphq.png`

Canonical references and consumers to audit:

- `GrandMosque` / `ARC_loc_GrandMosque` / legacy alias `marker_2`
- `BelleFoilleHotel` / `ARC_loc_BelleFoilleHotel` / legacy alias `marker_3`
- `arc_hq_TNP`
- nearby highway markers in the `mkr_highway_025`–`mkr_highway_030` corridor
- SitePop Grand Mosque roles: `elder`, `worshipper`, `vendor`, `tnp_outer`, `civ_car`
- SitePop hotel roles: `hotel_staff`, `guest`, `security`, `civ_car`

**Audit use:** mosque compound approach routes, TNP outer security, vendor/car placement, civilian crowd flow, hotel guest/staff placement, protest/cordon/incident surfaces.

**Action:** Consider adding anchor-local SitePop markers for the mosque only after visual validation. Do not expand counts until MP performance has been tested.

---

### F-05 — Prison imagery should be used to validate existing anchor-heavy SitePop design

Relevant image:

- `prison.png`

Canonical references and consumers to audit:

- `KarkanakPrison` / `ARC_loc_KarkanakPrison` / legacy alias `marker_6`
- `prison_admin_offices`
- `prison_entry_office`
- `prison_guard_tower_1`
- `prison_guard_tower_2`
- `prison_central_guard_tower`
- `prison_dorm_01` through `prison_dorm_04`
- `prison_intake_01`
- `prison_hospital`
- `prison_holding_area`

**Audit use:** prevent guard/prisoner/medical/vendor groups from bleeding across prison subzones; validate tower/entry/intake/hospital/dorm anchor placement.

**Action:** If the image shows anchor drift, patch anchor marker positions only. Do not rewrite SitePop behavior.

---

### F-06 — Mine imagery exposes a naming-contract gap

Relevant images:

- `mine_mkr16.png`
- `mines_mkr18-19.png`

Known mine markers currently include:

- `marker_16` — Mine
- `marker_18` — Mine
- `marker_19` — Mine
- `marker_20` — Mine
- `marker_21` — Mine

**Impact:** Medium. These are editor/legacy marker names, not durable semantic IDs. They are acceptable as existing references but should not be used as new cross-system contracts.

**Action:** Add canonical aliases in a future bounded data patch, for example:

- `ARC_loc_Mine_16`
- `ARC_loc_Mine_18`
- `ARC_loc_Mine_19`
- `ARC_loc_Mine_20`
- `ARC_loc_Mine_21`

Exact canonical names should be confirmed against the Project Dictionary before patching. If these become Threat/IED task anchors, they should also receive stable task/threat IDs rather than relying on marker display text.

---

### F-07 — `presidential_palance.png` has a filename typo

Relevant image:

- `presidential_palance.png`

Canonical references and consumers to audit:

- `PresidentialPalace` / `ARC_loc_PresidentialPalace` / legacy alias `marker_9`
- `ParadeGround`
- `VictoryMonument`
- `GreenZone`

**Impact:** Low. The filename typo is documentation friction, not a runtime bug unless referenced by briefing/UI paths later.

**Action:** Prefer a future asset-only rename to `presidential_palace.png` after confirming there are no path references. Avoid mixing the rename with mission logic changes.

---

### F-08 — Military/outpost imagery may reveal duplicated or overloaded `ARC_loc_military` semantics

Relevant image:

- `military_outpost_log1_BCoyHQ.png`

Canonical references and consumers to audit:

- `military` world location
- `MilitaryBase` world zone
- `ARC_loc_military`
- `ARC_m_logistics_01`
- `arc_hq_B_2_325_AIR`
- SitePop military compound roles: `tna_staff`, `patrol`, `mil_vehicle`

**Impact:** Medium. Marker-index output has historically shown `ARC_loc_military` associated with both a base/TOC-style location and the remote Logistics 01/military location. After marker-index regeneration, verify there is no duplicate/overloaded canonical marker ambiguity.

**Action:** If ambiguity remains, split display aliases from canonical markers. Do not let ORBAT/task routing infer from a friendly display name.

---

### F-09 — Embassy/A Co imagery is useful for ORBAT-aligned urban placement

Relevant image:

- `embassy_and_ACoYHQ.png`

Canonical references and consumers to audit:

- `EmbassyCompound` / `ARC_loc_EmbassyCompound` / legacy alias `marker_10`
- `arc_hq_A_2_325_AIR`
- `hq_a_2_325_offices`
- `hq_a_2_325_barracks_1`
- `hq_a_2_325_barracks_2`
- `hq_a_2_325_motor_maintenance`
- `hq_a_2_325_supply`
- `arc_hq_TNA`

**Audit use:** A Co HQ object/marker placement, embassy perimeter/security, TNA checkpoint placement, nearby motor/supply/barracks layout, urban access routes.

**Action:** Keep this as an ORBAT placement reference. If patching, preserve A/2-325 AIR and TNA ownership semantics from ORBAT.

---

### F-10 — Port/refinery imagery is useful for infrastructure-task design but should remain planning/audit input

Relevant images:

- `port.png`
- `oil_refinery.png`

Canonical references and consumers to audit:

- `PortFarabad` / `ARC_loc_PortFarabad` / legacy alias `marker_8`
- SitePop port roles: `stevedore`, `port_security`, `customs`, `cargo_truck`
- `JaziraOilRefinery` / `ARC_loc_JaziraOilRefinery` / legacy alias `marker_12`
- `JaziraOilField` / `ARC_loc_JaziraOilField` / legacy alias `marker_15`
- `marker_14` — Oil Processing
- SitePop oil/refinery roles: `worker`, `security`, `fuel_truck`

**Audit use:** cargo/fuel vehicle spawn placement, infrastructure perimeter security, approach routes, sabotage/IED task surfaces, non-road clutter avoidance.

**Action:** Use these images to prepare future infrastructure task planning. Do not add Threat/IED behavior from imagery without the locked Threat/IED contract.

---

## 6. Image-to-contract matrix

| Image | Primary placement question | Canonical references to verify | Subsystem risk if wrong | Recommended next action |
|---|---|---|---|---|
| `Farabad_Terrain.png` | Does the broad AO model match named locations/zones? | `Farabad`, `FarabadCity`, quadrant zones, airbase, military, port, refinery, mines | Bad strategic task placement, poor route design | Use as AO overview only |
| `Farabad_Terrain_2.png` | Same, likely alternate view | Same as above | Same as above | Use during planning/audit |
| `Farabad_Terrain_3_mkrs.png` | Do mission markers match the broad terrain? | generated marker index after regen | Stale/misaligned marker assumptions | Regenerate marker index first |
| `Farabad_City.png` | Does city POI layout match world locations? | Grand Mosque, hotel, palace, green zone, embassy, hospital, city center | CIVSUB/SitePop/incident placement drift | Use for city placement review |
| `Farabad_City_2.png` | Same, likely alternate city view | Same as above | Same as above | Use during visual QA |
| `Farabad_International_Airport.png` | Are airfield markers on correct surfaces? | runway/taxi/ATC/arrival/base markers | AIRBASE pathing, runway locks, convoy bleed | High-priority visual audit |
| `Farabad_International_Airport_2.png` | Same, likely alternate airport view | Same as above | Same as above | High-priority visual audit |
| `airbase_plain.png` | Can we audit airbase without annotation clutter? | runway/taxi/gate/parking markers | Hidden object/marker drift | Use as base overlay reference |
| `mosque_hotel_tnphq.png` | Are mosque/hotel/TNP entities placed plausibly? | `ARC_loc_GrandMosque`, `ARC_loc_BelleFoilleHotel`, `arc_hq_TNP` | Bad civilian/security placement | Add anchor markers only after visual confirmation |
| `prison.png` | Are prison anchors inside correct subzones? | `prison_*` anchors and `ARC_loc_KarkanakPrison` | Guard/prisoner bleed, bad SitePop | Validate all anchors |
| `embassy_and_ACoYHQ.png` | Are embassy/A Co/TNA markers coherent? | `ARC_loc_EmbassyCompound`, A Co HQ markers, `arc_hq_TNA` | ORBAT/task placement drift | Static + Eden visual audit |
| `military_outpost_log1_BCoyHQ.png` | Is Logistics 01/B Co HQ/military site unambiguous? | `ARC_loc_military`, `ARC_m_logistics_01`, `arc_hq_B_2_325_AIR` | Ambiguous route/task/RTB resolution | Check duplicate/alias ambiguity after marker regen |
| `mine_mkr16.png` | Is mine marker 16 usable as a POI? | `marker_16` | Legacy marker key leakage | Add canonical alias in future patch |
| `mines_mkr18-19.png` | Are mine markers 18/19 usable as POIs? | `marker_18`, `marker_19` | Same as above | Add canonical aliases in future patch |
| `oil_refinery.png` | Are refinery/oil-processing references distinct? | `JaziraOilRefinery`, `JaziraOilField`, `marker_14` | Infrastructure task ambiguity | Clarify marker naming/aliases |
| `port.png` | Are port workers/security/trucks placed plausibly? | `PortFarabad`, `ARC_loc_PortFarabad` | Bad SitePop or task anchor placement | Visual + SitePop audit |
| `presidential_palance.png` | Does palace imagery map to palace/government markers? | `PresidentialPalace`, `ParadeGround`, `VictoryMonument`, `GreenZone` | Minor unless used by tasks/UI | Rename typo in a separate asset-only patch |

---

## 7. Recommended follow-up sequence

1. **Regenerate marker index.** Run `python3 tools/generate_marker_index.py` after the current `mission.sqm` changes.
2. **Review generated diff only.** If marker docs changed, commit `docs/reference/marker-index.md` and `docs/reference/marker-index.json` in a marker-index-only patch.
3. **Do local pixel-level visual QA.** Open each `data/Imagery/*` image alongside Eden/map marker positions.
4. **Create a marker alias patch only if needed.** Prioritize mine aliases and any `ARC_loc_military` ambiguity.
5. **Patch object/marker placement only after audit.** Keep changes bounded to `mission.sqm` and generated marker docs.
6. **Do not alter AIRBASE/CIVSUB/Threat runtime logic from imagery alone.** Those systems require contract-first plans and dedicated MP/JIP validation.

---

## 8. Static checks to run

```bash
# Regenerate marker docs after mission.sqm changes
python3 tools/generate_marker_index.py

git diff -- docs/reference/marker-index.md docs/reference/marker-index.json

# Check for stale references to old root-level imagery paths
grep -R "data/Farabad_\|data\\Farabad_" -n . \
  --exclude-dir=.git \
  --exclude-dir=data/Imagery

# Check whether new imagery paths are referenced anywhere yet
grep -R "data/Imagery\|data\\Imagery" -n . \
  --exclude-dir=.git
```

Expected result:

- Marker index may change because `mission.sqm` changed.
- No stale references to removed root-level image paths should remain.
- `data/Imagery/*` may be unreferenced if currently used only as design documentation.

---

## 9. 10-minute dedicated MP smoke plan for future placement patch

Only needed if a follow-up patch moves markers/objects or changes SitePop/AIRBASE consumers.

1. Start dedicated server with the current approved mod preset.
2. Join as host/client, then JIP with a second client after mission start.
3. Enable relevant debug snapshots only if already supported by the subsystem.
4. Visit these locations in sequence:
   - Airbase / Landing Zone #B / tower / taxi markers.
   - Grand Mosque / Belle Foille Hotel / TNP HQ area.
   - Karkanak Prison.
   - Port Farabad.
   - Jazira Oil Refinery / Oil Field.
   - Mine markers 16, 18, and 19.
5. Confirm expected behavior:
   - No RPT missing-class spam from object placement.
   - No AIRBASE runway/taxi lock errors.
   - No convoy bleed onto protected airfield surfaces.
   - SitePop remains bounded by active-site caps and despawn bubbles.
   - JIP client receives current public state and does not infer hidden state.
   - No duplicate/ghost spawns after leaving/re-entering despawn bubbles.

---

## 10. Regression risks

| Risk | Detection | Mitigation |
|---|---|---|
| Stale marker index after `mission.sqm` edit | Generated docs differ after `tools/generate_marker_index.py` | Commit generated marker docs separately |
| Imagery treated as runtime source of truth | Code references PNGs for placement/state | Keep imagery docs-only unless used explicitly for UI/briefing |
| Legacy marker IDs leak into new systems | New code/tasks refer to `marker_16` etc. | Add canonical aliases first |
| `ARC_loc_military` ambiguity | Marker index shows duplicate/overloaded usage after regen | Split alias/display names from canonical marker IDs |
| AIRBASE protected surface intrusion | Aircraft pathing/runway-lock RPT warnings or convoy crossing runway/taxiway | Audit with `airbase_plain.png`, then patch markers/objects only |
| SitePop over-density | AI count spike around mosque/prison/port/refinery | Keep counts conservative; validate in dedicated MP |
| Asset rename breakage | `grep` finds stale path references | Rename only in asset-only patch with path grep |
| OneDrive rollback/conflict | Files disappear, reappear, or revert after Eden save | Disable OneDrive sync for mission folder before editing |

---

## 11. Recommendation

Proceed with the imagery pack as a permanent reference set, but treat this as an audit aid, not a new implementation baseline.

The next safe patch should be either:

1. **Marker index refresh only** after the current `mission.sqm`; or
2. **Canonical marker alias cleanup only** for mine markers and any military/logistics ambiguity found after regeneration.

Do not combine those with AIRBASE, CIVSUB, SitePop, or Threat runtime changes.
