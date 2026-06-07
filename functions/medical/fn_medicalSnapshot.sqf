/*
    ARC_fnc_medicalSnapshot

    Server-only: build a medical section snapshot suitable for inclusion in
    ARC_pub_state or the Console VM v1 stateSummary section.

    Returns: ARRAY of [key, value] pairs, or [] on failure
*/

if (!isServer) exitWith {[]};

private _baseMed = ["baseMed", 0.57] call ARC_fnc_stateGet;
if (!(_baseMed isEqualType 0)) then { _baseMed = 0.57; };
_baseMed = (_baseMed max 0) min 1;

private _civCas = ["civCasualties", 0] call ARC_fnc_stateGet;
if (!(_civCas isEqualType 0)) then { _civCas = 0; };
_civCas = _civCas max 0;

private _bCas = ["baseCasualties", 0] call ARC_fnc_stateGet;
if (!(_bCas isEqualType 0)) then { _bCas = 0; };
_bCas = _bCas max 0;

private _critical = missionNamespace getVariable ["ARC_medCriticalThreshold", 0.18];
if (!(_critical isEqualType 0)) then { _critical = 0.18; };

private _pairGet = {
    params ["_pairs", "_key", "_def"];
    private _out = _def;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _out = _x select 1; }; } forEach _pairs;
    _out
};
private _baseServices = if (!isNil "ARC_fnc_baseServicesSnapshot") then { [] call ARC_fnc_baseServicesSnapshot } else { ["baseServices_v1_snapshot", []] call ARC_fnc_stateGet };
if (!(_baseServices isEqualType [])) then { _baseServices = []; };
private _medicalEffective = [_baseServices, "medicalEffective", _baseMed] call _pairGet;
if (!(_medicalEffective isEqualType 0)) then { _medicalEffective = _baseMed; };
_medicalEffective = (_medicalEffective max 0) min 1;

[
    ["base_med",           _baseMed],
    ["base_med_effective", _medicalEffective],
    ["civ_casualties",     _civCas],
    ["base_casualties",    _bCas],
    ["critical_threshold", _critical],
    ["is_critical",        _medicalEffective < _critical],
    ["base_services",      _baseServices]
]
