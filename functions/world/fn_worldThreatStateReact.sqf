/*
    ARC_fnc_worldThreatStateReact

    Server-only: respond to a change in base threat posture by animating gate
    barriers and broadcasting the new posture to all clients.

    Idempotent — returns false without any side effects if the posture is
    already at the requested level.

    Params:
      0: STRING - target posture: "NORMAL" | "HIGH" | "CRITICAL". Default "NORMAL".

    Returns:
      BOOL - true if posture was changed, false if already at level or invalid.
*/

if (!isServer) exitWith {false};

params [["_level", "NORMAL", [""]]];

private _levelU = toUpper _level;
if (!(_levelU in ["NORMAL", "HIGH", "CRITICAL"])) exitWith
{
    diag_log format ["[ARC][WORLD] worldThreatStateReact: invalid level '%1' — expected NORMAL/HIGH/CRITICAL.", _level];
    false
};

// Idempotent check
private _curPosture = missionNamespace getVariable ["ARC_worldBasePosture", "NORMAL"];
if (!(_curPosture isEqualType "")) then { _curPosture = "NORMAL"; };
if (_curPosture isEqualTo _levelU) exitWith { false };

// Broadcast new posture to all clients
missionNamespace setVariable ["ARC_worldBasePosture",  _levelU, true];
missionNamespace setVariable ["ARC_worldThreatAlert",  [_levelU, serverTime], true];

// Barrier names to animate (registered in Eden via setVariable or initServer)
private _barrierNames = ["ARC_barrier_north", "ARC_barrier_main", "ARC_barrier_south"];

if (_levelU in ["HIGH", "CRITICAL"]) then
{
    diag_log format ["[ARC][WORLD] worldThreatStateReact: threat level=%1 — elevating base posture, closing barriers.", _levelU];
    {
        private _obj = missionNamespace getVariable [_x, objNull];
        if (!isNull _obj) then
        {
            _obj animateSource ["Door_1_rot", 1, false];
            _obj animateSource ["Door_2_rot", 1, false];
        };
    } forEach _barrierNames;
}
else
{
    diag_log "[ARC][WORLD] worldThreatStateReact: returning to NORMAL posture, opening barriers.";
    {
        private _obj = missionNamespace getVariable [_x, objNull];
        if (!isNull _obj) then
        {
            _obj animateSource ["Door_1_rot", 0, false];
            _obj animateSource ["Door_2_rot", 0, false];
        };
    } forEach _barrierNames;
};

true
