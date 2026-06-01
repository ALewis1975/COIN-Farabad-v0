/*
    ARC_fnc_convoyOpsLog

    Uniform convoy lifecycle OPS logging. Routes a convoy lifecycle transition
    through ARC_fnc_intelLog (category "OPS") so it lands in ARC_pub_opsLog
    (a bounded, JIP-visible slice of OPS entries) with a consistent
    id + grid + actor signature, per Design Guide §4.6.

    The grid is added automatically by ARC_fnc_intelLog from the supplied
    position; this helper guarantees the id (convoy/incident task id) and the
    actor (convoy callsign/designation) are always present in the meta.

    Params:
      0: STRING  event      lifecycle event key (e.g. "CONVOY_SPAWNED")
      1: STRING  summary    one-line human-readable summary
      2: ARRAY   posATL     [x,y,z] reference position (optional; default [0,0,0])
      3: STRING  taskId     convoy/incident id (optional; resolved from state if "")
      4: STRING  actor      convoy callsign/designation (optional; resolved if "")
      5: ARRAY   extraMeta  additional [[k,v], ...] meta pairs (optional)

    Returns:
      STRING - intelId from ARC_fnc_intelLog ("" if not server)
*/

if (!isServer) exitWith {""};

params [
    ["_event", "", [""]],
    ["_summary", "", [""]],
    ["_posATL", [0,0,0], [[]]],
    ["_taskId", "", [""]],
    ["_actor", "", [""]],
    ["_extraMeta", [], [[]]]
];

if (_event isEqualTo "") then { _event = "CONVOY_EVENT"; };
if (!(_posATL isEqualType []) || { (count _posATL) < 2 }) then { _posATL = [0,0,0]; };
if (!(_extraMeta isEqualType [])) then { _extraMeta = []; };

// Resolve the convoy id from the active convoy task when not supplied.
if (_taskId isEqualTo "") then
{
    private _activeTask = ["activeTaskId", ""] call ARC_fnc_stateGet;
    if (_activeTask isEqualType "") then { _taskId = _activeTask; };
};

// Resolve the actor (callsign) from the persisted convoy designation profile.
// Profile shape: [unit, parent, callsign, subUnits, ...]; index 2 is the callsign.
if (_actor isEqualTo "") then
{
    private _profile = ["activeConvoyDesignationProfile", []] call ARC_fnc_stateGet;
    if ((_profile isEqualType []) && { (count _profile) >= 3 } && { (_profile select 2) isEqualType "" }) then
    {
        _actor = _profile select 2;
    };
};
if (_actor isEqualTo "") then { _actor = "CONVOY"; };

private _meta = [
    ["event", _event],
    ["id", _taskId],
    ["taskId", _taskId],
    ["actor", _actor],
    ["lifecycle", "convoy"]
];
{ _meta pushBack _x; } forEach _extraMeta;

["OPS", _summary, _posATL, _meta] call ARC_fnc_intelLog
