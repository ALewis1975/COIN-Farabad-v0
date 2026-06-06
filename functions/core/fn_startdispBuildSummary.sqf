/* Build compact STARTDISP summary for public UI. */
params [["_record", [], [[]]]];
private _get = {
    params ["_pairs", "_key", "_def"];
    private _out = _def;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _out = _x select 1; }; } forEach _pairs;
    _out
};
private _personnel = [_record, "personnel", []] call _get;
private _vehicles = [_record, "vehicles", []] call _get;
private _lace = [_record, "lace", []] call _get;
[
    ["startdisp_id", [_record, "startdisp_id", ""] call _get],
    ["task_id", [_record, "task_id", ""] call _get],
    ["created_ts", [_record, "created_ts", -1] call _get],
    ["created_by_group", [_record, "created_by_group", ""] call _get],
    ["grid", [_record, "capture_grid", ""] call _get],
    ["personnel", _personnel],
    ["vehicle_count", [_vehicles, "count", 0] call _get],
    ["lace", _lace],
    ["additional_supplies_requested", [_record, "additional_supplies_requested", false] call _get]
]
