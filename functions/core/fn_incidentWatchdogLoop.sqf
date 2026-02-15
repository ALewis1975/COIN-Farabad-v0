/*
    ARC_fnc_incidentWatchdogLoop

    Tiny loop starter (server only). One guard, low frequency.

    Runs ARC_fnc_incidentWatchdog every ARC_wd_tickSeconds (default 30s).

    This loop also initializes config defaults ONCE if they are nil.
*/

if (!isServer) exitWith {false};

if (!isNil { missionNamespace getVariable "ARC_wd_running" }) exitWith {true};
missionNamespace setVariable ["ARC_wd_running", true];

// Initialize defaults once (do not overwrite user overrides)
private _setDefault = {
    params ["_key", "_val"];
    if (isNil { missionNamespace getVariable _key }) then
    {
        missionNamespace setVariable [_key, _val, true];
    };
};

["ARC_wd_enabled", true] call _setDefault;
["ARC_wd_tickSeconds", 30] call _setDefault;
["ARC_wd_graceSeconds", 120] call _setDefault;
["ARC_wd_unacceptedTimeout", 900] call _setDefault;
["ARC_wd_acceptedTimeout", 1800] call _setDefault;
["ARC_wd_suggestResult", "FAILED"] call _setDefault;
["ARC_wd_debugLog", false] call _setDefault;

private _tick = missionNamespace getVariable ["ARC_wd_tickSeconds", 30];
if !(_tick isEqualType 0) then { _tick = 30; };
if (_tick < 10) then { _tick = 10; };  // keep it boring and safe

diag_log format ["[ARC][WD] Watchdog loop started (tick=%1s)", _tick];

[] spawn
{
    while {true} do
    {
        // Pull tick fresh each cycle (allows live tuning), clamp safe minimum.
        private _t = missionNamespace getVariable ["ARC_wd_tickSeconds", 30];
        if !(_t isEqualType 0) then { _t = 30; };
        if (_t < 10) then { _t = 10; };

        [] call ARC_fnc_incidentWatchdog;

        sleep _t;
    };
};

true
