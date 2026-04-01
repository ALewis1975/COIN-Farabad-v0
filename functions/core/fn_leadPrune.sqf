/*
    Prune expired leads from the lead pool, and apply time-based confidence
    (strength) decay to non-expired leads.

    Confidence decay: leads degrade linearly from their creation strength to
    a minimum floor as they approach expiry. Expired leads that were never
    actioned emit a "window missed" intel log entry.

    Returns:
        NUMBER - count of removed leads
*/

if (!isServer) exitWith {0};

private _leads = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_leads isEqualType [])) then { _leads = []; };

private _now = serverTime;
private _before = count _leads;

// Track which leads expire (for end-state reporting)
private _expiredIds = [];
{
    if (_x isEqualType [] && { (count _x) >= 7 }) then
    {
        private _expiresAt = _x # 6;
        if (_expiresAt isEqualType 0 && { _expiresAt > 0 } && { _expiresAt <= _now }) then
        {
            _expiredIds pushBack (_x # 0);
        };
    };
} forEach _leads;

// Keep anything with no expiry, or expiry in the future.
_leads = _leads select
{
    _x params ["_id", "_type", "_disp", "_pos", ["_strength", 0.5], ["_createdAt", -1], ["_expiresAt", -1]];
    (_expiresAt <= 0) || { _expiresAt > _now }
};

// ── Confidence (strength) decay ───────────────────────────────────────────
// Rate: configurable via ARC_leadDecayRate (default 0.6 — strength reaches
// 40 % of original at expiry). Floor: ARC_leadDecayFloor (default 0.05).
private _decayEnabled = missionNamespace getVariable ["ARC_leadDecayEnabled", true];
if (!(_decayEnabled isEqualType true) && !(_decayEnabled isEqualType false)) then { _decayEnabled = true; };

if (_decayEnabled) then
{
    private _decayRate = missionNamespace getVariable ["ARC_leadDecayRate", 0.6];
    if (!(_decayRate isEqualType 0)) then { _decayRate = 0.6; };
    _decayRate = (_decayRate max 0) min 1;

    private _decayFloor = missionNamespace getVariable ["ARC_leadDecayFloor", 0.05];
    if (!(_decayFloor isEqualType 0)) then { _decayFloor = 0.05; };
    _decayFloor = (_decayFloor max 0) min 0.5;

    private _decayChanged = false;
    _leads = _leads apply
    {
        private _entry = _x;
        if (!(_entry isEqualType []) || { (count _entry) < 7 }) exitWith { _entry };

        private _strength   = _entry # 4;
        private _createdAt  = _entry # 5;
        private _expiresAt  = _entry # 6;

        if (!(_strength  isEqualType 0) || !(_createdAt isEqualType 0) || !(_expiresAt isEqualType 0)) exitWith { _entry };
        if (_expiresAt <= 0) exitWith { _entry };

        private _ttl = _expiresAt - _createdAt;
        if (_ttl <= 0) exitWith { _entry };

        private _age = _now - _createdAt;
        if (_age <= 0) exitWith { _entry };

        // ageFraction: 0 at creation → 1 at expiry
        private _ageFrac = (_age / _ttl) min 1;

        // strength decay: linear from original down to floor scaled by decayRate
        // At expiry: min_strength = original * (1 - decayRate)
        private _minStrength  = (_strength * (1 - _decayRate)) max _decayFloor;
        private _newStrength  = _strength - ((_strength - _minStrength) * _ageFrac);
        _newStrength = (_newStrength max _decayFloor) min _strength;

        if (abs (_newStrength - _strength) > 0.005) then
        {
            private _updated = +_entry;
            _updated set [4, _newStrength];
            _decayChanged = true;
            _updated
        }
        else { _entry };
    };

    if (_decayChanged) then { ["leadPool", _leads] call ARC_fnc_stateSet; };
};



// Safety net: if a suspicious lead circle has a TTL, remove its marker even if the lead itself does not expire.
{
    if (!(_x isEqualType []) || { (count _x) < 11 }) then { continue; };
    private _id = _x # 0;
    private _tag = _x # 10;
    if (!(_tag isEqualType "")) then { continue; };

    private _tU = toUpper (trim _tag);
    if (_tU find "SUS_" != 0) then { continue; };

    private _exp = missionNamespace getVariable [format ["ARC_leadCircleExpiresAt_%1", _id], -1];
    if (!(_exp isEqualType 0) || { _exp <= 0 }) then { continue; };

    if (_exp <= _now) then
    {
        private _mk = format ["ARC_leadCircle_%1", _id];
        if (_mk in allMapMarkers) then { deleteMarker _mk; };
        missionNamespace setVariable [format ["ARC_leadCircleExpiresAt_%1", _id], nil];
    };
} forEach _leads;

private _after = count _leads;
private _removed = _before - _after;

if (_removed > 0) then
{
    ["leadPool", _leads] call ARC_fnc_stateSet;


// Remove any suspicious lead circle markers for expired leads.
{
    private _mk = format ["ARC_leadCircle_%1", _x];
    if (_mk in allMapMarkers) then { deleteMarker _mk; };
    missionNamespace setVariable [format ["ARC_leadCircleExpiresAt_%1", _x], nil];
} forEach _expiredIds;

    // Lead end-state: expired (never actioned) — emit "window missed" intel log
    if (_expiredIds isNotEqualTo []) then
    {
        private _lh = ["leadHistory", []] call ARC_fnc_stateGet;
        if (!(_lh isEqualType [])) then { _lh = []; };
        {
            _lh pushBack [_x, "EXPIRED", _now];
        } forEach _expiredIds;
        ["leadHistory", _lh] call ARC_fnc_stateSet;

        // Window missed: log each expired lead so TOC can see the opportunity cost
        if (!isNil "ARC_fnc_intelLog") then
        {
            {
                diag_log format ["[ARC][WARN] ARC_fnc_leadPrune: window missed — lead %1 expired without being actioned.", _x];
                ["OPS",
                    format ["Intel window missed: lead %1 expired without action.", _x],
                    [],
                    [["event", "LEAD_WINDOW_MISSED"], ["leadId", _x], ["expiredAt", _now]]
                ] call ARC_fnc_intelLog;
            } forEach _expiredIds;
        };
    };

    // Keep clients up to date for TOC tools
    [] call ARC_fnc_leadBroadcast;
};

_removed
