/*
    Starts a lightweight loop that periodically tries to ensure one active incident exists.

    Notes:
      - Server only.
      - Single-run guard to prevent double loops.
      - Respects ["systemPauseUntil"] in ARC_state (serverTime) to temporarily pause spawning.
      - Logging is safe even if ARC_fnc_log is not present.
*/

if (!isServer) exitWith {false};

if (!isNil { missionNamespace getVariable "ARC_incidentLoopRunning" }) exitWith {true};
missionNamespace setVariable ["ARC_incidentLoopRunning", true];

// Safe log (do not hard-depend on ARC_fnc_log)
if (!isNil "ARC_fnc_log") then
{
    ["INC", "Incident loop started"] call ARC_fnc_log;
}
else
{
    diag_log "[ARC][INC] Incident loop started";
};

[] spawn
{
    while {true} do
    {
        // Global pause (maintenance, admin pause, etc.)
        private _pauseUntil = ["systemPauseUntil", -1] call ARC_fnc_stateGet;
        if (_pauseUntil isEqualType 0 && { _pauseUntil > serverTime }) then
        {
            sleep 10;
        }
        else
        {
            [] call ARC_fnc_incidentTick;
            sleep 60;
        };
    };
};

true
