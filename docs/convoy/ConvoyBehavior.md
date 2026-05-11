# Convoy Behavior (Moving Under Fire)

## Overview
Convoy execution remains server-authoritative in `ARC_fnc_execTickConvoy` and `ARC_fnc_execSpawnConvoy`.

The convoy now prioritizes forward movement under threat:
- Contact near the lead vehicle activates a temporary **contact profile**.
- Contact profile raises speed cap, tightens separation, and sets group behavior to `AWARE` with `FULL` speed mode.
- Drivers are kept in movement mode (`AUTOCOMBAT`/`COVER`/`SUPPRESSION` disabled for drivers only), while turret crews remain free to engage.

## Waypoint / Route Continuity
The convoy route is reapplied by watchdog logic when waypoints are missing, and all recovery branches reapply route waypoints with `AWARE` behavior to avoid stop-and-engage stalls.

## Lead Promotion and Immobilized Vehicle Handling
Lead selection now prefers the first **alive and drivable** convoy vehicle (`canMove`).

Implications:
- Destroyed/immobilized original lead vehicles no longer hard-fail the convoy.
- The next drivable vehicle is promoted as lead.
- Existing follower recovery and bypass logic continues to route trailing vehicles around disabled/wrecked blockers.
- Convoy fails as `CONVOY_IMMOBILIZED` only if no convoy vehicle can move.

## Mission-Editor Validation Scenario
1. Spawn a 4-vehicle convoy with waypoints A → B → C.
2. Place OPFOR near B and verify convoy transitions to contact profile while continuing movement.
3. Destroy or immobilize the lead vehicle and verify lead promotion + continued movement.
4. Destroy a middle vehicle and verify trailing vehicles bypass and continue.
5. Check server logs for contact activation/clear and lead-promotion entries.
