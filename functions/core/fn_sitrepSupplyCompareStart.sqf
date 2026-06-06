/* Derive readiness delta by comparing STARTDISP and ending Supply Annex. */
params [["_start", [], [[]]], ["_annex", [], [[]]]];
private _get = {
    params ["_pairs", "_key", "_def"];
    private _out = _def;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _out = _x select 1; }; } forEach _pairs;
    _out
};
private _score = {
    params ["_v"];
    if (!(_v isEqualType "")) then { _v = "GREEN"; };
    switch (toUpper _v) do { case "GREEN": { 0 }; case "AMBER": { 1 }; case "RED": { 2 }; default { 0 }; };
};
private _startLace = [_start, "lace", []] call _get;
private _endLace = [_annex, "ending_lace", []] call _get;
private _cas = [_annex, "casualties", []] call _get;
private _deltaRows = [];
{
    private _k = _x;
    private _s = [_startLace, _k, "GREEN"] call _get;
    private _e = [_endLace, _k, "GREEN"] call _get;
    _deltaRows pushBack [_k, _s, _e, ([_e] call _score) - ([_s] call _score)];
} forEach ["liquids", "ammo", "casualties", "equipment", "overall"];
[
    ["v", 1],
    ["startdisp_id", [_annex, "startdisp_id", ""] call _get],
    ["task_id", [_annex, "task_id", ""] call _get],
    ["lace_delta", _deltaRows],
    ["kia", [_cas, "kia", 0] call _get],
    ["wia", [_cas, "wia", 0] call _get],
    ["casevac_required", [_cas, "casevac_required", false] call _get],
    ["resupply_recommended", [_annex, "resupply_recommended", false] call _get],
    ["refit_recommended", [_annex, "refit_recommended", false] call _get]
]
