/*
    ARC_fnc_missionScoreGenerate

    Server-side: produce a structured after-action summary of the current
    mission session. Can be called by a TOC operator (via console) or
    automatically on server shutdown / mission-end trigger.

    Aggregates:
      - Tasks completed / failed / active
      - SITREPs submitted
      - Influence deltas per district (CIVSUB)
      - BLUFOR and civilian casualties
      - Detainees processed
      - CASREQ sorties
      - Intel leads actioned / expired
      - Sustainment health (fuel / ammo / med) at summary time

    Publishes result to:
      missionNamespace ARC_pub_missionScore     (ARRAY of pairs, broadcast)
      missionNamespace ARC_pub_missionScoreAt   (NUMBER serverTime, broadcast)

    Returns:
      ARRAY of pairs (the score payload)
*/

if (!isServer) exitWith {[]};

// Optional caller unit (provided when invoked via remoteExec from a TOC operator).
params [["_unit", objNull, [objNull]]];

// Validate sender when invoked via RPC.
if (!isNull _unit) then
{
    if (!([_unit, "ARC_fnc_missionScoreGenerate", "Score generate rejected: sender mismatch.", "SCORE_GEN_SEC_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith { [] };
};

private _now = serverTime;

// ── Tasks ──────────────────────────────────────────────────────────────────
private _hist = ["incidentHistory", []] call ARC_fnc_stateGet;
if (!(_hist isEqualType [])) then { _hist = []; };

private _tasksCompleted = count (_hist select { _x isEqualType [] && { (count _x) >= 2 } && { (toUpper (_x # 1)) isEqualTo "SUCCESS" } });
private _tasksFailed    = count (_hist select { _x isEqualType [] && { (count _x) >= 2 } && { (toUpper (_x # 1)) isEqualTo "FAIL" } });
private _tasksTotal     = count _hist;

// ── SITREPs ────────────────────────────────────────────────────────────────
private _sitrepCount = ["sitrepSubmittedCount", 0] call ARC_fnc_stateGet;
if (!(_sitrepCount isEqualType 0)) then { _sitrepCount = 0; };
_sitrepCount = _sitrepCount max 0;

// ── Casualties ─────────────────────────────────────────────────────────────
private _bCas   = ["baseCasualties",  0] call ARC_fnc_stateGet;
private _civCas = ["civCasualties",   0] call ARC_fnc_stateGet;
if (!(_bCas   isEqualType 0)) then { _bCas   = 0; };
if (!(_civCas isEqualType 0)) then { _civCas = 0; };
_bCas   = _bCas   max 0;
_civCas = _civCas max 0;

// ── Detainees ──────────────────────────────────────────────────────────────
private _detained = ["totalDetained", 0] call ARC_fnc_stateGet;
if (!(_detained isEqualType 0)) then { _detained = 0; };
_detained = _detained max 0;

// ── CAS sorties ────────────────────────────────────────────────────────────
private _casreqs = ["casreq_v1_records", []] call ARC_fnc_stateGet;
if (!(_casreqs isEqualType [])) then { _casreqs = []; };
private _casreqCompleted = count (_casreqs select
{
    _x isEqualType []
    && { (count _x) >= 3 }
    && { (toUpper (_x # 2)) isEqualTo "CLOSED" }
});

// ── Lead actions ───────────────────────────────────────────────────────────
private _leadHistory = ["leadHistory", []] call ARC_fnc_stateGet;
if (!(_leadHistory isEqualType [])) then { _leadHistory = []; };
private _leadsActioned = count (_leadHistory select
{
    _x isEqualType [] && { (count _x) >= 2 } && { (toUpper (_x # 1)) isEqualTo "CONSUMED" }
});
private _leadsExpired  = count (_leadHistory select
{
    _x isEqualType [] && { (count _x) >= 2 } && { (toUpper (_x # 1)) isEqualTo "EXPIRED" }
});

// ── Sustainment snapshot ───────────────────────────────────────────────────
private _baseFuel = ["baseFuel", 0.68] call ARC_fnc_stateGet;
private _baseAmmo = ["baseAmmo", 0.61] call ARC_fnc_stateGet;
private _baseMed  = ["baseMed",  0.57] call ARC_fnc_stateGet;
if (!(_baseFuel isEqualType 0)) then { _baseFuel = 0.68; };
if (!(_baseAmmo isEqualType 0)) then { _baseAmmo = 0.61; };
if (!(_baseMed  isEqualType 0)) then { _baseMed  = 0.57; };

// ── CIVSUB influence deltas ────────────────────────────────────────────────
private _districtDeltas = [];
if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
{
    private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
    if (_districts isEqualType createHashMap) then
    {
        {
            private _did   = _x;
            private _d     = _y;
            if (!(_d isEqualType createHashMap)) then { continue; };
            private _r = _d getOrDefault ["R", 35];
            private _g = _d getOrDefault ["G", 35];
            private _w = _d getOrDefault ["W", 30];
            if (!(_r isEqualType 0)) then { _r = 35; };
            if (!(_g isEqualType 0)) then { _g = 35; };
            if (!(_w isEqualType 0)) then { _w = 30; };
            _districtDeltas pushBack [_did, _r, _g, _w];
        } forEach _districts;
    };
};

// ── Overall score rating ───────────────────────────────────────────────────
// Simple weighted composite (0–100):
//   Tasks completed rate   30 %
//   Civilian protection    20 % (inverse of civCas capped at 20)
//   Lead actioned rate     20 %
//   Sustainment average    15 %
//   SITREPs filed          15 % (capped at 10 SITREPs = max)
private _taskRate       = if (_tasksTotal > 0) then { (_tasksCompleted / _tasksTotal) min 1 } else { 0 };
private _civProtection  = (1 - ((_civCas min 20) / 20)) max 0;
private _leadRate       = if ((_leadsActioned + _leadsExpired) > 0) then { (_leadsActioned / ((_leadsActioned + _leadsExpired) max 1)) min 1 } else { 0 };
private _sustainAvg     = (((_baseFuel + _baseAmmo + _baseMed) / 3) max 0) min 1;
private _sitrepRate     = ((_sitrepCount min 10) / 10) min 1;

private _compositeScore = round (
    (_taskRate      * 30) +
    (_civProtection * 20) +
    (_leadRate      * 20) +
    (_sustainAvg    * 15) +
    (_sitrepRate    * 15)
);

private _rating = "UNSAT";
if (_compositeScore >= 40) then { _rating = "MARGINAL"; };
if (_compositeScore >= 60) then { _rating = "SATISFACTORY"; };
if (_compositeScore >= 80) then { _rating = "OUTSTANDING"; };

// ── Assemble payload ───────────────────────────────────────────────────────
private _payload = [
    ["generatedAt",       _now],
    ["schema",            "ARC_missionScore_v1"],
    ["tasks", [
        ["completed",     _tasksCompleted],
        ["failed",        _tasksFailed],
        ["total",         _tasksTotal]
    ]],
    ["sitreps",           _sitrepCount],
    ["casualties", [
        ["blufor",        _bCas],
        ["civilian",      _civCas]
    ]],
    ["detainees",         _detained],
    ["casreqCompleted",   _casreqCompleted],
    ["leads", [
        ["actioned",      _leadsActioned],
        ["expired",       _leadsExpired]
    ]],
    ["sustainment", [
        ["baseFuel",      round (_baseFuel * 100) / 100],
        ["baseAmmo",      round (_baseAmmo * 100) / 100],
        ["baseMed",       round (_baseMed  * 100) / 100]
    ]],
    ["districtInfluence", _districtDeltas],
    ["compositeScore",    _compositeScore],
    ["rating",            _rating]
];

missionNamespace setVariable ["ARC_pub_missionScore",   _payload, true];
missionNamespace setVariable ["ARC_pub_missionScoreAt", _now,     true];

diag_log format ["[ARC][SCORE] ARC_fnc_missionScoreGenerate: score=%1 rating=%2 tasks=%3/%4 bCas=%5 civCas=%6 leads=%7/%8",
    _compositeScore, _rating, _tasksCompleted, _tasksTotal, _bCas, _civCas, _leadsActioned, _leadsExpired];

_payload
