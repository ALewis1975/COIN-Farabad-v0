/*
    Farabad world zones.
    Each entry: [id, displayName, centerPos2D, sizeHalfExtents, dir]

    sizeHalfExtents: [halfWidth, halfHeight] in meters for RECTANGLE markers.
*/

private _zones = [
    ["Airbase", "Farabad Airbase", [6117.955, 2280.710], [650, 525], 89.864],
    ["GreenZone", "Green Zone", [5104.140, 4948.940], [287.5, 150], 113],
    // Broad city footprint (used in addition to quadrant zones). Adjust size/dir as the mission evolves.
    ["FarabadCity", "Farabad City", [4507.911, 5144.383], [1200, 900], 0]
];

// Additional quadrant zone markers (added in-editor):
// arc_zone_NorthWest / NorthEast / SouthWest / SouthEast
private _quadrantDefs = [
    ["NorthWest", "NW Sector", "arc_zone_NorthWest"],
    ["NorthEast", "NE Sector", "arc_zone_NorthEast"],
    ["SouthWest", "SW Sector", "arc_zone_SouthWest"],
    ["SouthEast", "SE Sector", "arc_zone_SouthEast"]
];

{
    _x params ["_id", "_name", "_mkr"];

    if (_mkr in allMapMarkers) then
    {
        private _c = getMarkerPos _mkr;
        private _sz = getMarkerSize _mkr;
        private _dir = markerDir _mkr;

        // Push after the more-specific Airbase/GreenZone/City, so those override when overlapping.
        _zones pushBack [_id, _name, [_c # 0, _c # 1], [_sz # 0, _sz # 1], _dir];
    };
} forEach _quadrantDefs;

_zones
