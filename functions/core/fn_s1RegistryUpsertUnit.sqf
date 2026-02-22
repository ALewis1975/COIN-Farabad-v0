/*
    Server-owned S1 registry upsert for one unit/group record.

    Params:
      0: OBJECT - unit (optional; objNull allowed for virtual rows)
      1: GROUP  - group reference (optional; grpNull allowed when groupId passed in patch)
      2: ARRAY  - patch pairs that override normalized defaults (optional)
      3: BOOL   - publish snapshot after write (default true)

    Returns:
      ARRAY - normalized record (pairs) or [] on rejected write.
*/

params [
    ["_unit", objNull, [objNull]],
    ["_group", grpNull, [grpNull]],
    ["_patch", [], [[]]],
    ["_publish", true, [true]]
];

if (!isServer) exitWith { [] };

private _registry = missionNamespace getVariable ["ARC_s1_registry", []];
if !(_registry isEqualType []) then { _registry = []; };

private _groups = [];
private _units = [];
private _version = 1;
{
    private _k = _x param [0, ""];
    switch (_k) do {
        case "groups": { _groups = +(_x param [1, []]); };
        case "units": { _units = +(_x param [1, []]); };
        case "version": { _version = _x param [1, 1]; };
    };
} forEach _registry;

private _safeUnit = _unit;
if (isNull _safeUnit && {!isNull _group}) then
{
    private _members = units _group;
    if ((count _members) > 0) then { _safeUnit = _members # 0; };
};

private _resolvedGroup = _group;
if (isNull _resolvedGroup && {!isNull _safeUnit}) then { _resolvedGroup = group _safeUnit; };

private _groupId = "";
if (!isNull _resolvedGroup) then { _groupId = groupId _resolvedGroup; };
if (_groupId isEqualTo "") then {
    private _idxGroupId = _patch findIf { (_x isEqualType []) && {count _x >= 2} && {(_x # 0) isEqualTo "groupId"} };
    if (_idxGroupId >= 0) then { _groupId = ((_patch # _idxGroupId) param [1, ""]); };
};

private _unitId = "";
if (!isNull _safeUnit) then { _unitId = netId _safeUnit; };
if (_unitId isEqualTo "") then {
    private _idxUnitId = _patch findIf { (_x isEqualType []) && {count _x >= 2} && {(_x # 0) isEqualTo "unitId"} };
    if (_idxUnitId >= 0) then { _unitId = ((_patch # _idxUnitId) param [1, ""]); };
};
if (_unitId isEqualTo "") then { _unitId = format ["virtual:%1", diag_tickTime]; };

private _groupTokens = _groupId splitString "|";
private _orbatLeft = "";
private _callsign = "";
if ((count _groupTokens) > 0) then { _orbatLeft = trim (_groupTokens # 0); };
if ((count _groupTokens) > 1) then { _callsign = trim (_groupTokens # 1); };
if (_callsign isEqualTo "") then
{
    if (!isNull _resolvedGroup) then { _callsign = _resolvedGroup getVariable ["ARC_groupCallsign", ""]; };
};

private _leftTokens = _orbatLeft splitString "- ";
private _company = "";
if ((count _leftTokens) >= 3) then {
    private _candidate = _leftTokens # 2;
    if ((count _candidate) <= 2) then { _company = toUpper _candidate; };
};

private _parentEchelon = _orbatLeft;
if (_parentEchelon isEqualTo "") then { _parentEchelon = _groupId; };

private _role = "RIFLEMAN";
if (!isNull _safeUnit) then
{
    _role = toUpperANSI (typeOf _safeUnit);
    if ((toUpperANSI _role) find "LEADER" >= 0) then { _role = "LEADER"; };
};

private _locationAnchor = [];
if (!isNull _safeUnit) then { _locationAnchor = getPosATL _safeUnit; };

private _virtualStatus = "VIRTUAL";
private _readiness = 0;
if (!isNull _safeUnit) then
{
    if (alive _safeUnit) then {
        _virtualStatus = "ACTIVE";
        _readiness = 1;
        if (!(canMove _safeUnit)) then { _readiness = 0.5; };
    } else {
        _virtualStatus = "KIA";
        _readiness = 0;
    };
};

private _currentTaskId = "";
if (!isNull _safeUnit) then { _currentTaskId = _safeUnit getVariable ["ARC_currentTaskId", ""]; };

private _side = "Unknown";
if (!isNull _resolvedGroup) then { _side = str (side _resolvedGroup); };

private _groupRecord = [
    ["groupId", _groupId],
    ["callsign", _callsign],
    ["parentEchelon", _parentEchelon],
    ["company", _company],
    ["side", _side],
    ["composition", if (!isNull _resolvedGroup) then { (units _resolvedGroup) apply { typeOf _x } } else { [] }],
    ["lastUpdate", serverTime],
    ["source", "docs/reference/unit-index.json+Farabad_ORBAT" ]
];

private _unitRecord = [
    ["unitId", _unitId],
    ["groupId", _groupId],
    ["callsign", _callsign],
    ["parentEchelon", _parentEchelon],
    ["company", _company],
    ["role", _role],
    ["virtualStatus", _virtualStatus],
    ["locationAnchor", _locationAnchor],
    ["lastUpdate", serverTime],
    ["currentTaskId", _currentTaskId],
    ["readiness", _readiness],
    ["source", "docs/reference/unit-index.json+Farabad_ORBAT"]
];

{
    private _k = _x param [0, ""];
    private _v = _x param [1, nil];
    if (_k isNotEqualTo "") then
    {
        private _gIdx = _groupRecord findIf { (_x param [0, ""]) isEqualTo _k };
        if (_gIdx >= 0) then { (_groupRecord # _gIdx) set [1, _v]; } else { _groupRecord pushBack [_k, _v]; };

        private _uIdx = _unitRecord findIf { (_x param [0, ""]) isEqualTo _k };
        if (_uIdx >= 0) then { (_unitRecord # _uIdx) set [1, _v]; } else { _unitRecord pushBack [_k, _v]; };
    };
} forEach _patch;

private _groupIdx = _groups findIf {
    private _gidIdx = _x findIf { (_x param [0, ""]) isEqualTo "groupId" };
    (_gidIdx >= 0) && { ((_x # _gidIdx) param [1, ""]) isEqualTo _groupId }
};
if (_groupIdx >= 0) then { _groups set [_groupIdx, _groupRecord]; } else { _groups pushBack _groupRecord; };

private _unitIdx = _units findIf {
    private _uidIdx = _x findIf { (_x param [0, ""]) isEqualTo "unitId" };
    (_uidIdx >= 0) && { ((_x # _uidIdx) param [1, ""]) isEqualTo _unitId }
};
if (_unitIdx >= 0) then { _units set [_unitIdx, _unitRecord]; } else { _units pushBack _unitRecord; };

private _updatedAt = serverTime;
private _newRegistry = [
    ["version", _version],
    ["updatedAt", _updatedAt],
    ["groups", _groups],
    ["units", _units]
];

missionNamespace setVariable ["ARC_s1_registry", _newRegistry];
if (_publish) then { [] call ARC_fnc_s1RegistrySnapshot; };

_unitRecord
