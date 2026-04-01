/*
    ARC_fnc_districtMarkersUpdate

    Server-side: create or update per-district map markers reflecting the
    dominant influence axis (RED / WHITE / GREEN) for each CIVSUB district.

    Markers are named ARC_district_<districtId>_influence and are replicated to
    all clients on each broadcast cycle. Only runs when CIVSUB is enabled.

    Marker colour mapping:
      RED dominant (R >= W && R >= G && R > 45): ColorRed
      GREEN dominant (G >= R && G >= W && G > 45): ColorGreen
      WHITE dominant / contested:                 ColorWhite

    Called from ARC_fnc_publicBroadcastState after the state publish.

    Returns:
      NUMBER — count of markers updated
*/

if (!isServer) exitWith {0};

if (!(missionNamespace getVariable ["civsub_v1_enabled", false])) exitWith {0};

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if (!(_districts isEqualType createHashMap)) exitWith {0};
if (_districts isEqualTo createHashMap) exitWith {0};

private _updated = 0;
private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

private _getScore = {
    params ["_d", "_key", "_default"];
    private _v = _d getOrDefault [_key, _default];
    if (!(_v isEqualType 0)) then { _v = _default; };
    (_v max 0) min 100
};

{
    private _districtId = _x;
    private _d = _y;
    if !(_d isEqualType createHashMap) then { continue; };

    private _scoreR = [_d, "R", 35] call _getScore;
    private _scoreG = [_d, "G", 35] call _getScore;
    private _scoreW = [_d, "W", 30] call _getScore;

    // Dominant axis
    private _color = "ColorWhite";
    if (_scoreR >= _scoreG && { _scoreR >= _scoreW } && { _scoreR > 45 }) then { _color = "ColorRed"; };
    if (_scoreG >= _scoreR && { _scoreG >= _scoreW } && { _scoreG > 45 } && { _color isEqualTo "ColorWhite" }) then { _color = "ColorGreen"; };

    // Centroid (stored as [x,y] or [x,y,z])
    private _cent = _d getOrDefault ["centroid", []];
    if (!(_cent isEqualType []) || { (count _cent) < 2 }) then { continue; };
    private _pos2 = [_cent # 0, _cent # 1];

    private _mkName = format ["ARC_district_%1_influence", _districtId];

    if !(_mkName in allMapMarkers) then
    {
        createMarker [_mkName, _pos2];
    }
    else
    {
        _mkName setMarkerPos _pos2;
    };

    _mkName setMarkerShape "ELLIPSE";
    _mkName setMarkerBrush "SolidBorder";
    _mkName setMarkerColor _color;
    _mkName setMarkerAlpha 0.18;

    private _radius = _d getOrDefault ["radius_m", 400];
    if (!(_radius isEqualType 0)) then { _radius = 400; };
    _radius = (_radius max 100) min 3000;
    _mkName setMarkerSize [_radius, _radius];

    private _labelR = round _scoreR;
    private _labelG = round _scoreG;
    private _labelW = round _scoreW;
    _mkName setMarkerText format ["%1 R:%2 G:%3 W:%4", _districtId, _labelR, _labelG, _labelW];

    _updated = _updated + 1;
} forEach _districts;

if (_updated > 0) then
{
    diag_log format ["[ARC][INFO] ARC_fnc_districtMarkersUpdate: updated %1 district influence markers.", _updated];
};

_updated
