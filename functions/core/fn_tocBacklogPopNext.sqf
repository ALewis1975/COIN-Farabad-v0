/*
    ARC_fnc_tocBacklogPopNext

    Server: pop (remove and return) the next best backlog entry.

    Selection:
      - Highest priority first (5..1)
      - Tie-breaker: oldest enqueued first (FIFO within priority)
    Defensive behavior:
      - Drops backlog entries if the referenced lead no longer exists in leadPool.
      - When _forceLogistics is true (base stocks critical), only returns items that are:
          * priority >= 4 (treated as urgent), OR
          * leadType in ["LOGISTICS","ESCORT"], OR
          * lead tag begins with "TOC_" or "URGENT_"
        Otherwise returns [] and leaves remaining backlog items intact.

    Params:
      0: BOOL forceLogistics (default false)

    Returns:
      ARRAY backlog entry (shape below) or []
      Shape: [leadId, priority, enqueuedAt, sourceQueueId, by, note, leadType, leadName, zone, tag]
*/

if (!isServer) exitWith {[]};

params [ ["_forceLogistics", false, [true]] ];
if (!(_forceLogistics isEqualType true)) then { _forceLogistics = false; };

private _back = ["tocBacklog", []] call ARC_fnc_stateGet;
if (!(_back isEqualType [])) then { _back = []; };
if (_back isEqualTo []) exitWith {[]};

private _pool = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_pool isEqualType [])) then { _pool = []; };

private _changed = false;

// First pass: drop invalid entries (bad shape or missing lead).
for "_i" from ((count _back) - 1) to 0 step -1 do
{
    private _e = _back # _i;
    if !(_e isEqualType [] && { (count _e) >= 3 }) then
    {
        _back deleteAt _i;
        _changed = true;
        continue;
    };

    private _lid = _e # 0;
    if !(_lid isEqualType "" && { (trim _lid) != "" }) then
    {
        _back deleteAt _i;
        _changed = true;
        continue;
    };

    private _li = -1;
    { if (_x isEqualType [] && { (count _x) >= 1 } && { (_x # 0) isEqualTo _lid }) exitWith { _li = _forEachIndex; }; } forEach _pool;
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
};

if (_back isEqualTo []) exitWith {[]};

// Second pass: find best eligible.
private _bestIdx = -1;
private _bestPri = -1;
private _bestAt = 1e12;

for "_i" from 0 to ((count _back) - 1) do
{
    private _e = _back # _i;
    if !(_e isEqualType [] && { (count _e) >= 3 }) then { continue; };

    private _lid = _e # 0;
    private _pri = _e # 1;
    private _at  = _e # 2;

    if (!(_pri isEqualType 0)) then { _pri = 3; };
    _pri = round _pri;
    _pri = (_pri max 1) min 5;

    if (!(_at isEqualType 0)) then { _at = serverTime; };

    // Eligibility under sustainment override.
    if (_forceLogistics) then
    {
        private _urgent = (_pri >= 4);

        if (!_urgent) then
        {
            // Look up live lead rec to verify type/tag for eligibility.
            private _li = -1;
            { if (_x isEqualType [] && { (count _x) >= 1 } && { (_x # 0) isEqualTo _lid }) exitWith { _li = _forEachIndex; }; } forEach _pool;
            if (_li >= 0) then
            {
                private _lr = _pool # _li;

                private _lt = "";
                private _tag = "";

                if ((count _lr) >= 2 && { (_lr # 1) isEqualType "" }) then { _lt = toUpper (trim (_lr # 1)); };
                if ((count _lr) >= 11 && { (_lr # 10) isEqualType "" }) then { _tag = toUpper (trim (_lr # 10)); };

                private _ok = (_lt in ["LOGISTICS","ESCORT"]) || { (_tag find "TOC_" == 0) } || { (_tag find "URGENT_" == 0) };
                if (!_ok) then { continue; };
            }
            else
            {
                // Defensive: if we can't resolve the lead, skip it (it will be pruned on next call).
                continue;
            };
        };
    };

    // Compare: higher priority wins, then older.
    if (_pri > _bestPri || { _pri == _bestPri && { _at < _bestAt } }) then
    {
        _bestPri = _pri;
        _bestAt = _at;
        _bestIdx = _i;
    };
};

if (_bestIdx < 0) exitWith {[]};

private _picked = _back deleteAt _bestIdx;
["tocBacklog", _back] call ARC_fnc_stateSet;

_picked
