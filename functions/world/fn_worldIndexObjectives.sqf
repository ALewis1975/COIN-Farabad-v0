/*
    ARC_fnc_worldIndexObjectives

    Server-only startup pass. Assigns a strategic value score (0..1) to every named
    location in ARC_worldNamedLocations. ARC_fnc_incidentSeedQueue uses these scores
    to weight incident placement toward locations with higher strategic importance,
    consistent with COIN doctrine (FM 3-24: contest population centres, protect key
    infrastructure, secure lines of communication).

    Scoring components (weights tunable via ARC_worldIndex_weights in initServer.sqf):
        density     (w[0]) – named location cluster density within 1200 m
                            (populated/urban area indicator)
        junction    (w[1]) – road intersection density at 80 m radius
                            (LOC / control-node value)
        site        (w[2]) – proximity to key terrain sites
                            (TRANSMITTER, HOSPITAL, FUELSTATION within 500 m)
        proximity   (w[3]) – inverse distance from airbase centre
                            (closer = more operationally contested)

    Tier assignment:
        HIGH  score >= ARC_worldIndex_tierThresholds[0] (default 0.65)
        MED   score >= ARC_worldIndex_tierThresholds[1] (default 0.35)
        LOW   score <  ARC_worldIndex_tierThresholds[1]

    Must be called AFTER ARC_fnc_worldInit (which populates ARC_worldNamedLocations,
    ARC_worldTerrainSites, and ARC_worldZones). Called automatically from ARC_fnc_worldInit.

    State written (server missionNamespace, NOT replicated, NOT persisted):
        ARC_worldObjectiveIndex  (HashMap)
            key   : locationId (STRING)
            value : [score (NUMBER), tier (STRING "HIGH"|"MED"|"LOW")]
        ARC_worldObjectiveRanked (ARRAY of locationIds sorted highest score first)

    Returns: NUMBER - count of indexed locations
*/

if (!isServer) exitWith {0};

private _locations = missionNamespace getVariable ["ARC_worldNamedLocations", []];
if (!(_locations isEqualType [])) then { _locations = []; };

if ((count _locations) == 0) exitWith {
    diag_log "[ARC][WORLD][WARN] ARC_fnc_worldIndexObjectives: ARC_worldNamedLocations is empty — skipping.";
    0
};

private _sites = missionNamespace getVariable ["ARC_worldTerrainSites", []];
if (!(_sites isEqualType [])) then { _sites = []; };

private _zones = missionNamespace getVariable ["ARC_worldZones", []];
if (!(_zones isEqualType [])) then { _zones = []; };

// Operator-tunable weights (density, junction, site, proximity)
private _weights = missionNamespace getVariable ["ARC_worldIndex_weights", [0.25, 0.25, 0.30, 0.20]];
if (!(_weights isEqualType []) || {(count _weights) < 4}) then { _weights = [0.25, 0.25, 0.30, 0.20]; };

private _tierThresholds = missionNamespace getVariable ["ARC_worldIndex_tierThresholds", [0.65, 0.35]];
if (!(_tierThresholds isEqualType []) || {(count _tierThresholds) < 2}) then { _tierThresholds = [0.65, 0.35]; };

private _wDensity   = (_weights select 0) max 0;
private _wJunction  = (_weights select 1) max 0;
private _wSite      = (_weights select 2) max 0;
private _wProximity = (_weights select 3) max 0;

// Warn if weights deviate significantly from 1.0 (common config mistake)
private _wSum = _wDensity + _wJunction + _wSite + _wProximity;
if ((_wSum < 0.8) || {_wSum > 1.2}) then {
    diag_log format ["[ARC][WORLD][WARN] ARC_fnc_worldIndexObjectives: ARC_worldIndex_weights sum=%1 (expected ~1.0). Scores will be proportionally scaled.", _wSum];
};
private _tierHigh   = (_tierThresholds select 0) max 0;
private _tierMed    = (_tierThresholds select 1) max 0;

// Find airbase centre from ARC_worldZones (fallback: southern edge of map, near airbase area)
private _airbasePos = [7000, 1800, 0];
{
    if ((count _x) >= 3) then {
        if ((_x select 0) isEqualTo "Airbase") then {
            _airbasePos = _x select 2;
        };
    };
} forEach _zones;

// Derive site position lists for the three site types we score against
private _siteTypesOfInterest = ["TRANSMITTER", "HOSPITAL", "FUELSTATION"];
private _sitePositions = []; // array parallel to _siteTypesOfInterest; each entry: [pos,...]

