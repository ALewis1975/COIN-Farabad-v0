/*
    ARC_fnc_govStatsCompute

    Server-side government statistics aggregate.

    Computes legitimacy index, security force effectiveness, and infrastructure
    status from available district snapshots and mission state, then publishes
    ARC_govStats for client UI consumption.

    Authority: Server only.

    Returns:
        BOOL — true on success, false if not server or data unavailable.

    Publishes (JIP-safe broadcast):
        ARC_govStats: ARRAY of pairs [[key, value], ...]
            Keys:
              "legitimacy_index"    NUMBER  0-100 (avg G_EFF_U across districts)
              "legitimacy_rating"   STRING  "A"/"B"/"C"/"D"/"F" label
              "legitimacy_color"    STRING  hex color string
              "district_cnt"        NUMBER  districts sampled
              "district_stable"     NUMBER  districts rated Stable  (G >= 55)
              "district_fragile"    NUMBER  districts rated Fragile (G 30-55)
              "district_failing"    NUMBER  districts rated Failing (G <= 30)
              "security_effectiveness" NUMBER 0-100
              "security_rating"     STRING  "HIGH"/"MODERATE"/"LOW"
              "incidents_closed"    NUMBER  total closed incidents
              "incidents_total"     NUMBER  total incidents created
              "aid_events_total"    NUMBER  cumulative aid events across districts
              "computed_at"         NUMBER  serverTime when computed
*/

if (!isServer) exitWith { false };

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
private _hg       = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

// ---------------------------------------------------------------------------
// District governance aggregation from published civsub snapshots.
// ---------------------------------------------------------------------------
private _prefix = "civsub_v1_district_pub_";
private _distIds = [];
{
    private _n = _x;
    if ((_n find _prefix) == 0) then { _distIds pushBack (_n select [count _prefix]); };
} forEach (allVariables missionNamespace);

private _gTotal  = 0;
private _distCnt = 0;
private _stable  = 0;
private _fragile = 0;
private _failing = 0;
private _aidTotal = 0;

{
    private _did = _x;
    private _pub = missionNamespace getVariable [format ["%1%2", _prefix, _did], []];
    if (!(_pub isEqualType [])) then { continue; };
    if ((count _pub) == 0) then { continue; };

    private _ph = [_pub] call _hmCreate;
    private _G  = [_ph, "G", 35] call _hg;
    if (!(_G isEqualType 0)) then { _G = 35; };

    _gTotal  = _gTotal + _G;
    _distCnt = _distCnt + 1;

    if (_G >= 55) then { _stable  = _stable  + 1; } else {
        if (_G <= 30) then { _failing = _failing + 1; } else {
            _fragile = _fragile + 1;
        };
    };

    private _aidD = [_ph, "aid_events", 0] call _hg;
    if (_aidD isEqualType 0) then { _aidTotal = _aidTotal + _aidD; };
} forEach _distIds;

private _avgG = if (_distCnt > 0) then { _gTotal / _distCnt } else { 0 };
private _legRating = "C — Developing";
private _legColor  = "#FFD166";
if (_avgG >= 65) then      { _legRating = "A — Strong";     _legColor = "#9FE870"; } else {
if (_avgG >= 50) then      { _legRating = "B — Functional"; _legColor = "#C8E87A"; } else {
if (_avgG <= 25) then      { _legRating = "F — Failed";     _legColor = "#FF7A7A"; } else {
if (_avgG <= 35) then      { _legRating = "D — Fragile";    _legColor = "#FF9966"; };
};};};

// ---------------------------------------------------------------------------
// Security force effectiveness from incident close-rate.
// Closed / total gives a raw ratio; weight toward 70 (moderate) when no data.
// ---------------------------------------------------------------------------
private _closedCnt = ["incidentClosedCount", 0] call ARC_fnc_stateGet;
private _totalCnt  = ["incidentCounter",     0] call ARC_fnc_stateGet;
if (!(_closedCnt isEqualType 0)) then { _closedCnt = 0; };
if (!(_totalCnt  isEqualType 0)) then { _totalCnt  = 0; };

private _secEff = 50;
if (_totalCnt > 0) then
{
    _secEff = round ((_closedCnt / _totalCnt) * 100);
    _secEff = (_secEff max 0) min 100;
};

private _secRating = "MODERATE";
if (_secEff >= 70) then { _secRating = "HIGH"; } else {
    if (_secEff < 40) then { _secRating = "LOW"; };
};

// ---------------------------------------------------------------------------
// Publish.
// Use an array-of-pairs for sqflint compat (no bare createHashMapFromArray).
// ---------------------------------------------------------------------------
private _stats = [
    ["legitimacy_index",      _avgG],
    ["legitimacy_rating",     _legRating],
    ["legitimacy_color",      _legColor],
    ["district_cnt",          _distCnt],
    ["district_stable",       _stable],
    ["district_fragile",      _fragile],
    ["district_failing",      _failing],
    ["security_effectiveness", _secEff],
    ["security_rating",       _secRating],
    ["incidents_closed",      _closedCnt],
    ["incidents_total",       _totalCnt],
    ["aid_events_total",      _aidTotal],
    ["computed_at",           serverTime]
];

missionNamespace setVariable ["ARC_govStats", _stats, true];

if (missionNamespace getVariable ["ARC_debugLogEnabled", false]) then
{
    diag_log format [
        "[ARC][GOVSTATS] legitimacy=%1 (%2) secEff=%3 (%4) dists=%5 stable=%6 fragile=%7 failing=%8 aid=%9",
        round _avgG, _legRating, _secEff, _secRating, _distCnt, _stable, _fragile, _failing, _aidTotal
    ];
};

true
