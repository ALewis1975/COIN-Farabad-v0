/*
    ARC_fnc_tocBacklogPrune

    Server: reconcile the TOC backlog against the live lead pool.

    Non-destructive triage maintenance:
      - Drops backlog entries with a bad shape (not an array of >= 3 elements).
      - Drops entries whose leadId is not a non-empty string.
      - Drops entries whose lead no longer exists in leadPool (expired/consumed).

    On any change it persists the trimmed backlog and rebroadcasts the read model
    (ARC_pub_tocBacklog) so field + TOC consoles stop showing stale
    "in the TOC Queue" indications for leads that have aged out of the pool.

    This is the single source of truth for backlog reconciliation; both the
    periodic incident tick and ARC_fnc_tocBacklogPopNext call it.

    Returns:
      BOOL changed (true if any entry was removed)
*/

if (!isServer) exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";

private _back = ["tocBacklog", []] call ARC_fnc_stateGet;
if (!(_back isEqualType [])) then { _back = []; };
if (_back isEqualTo []) exitWith {false};

private _pool = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_pool isEqualType [])) then { _pool = []; };

private _changed = false;

for "_i" from ((count _back) - 1) to 0 step -1 do
{
    private _e = _back select _i;
    if !(_e isEqualType [] && { (count _e) >= 3 }) then
    {
        _back deleteAt _i;
        _changed = true;
        continue;
    };

    private _lid = _e select 0;
    if !(_lid isEqualType "" && { ([_lid] call _trimFn) != "" }) then
    {
        _back deleteAt _i;
        _changed = true;
        continue;
    };

    private _li = -1;
    { if (_x isEqualType [] && { (count _x) >= 1 } && { (_x select 0) isEqualTo _lid }) exitWith { _li = _forEachIndex; }; } forEach _pool;
    if (_li < 0) then
    {
        // Lead expired/consumed; drop backlog entry.
        _back deleteAt _i;
        _changed = true;
        continue;
    };
};

if (_changed) then
{
    ["tocBacklog", _back] call ARC_fnc_stateSet;
    if (!isNil "ARC_fnc_tocBacklogBroadcast") then { [] call ARC_fnc_tocBacklogBroadcast; };
};

_changed
