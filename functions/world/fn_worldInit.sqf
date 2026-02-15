/*
    World reference initialization.

    - Loads named locations for Farabad from data\farabad_world_locations.sqf
    - Creates hidden reference markers: ARC_loc_<id>
    - Loads world zones from data\farabad_world_zones.sqf
      and creates hidden rectangle markers: ARC_zone_<id>
    - Loads marker alias map from data\farabad_marker_aliases.sqf

    This gives us a stable reference layer that survives marker cleanup in Eden.
*/

if (!isServer) exitWith {false};

// Marker alias map (legacy -> canonical)
private _aliases = call compile preprocessFileLineNumbers "data\farabad_marker_aliases.sqf";
if (_aliases isEqualType createHashMap) then
{
    missionNamespace setVariable ["ARC_markerAliases", _aliases, true];
}
else
{
    missionNamespace setVariable ["ARC_markerAliases", createHashMap, true];
};

// Named locations + terrain sites
private _locData = call compile preprocessFileLineNumbers "data\farabad_world_locations.sqf";
if (!(_locData isEqualType [])) exitWith {false};
_locData params ["_namedLocations", "_terrainSites"];

missionNamespace setVariable ["ARC_worldNamedLocations", _namedLocations, true];
missionNamespace setVariable ["ARC_worldTerrainSites", _terrainSites, true];

{
    _x params ["_id", "_displayName", "_pos"];

    private _mName = format ["ARC_loc_%1", _id];

	if (!(_mName in allMapMarkers)) then
    {
        createMarker [_mName, _pos];
    }
    else
    {
        _mName setMarkerPos _pos;
    };

    _mName setMarkerType "Empty";
    _mName setMarkerText _displayName;
    _mName setMarkerAlpha 0; // keep hidden by default
} forEach _namedLocations;

// World zones
private _zones = call compile preprocessFileLineNumbers "data\farabad_world_zones.sqf";
if (_zones isEqualType []) then
{
    missionNamespace setVariable ["ARC_worldZones", _zones, true];

    {
        _x params ["_id", "_displayName", "_center", "_halfExtents", "_dir"];

        private _zName = format ["ARC_zone_%1", _id];

		if (!(_zName in allMapMarkers)) then
        {
            createMarker [_zName, _center];
        }
        else
        {
            _zName setMarkerPos _center;
        };

        _zName setMarkerShape "RECTANGLE";
        _zName setMarkerSize _halfExtents;
        _zName setMarkerDir _dir;
        _zName setMarkerBrush "SolidBorder";
        _zName setMarkerColor "ColorYellow";
        _zName setMarkerText _displayName;
        _zName setMarkerAlpha 0; // hidden by default
    } forEach _zones;
};

true
