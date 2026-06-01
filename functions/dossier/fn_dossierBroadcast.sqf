/*
    ARC_fnc_dossierBroadcast

    Publish the unified SHERIFF/SSE dossier read model so field + TOC consoles and
    JIP clients reconstruct dossiers from the server snapshot.

    Publishes (public, JIP-safe):
      ARC_pub_dossier          - bounded array (last N) of dossier records (array-of-pairs)
      ARC_pub_dossierUpdatedAt - serverTime of last publish

    Server-only. Returns the count published.
*/

if (!isServer) exitWith {0};

private _records = ["dossier_v0_records", []] call ARC_fnc_stateGet;
if !(_records isEqualType []) then { _records = []; };

// Bound the broadcast slice (keep most recent), independent of the stored cap.
private _pubMax = 40;
private _slice = _records;
private _n = count _records;
if (_n > _pubMax) then {
    _slice = _records select [_n - _pubMax, _pubMax];
};

missionNamespace setVariable ["ARC_pub_dossier", _slice, true];
missionNamespace setVariable ["ARC_pub_dossierUpdatedAt", serverTime, true];

count _slice
