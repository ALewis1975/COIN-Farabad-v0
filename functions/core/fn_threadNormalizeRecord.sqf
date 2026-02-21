/*
    Normalize persisted thread tuple shape to the current schema.

    Current thread tuple fields:
      [id, type, zoneBias, basePos, confidence, heat, commanderState, evidence,
       fuSuccess, fuFail, lastTouchedAt, cooldownUntil, lastCommandNodeAt,
       parentTaskId, districtId]

    Returns:
      ARRAY normalized thread tuple or [] when invalid.
*/

params [
    ["_thread", [], [[]]]
];

if !(_thread isEqualType []) exitWith {[]};
if ((count _thread) < 14) exitWith {[]};

private _out = +_thread;

if ((count _out) < 15) then
{
    private _districtId = [(_out select 3)] call ARC_fnc_threadResolveDistrictId;
    _out pushBack _districtId;
};

private _did = _out select 14;
if !(_did isEqualType "") then
{
    _did = "";
};
_out set [14, _did];

_out
