/*
    Server: process deferred cleanup queue.

    Each queue entry format:
        [netId, anchorPosATL, radiusM, earliestDeleteAt, label]

    The tick deletes registered objects when no alive players are within radius
    of anchorPosATL. Vehicles are deleted along with their AI crew.

    Params:
        0: BOOL - (optional) force delete regardless of players/earliest time (default false)

    Returns:
        BOOL
*/

if (!isServer) exitWith {false};

params [["_force", false]];

private _queue = ["cleanupQueue", []] call ARC_fnc_stateGet;
if (!(_queue isEqualType []) || { (count _queue) isEqualTo 0 }) exitWith {true};

private _now = serverTime;
private _players = allPlayers select { alive _x };

private _debug = missionNamespace getVariable ["ARC_debugCleanup", false];

private _new = [];

{
    if !(_x isEqualType []) then { continue; };
    if ((count _x) < 4) then { continue; };

    _x params [
        ["_nid", ""],
        ["_anchor", []],
        ["_radius", 1000],
        ["_earliest", 0],
        ["_label", ""]
    ];

    if (_nid isEqualTo "") then { continue; };

    if (!_force) then
    {
        if (_earliest isEqualType 0 && { _now < _earliest }) then
        {
            _new pushBack _x;
            continue;
        };
    };

    private _obj = objectFromNetId _nid;
    if (isNull _obj) then
    {
        // Object no longer exists; drop entry.
        // If the entry was a threat-tagged cleanup label, mark it CLEANED anyway.
        if (((_label select [0,7]) isEqualTo "THREAT:") && { !isNil "ARC_fnc_threatMarkCleanedByLabel" }) then
        {
            [_label, _nid] call ARC_fnc_threatMarkCleanedByLabel;
        };
        continue;
    };


    // Persistent AO compositions (ex: checkpoints) should never be deleted by deferred cleanup.
    private _persist = _obj getVariable ["ARC_persistInAO", false];
    if (_persist isEqualType true && { _persist }) then
    {
        if (_debug) then
        {
            diag_log format ["[ARC][CLEANUP] Skipped persistent entity %1 (%2).", _nid, _label];
        };
        continue;
    };

    private _objPos = getPosATL _obj;
_objPos = +_objPos; _objPos resize 3;

private _a = _anchor;
if (!(_a isEqualType []) || { (count _a) < 2 }) then
{
    _a = _objPos;
};
_a = +_a; _a resize 3;

private _nearPlayers = false;
if (!_force) then
{
    // Key rule: keep the entity if any alive player is near the entity itself.
    // This prevents "early despawn" when an anchor is far from the convoy/prop.
    _nearPlayers = (_players findIf { (_x distance2D _objPos) <= _radius }) >= 0;
};

if (_nearPlayers) then
    {
        // Keep it, but refresh the anchor to where the action was (helps moving convoys)
        _new pushBack [_nid, _objPos, _radius, _earliest, _label];
        continue;
    };

    // Safety: never delete player-owned entities.
    if (_obj isKindOf "Man" && { isPlayer _obj }) then
    {
        _new pushBack [_nid, _objPos, _radius, _earliest, _label];
        continue;
    };

    // Vehicles: delete crew first, then the vehicle.
    if (_obj isKindOf "LandVehicle" || { _obj isKindOf "Air" } || { _obj isKindOf "Ship" }) then
    {
        private _crew = crew _obj;
        private _groups = [];

        // If any player is somehow in the vehicle, keep it.
        if ((_crew findIf { isPlayer _x }) >= 0) then
        {
            _new pushBack [_nid, _objPos, _radius, _earliest, _label];
            continue;
        };

        {
            if (isNull _x) then { continue; };
            if (isPlayer _x) then { continue; };
            private _g = group _x;
            if (!isNull _g) then { _groups pushBackUnique _g; };
            deleteVehicle _x;
        } forEach _crew;

        deleteVehicle _obj;

        { if (!isNull _x) then { deleteGroup _x; }; } forEach _groups;
    }
    else
    {
        // Simple objects / props / AI units.
        deleteVehicle _obj;
    };

    // Threat system: if this entry was tagged to a threat, mark it CLEANED.
    if (((_label select [0,7]) isEqualTo "THREAT:") && { !isNil "ARC_fnc_threatMarkCleanedByLabel" }) then
    {
        [_label, _nid] call ARC_fnc_threatMarkCleanedByLabel;
    };

    if (_debug) then
    {
        diag_log format ["[ARC][CLEANUP] Deleted %1 (%2) at %3 (r=%4).", _nid, _label, mapGridPosition _a, _radius];
    };

} forEach _queue;

["cleanupQueue", _new] call ARC_fnc_stateSet;
true
