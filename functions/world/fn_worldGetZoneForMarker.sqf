/*
    Convenience wrapper: returns the zone id for a marker.

    Params:
        0: STRING - marker name (canonical or legacy)

    Returns:
        STRING - zone id, or "" if none/invalid.
*/

params ["_markerName"];

private _m = [_markerName] call ARC_fnc_worldResolveMarker;
if (_m isEqualTo "" || { !(_m in allMapMarkers) }) exitWith {""};

[markerPos _m] call ARC_fnc_worldGetZoneForPos
