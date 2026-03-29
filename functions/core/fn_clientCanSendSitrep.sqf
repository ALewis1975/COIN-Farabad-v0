/*
    Client helper for field SITREP addAction conditions.

    Enforces, client-side:
      - Active incident exists + accepted
      - SITREP not already sent
      - Player role authorized (RHSUSAF Officer / Squad Leader classnames)
      - Proximity to task/lead/convoy anchors (best-effort using public vars)

    Server is still authoritative (server repeats role + proximity checks).

    Uses ARC_fnc_sitrepGateEval for gate parity with server-side checks.
    See docs/architecture/SITREP_Gate_Parity.md for the canonical gate matrix.
*/

params [["_unit", player]];
if (isNull _unit) exitWith {false};


// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
// Fail-safe: ensure role helper functions exist even if CfgFunctions.hpp was not updated.
if (isNil "ARC_fnc_rolesIsAuthorized") then { ARC_fnc_rolesIsAuthorized = compile preprocessFileLineNumbers "functions\\core\\fn_rolesIsAuthorized.sqf"; };

// Simple cache to avoid heavy work every frame (addAction conditions are evaluated often).
private _now = diag_tickTime;
private _next = _unit getVariable ["ARC_sitrep_canSendNext", 0];
if (_now < _next) exitWith { _unit getVariable ["ARC_sitrep_canSendCached", false] };
_unit setVariable ["ARC_sitrep_canSendNext", _now + 0.5];

// Build context for shared gate evaluation
private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""];
private _incType = missionNamespace getVariable ["ARC_activeIncidentType", ""];
if (!(_incType isEqualType "")) then { _incType = ""; };
private _roleAuth = [_unit] call ARC_fnc_rolesIsAuthorized;

// Proximity evaluation (client-side)
private _proxResult = true;
private _prox = missionNamespace getVariable ["ARC_sitrepProximityM", 350];
if (!(_prox isEqualType 0)) then { _prox = 350; };
_prox = (_prox max 100) min 2000;

private _anchors = [];

private _p0 = missionNamespace getVariable ["ARC_activeIncidentPos", []];
if (_p0 isEqualType [] && { (count _p0) >= 2 }) then
{
    private _p = +_p0; _p resize 3;
    _anchors pushBack _p;
};

// Optional: server can publish extra anchor positions for SITREP gating.
private _extra = missionNamespace getVariable ["ARC_sitrepAnchorPosList", []];
if (_extra isEqualType []) then
{
    {
        if (_x isEqualType [] && { (count _x) >= 2 }) then
        {
            private _p = +_x; _p resize 3;
            _anchors pushBack _p;
        };
    } forEach _extra;
};

// Optional: convoy vehicles (netIds) can be published for better proximity gating.
private _nids = missionNamespace getVariable ["ARC_activeConvoyNetIds", []];
if (_nids isEqualType []) then
{
    {
        private _o = objectFromNetId _x;
        if (!isNull _o) then
        {
            private _p = getPosATL _o;
            _p = +_p; _p resize 3;
            _anchors pushBack _p;
        };
    } forEach _nids;
};

if ((count _anchors) > 0) then
{
    _proxResult = false;
    private _uPos = getPosATL _unit;
    {
        if ((_uPos distance2D _x) <= _prox) exitWith { _proxResult = true; };
    } forEach _anchors;
};

// Run shared gate evaluation for parity
private _ctx = createHashMap;
_ctx set ["taskId", _taskId];
_ctx set ["taskState", ""];
_ctx set ["incidentType", _incType];
_ctx set ["accepted", missionNamespace getVariable ["ARC_activeIncidentAccepted", false]];
_ctx set ["closeReady", missionNamespace getVariable ["ARC_activeIncidentCloseReady", false]];
_ctx set ["sitrepSent", missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false]];
_ctx set ["roleAuthorized", _roleAuth];
_ctx set ["proximity", _proxResult];

private _gateResult = ["UNIT_SITREP_SUBMIT", _ctx] call ARC_fnc_sitrepGateEval;
private _ok = [_gateResult, "allowed", false] call _hg;
private _reason = [_gateResult, "reasonCode", ""] call _hg;

// Store breadcrumb for telemetry / parity mismatch debugging
_unit setVariable ["ARC_sitrep_lastGateReason", _reason];

_unit setVariable ["ARC_sitrep_canSendCached", _ok];
_ok
