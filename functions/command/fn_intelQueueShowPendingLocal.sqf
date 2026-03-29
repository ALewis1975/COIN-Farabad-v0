/*
    ARC_fnc_intelQueueShowPendingLocal

    Client: show pending TOC queue items in a simple hint.

    Uses missionNamespace vars published by ARC_fnc_intelQueueBroadcast.

    Returns:
      BOOL

    Debug-only operator helper: keeps local HINT channel output for queue snapshots.
*/

if (!hasInterface) exitWith {false};

private _q = missionNamespace getVariable ["ARC_pub_queuePending", (missionNamespace getVariable ["ARC_pub_queue", []])];
if (!(_q isEqualType []) || { (count _q) isEqualTo 0 }) exitWith
{
    ["No pending TOC queue requests.", "INFO", "HINT"] call ARC_fnc_clientHint;
    false
};

private _updatedAt = missionNamespace getVariable ["ARC_pub_queueUpdatedAt", -1];

// Helper: pull from meta pairs
private _getMeta = {
    params ["_meta", "_k", "_d"]; 
    if (!(_meta isEqualType [])) exitWith { _d };
    private _out = _d;
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x # 0) isEqualTo _k }) exitWith
        {
            _out = _x # 1;
        };
    } forEach _meta;
    _out
};

private _lines = [];
_lines pushBack "TOC Queue (Pending)";
_lines pushBack "-------------------";

if (_updatedAt isEqualType 0 && { _updatedAt > 0 }) then
{
    private _age = floor ((serverTime - _updatedAt) / 60);
    _lines pushBack (format ["Snapshot: ~%1m old", _age]);
    _lines pushBack "";
};

{
    if !(_x isEqualType [] && { (count _x) >= 12 }) then { continue; };

    _x params [
        "_qid",
        "_t",
        "_st",
        "_kind",
        "_from",
        "_fromGroup",
        "_fromUID",
        "_pos",
        "_sum",
        "_det",
        "_payload",
        "_meta",
        ["_decision", []]
    ];

    private _ageMin = 0;
    if (_t isEqualType 0) then { _ageMin = floor ((serverTime - _t) / 60); };

    private _grid = mapGridPosition _pos;
    private _zone = [_meta, "zone", ""] call _getMeta;

    private _shortFrom = if (_fromGroup isEqualTo "") then { _from } else { format ["%1", _fromGroup] };
    private _s = _sum;
    if (!(_s isEqualType "")) then { _s = ""; };
    if ((count _s) > 72) then { _s = (_s select [0, 72]) + "..."; };

    _lines pushBack (format ["%1 | %2 | %3m | %4 | %5 | %6", _qid, _kind, _ageMin, _shortFrom, _zone, _grid]);
    if (!(_s isEqualTo "")) then { _lines pushBack (format ["  %1", _s]); };
} forEach _q;

[(_lines joinString "\n"), "INFO", "HINT"] call ARC_fnc_clientHint;
true
