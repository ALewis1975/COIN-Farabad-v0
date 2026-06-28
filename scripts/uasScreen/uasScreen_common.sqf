/*
    Farabad UAS Screen Feed - shared helpers.

    Runtime-only subsystem:
    - server owns the selected screen->UAV feed snapshot
    - clients render local PiP cameras from that explicit snapshot
    - no persistence; JIP reconstructs from public missionNamespace snapshot
*/

ARC_fnc_uasScreenEnsureDefaults = {
    if (!isServer) exitWith {true};

    private _setDefault = {
        params ["_key", "_value", ["_public", false]];
        if (isNil { missionNamespace getVariable _key }) then
        {
            missionNamespace setVariable [_key, _value, _public];
        };
    };

    ["ARC_uasScreenEnabled", true, isServer] call _setDefault;
    ["ARC_uasScreenObjectVarNames", [
        "ARC_toc_screen_4",
        "ARC_toc_screen_5",
        "ARC_toc_screen_1",
        "ARC_toc_screen_2",
        "ARC_toc_screen_3",
        "ARC_toc_air_1",
        "ARC_toc_air_2",
        "ARC_toc_FSE",
        "ARC_toc_intel_1",
        "ARC_toc_intel_2",
        "ARC_toc_ops_1",
        "ARC_toc_ops_2",
        "ARC_toc_ops_3",
        "ARC_toc_ops_4",
        "ARC_toc_ops_5",
        "ARC_toc_UAS_1",
        "ARC_toc_XO"
    ], isServer] call _setDefault;

    ["ARC_uasScreenRequireAuthorizedRole", false, isServer] call _setDefault;
    ["ARC_uasScreenAllowedSides", ["WEST"], isServer] call _setDefault;
    ["ARC_uasScreenFilterActiveAO", false, isServer] call _setDefault;
    ["ARC_uasScreenActiveAORadiusM", 6000, isServer] call _setDefault;
    ["ARC_uasScreenTextureSelection", 0, isServer] call _setDefault;
    ["ARC_uasScreenCameraMode", "NADIR", isServer] call _setDefault;
    ["ARC_uasScreenCameraOffset", [0,0,-1], isServer] call _setDefault;
    ["ARC_uasScreenCameraFov", 0.55, isServer] call _setDefault;
    ["ARC_uasScreenIdleTexture", "#(argb,8,8,3)color(0,0,0,1)", isServer] call _setDefault;

    true
};

ARC_fnc_uasScreenResolveManagedScreens = {
    [] call ARC_fnc_uasScreenEnsureDefaults;

    private _names = missionNamespace getVariable ["ARC_uasScreenObjectVarNames", []];
    if (!(_names isEqualType [])) then { _names = []; };

    private _objects = [];
    {
        if (!(_x isEqualType "")) then { continue; };

        private _name = _x;
        private _obj = missionNamespace getVariable [_name, objNull];

        if (isNull _obj) then
        {
            private _needle = toLower _name;
            {
                if ((toLower (vehicleVarName _x)) isEqualTo _needle) exitWith { _obj = _x; };
            } forEach (allMissionObjects "All");

            if (!isNull _obj) then
            {
                missionNamespace setVariable [_name, _obj, false];
            };
        };

        if (!isNull _obj) then { _objects pushBackUnique _obj; };
    } forEach _names;

    _objects
};

ARC_fnc_uasScreenIsManaged = {
    params [["_obj", objNull, [objNull]]];
    if (isNull _obj) exitWith {false};

    [] call ARC_fnc_uasScreenEnsureDefaults;
    private _names = missionNamespace getVariable ["ARC_uasScreenObjectVarNames", []];
    if (!(_names isEqualType [])) then { _names = []; };

    private _varName = toLower (vehicleVarName _obj);
    private _managed = false;

    {
        if (!(_x isEqualType "")) then { continue; };
        private _name = _x;
        if (_varName != "" && { (toLower _name) isEqualTo _varName }) exitWith { _managed = true; };

        private _namedObj = missionNamespace getVariable [_name, objNull];
        if (!isNull _namedObj && { _namedObj isEqualTo _obj }) exitWith { _managed = true; };
    } forEach _names;

    _managed
};

ARC_fnc_uasScreenGetActiveUavs = {
    [] call ARC_fnc_uasScreenEnsureDefaults;

    private _allowed = missionNamespace getVariable ["ARC_uasScreenAllowedSides", ["WEST"]];
    if (!(_allowed isEqualType [])) then { _allowed = ["WEST"]; };

    private _allowedU = [];
    {
        if (_x isEqualType "") then { _allowedU pushBackUnique (toUpper _x); };
    } forEach _allowed;

    private _uavs = [];
    {
        private _veh = _x;
        if (isNull _veh || {!alive _veh}) then { continue; };

        private _cfg = configFile >> "CfgVehicles" >> typeOf _veh;
        private _isUav = (getNumber (_cfg >> "isUav")) > 0;
        if (!_isUav) then { continue; };

        private _crew = crew _veh;
        private _sideStr = "";
        if ((count _crew) > 0) then
        {
            _sideStr = toUpper str (side (group (_crew select 0)));
        }
        else
        {
            _sideStr = toUpper str (side _veh);
        };

        if ((count _allowedU) > 0 && {!(_sideStr in _allowedU)}) then { continue; };
        _uavs pushBackUnique _veh;
    } forEach vehicles;

    if (missionNamespace getVariable ["ARC_uasScreenFilterActiveAO", false]) then
    {
        private _center = missionNamespace getVariable ["ARC_activeIncidentPos", []];
        if (_center isEqualType [] && { (count _center) >= 2 }) then
        {
            private _radius = missionNamespace getVariable ["ARC_activeExecRadius", missionNamespace getVariable ["ARC_uasScreenActiveAORadiusM", 6000]];
            if (!(_radius isEqualType 0)) then { _radius = missionNamespace getVariable ["ARC_uasScreenActiveAORadiusM", 6000]; };
            _radius = (_radius max 100) min 15000;
            _uavs = _uavs select { (_x distance2D _center) <= _radius };
        };
    };

    _uavs
};

ARC_fnc_uasScreenLabel = {
    params [["_uav", objNull, [objNull]]];
    if (isNull _uav) exitWith {"UNKNOWN UAV"};

    private _name = vehicleVarName _uav;
    private _display = getText (configFile >> "CfgVehicles" >> typeOf _uav >> "displayName");
    if (_display isEqualTo "") then { _display = typeOf _uav; };

    private _crew = crew _uav;
    private _groupId = "";
    if ((count _crew) > 0) then
    {
        _groupId = groupId (group (_crew select 0));
    };

    private _base = _display;
    if (_groupId != "") then { _base = _groupId; };
    if (_name != "") then { _base = _name; };

    format ["%1 GR %2", _base, mapGridPosition _uav]
};

ARC_fnc_uasScreenFindRecordIndex = {
    params [["_snapshot", [], [[]]], ["_screenNid", "", [""]]];

    private _idx = -1;
    {
        if (_x isEqualType [] && { (_x param [0, ""]) isEqualTo _screenNid }) exitWith
        {
            _idx = _forEachIndex;
        };
    } forEach _snapshot;

    _idx
};

true
