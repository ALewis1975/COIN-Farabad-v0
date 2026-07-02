# PR C Airbase Placement Reference Cleanup

Status: partial PR C implementation. Scope is airbase reference cleanup only. No Eden object or marker movement is included.

## Execution context

- Dedicated MP mission.
- Server remains the authority for runtime and campaign state.
- No AIRBASE logic, persistence schema, UI, CIVSUB, SitePop, or Threat state machine is changed.
- No `mission.sqm` edit is included.

## Reference cleanup applied

The generated marker index showed several legacy editor markers sitting on top of stable airbase markers. `data/farabad_marker_aliases.sqf` now resolves these legacy names to the stable markers:

| Legacy marker | Meaning | Canonical marker |
|---|---|---|
| `marker_24` | Farabad Tower | `arc_m_base_atc_tower` |
| `marker_27` | Joint Base HQ | `ARC_m_base_hq_1` |
| `marker_28` | Base Mayor | `ARC_m_base_mayor_1` |
| `marker_29` | USAF Security HQ | `arc_m_base_police_hq` |
| `marker_31` | Joint Aviation HQ | `ARC_m_base_avn_hq` |
| `marker_32` | USAF Pilot Hangar | `ARC_m_base_usaf_pilot_hangar` |

This prevents future consumers from using disposable `marker_N` names for known airbase support locations.

## Not changed

No physical placement was moved. I found no discoverable `LZ #B`, `Landing Zone #B`, `LZ_B`, or equivalent marker reference in repository search or the generated marker index. A future Eden visual pass is still required before changing physical placement.

Existing runway and taxi markers remain unchanged, including `AEON_Right_270_Outbound`, `AEON_Right_270_Outbound_Clear`, `AEON_Taxi_Right_Egress`, `AEON_Taxi_Right_Ingress`, `mkr_arrivalRunwayStart`, `mkr_arrivalRunwayStop`, and `mkr_arrivalRunwayTaxiOut`.

## Full PR C follow-up gate

Before editing `mission.sqm`, confirm the actual LZ B object, marker, or layer in Eden and compare it with `data/Imagery/airbase_plain.png`, `Farabad_International_Airport.png`, and `Farabad_International_Airport_2.png`.

If a physical correction is confirmed, patch only `mission.sqm` and regenerated `docs/reference/marker-index.*`.

## Regression risk

Low to moderate-low. This is a reference cleanup. It changes how legacy editor marker names resolve, but the targets are already present airbase markers.