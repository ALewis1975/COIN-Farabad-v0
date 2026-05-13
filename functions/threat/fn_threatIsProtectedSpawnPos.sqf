/*
    ARC_fnc_threatIsProtectedSpawnPos

    Server-side helper for hostile spawn/materialization guards.
    Returns true when a position is inside a protected world zone or within a
    protected marker-radius bubble such as the Farabad airbase boundary.
*/

if (!isServer) exitWith {false};

params [
    ["_pos", [], [[]]],
    ["_protectedZones", [], [[]]],
    ["_protectedMarkers", [], [[]]]
];

if (!(_pos isEqualType []) || {(count _pos) < 2}) exitWith {false};

if ((count _protectedZones) == 0) then {
    _protectedZones = missionNamespace getVariable ["ARC_threatVirtualProtectedZones", ["Airbase", "GreenZone", "MilitaryBase"]];
    if (!(_protectedZones isEqualType [])) then { _protectedZones = ["Airbase", "GreenZone", "MilitaryBase"]; };
};

private _defaultProtectedMarkers = [["mkr_airbaseCenter", missionNamespace getVariable ["ARC_airbase_dynamic_radius_m", 1600]]];
if ((count _protectedMarkers) == 0) then {
    _protectedMarkers = missionNamespace getVariable ["ARC_threatProtectedSpawnMarkers", _defaultProtectedMarkers];
    if (!(_protectedMarkers isEqualType [])) then {
        _protectedMarkers = _defaultProtectedMarkers;
    };
};

private _zone = [_pos] call ARC_fnc_worldGetZoneForPos;
if (_zone in _protectedZones) exitWith {true};

private _protected = false;
{
    if (!(_x isEqualType []) || {(count _x) < 2}) then { continue; };
    private _markerName = _x select 0;
    private _radiusM = _x select 1;
    if (!(_markerName isEqualType "") || {!(_radiusM isEqualType 0)} || {_radiusM <= 0}) then { continue; };

    private _resolvedMarker = _markerName;
    if (!isNil "ARC_fnc_worldResolveMarker") then {
        _resolvedMarker = [_markerName] call ARC_fnc_worldResolveMarker;
    };
    if (!(_resolvedMarker in allMapMarkers)) then {
        private _warnedMarkers = missionNamespace getVariable ["ARC_threatProtectedMarkerWarned", []];
        if (!(_warnedMarkers isEqualType [])) then { _warnedMarkers = []; };
        if (!(_markerName in _warnedMarkers)) then {
            diag_log format ["[ARC][VPOOL][WARN] ARC_fnc_threatIsProtectedSpawnPos: protected marker unavailable marker=%1 resolved=%2", _markerName, _resolvedMarker];
            _warnedMarkers pushBack _markerName;
            missionNamespace setVariable ["ARC_threatProtectedMarkerWarned", _warnedMarkers, false];
        };
        continue;
    };

    if ((_pos distance2D (getMarkerPos _resolvedMarker)) <= _radiusM) exitWith {
        _protected = true;
    };
} forEach _protectedMarkers;

_protected
