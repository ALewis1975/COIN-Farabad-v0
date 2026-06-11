/*
    ARC_fnc_districtMarkersUpdate

    Server-side: create or update per-district map markers reflecting the
    dominant influence axis (RED / WHITE / GREEN) for each CIVSUB district.

    Markers are named ARC_district_<districtId>_influence. Only runs when
    CIVSUB is enabled.

    Perf: every global setMarker* command is a network message to every client.
    A server-local signature cache (ARC_districtMarkersApplied) suppresses
    re-sends when a district's marker visuals have not changed since the last
    broadcast, so steady-state broadcasts cost zero marker traffic.

    Marker colour mapping:
      RED dominant (R >= W && R >= G && R > 45): ColorRed
      GREEN dominant (G >= R && G >= W && G > 45): ColorGreen
      WHITE dominant / contested:                 ColorWhite

    Called from ARC_fnc_publicBroadcastState after the state publish.

    Returns:
      NUMBER — count of markers actually created/updated this call
*/

if (!isServer) exitWith {0};

if (!(missionNamespace getVariable ["civsub_v1_enabled", false])) exitWith {0};

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if (!(_districts isEqualType createHashMap)) exitWith {0};
if (_districts isEqualTo createHashMap) exitWith {0};

private _updated = 0;
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k,_d]";

// Server-local cache of last-applied marker signatures (districtId -> signature).
private _applied = missionNamespace getVariable ["ARC_districtMarkersApplied", createHashMap];
if (!(_applied isEqualType createHashMap)) then { _applied = createHashMap; };

private _getScore = {
    params ["_d", "_key", "_default"];
    private _hg2 = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k,_d]";
    private _v = [_d, _key, _default] call _hg2;
    if (!(_v isEqualType 0)) then { _v = _default; };
    (_v max 0) min 100
};

{
    private _districtId = _x;
    private _d = [_districts, _districtId, createHashMap] call _hg;
    if !(_d isEqualType createHashMap) then { continue; };

    private _scoreR = [_d, "R", 35] call _getScore;
    private _scoreG = [_d, "G", 35] call _getScore;
    private _scoreW = [_d, "W", 30] call _getScore;

    // Dominant axis
    private _color = "ColorWhite";
    if (_scoreR >= _scoreG && { _scoreR >= _scoreW } && { _scoreR > 45 }) then { _color = "ColorRed"; };
    if (_scoreG >= _scoreR && { _scoreG >= _scoreW } && { _scoreG > 45 } && { _color isEqualTo "ColorWhite" }) then { _color = "ColorGreen"; };

    // Centroid (stored as [x,y] or [x,y,z])
    private _cent = [_d, "centroid", []] call _hg;
    if (!(_cent isEqualType []) || { (count _cent) < 2 }) then { continue; };
    private _pos2 = [_cent select 0, _cent select 1];

    private _mkName = format ["ARC_district_%1_influence", _districtId];

    private _radius = [_d, "radius_m", 400] call _hg;
    if (!(_radius isEqualType 0)) then { _radius = 400; };
    _radius = (_radius max 100) min 3000;

    private _labelR = round _scoreR;
    private _labelG = round _scoreG;
    private _labelW = round _scoreW;
    private _displayName = [_d, "display_name", _districtId] call _hg;
    private _text = format ["%1 - %2 | R:%3 G:%4 W:%5", _districtId, _displayName, _labelR, _labelG, _labelW];

    // Skip all global setMarker* traffic when nothing visible changed.
    private _sig = [_pos2, _color, _radius, _text];
    private _lastSig = [_applied, _districtId, []] call _hg;
    private _exists = _mkName in allMapMarkers;
    if (_exists && { _sig isEqualTo _lastSig }) then { continue; };

    if (!_exists) then
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
    _mkName setMarkerSize [_radius, _radius];
    _mkName setMarkerText _text;

    _applied set [_districtId, _sig];
    _updated = _updated + 1;
} forEach _districts;

missionNamespace setVariable ["ARC_districtMarkersApplied", _applied];

if (_updated > 0) then
{
    diag_log format ["[ARC][INFO] ARC_fnc_districtMarkersUpdate: updated %1 district influence markers.", _updated];
};

_updated
