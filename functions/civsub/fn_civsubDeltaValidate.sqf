/*
    ARC_fnc_civsubDeltaValidate

    Light validation for Phase 2.

    Params:
      0: event (string)
      1: payload (hashmap or array-of-pairs)

    Returns: bool
*/

params [
    ["_event", "", [""]],
    ["_payload", createHashMap, [createHashMap, []]]
];

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; [(_h), _k, _d] call _hg";

// Allow payload as HashMap or as array-of-pairs (e.g., [["hit", true]])
if (_payload isEqualType []) then {
    private _hm = createHashMap;
    {
        if (_x isEqualType [] && {count _x == 2}) then {
            _hm set [_x select 0, _x select 1];
        };
    } forEach _payload;
    _payload = _hm;
};

private _allow = [
    "SHOW_PAPERS",
    "CHECK_PAPERS",
    "CRIME_DB_HIT",
    "DETENTION_INIT",
    "DETENTION_HANDOFF",
    "AID_WATER",
    "AID_RATIONS",
    "MED_AID_CIV",
    "CIV_KILLED",
    "CIV_WIA",
    "INTIMIDATION_EVENT"
];

if !(_event in _allow) exitWith {false};

// CHECK_PAPERS can optionally include hit (bool)
if (_event isEqualTo "CHECK_PAPERS") then
{
    private _hit = [_payload, "hit", false] call _hg;
    if !(_hit isEqualType true) then { _payload set ["hit", false]; };
};

true
