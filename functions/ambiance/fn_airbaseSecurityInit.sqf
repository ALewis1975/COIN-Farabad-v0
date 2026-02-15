/*
    AIRBASESUB: Perimeter patrol ambience (server-only)

    Starts patrol loops for editor-placed security vehicles.
    This is "ambience" only: the patrols do not manage base posture, alerts, or gates.

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

if (missionNamespace getVariable ["airbase_v1_security_inited", false]) exitWith {true};
missionNamespace setVariable ["airbase_v1_security_inited", true];

private _markers = [
    "Main_Gate",
    "NE_Corner",
    "North_Gate",
    "NW_Corner",
    "SE_Corner",
    "South_Gate",
    "SW_Corner"
];

private _v1 = missionNamespace getVariable ["Patrol_01", objNull];
private _v2 = missionNamespace getVariable ["Patrol_02", objNull];

if (!isNull _v1) then
{
    [_v1, "Main_Gate", _markers] spawn ARC_fnc_airbaseSecurityPatrol;
};
if (!isNull _v2) then
{
    [_v2, "South_Gate", _markers] spawn ARC_fnc_airbaseSecurityPatrol;
};

true
