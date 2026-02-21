/*
    Registers Farabad world locations and terrain sites as hidden global markers.

    Data source: data\farabad_world_locations.sqf

    Markers created (global, server-created):
      - ARC_loc_<LocationId>
      - ARC_site_<SiteType>_<NN>

    Cached variables (missionNamespace):
      - ARC_worldNamedLocations: original named location array
      - ARC_worldNamedLocationMarkers: hash map id -> [markerName, displayName, position]
      - ARC_worldTerrainSites: hash map siteType -> [positions]
      - ARC_worldTerrainSiteMarkers: hash map siteType -> [markerNames]

    Debug:
      Set missionNamespace var ARC_debugWorldMarkers = true to show markers.
*/

if (!isServer) exitWith {false};

// sqflint-compat helpers
private _fileExFn   = compile "params ['_p']; fileExists _p";

private _path = "data\farabad_world_locations.sqf";

// Load the exported locations/sites list. Use fileExists + diag_log so missing
// data files don't cause confusing follow-on errors.
private _data = [];
if ([_path] call _fileExFn) then {
    _data = call compile preprocessFileLineNumbers _path;
} else {
    diag_log format ["[ARC][worldRegisterLocations] Missing file: %1", _path];
};

if (!(_data isEqualType [])) exitWith {
    diag_log "[ARC][worldRegisterLocations] Data file did not return an array.";
    false
};

if ((count _data) < 2) exitWith {
    diag_log "[ARC][worldRegisterLocations] Data array incomplete (expected [named, sites]).";
    false
};

_data params ["_named", "_sites"]; // arrays

private _debug = missionNamespace getVariable ["ARC_debugWorldMarkers", false];
private _alpha = if (_debug) then {0.6} else {0};

	// --- named locations ---------------------------------------------------------
	private _namedMarkers = createHashMap;
	{
	    _x params ["_id", "_disp", "_pos"];
	
	    private _mName = format ["ARC_loc_%1", _id];
	
	    // createMarker is ignored if the name already exists; this keeps the logic simple
	    // and avoids relying on marker existence helpers.
	    createMarker [_mName, _pos];
	    _mName setMarkerShape "ICON";
	    _mName setMarkerType "mil_dot";
	    _mName setMarkerPos _pos;
	    _mName setMarkerAlpha _alpha;
	    if (_debug) then { _mName setMarkerText _disp; } else { _mName setMarkerText ""; };
	
	    _namedMarkers set [_id, [_mName, _disp, _pos]];
	} forEach _named;

// --- terrain sites -----------------------------------------------------------
private _sitePosMap = createHashMap;
private _siteMarkerMap = createHashMap;

{
    _x params ["_siteType", "_positions"]; // _positions is [ [x,y,z], ... ]

    _sitePosMap set [_siteType, _positions];

    private _markerNames = [];
    private _i = 0;
	    {
	        _i = _i + 1;
	        private _mName = format ["ARC_site_%1_%2", _siteType, str _i];
	
	        createMarker [_mName, _x];
	        _mName setMarkerShape "ICON";
	        _mName setMarkerType "mil_triangle";
	        _mName setMarkerPos _x;
	        _mName setMarkerAlpha _alpha;
	        if (_debug) then { _mName setMarkerText _siteType; } else { _mName setMarkerText ""; };
	
	        _markerNames pushBack _mName;
	    } forEach _positions;

    _siteMarkerMap set [_siteType, _markerNames];
} forEach _sites;

missionNamespace setVariable ["ARC_worldNamedLocations", _named, true];
missionNamespace setVariable ["ARC_worldNamedLocationMarkers", _namedMarkers, true];
missionNamespace setVariable ["ARC_worldTerrainSites", _sitePosMap, true];
missionNamespace setVariable ["ARC_worldTerrainSiteMarkers", _siteMarkerMap, true];

true
