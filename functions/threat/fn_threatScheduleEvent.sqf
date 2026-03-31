/*
    ARC_fnc_threatScheduleEvent

    Threat Economy v0 stub: placeholder for scheduling a new threat event in a district.
    Called by ARC_fnc_threatSchedulerTick when the governor clears a district.

    This stub logs intent and returns true. Downstream spawn ticks
    (fn_iedSpawnTick, fn_vbiedSpawnTick, fn_vbiedDrivenSpawnTick, fn_suicideBomberSpawnTick)
    handle actual world instantiation based on active objective kind.

    Params:
      0: STRING districtId
      1: NUMBER escalationTier

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_districtId", "", [""]],
    ["_tier", 0, [0]]
];

if (_districtId isEqualTo "") exitWith {false};

diag_log format ["[ARC][INFO] ARC_fnc_threatScheduleEvent: district=%1 tier=%2 (stub — spawn ticks handle instantiation)", _districtId, _tier];

true
