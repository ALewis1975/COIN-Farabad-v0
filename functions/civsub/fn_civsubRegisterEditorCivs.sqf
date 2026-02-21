/*
    ARC_fnc_civsubRegisterEditorCivs

    Registers editor-placed civilians as CIVSUB-managed civilians for testing.

    Config (missionNamespace):
      - civsub_v1_editorTestCivs: []
          Entry forms:
            "civsub_test_01"
            ["civsub_test_01", "D14"]
            ["civsub_test_01", "D14", true]
      - civsub_v1_editorTestCivs_pin: bool (default true)

    Returns: [registeredCount, skippedCount]
*/

if (!isServer) exitWith {[0, 0]};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {[0, 0]};

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; [(_h), _k, _d] call _hg";
private _keysFn   = compile "params ['_m']; keys _m";

private _entries = missionNamespace getVariable ["civsub_v1_editorTestCivs", []];
if !(_entries isEqualType []) exitWith {
    diag_log "[CIVSUB][EDITOR] civsub_v1_editorTestCivs is not an array; skipping editor registration";
    [0, 0]
};

private _defaultPin = missionNamespace getVariable ["civsub_v1_editorTestCivs_pin", true];
if !(_defaultPin isEqualType true) then { _defaultPin = true; };

private _registered = 0;
private _skipped = 0;

{
    private _entry = _x;

    private _varName = "";
    private _districtOverride = "";
    private _pin = _defaultPin;

    if (_entry isEqualType "") then {
        _varName = _entry;
    } else {
        if (_entry isEqualType [] && { (count _entry) >= 1 }) then {
            _varName = _entry select 0;
            if ((count _entry) >= 2) then { _districtOverride = _entry select 1; };
            if ((count _entry) >= 3) then {
                private _entryPin = _entry select 2;
                if (_entryPin isEqualType true) then { _pin = _entryPin; };
            };
        };
    };

    if !(_varName isEqualType "") then {
        _skipped = _skipped + 1;
        diag_log format ["[CIVSUB][EDITOR] Registration failed (var='<unknown>', reason=invalid var name type, entry=%1)", _entry];
        continue;
    };

    if (_varName isEqualTo "") then {
        _skipped = _skipped + 1;
        diag_log format ["[CIVSUB][EDITOR] Registration failed (var='<empty>', reason=empty var name, entry=%1)", _entry];
        continue;
    };

    private _unit = missionNamespace getVariable [_varName, objNull];
    if (isNull _unit) then {
        _skipped = _skipped + 1;
        diag_log format ["[CIVSUB][EDITOR] Registration failed (var='%1', reason=unit not found in missionNamespace)", _varName];
        continue;
    };

    if !(alive _unit) then {
        _skipped = _skipped + 1;
        diag_log format ["[CIVSUB][EDITOR] Registration failed (var='%1', reason=unit not alive)", _varName];
        continue;
    };

    if !(side _unit isEqualTo civilian) then {
        _skipped = _skipped + 1;
        diag_log format ["[CIVSUB][EDITOR] Registration failed (var='%1', reason=unit side is not civilian)", _varName];
        continue;
    };

    private _districtId = "";
    if (_districtOverride isEqualType "" && { !(_districtOverride isEqualTo "") }) then {
        _districtId = _districtOverride;
    } else {
        _districtId = [getPosATL _unit] call ARC_fnc_civsubDistrictsFindByPos;
    };

    if (_districtId isEqualTo "") then {
        _skipped = _skipped + 1;
        diag_log format ["[CIVSUB][EDITOR] Registration failed (var='%1', reason=no district resolved)", _varName];
        continue;
    };

    private _reg = missionNamespace getVariable ["civsub_v1_civ_registry", createHashMap];
    if !(_reg isEqualType createHashMap) then { _reg = createHashMap; };

    private _key = netId _unit;
    if (_key isEqualTo "") then { _key = str _unit; };

    private _already = false;
    if !(_key isEqualTo "") then {
        private _row = [_reg, _key, createHashMap] call _hg;
        if (_row isEqualType createHashMap) then {
            private _existing = [_row, "unit", objNull] call _hg;
            _already = (!isNull _existing) && { _existing isEqualTo _unit };
        };
    };

    if (_already) then {
        _skipped = _skipped + 1;
        diag_log format ["[CIVSUB][EDITOR] Registration failed (var='%1', reason=duplicate already registered)", _varName];
        continue;
    };

    if (!([_unit, _districtId] call ARC_fnc_civsubCivAssignIdentity)) then {
        _skipped = _skipped + 1;
        diag_log format ["[CIVSUB][EDITOR] Registration failed (var='%1', reason=identity assignment failed)", _varName];
        continue;
    };

    private _regKey = [_unit, _districtId] call ARC_fnc_civsubCivRegisterSpawn;
    if (_regKey isEqualTo "") then {
        _skipped = _skipped + 1;
        diag_log format ["[CIVSUB][EDITOR] Registration failed (var='%1', reason=registry insert failed)", _varName];
        continue;
    };

    if (_pin) then {
        _unit setVariable ["civsub_v1_pinned", true, true];
        _unit setVariable ["civsub_v1_editorTestPinned", true, true];
    };

    _unit setVariable ["civsub_v1_editorTestCiv", true, true];
    _unit setVariable ["civsub_v1_editorVarName", _varName, true];

    _registered = _registered + 1;
    diag_log format ["[CIVSUB][EDITOR] Registered '%1' as CIVSUB civ (district=%2, pinned=%3)", _varName, _districtId, _pin];
} forEach _entries;

diag_log format ["[CIVSUB][EDITOR] Registration pass complete (registered=%1 skipped=%2 entries=%3)", _registered, _skipped, count _entries];

private _finalRegistry = missionNamespace getVariable ["civsub_v1_civ_registry", createHashMap];
private _finalKeys = [];
if (_finalRegistry isEqualType createHashMap) then {
    _finalKeys = [_finalRegistry] call _keysFn;
};
diag_log format ["[CIVSUB][EDITOR] Final registered unit keys: %1", _finalKeys];

[_registered, _skipped]
