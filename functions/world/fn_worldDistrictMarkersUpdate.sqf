/*
    ARC_fnc_worldDistrictMarkersUpdate

    Client-only: create or update local-only map markers visualising district
    influence axis dominance (R/W/G) for the S2 heat-map toggle.

    One marker per district, positioned at the district centroid.
    Marker colour is driven by the dominant W/R/G axis:
      R dominant (R > W and R > G)   → ColorRed      (insurgent pressure)
      G dominant (G > R and G >= W)  → ColorBlue     (governance legitimacy)
      W dominant (W >= R and W > G)  → ColorGreen    (civilian trust)
      Balanced                        → ColorYellow

    Markers are LOCAL ONLY (createMarkerLocal) — never broadcast to other clients.

    Params:
      0: BOOL - show (true) or hide/delete (false). Default true.

    Returns:
      NUMBER - count of markers created/updated, or 0 when hiding.
*/

if (!hasInterface) exitWith {0};

params [["_show", true, [true]]];

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if (!(_districts isEqualType createHashMap)) then { _districts = createHashMap; };

// Track markers we own so we can delete them later.
private _ownedMarkers = uiNamespace getVariable ["ARC_s2_districtMarkerNames", []];
if (!(_ownedMarkers isEqualType [])) then { _ownedMarkers = []; };

// ── Hide / delete path ────────────────────────────────────────────────────────
if (!_show) exitWith
{
    { deleteMarkerLocal _x; } forEach _ownedMarkers;
    uiNamespace setVariable ["ARC_s2_districtMarkerNames", []];
    diag_log format ["[ARC][WORLD] worldDistrictMarkersUpdate: removed %1 heat-map marker(s).", count _ownedMarkers];
    0
};

// ── Show / update path ────────────────────────────────────────────────────────
private _count = 0;

{
    private _did = _x;
    private _ds  = _districts getOrDefault [_did, createHashMap];
    if (!(_ds isEqualType createHashMap)) then { continue; };

    private _centroid = _ds getOrDefault ["centroid", []];
    if (!(_centroid isEqualType []) || { (count _centroid) < 2 }) then { continue; };

    private _cx = _centroid select 0;
    private _cy = _centroid select 1;
    if (!(_cx isEqualType 0)) then { _cx = 0; };
    if (!(_cy isEqualType 0)) then { _cy = 0; };

    private _wEff = _ds getOrDefault ["W_EFF_U", 50];
    private _rEff = _ds getOrDefault ["R_EFF_U", 50];
    private _gEff = _ds getOrDefault ["G_EFF_U", 50];
    if (!(_wEff isEqualType 0)) then { _wEff = 50; };
    if (!(_rEff isEqualType 0)) then { _rEff = 50; };
    if (!(_gEff isEqualType 0)) then { _gEff = 50; };

    // Dominant axis → marker colour
    private _color = "ColorYellow";
    if (_rEff > _wEff && { _rEff > _gEff }) then
    {
        _color = "ColorRed";
    }
    else
    {
        if (_gEff > _rEff && { _gEff >= _wEff }) then
        {
            _color = "ColorBlue";
        }
        else
        {
            if (_wEff >= _rEff && { _wEff > _gEff }) then { _color = "ColorGreen"; };
        };
    };

    private _mName = "ARC_s2_dist_" + _did;
    deleteMarkerLocal _mName;

    private _mk = createMarkerLocal [_mName, [_cx, _cy, 0]];
    _mk setMarkerTypeLocal "mil_dot";
    _mk setMarkerColorLocal _color;
    _mk setMarkerAlphaLocal 0.70;
    _mk setMarkerTextLocal _did;
    _mk setMarkerSizeLocal [0.5, 0.5];

    _ownedMarkers pushBackUnique _mName;
    _count = _count + 1;

} forEach (keys _districts);

uiNamespace setVariable ["ARC_s2_districtMarkerNames", _ownedMarkers];
diag_log format ["[ARC][WORLD] worldDistrictMarkersUpdate: painted %1 district heat-map marker(s).", _count];

_count
