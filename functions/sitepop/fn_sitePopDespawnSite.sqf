/*
    ARC_fnc_sitePopDespawnSite

    Server: delete all spawned groups/units for an active site and apply a
    60-second re-spawn lockout.

    Iterates the site's spawn record from ARC_sitePopActive, deletes each unit
    and group, then resets the active record to an empty sentinel and writes
    the lockout expiry to ARC_sitePopLockout.

    No-ops silently if the site is not currently recorded as active.

    Params:
        0: STRING — siteId

    Returns: BOOLEAN — true on success, false if site not found or not active.
*/

if (!isServer) exitWith {false};

params [["_siteId", "", [""]]];
if (_siteId isEqualTo "") exitWith {false};

private _hg     = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _active = missionNamespace getVariable ["ARC_sitePopActive", createHashMap];

private _record = [_active, _siteId, []] call _hg;
if (!(_record isEqualType []) || { (count _record) isEqualTo 0 }) exitWith
{
    diag_log format ["[ARC][SITEPOP][WARN] ARC_fnc_sitePopDespawnSite: '%1' not in active map — no-op.", _siteId];
    false
};

private _groups    = _record select 0;
private _unitCount = 0;

if (!(_groups isEqualType [])) then { _groups = []; };

{
    private _g = _x;
    if (!isNull _g) then
    {
        private _gUnits = units _g;
        _unitCount = _unitCount + (count _gUnits);
        { if (!isNull _x) then { deleteVehicle _x; }; } forEach _gUnits;
        deleteGroup _g;
    };
} forEach _groups;

// Reset active record to empty sentinel (marks site as inactive)
_active set [_siteId, []];

// Apply 60-second lockout before next proximity spawn is allowed
private _lockout = missionNamespace getVariable ["ARC_sitePopLockout", createHashMap];
private _lockoutS = 60;
_lockout set [_siteId, time + _lockoutS];

diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopDespawnSite: site '%1' despawned %2 unit(s); lockout for %3 s.", _siteId, _unitCount, _lockoutS];

true
