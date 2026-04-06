# AIR / TOWER — Arma-Native Phase-by-Phase Implementation Matrix

Date: 2026-04-06  
Status: Proposed for PR inclusion

## Overview

This document converts the AIR / TOWER Arma-native audit into a phase-by-phase implementation plan sized for narrow pull requests.

| Phase | Goal | Main repo files | Status | Exit gate |
|---|---|---|---|---|
| 0 | Freeze contract and implementation rules | docs/architecture/* | Done | One agreed contract, no ambiguity on scope changes |
| 1 | Refactor the shell to use better Arma controls inside the existing console | config/CfgDialogs.hpp, functions/ui/fn_uiConsoleRefresh.sqf, functions/ui/fn_uiConsoleAirPaint.sqf, config/CfgFunctions.hpp | Not started | AIR / TOWER gets dedicated grouped controls, no second dialog |
| 2 | Convert AIRFIELD_OPS from a list-driven screen to a fixed operational board | functions/core/fn_publicBroadcastState.sqf, functions/ui/fn_uiConsoleAirPaint.sqf, functions/ui/fn_uiConsoleRefresh.sqf, functions/ui/fn_uiConsoleMainListSelChanged.sqf | Partial | 3-second scan works, default focus lands on ops state |
| 3 | Harden CLEARANCES so actions are safer and faster | functions/ui/fn_uiConsoleActionAirPrimary.sqf, functions/ui/fn_uiConsoleActionAirSecondary.sqf, functions/ui/fn_uiConsoleAirPaint.sqf, functions/ui/fn_uiConsoleOnLoad.sqf | Partial | No unsafe global action from inert selection |
| 4 | Finish locality, JIP, freshness, and RemoteExec hardening | functions/core/fn_publicBroadcastState.sqf, description.ext, tests/TEST-LOG.md, README.md | Partial | Stale/degraded state is real, late joiners safe, allowlist complete |
| 5 | Strengthen DASH so commanders do not need AIR / TOWER open | functions/ui/fn_uiConsoleDashboardPaint.sqf, functions/core/fn_publicBroadcastState.sqf | Partial | Command staff can read air status from DASH alone |
| 6 | Add spatial map integration inside AIR / TOWER | config/CfgDialogs.hpp, functions/ui/fn_uiConsoleAirPaint.sqf, functions/ui/fn_uiConsoleRefresh.sqf, functions/core/fn_publicBroadcastState.sqf, functions/ui/fn_uiConsoleMainListSelChanged.sqf | Not started | Selected traffic syncs to map, runway geometry visible |
| 7 | Add tower and pilot overlays outside the dialog | initPlayerLocal.sqf, config/CfgFunctions.hpp, new AIR overlay functions | Not started | Highest-value runway and conflict cues visible in-world |
| 8 | Final cutover and DEBUG cleanup | functions/ui/fn_uiConsoleAirPaint.sqf, functions/core/fn_publicBroadcastState.sqf, functions/ui/fn_uiConsoleRefresh.sqf | Partial | Operator view clean, debug isolated, fallback list logic retired |

## Recommended rollout order

0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8

## Notes

- This plan intentionally keeps the existing Farabad Console shell and AIR tab.
- The main scope expansion versus the earlier AIR / TOWER audit is that config/CfgDialogs.hpp, description.ext, and initPlayerLocal.sqf are now eligible touch points when required by Arma-native dialog, HUD, and networking behavior.
