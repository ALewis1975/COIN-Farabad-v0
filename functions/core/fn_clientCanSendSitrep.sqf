/*
    Client helper for field SITREP addAction conditions.

    Enforces, client-side:
      - Active incident exists + accepted
      - SITREP not already sent
      - Player role authorized (RHSUSAF Officer / Squad Leader classnames)
      - Proximity to task/lead/convoy anchors (best-effort using public vars)

    Server is still authoritative (server repeats role + proximity checks).
*/

params [["_unit", player]];
if (isNull _unit) exitWith {false};

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";

// Fail-safe: ensure role helper functions exist even if CfgFunctions.hpp was not updated.
if (isNil "ARC_fnc_rolesIsAuthorized") then { ARC_fnc_rolesIsAuthorized = compile preprocessFileLineNumbers "functions\\core\\fn_rolesIsAuthorized.sqf"; };

// Simple cache to avoid heavy work every frame (addAction conditions are evaluated often).
private _now = diag_tickTime;
private _next = _unit getVariable ["ARC_sitrep_canSendNext", 0];
if (_now < _next) exitWith { _unit getVariable ["ARC_sitrep_canSendCached", false] };
_unit setVariable ["ARC_sitrep_canSendNext", _now + 0.5];

private _ok = true;

if ((missionNamespace getVariable ["ARC_activeTaskId", ""]) isEqualTo "") then { _ok = false; };
if !(missionNamespace getVariable ["ARC_activeIncidentAccepted", false]) then { _ok = false; };
private _typU = missionNamespace getVariable ["ARC_activeIncidentType", ""]; if (!(_typU isEqualType "")) then { _typU = ""; }; _typU = toUpper ([_typU] call _trimFn);
if !(_typU in ["IED"]) then {
    if !(missionNamespace getVariable ["ARC_activeIncidentCloseReady", false]) then { _ok = false; };
};
if (missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false]) then { _ok = false; };

if (_ok && { !([_unit] call ARC_fnc_rolesIsAuthorized) }) then { _ok = false; };

if (_ok) then
{
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
        _ok = false;
        private _uPos = getPosATL _unit;
        {
            if ((_uPos distance2D _x) <= _prox) exitWith { _ok = true; };
        } forEach _anchors;
    };
};

_unit setVariable ["ARC_sitrep_canSendCached", _ok];
_ok
