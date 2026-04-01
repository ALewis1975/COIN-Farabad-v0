/*
    ARC_fnc_worldScanBuildingSlots

    Server-only startup scan. For every entry in ARC_worldNamedLocations, queries
    nearby enterable building interior positions and roadside offset positions using
    Arma terrain functions. Results are stored in a server-local HashMap so that
    ARC_fnc_civsubSpawnCacheEnsure can look up pre-scanned positions instead of
    repeating expensive nearestObjects / BIS_fnc_buildingPositions calls on every
    spawn-cache rebuild tick.

    Must be called AFTER ARC_fnc_worldInit (which populates ARC_worldNamedLocations).
    Called automatically from ARC_fnc_worldInit.

    State written (server missionNamespace, NOT replicated, NOT persisted):
        ARC_worldBuildingSlots (HashMap)
            key   : locationId (STRING from ARC_worldNamedLocations)
            value : [bldPositions (ARRAY), roadsidePositions (ARRAY)]

    Returns: NUMBER - count of locations successfully scanned
*/

if (!isServer) exitWith {0};

private _locations = missionNamespace getVariable ["ARC_worldNamedLocations", []];
if (!(_locations isEqualType [])) then { _locations = []; };

if ((count _locations) == 0) exitWith {
    diag_log "[ARC][WORLD][WARN] ARC_fnc_worldScanBuildingSlots: ARC_worldNamedLocations is empty — skipping scan.";
    0
};

private _scanR    = 350;
private _maxBld   = 400;
private _maxRoad  = 250;
private _offsetM  = 4;

private _slots = createHashMap;

{
    _x params [["_id", "", [""]], ["_displayName", "", [""]], ["_pos", [], [[]]]];

    if (!(_pos isEqualType []) || {(count _pos) < 2}) then { continue; };

    private _p3 = +_pos;
    if ((count _p3) == 2) then { _p3 pushBack 0; };

    // Building interior positions (enterable building types)
    private _bldPos = [];
    private _objs   = nearestObjects [_p3, ["House","House_F","Building","Building_F"], _scanR];
    {
        private _bp = [_x] call BIS_fnc_buildingPositions;
        if (_bp isEqualType [] && {(count _bp) > 0}) then {
            {
                if (_x isEqualType [] && {(count _x) >= 2}) then {
                    _bldPos pushBackUnique _x;
                };
            } forEach _bp;
        };
    } forEach _objs;

    if ((count _bldPos) > _maxBld) then { _bldPos resize _maxBld; };

    // Roadside offset positions
    private _roads      = _p3 nearRoads _scanR;
    private _roadsidePos = [_roads, _offsetM] call ARC_fnc_worldRoadsideOffsets;
    if ((count _roadsidePos) > _maxRoad) then { _roadsidePos resize _maxRoad; };

    _slots set [_id, [_bldPos, _roadsidePos]];

} forEach _locations;

missionNamespace setVariable ["ARC_worldBuildingSlots", _slots]; // server-local only; no broadcast

diag_log format ["[ARC][WORLD][INFO] ARC_fnc_worldScanBuildingSlots: scanned %1 location(s).", count _slots];

count _slots
