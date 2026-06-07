/*
    ARC_fnc_dossierAnnexBuild

    Build a compact SITREP annex describing the SHERIFF/SSE dossier(s) tied to an
    incident, for inclusion in the TOC SITREP. Reads the persisted dossier store
    (array-of-pairs records), so it reconstructs from the server snapshot.

    Params:
      0: STRING - taskId    (active incident task id; primary match)
      1: STRING - districtId (fallback match when taskId empty)

    Returns:
      STRING ("" when dossier disabled or no matching record)
*/

if (!isServer) exitWith {""};
if (!(["dossier_v0_enabled", true] call ARC_fnc_stateGet)) exitWith {""};

params [
    ["_taskId", "", [""]],
    ["_districtId", "", [""]]
];

private _records = ["dossier_v0_records", []] call ARC_fnc_stateGet;
if !(_records isEqualType []) then { _records = []; };
if ((count _records) isEqualTo 0) exitWith {""};

// Pair lookup over an array-of-pairs record.
private _pget = compile "params ['_arr','_key','_def']; if (!(_arr isEqualType [])) exitWith { _def }; private _r = _def; { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _r = _x select 1 }; } forEach _arr; _r";

private _lines = [];
{
    private _rec = _x;
    if (_rec isEqualType []) then {
        private _rTask = [_rec, "task_id", ""] call _pget;
        private _rDist = [_rec, "district_id", ""] call _pget;
        private _match = false;
        if (!(_taskId isEqualTo "") && {_rTask isEqualTo _taskId}) then { _match = true; };
        if (!_match && {_taskId isEqualTo ""} && {!(_districtId isEqualTo "")} && {_rDist isEqualTo _districtId}) then { _match = true; };

        if (_match) then {
            private _dosId = [_rec, "dossier_id", "?"] call _pget;
            private _conf  = [_rec, "confidence", 0] call _pget;
            if !(_conf isEqualType 0) then { _conf = 0; };
            private _leadId = [_rec, "lead_id", ""] call _pget;

            private _identity = [_rec, "identity", []] call _pget;
            if !(_identity isEqualType []) then { _identity = []; };
            private _name = [_identity, "name", "UNKNOWN"] call _pget;
            private _wl   = [_identity, "wanted_level", 0] call _pget;
            private _charges = [_identity, "charges", []] call _pget;
            if !(_charges isEqualType []) then { _charges = []; };
            private _chargeTxt = "none";
            if ((count _charges) > 0) then { _chargeTxt = _charges joinString ", "; };

            private _evidence = [_rec, "evidence", []] call _pget;
            if !(_evidence isEqualType []) then { _evidence = []; };
            private _evItems = 0;
            {
                private _cnt = [_x, "item_count", 0] call _pget;
                if !(_cnt isEqualType 0) then { _cnt = 0; };
                _evItems = _evItems + _cnt;
            } forEach _evidence;

            private _leadTxt = "no lead";
            if (!(_leadId isEqualTo "")) then { _leadTxt = format ["lead %1", _leadId]; };

            _lines pushBack (format [
                "  - %1 | %2 (WL%3) | charges: %4 | evidence: %5 item(s) across %6 case file(s) | conf %7%% | %8",
                _dosId, _name, _wl, _chargeTxt, _evItems, count _evidence, round (_conf * 100), _leadTxt
            ]);
        };
    };
} forEach _records;

if ((count _lines) isEqualTo 0) exitWith {""};

private _out = ["SHERIFF/SSE DOSSIER:"];
_out append _lines;
_out joinString (toString [10])
