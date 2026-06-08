/*
    ARC_fnc_intelLeadCreateCoupled

    Creates a lead after coupling its strength and metadata to district trust,
    intimidation, and stability.

    Params mirror ARC_fnc_leadCreate, with district/source context appended:
      0-10: ARC_fnc_leadCreate params
      11: STRING districtId
      12: STRING sourceType
      13: ARRAY context pairs

    Returns:
      STRING leadId
*/

if (!isServer) exitWith {""};

params [
    ["_leadType", "", [""]],
    ["_displayName", "", [""]],
    ["_pos", [], [[]]],
    ["_baseStrength", 0.5, [0]],
    ["_expiresIn", 3600, [0]],
    ["_sourceTaskId", "", [""]],
    ["_sourceIncidentType", "", [""]],
    ["_threadId", "", [""]],
    ["_tag", "", [""]],
    ["_missionMeta", [], [[]]],
    ["_origin", "FIELD", [""]],
    ["_districtId", "D00", [""]],
    ["_sourceType", "UNKNOWN", [""]],
    ["_context", [], [[]]]
];

private _pget = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith { _default };
    private _out = _default;
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith
        {
            _out = _x select 1;
        };
    } forEach _pairs;
    _out
};

private _setPair = {
    params ["_pairs", "_key", "_value"];
    if (!(_pairs isEqualType [])) then { _pairs = []; };
    private _idx = -1;
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _idx = _forEachIndex; };
    } forEach _pairs;
    if (_idx < 0) then { _pairs pushBack [_key, _value]; } else { _pairs set [_idx, [_key, _value]]; };
    _pairs
};

if (isNil "ARC_fnc_intelQualityCouple") then
{
    ARC_fnc_intelQualityCouple = compile preprocessFileLineNumbers "functions\\intel\\fn_intelQualityCouple.sqf";
};

if (!(_missionMeta isEqualType [])) then { _missionMeta = []; };
if (!(_context isEqualType [])) then { _context = []; };

private _coupling = [_districtId, _baseStrength, _sourceType, _tag, _context] call ARC_fnc_intelQualityCouple;
if (!(_coupling isEqualType [])) then { _coupling = []; };

private _quality = [_coupling, "quality", _baseStrength] call _pget;
if (!(_quality isEqualType 0)) then { _quality = _baseStrength; };
_quality = (_quality max 0) min 1;

private _confidenceBand = [_coupling, "confidence_band", "UNKNOWN"] call _pget;
if (!(_confidenceBand isEqualType "")) then { _confidenceBand = "UNKNOWN"; };

private _precision = [_coupling, "precision", "UNKNOWN"] call _pget;
if (!(_precision isEqualType "")) then { _precision = "UNKNOWN"; };

private _timeliness = [_coupling, "timeliness", "UNKNOWN"] call _pget;
if (!(_timeliness isEqualType "")) then { _timeliness = "UNKNOWN"; };

_missionMeta = [_missionMeta, "intel_quality", _quality] call _setPair;
_missionMeta = [_missionMeta, "intel_confidence_band", _confidenceBand] call _setPair;
_missionMeta = [_missionMeta, "intel_precision", _precision] call _setPair;
_missionMeta = [_missionMeta, "intel_timeliness", _timeliness] call _setPair;
_missionMeta = [_missionMeta, "intel_quality_coupling", _coupling] call _setPair;
_missionMeta = [_missionMeta, "district_id", _districtId] call _setPair;

[
    _leadType,
    _displayName,
    _pos,
    _quality,
    _expiresIn,
    _sourceTaskId,
    _sourceIncidentType,
    _threadId,
    _tag,
    _missionMeta,
    _origin
] call ARC_fnc_leadCreate
