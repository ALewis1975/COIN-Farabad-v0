# AIR / TOWER — Arma-Native Audit Matrix

Date: 2026-04-06  
Status: Proposed for PR inclusion  
Scope: AIR / TOWER surface inside the existing Farabad Console shell

## Summary

This matrix scores the current AIR / TOWER interface against Arma-native capabilities rather than only real-world military UI logic.

| Area | Score | Audit note |
|---|---|---|
| Control choice | C | The AIR surface still centers on a single list/detail model. Arma supports CT_LISTNBOX, CT_TREE, CT_MAP, and CT_CONTROLS_GROUP, which are better fits for arrivals, departures, clearances, debug drill-down, and grouped layout. |
| SafeZone behavior | C | Runtime layout discipline exists, but the shell should be reviewed against GUI_GRID and SafeZone assumptions before further AIR expansion. |
| Event flow | C+ | Refresh and action dispatch are predictable, but the AIR tab still lacks purpose-built keyboard flow and safer action confirmations. |
| Multiplayer locality | B- | The repo already follows a sound server-authoritative model and publishes a normalized UI snapshot, but stale-state handling and RemoteExec allowlist hardening still need completion. |
| World-space overlays | D | AIR / TOWER currently leaves Draw3D-based runway and conflict cueing unused. |
| Map integration | D+ | AIRFIELD_OPS still behaves like a text board instead of a spatial traffic picture. |

## Weighted overall grade

**C-**

The AIR / TOWER subsystem is architecturally disciplined and locality-aware, but it still behaves like a formatted operations log rather than an Arma-native airfield interface.

## Key implementation implications

1. Keep AIR / TOWER as the deliberate control surface inside the existing console.
2. Upgrade the shell to use better Arma controls rather than only shared list/detail controls.
3. Add a map pane before adding any broad visual complexity.
4. Add world overlays only for the highest-value tower and pilot cues.
5. Finish freshness and RemoteExec hardening before declaring the subsystem complete.
