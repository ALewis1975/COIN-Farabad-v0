/*
    Client helper for field SITREP addAction conditions.

    Enforces, client-side:
      - Active incident exists + accepted
      - SITREP not already sent
      - Player role authorized (RHSUSAF Officer / Squad Leader classnames)
      - Proximity to task/lead/convoy anchors (best-effort using public vars)

    Server is still authoritative (server repeats checks via ARC_fnc_sitrepGateEval).

    Uses ARC_fnc_sitrepGateEval as the shared rule engine so client and server
    cannot drift out of sync.
*/

params [["_unit", player]];
if (isNull _unit) exitWith {false};

// Fail-safe: ensure evaluator exists even if CfgFunctions.hpp was not yet updated.
if (isNil "ARC_fnc_sitrepGateEval") then {
    ARC_fnc_sitrepGateEval = compile preprocessFileLineNumbers "functions\\core\\fn_sitrepGateEval.sqf";
};

// Simple cache to avoid heavy work every frame (addAction conditions are evaluated often).
private _now = diag_tickTime;
private _next = _unit getVariable ["ARC_sitrep_canSendNext", 0];
if (_now < _next) exitWith { _unit getVariable ["ARC_sitrep_canSendCached", false] };
_unit setVariable ["ARC_sitrep_canSendNext", _now + 0.5];

// Build anchor list from public replicated vars (best-effort; server validates again)
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

// Delegate all gate logic to the shared evaluator.
// Pass _silent=true (param 5) to suppress diag_log breadcrumbs: this function is
// called from addAction condition evaluation (~2/sec) and in hosted MP sessions
// isServer is true on the player machine, producing log storms when the deny
// reason is unchanged. The server-authoritative path (fn_tocReceiveSitrep) always
// logs normally since it does not pass _silent.
// Params: [unit, anchors, prox, updateOnly=false, requestId="", silent=true]
private _result = [_unit, _anchors, _prox, false, "", true] call ARC_fnc_sitrepGateEval;
private _ok = (_result select 0);

// Cache the reason code alongside the bool so the UI can display a specific hint.
// Callers that only need a bool continue to work unchanged; the detail is available
// via ARC_sitrep_lastDenyReason for UI layers that want to show a specific message.
private _reasonCode = (_result select 1);
if (!(_reasonCode isEqualType "")) then { _reasonCode = ""; };
_unit setVariable ["ARC_sitrep_lastDenyReason", _reasonCode];

_unit setVariable ["ARC_sitrep_canSendCached", _ok];
_ok