{
    private _target = _x;
    private _posList = [];
    {
        if ((count _x) >= 2 && {(_x select 0) isEqualTo _target}) then {
            _posList = _x select 1;
        };
    } forEach _sites;
    if (!(_posList isEqualType [])) then { _posList = []; };
    _sitePositions pushBack _posList;
} forEach _siteTypesOfInterest;

// Pass 1: compute raw density counts (need all positions before normalising)
private _densityCounts = [];
private _densityMax    = 1;

{
    _x params [["_id", "", [""]], ["_displayName", "", [""]], ["_pos", [], [[]]]];

    private _p3 = +_pos;
    if ((count _p3) < 2) then { _densityCounts pushBack 0; continue; };
    if ((count _p3) == 2) then { _p3 pushBack 0; };

    private _cnt = 0;
    {
        _x params [["_oid", "", [""]], ["_odisplay", "", [""]], ["_opos", [], [[]]]];
        if (!(_oid isEqualTo _id) && {(count _opos) >= 2} && {(_p3 distance2D _opos) <= 1200}) then {
            _cnt = _cnt + 1;
        };
    } forEach _locations;

    if (_cnt > _densityMax) then { _densityMax = _cnt; };
    _densityCounts pushBack _cnt;

} forEach _locations;

// Pass 2: compute final scores for each location
private _index    = createHashMap;
private _ranked   = []; // [[score, id], ...]

{
    _x params [["_id", "", [""]], ["_displayName", "", [""]], ["_pos", [], [[]]]];

    private _p3 = +_pos;
    if ((count _p3) < 2) then { continue; };
    if ((count _p3) == 2) then { _p3 pushBack 0; };

    // Component 1: population density
    private _densityRaw   = _densityCounts select _forEachIndex;
    private _densityScore = (_densityRaw / _densityMax) min 1;

    // Component 2: road junction (nearRoads at 80 m)
    private _nearRds      = _p3 nearRoads 80;
    private _junctionScore = 0;
    if ((count _nearRds) >= 2) then { _junctionScore = 1; };

    // Component 3: key terrain site proximity (TRANSMITTER/HOSPITAL/FUELSTATION within 500 m)
    private _siteScore    = 0;
    private _siteRadius2  = 500 * 500;
    private _siteHitCount = 0;

    {
        private _posList = _sitePositions select _forEachIndex;
        private _hit     = false;
        {
            if (_x isEqualType [] && {(count _x) >= 2}) then {
                private _dx = (_p3 select 0) - (_x select 0);
                private _dy = (_p3 select 1) - (_x select 1);
                if ((_dx * _dx + _dy * _dy) <= _siteRadius2) exitWith { _hit = true; };
            };
        } forEach _posList;
        if (_hit) then { _siteHitCount = _siteHitCount + 1; };
    } forEach _siteTypesOfInterest;

    if (_siteHitCount > 0) then {
        _siteScore = (_siteHitCount / (count _siteTypesOfInterest)) min 1;
    };

    // Component 4: proximity to airbase (inverse distance; closer = higher score)
    private _distToBase   = (_p3 distance2D _airbasePos) max 1;
    private _proximityScore = (1 - (_distToBase / 12000)) max 0;

    // Weighted sum
    private _score =
        (_wDensity   * _densityScore)  +
        (_wJunction  * _junctionScore) +
        (_wSite      * _siteScore)     +
        (_wProximity * _proximityScore);

    _score = (_score max 0) min 1;

    // Tier assignment
    private _tier = "LOW";
    if (_score >= _tierHigh) then { _tier = "HIGH"; } else {
        if (_score >= _tierMed) then { _tier = "MED"; };
    };

    _index set [_id, [_score, _tier]];
    _ranked pushBack [_score, _id];

} forEach _locations;

// Sort ranked list: highest score first (bubble-sort friendly; 42 entries max)
_ranked sort false;
private _rankedIds = [];
{ _rankedIds pushBack (_x select 1); } forEach _ranked;

missionNamespace setVariable ["ARC_worldObjectiveIndex",  _index];     // server-local only
missionNamespace setVariable ["ARC_worldObjectiveRanked", _rankedIds]; // server-local only

diag_log format ["[ARC][WORLD][INFO] ARC_fnc_worldIndexObjectives: indexed %1 location(s). Top: %2", count _index, (if ((count _rankedIds) > 0) then {_rankedIds select 0} else {"(none)"})];

count _index
