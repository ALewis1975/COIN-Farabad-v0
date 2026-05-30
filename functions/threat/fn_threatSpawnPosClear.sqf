/*
    ARC_fnc_threatSpawnPosClear

    Server-side predicate for hostile spawn/materialization guards. Centralises the
    single "is this position acceptable to materialise OPFOR at?" rule so every
    spawner (virtual pool, ops patrol contacts, ...) shares the same logic instead
    of re-implementing it inline.

    A position is "clear" when BOTH hold:
      * it is at least _minDist (2D) from every supplied alive player — so groups
        never materialise on top of players (e.g. holders of a co-located objective);
      * it is not inside a protected world zone / marker bubble
        (see ARC_fnc_threatIsProtectedSpawnPos).

    The standoff distance is a caller-supplied parameter: callers that intentionally
    place contacts close (ops route patrols) pass a smaller value than the virtual
    pool. The rule is shared; only the tuning differs per caller.

    Params:
        0: ARRAY  _pos              - candidate position [x,y,(z)]
        1: ARRAY  _players          - alive players to keep clear of
        2: NUMBER _minDist          - minimum standoff distance (m); <= 0 disables the player check
        3: ARRAY  _protectedZones   - optional; defaults via ARC_fnc_threatIsProtectedSpawnPos
        4: ARRAY  _protectedMarkers - optional; defaults via ARC_fnc_threatIsProtectedSpawnPos

    Returns: BOOL (true if the position is a safe standoff spawn point)
*/

if (!isServer) exitWith {false};

params [
    ["_pos", [], [[]]],
    ["_players", [], [[]]],
    ["_minDist", 0, [0]],
    ["_protectedZones", [], [[]]],
    ["_protectedMarkers", [], [[]]]
];

// An invalid position is never a safe spawn point.
if (!(_pos isEqualType []) || {(count _pos) < 2}) exitWith {false};
if (!(_minDist isEqualType 0)) then { _minDist = 0; };
if (!(_players isEqualType [])) then { _players = []; };

// Standoff check: reject if any alive player is inside the standoff bubble.
// Explicit loop search (sqflint parser compatibility — avoid findIf).
private _tooClose = false;
if (_minDist > 0) then {
    {
        if (!isNull _x && { alive _x } && { (_x distance2D _pos) < _minDist }) exitWith {
            _tooClose = true;
        };
    } forEach _players;
};
if (_tooClose) exitWith {false};

// Protected-zone check (last line of defence; mirrors the materialisation guards).
if ([_pos, _protectedZones, _protectedMarkers] call ARC_fnc_threatIsProtectedSpawnPos) exitWith {false};

true
