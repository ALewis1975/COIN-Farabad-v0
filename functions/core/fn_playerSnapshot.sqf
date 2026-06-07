/*
    ARC_fnc_playerSnapshot

    Returns a per-frame-cached snapshot of all players and their positions so
    callers can avoid re-iterating allPlayers / re-reading getPos inside
    per-entity loops (eliminates repeated O(players) engine queries, e.g. the
    per-district min-distance scan in ARC_fnc_civsubIsDistrictActive).

    Returns:
      Array of [unit, posATL] pairs, one per entry in allPlayers. No alive
      filtering is applied — callers that need alive-only should filter on
      `alive (_x select 0)`, matching their previous behaviour.

    Notes:
      - Cached in missionNamespace keyed by diag_frameNo and recomputed once per
        engine frame. Player positions are stable within a single frame, so the
        cache can never return stale data within one server tick.
      - Server-authoritative; returns [] off the server (all callers are
        server-side ticks).
*/

if (!isServer) exitWith { [] };

private _frame = diag_frameNo;
private _cachedFrame = missionNamespace getVariable ["ARC_playerSnapshotFrame", -1];
if (_cachedFrame isEqualTo _frame) exitWith {
    missionNamespace getVariable ["ARC_playerSnapshotData", []]
};

private _snap = allPlayers apply { [_x, getPosATL _x] };
missionNamespace setVariable ["ARC_playerSnapshotFrame", _frame];
missionNamespace setVariable ["ARC_playerSnapshotData", _snap];

_snap
