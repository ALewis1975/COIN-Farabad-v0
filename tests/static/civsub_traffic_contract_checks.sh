#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

drive_picker="functions/civsub/fn_civsubTrafficPickRoadDrivePos.sqf"
moving_spawn="functions/civsub/fn_civsubTrafficSpawnMoving.sqf"
traffic_tick="functions/civsub/fn_civsubTrafficTick.sqf"

grep -q 'ARC_fnc_worldHighwayMarkerNearest' "$drive_picker"
grep -q '_candDir' "$drive_picker"
grep -q '_candHwyDir' "$drive_picker"
grep -q 'ARC_fnc_worldBearingDelta' "$drive_picker"
grep -q '_score = _delta + (_candMarkerDist \* 0.05)' "$drive_picker"

grep -q 'ARC_fnc_civsubCivBuildClassPool' "$moving_spawn"
grep -q 'assignAsDriver' "$moving_spawn"
grep -q '\[_drv\] allowGetIn true' "$moving_spawn"
grep -q 'driver _veh' "$moving_spawn"

grep -q 'private _drv = driver _v' "$traffic_tick"
grep -q 'deleteVehicle _v' "$traffic_tick"

echo "[civsub-traffic-contract] PASS"
