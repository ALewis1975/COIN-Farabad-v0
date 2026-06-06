/* Build authoritative SITREP Supply Annex v1 from sanitized payload. */
if (!isServer) exitWith { [] };
params [
    ["_unit", objNull],
    ["_payload", [], [[]]],
    ["_taskId", "", [""]]
];

private _get = {
    params ["_pairs", "_key", "_def"];
    private _out = _def;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _out = _x select 1; }; } forEach _pairs;
    _out
};
private _clean = [_payload] call ARC_fnc_sitrepSupplyValidate;
private _startdispId = ["activeIncidentStartdispId", ""] call ARC_fnc_stateGet;
private _uid = if (isNull _unit) then { "" } else { getPlayerUID _unit };
private _gid = if (isNull _unit || { isNull (group _unit) }) then { "" } else { groupId (group _unit) };

[
    ["v", 1],
    ["task_id", _taskId],
    ["startdisp_id", _startdispId],
    ["reported_ts", serverTime],
    ["reported_by_uid", _uid],
    ["reported_by_group", _gid],
    ["ammo_expended", [_clean, "ammo_expended", []] call _get],
    ["medical_used", [_clean, "medical_used", "NONE"] call _get],
    ["equipment_lost", [_clean, "equipment_lost", ""] call _get],
    ["equipment_damaged", [_clean, "equipment_damaged", ""] call _get],
    ["vehicle_losses", []],
    ["vehicle_damage_notes", [_clean, "vehicle_damage_notes", ""] call _get],
    ["casualties", [_clean, "casualties", []] call _get],
    ["ending_lace", [_clean, "ending_lace", []] call _get],
    ["remaining_limitations", [_clean, "remaining_limitations", ""] call _get],
    ["refit_recommended", [_clean, "refit_recommended", false] call _get],
    ["resupply_recommended", [_clean, "resupply_recommended", false] call _get]
]
