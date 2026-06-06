private _records = ["startdisp_v1_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) then { _records = []; };
[
    ["enabled", ["startdisp_v1_enabled", true] call ARC_fnc_stateGet],
    ["required", ["startdisp_v1_required", true] call ARC_fnc_stateGet],
    ["seq", ["startdisp_v1_seq", 0] call ARC_fnc_stateGet],
    ["recordCount", count _records],
    ["activeStartdispId", ["activeIncidentStartdispId", ""] call ARC_fnc_stateGet],
    ["activeSummary", ["activeIncidentStartdispSummary", []] call ARC_fnc_stateGet]
]
