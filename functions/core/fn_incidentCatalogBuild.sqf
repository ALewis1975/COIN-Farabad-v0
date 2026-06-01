/*
    ARC_fnc_incidentCatalogBuild

    Returns the legacy incident marker catalog plus structured COIN civic mission
    records expanded to normal incident rows:
      [markerName, displayName, incidentType, missionMeta]

    Existing consumers that only read the first three fields remain compatible.
*/

private _catalog = [];
private _basePath = "data\incident_markers.sqf";
if (fileExists _basePath) then
{
    private _base = call compile preprocessFileLineNumbers _basePath;
    if (_base isEqualType []) then { _catalog append _base; };
};

private _civicPath = "data\coin_civic_mission_catalog.sqf";
if !(fileExists _civicPath) exitWith { _catalog };

private _records = call compile preprocessFileLineNumbers _civicPath;
if (!(_records isEqualType [])) exitWith { _catalog };

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _trimFn = compile "params ['_s']; trim _s";

private _siteMarkerMap = missionNamespace getVariable ["ARC_worldTerrainSiteMarkers", createHashMap];
if (!(_siteMarkerMap isEqualType createHashMap)) then { _siteMarkerMap = createHashMap; };

private _districtDefaults = createHashMap;
private _getDistrict = {
    params ["_did"];

    private _d = createHashMap;
    if (!isNil "ARC_fnc_civsubDistrictsGetById") then
    {
        _d = [_did] call ARC_fnc_civsubDistrictsGetById;
    };

    if ((!(_d isEqualType createHashMap) || { (count _d) == 0 }) && { !isNil "ARC_fnc_civsubDistrictsCreateDefaults" }) then
    {
        if ((count _districtDefaults) == 0) then { _districtDefaults = call ARC_fnc_civsubDistrictsCreateDefaults; };
        if (_districtDefaults isEqualType createHashMap) then { _d = _districtDefaults getOrDefault [_did, createHashMap]; };
    };

    if (!(_d isEqualType createHashMap)) then { createHashMap } else { _d }
};

private _makeDistrictMarker = {
    params ["_did"];

    _did = toUpper ([_did] call _trimFn);
    if (_did isEqualTo "") exitWith { "" };

    private _d = [_did] call _getDistrict;
    if (!(_d isEqualType createHashMap) || { (count _d) == 0 }) exitWith { "" };

    private _centroid = [_d, "centroid", []] call _hg;
    if (!(_centroid isEqualType []) || { (count _centroid) < 2 }) exitWith { "" };

    private _pos = +_centroid;
    _pos resize 3;
    if (!((_pos select 2) isEqualType 0)) then { _pos set [2, 0]; };

    private _mk = format ["ARC_civloc_%1", _did];
    if (!(_mk in allMapMarkers)) then
    {
        createMarker [_mk, _pos];
        _mk setMarkerShape "ICON";
        _mk setMarkerType "mil_dot";
        _mk setMarkerAlpha 0;
    };
    _mk setMarkerPos _pos;
    _mk
};

private _pushRow = {
    params ["_marker", "_display", "_type", "_meta"];

    _marker = [_marker] call _trimFn;
    _display = [_display] call _trimFn;
    _type = toUpper ([_type] call _trimFn);
    if (_marker isEqualTo "" || { _display isEqualTo "" } || { _type isEqualTo "" }) exitWith {};

    _catalog pushBack [_marker, _display, _type, _meta];
};

{
    if (!(_x isEqualType [])) then { continue; };
    private _rec = [_x] call _hmCreate;
    if (!(_rec isEqualType createHashMap)) then { continue; };

    private _id = [_rec, "id", ""] call _hg;
    private _missionSet = [_rec, "missionSet", ""] call _hg;
    private _subtype = [_rec, "subtype", ""] call _hg;
    private _incidentType = [_rec, "incidentType", "CIVIL"] call _hg;
    private _displayName = [_rec, "displayName", ""] call _hg;
    private _locations = [_rec, "locations", []] call _hg;
    private _siteTypes = [_rec, "siteTypes", []] call _hg;
    private _districts = [_rec, "districts", []] call _hg;
    private _civsubFactors = [_rec, "civsubFactors", []] call _hg;
    private _endState = [_rec, "endState", ""] call _hg;
    private _threatHooks = [_rec, "threatHooks", []] call _hg;
    private _outcomeDeltas = [_rec, "outcomeDeltas", []] call _hg;

    if (!(_locations isEqualType [])) then { _locations = []; };
    if (!(_siteTypes isEqualType [])) then { _siteTypes = []; };
    if (!(_districts isEqualType [])) then { _districts = []; };

    private _baseMeta = [
        ["catalog", "COIN_CIVIC"],
        ["catalogId", _id],
        ["missionSet", _missionSet],
        ["subtype", _subtype],
        ["endState", _endState],
        ["civsubFactors", _civsubFactors],
        ["threatHooks", _threatHooks],
        ["outcomeDeltas", _outcomeDeltas]
    ];

    {
        if (!(_x isEqualType "")) then { continue; };
        private _meta = +_baseMeta;
        _meta pushBack ["sourceKind", "LOCATION"];
        _meta pushBack ["sourceRef", _x];
        [_x, _displayName, _incidentType, _meta] call _pushRow;
    } forEach _locations;

    {
        if (!(_x isEqualType "")) then { continue; };
        private _siteType = toUpper ([_x] call _trimFn);
        private _markers = [_siteMarkerMap, _siteType, []] call _hg;
        if (!(_markers isEqualType [])) then { _markers = []; };
        {
            if (!(_x isEqualType "")) then { continue; };
            private _meta = +_baseMeta;
            _meta pushBack ["sourceKind", "TERRAIN_SITE"];
            _meta pushBack ["sourceRef", _siteType];
            [_x, format ["%1 (%2)", _displayName, _siteType], _incidentType, _meta] call _pushRow;
        } forEach _markers;
    } forEach _siteTypes;

    {
        if (!(_x isEqualType "")) then { continue; };
        private _did = toUpper ([_x] call _trimFn);
        private _mk = [_did] call _makeDistrictMarker;
        if (_mk isEqualTo "") then { continue; };
        private _meta = +_baseMeta;
        _meta pushBack ["sourceKind", "CIVSUB_DISTRICT"];
        _meta pushBack ["sourceRef", _did];
        _meta pushBack ["districtId", _did];
        [_mk, format ["%1 — %2", _displayName, _did], _incidentType, _meta] call _pushRow;
    } forEach _districts;
} forEach _records;

_catalog
