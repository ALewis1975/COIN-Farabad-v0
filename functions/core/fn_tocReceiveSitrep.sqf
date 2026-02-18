/*
    Server: receive a field SITREP from a player.

    Behavior:
      1) Logs the SITREP into the OPS log (no map marker clutter).
      2) Captures the reporting unit identity (group + player name) for traceability.
      3) Enforces "one SITREP per incident" so the workflow stays clean.
      4) Optionally (if updateOnly=false and recommendation provided) marks the
         active incident as ready to close (TOC still closes manually).

    Params:
        0: OBJECT - reporting unit (player)
        1: STRING - recommendation: "SUCCEEDED" | "FAILED" | "" (optional)
        2: STRING - summary
        3: STRING - details (optional)
        4: ARRAY  - posATL (optional)
        5: BOOL   - updateOnly (default false)

    Returns:
        BOOL
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };

// Fail-safe: ensure role helper functions exist even if CfgFunctions.hpp was not updated.
if (isNil "ARC_fnc_rolesIsAuthorized") then { ARC_fnc_rolesIsAuthorized = compile preprocessFileLineNumbers "functions\\core\\fn_rolesIsAuthorized.sqf"; };
if (isNil "ARC_fnc_rolesGetTag") then { ARC_fnc_rolesGetTag = compile preprocessFileLineNumbers "functions\\core\\fn_rolesGetTag.sqf"; };
if (isNil "ARC_fnc_rolesFormatUnit") then { ARC_fnc_rolesFormatUnit = compile preprocessFileLineNumbers "functions\\core\\fn_rolesFormatUnit.sqf"; };

params [
    ["_unit", objNull],
    ["_recommend", ""],
    ["_summary", ""],
    ["_details", ""],
    ["_posATL", [0,0,0]],
    ["_updateOnly", false],

    // Optional: integrated follow-on request submitted as part of the SITREP workflow (UI10+)
    ["_foRequest", ""],
    ["_foPurpose", ""],
    ["_foRationale", ""],
    ["_foConstraints", ""],
    ["_foSupport", ""],
    ["_foNotes", ""],
    ["_foHoldIntent", ""],
    ["_foHoldMinutes", -1],
    ["_foProceedIntent", ""]
];

// RemoteExec-only validation path: requires remoteExecutedOwner context.
if (!([_unit, "ARC_fnc_tocReceiveSitrep", "SITREP rejected: sender verification failed.", "TOC_SITREP_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (_taskId isEqualTo "") exitWith {false};

private _accepted = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
if (!(_accepted isEqualType true)) then { _accepted = false; };
if (!_accepted) exitWith {false};

// Role-gated SITREPs (RHSUSAF Officer / Squad Leader classnames).
if (!isNull _unit && { !([_unit] call ARC_fnc_rolesIsAuthorized) }) exitWith
{
    private _whoBad = [_unit] call ARC_fnc_rolesFormatUnit;
    diag_log format ["[ARC][SITREP] Rejecting SITREP from unauthorized role: %1", _whoBad];
    ["You are not authorized to send ARC SITREPs. Authorized: RHSUSAF Officer / Squad Leader classnames."] remoteExec ["ARC_fnc_clientHint", owner _unit];
    false
};

// Closure SITREPs are only accepted once the incident is ready to close (end-state reached).
// Exception: IED/VBIED incidents may submit SITREP earlier to request TOC permission/disposition.
private _closeReady = ["activeIncidentCloseReady", false] call ARC_fnc_stateGet;
if (!(_closeReady isEqualType true)) then { _closeReady = false; };

private _tU = toUpper (trim (["activeIncidentType", ""] call ARC_fnc_stateGet));
if (!_updateOnly && { !_closeReady } && { _tU isNotEqualTo "IED" }) exitWith
{
    private _msg = "SITREP rejected: incident still in progress. Complete the objective or wait for the incident timer to expire.";
    if (!isNull _unit) then { [_msg] remoteExec ["ARC_fnc_clientHint", owner _unit]; };
    false
};


// One SITREP per incident
private _alreadySent = ["activeIncidentSitrepSent", false] call ARC_fnc_stateGet;
if (!(_alreadySent isEqualType true)) then { _alreadySent = false; };
if (_alreadySent) exitWith
{
    // Silently reject duplicates to avoid spam/race conditions.
    false
};

// Identify sender (prefer group ID + player name)
private _pName = "UNKNOWN";
private _grpId = "";
private _uid = "";
private _sideTxt = "";

if (!isNull _unit) then
{
    _pName = name _unit;
    _uid = getPlayerUID _unit;

    private _g = group _unit;
    if (!isNull _g) then
    {
        _grpId = groupId _g;
        _sideTxt = str (side _g);
    };
};

private _from = if (isNull _unit) then { _pName } else { [_unit] call ARC_fnc_rolesFormatUnit };

private _recU = "";
if (_recommend isEqualType "") then
{
    _recU = toUpper _recommend;
    if !(_recU in ["SUCCEEDED", "FAILED"]) then { _recU = ""; };
};

if (!(_summary isEqualType "")) then { _summary = ""; };
if (!(_details isEqualType "")) then { _details = ""; };
_summary = trim _summary;
_details = trim _details;

// Position resolution: prefer actual sender position (prevents spoofed client coords).
private _pos = if (!isNull _unit) then { getPosATL _unit } else { _posATL };
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then
{
    _pos = ["activeIncidentPos", [0,0,0]] call ARC_fnc_stateGet;
};
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
_pos = +_pos; _pos resize 3;

// Proximity enforcement: SITREPs only from near the task / lead / convoy.
private _prox = missionNamespace getVariable ["ARC_sitrepProximityM", 350];
if (!(_prox isEqualType 0)) then { _prox = 350; };
_prox = (_prox max 100) min 2000;

private _execRad = ["activeExecRadius", 0] call ARC_fnc_stateGet;
if (_execRad isEqualType 0 && { _execRad > 0 }) then
{
    _prox = (_prox max (_execRad + 100));
};

private _anchors = [];
{
    private _p = [_x, []] call ARC_fnc_stateGet;
    if (_p isEqualType [] && { (count _p) >= 2 }) then
    {
        private _pp = +_p;
        _pp resize 3;
        _anchors pushBack _pp;
    };
} forEach ["activeIncidentPos", "activeExecPos", "activeObjectivePos", "activeConvoyLinkupPos", "activeConvoyIngressPos"];

// Route recon: allow SITREP from the route start/end anchors (not just the incident center).
private _k = ["activeExecKind", ""] call ARC_fnc_stateGet;
if (_k isEqualType "" && { (toUpper _k) isEqualTo "ROUTE_RECON" }) then
{
    {
        private _p = [_x, []] call ARC_fnc_stateGet;
        if (_p isEqualType [] && { (count _p) >= 2 }) then
        {
            private _pp = +_p;
            _pp resize 3;
            _anchors pushBack _pp;
        };
    } forEach ["activeReconRouteStartPos", "activeReconRouteEndPos"];
};


private _nids = ["activeConvoyNetIds", []] call ARC_fnc_stateGet;
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

private _nearOk = true;
if ((count _anchors) > 0) then
{
    _nearOk = false;
    {
        if ((_pos distance2D _x) <= _prox) exitWith { _nearOk = true; };
    } forEach _anchors;
};

if (!_nearOk) exitWith
{
    private _msg = format ["SITREP rejected: you must be within %1m of the active task / objective / convoy to send a SITREP.", round _prox];
    if (!isNull _unit) then { [_msg] remoteExec ["ARC_fnc_clientHint", owner _unit]; };
    false
};

private _grid = "";
if !((_pos # 0) isEqualTo 0 && {(_pos # 1) isEqualTo 0}) then
{
    _grid = mapGridPosition _pos;
};

// Phase 6: CIVSUB SITREP annex (contract: include for every SITREP when CIVSUB is enabled)
private _civAnnex = "";
if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
{
    // Clear prior annex (prevents stale value if we cannot resolve a district)
    ["activeIncidentSitrepAnnexCivsub", ""] call ARC_fnc_stateSet;
    missionNamespace setVariable ["ARC_activeIncidentSitrepAnnexCivsub", "", true];

    // Fail-safe compile if mission was patched without a full restart
    if (isNil "ARC_fnc_civsubSitrepAnnexBuild") then { ARC_fnc_civsubSitrepAnnexBuild = compile preprocessFileLineNumbers "functions\civsub\fn_civsubSitrepAnnexBuild.sqf"; };
    if (isNil "ARC_fnc_civsubDistrictsFindByPos") then { ARC_fnc_civsubDistrictsFindByPos = compile preprocessFileLineNumbers "functions\civsub\fn_civsubDistrictsFindByPos.sqf"; };

    // Resolution chain (server authoritative):
    //  1) district by SITREP position
    //  2) incident-owned district captured at acceptance
    //  3) explicit UNKNOWN-district fallback annex (never empty)
    private _didC = [_pos] call ARC_fnc_civsubDistrictsFindByPos;
    if (!(_didC isEqualType "")) then { _didC = ""; };
    _didC = toUpper (trim _didC);

    if (_didC isEqualTo "") then
    {
        _didC = ["activeIncidentCivsubDistrictId", ""] call ARC_fnc_stateGet;
        if (!(_didC isEqualType "")) then { _didC = ""; };
        _didC = toUpper (trim _didC);
    };

    if (_didC isNotEqualTo "") then
    {
        _civAnnex = [_didC, _pos] call ARC_fnc_civsubSitrepAnnexBuild;
        if (!(_civAnnex isEqualType "")) then { _civAnnex = ""; };
        _civAnnex = trim _civAnnex;
    };

    // Contract-safe fallback when district cannot be resolved or builder returns blank.
    if (_civAnnex isEqualTo "") then
    {
        private _gridSafe = if (_grid isEqualTo "") then { "UNKNOWN" } else { _grid };
        _civAnnex = [
            "CIVSUB ANNEX",
            "District: UNKNOWN",
            format ["Reference grid: %1", _gridSafe],
            "Influence delta dW/dR/dG: N/A (district unresolved)",
            "Civilian casualties / Crime DB / Detentions / Aid: N/A (district unresolved)"
        ] joinString "\n";
    };

    // Store separately so UI can show it without parsing details blob
    ["activeIncidentSitrepAnnexCivsub", _civAnnex] call ARC_fnc_stateSet;
    missionNamespace setVariable ["ARC_activeIncidentSitrepAnnexCivsub", _civAnnex, true];

    // Also append to details for archival
    if (_details isEqualTo "") then { _details = _civAnnex; } else { _details = _details + "\n\n" + _civAnnex; };
};

// Persist SITREP gating and capture sender + payload (useful for debugging / after restart)
["activeIncidentSitrepSent", true] call ARC_fnc_stateSet;
["activeIncidentSitrepSentAt", serverTime] call ARC_fnc_stateSet;
["activeIncidentSitrepFrom", _from] call ARC_fnc_stateSet;
["activeIncidentSitrepFromUID", _uid] call ARC_fnc_stateSet;
["activeIncidentSitrepFromGroup", _grpId] call ARC_fnc_stateSet;
["activeIncidentSitrepFromRoleTag", if (isNull _unit) then {""} else { [_unit] call ARC_fnc_rolesGetTag }] call ARC_fnc_stateSet;
["activeIncidentSitrepSummary", _summary] call ARC_fnc_stateSet;
["activeIncidentSitrepDetails", _details] call ARC_fnc_stateSet;

// Remember last SITREP context (useful for follow-on orders even after closure).
["lastSitrepFrom", _from] call ARC_fnc_stateSet;
["lastSitrepFromGroup", _grpId] call ARC_fnc_stateSet;
["lastSitrepAt", serverTime] call ARC_fnc_stateSet;

// Broadcast lightweight state for UI/menu gating (clients don't have full server state).
missionNamespace setVariable ["ARC_activeIncidentSitrepSent", true, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepSentAt", serverTime, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepFrom", _from, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepFromGroup", _grpId, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepSummary", _summary, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepDetails", _details, true];


// Optional: capture a structured follow-on request (submitted in the same flow as the SITREP)
private _foReqU = "";
if (_foRequest isEqualType "") then
{
    _foReqU = toUpper (trim _foRequest);
    if !(_foReqU in ["RTB", "HOLD", "PROCEED"]) then { _foReqU = ""; };
};

if (!_updateOnly && { _foReqU isNotEqualTo "" }) then
{
    // Use the SITREP reporting group string as the follow-on "from group" identifier.
    private _groupId = _grpId;
    if !(_groupId isEqualType "") then { _groupId = ""; };

    // Build payload pairs (matches FOLLOWON_REQUEST queue schema)
    private _fo = [];
    private _setPair = {
        params ["_arr", "_k", "_v"];
        private _i = _arr findIf { _x isEqualType [] && { (count _x) == 2 } && { (_x # 0) isEqualTo _k } };
        if (_i >= 0) then { _arr set [_i, [_k, _v]]; } else { _arr pushBack [_k, _v]; };
        _arr
    };

    _fo = [_fo, "request", _foReqU] call _setPair;

    // RTB purpose (REFIT/INTEL/EPW)
    private _pU = "";
    if (_foPurpose isEqualType "") then
    {
        _pU = toUpper (trim _foPurpose);
        if !(_pU in ["REFIT", "INTEL", "EPW"]) then { _pU = ""; };
    };
    if (_pU isNotEqualTo "") then { _fo = [_fo, "purpose", _pU] call _setPair; };

    // Optional narrative fields
    if (_foRationale isEqualType "" && { (trim _foRationale) isNotEqualTo "" }) then { _fo = [_fo, "rationale", trim _foRationale] call _setPair; };
    if (_foConstraints isEqualType "" && { (trim _foConstraints) isNotEqualTo "" }) then { _fo = [_fo, "constraints", trim _foConstraints] call _setPair; };
    if (_foSupport isEqualType "" && { (trim _foSupport) isNotEqualTo "" }) then { _fo = [_fo, "support", trim _foSupport] call _setPair; };
    if (_foNotes isEqualType "" && { (trim _foNotes) isNotEqualTo "" }) then { _fo = [_fo, "notes", trim _foNotes] call _setPair; };

    // HOLD/PROCEED specifics
    if (_foHoldIntent isEqualType "" && { (trim _foHoldIntent) isNotEqualTo "" }) then { _fo = [_fo, "holdIntent", trim _foHoldIntent] call _setPair; };
    if (_foHoldMinutes isEqualType 0 && { _foHoldMinutes > 0 }) then { _fo = [_fo, "holdMinutes", _foHoldMinutes] call _setPair; };
    if (_foProceedIntent isEqualType "" && { (trim _foProceedIntent) isNotEqualTo "" }) then { _fo = [_fo, "proceedIntent", trim _foProceedIntent] call _setPair; };

    // Keep a server-side copy for TOC closeout logic + UI display.
    ["activeIncidentFollowOnRequest", _fo] call ARC_fnc_stateSet;

    // Compose a compact summary line for TOC.
    private _foSum = format [
        "FOLLOW-ON REQUEST (%1): %2%3",
        _groupId,
        _foReqU,
        if (_foReqU isEqualTo "RTB" && { _pU isNotEqualTo "" }) then { format [" (%1)", _pU] } else { "" }
    ];

    // Compose details from the structured fields.
    private _foDet = "";
    {
        if (_x isEqualType [] && { (count _x) == 2 }) then
        {
            private _k = _x # 0;
            private _v = _x # 1;
            if (_v isEqualType "" && { (trim _v) isNotEqualTo "" }) then
            {
                _foDet = _foDet + format ["%1: %2\n", toUpper _k, trim _v];
            }
            else
            {
                if (_v isEqualType 0 && { _v > 0 }) then
                {
                    _foDet = _foDet + format ["%1: %2\n", toUpper _k, _v];
                };
            };
        };
    } forEach _fo;
    _foDet = trim _foDet;

    // Informational only: store with the incident so TOC can review during closeout.
    // Do NOT create a TOC approval queue item.
    private _qid = "";

    ["activeIncidentFollowOnQueueId", _qid] call ARC_fnc_stateSet;
    ["activeIncidentFollowOnSummary", _foSum] call ARC_fnc_stateSet;
    ["activeIncidentFollowOnDetails", _foDet] call ARC_fnc_stateSet;
    ["activeIncidentFollowOnFromGroup", _groupId] call ARC_fnc_stateSet;
    ["activeIncidentFollowOnAt", serverTime] call ARC_fnc_stateSet;

    missionNamespace setVariable ["ARC_activeIncidentFollowOnRequest", _fo, true];
    missionNamespace setVariable ["ARC_activeIncidentFollowOnQueueId", _qid, true];
    missionNamespace setVariable ["ARC_activeIncidentFollowOnSummary", _foSum, true];
    missionNamespace setVariable ["ARC_activeIncidentFollowOnDetails", _foDet, true];
    missionNamespace setVariable ["ARC_activeIncidentFollowOnFromGroup", _groupId, true];
    missionNamespace setVariable ["ARC_activeIncidentFollowOnAt", serverTime, true];
};

// Compose log line
private _head = if (_recU isEqualTo "") then { "SITREP" } else { format ["SITREP (%1)", _recU] };
private _where = if (_grid isEqualTo "") then { "" } else { format [" (%1)", _grid] };

private _line = if (_summary isEqualTo "") then
{
    format ["%1 from %2%3.", _head, _from, _where]
}
else
{
    format ["%1 from %2%3: %4", _head, _from, _where, _summary]
};

private _meta = [
    ["event", "SITREP"],
    ["taskId", _taskId],
    ["from", _from],
    ["fromName", _pName],
    ["fromGroup", _grpId],
    ["fromUID", _uid],
    ["fromSide", _sideTxt]
];

if (_recU isNotEqualTo "") then { _meta pushBack ["recommend", _recU]; };
if (_details isNotEqualTo "") then { _meta pushBack ["details", _details]; };

// Log to OPS (OPS entries have no marker clutter; now displayed in ARC_OPS dashboard)
["OPS", _line, _pos, _meta] call ARC_fnc_intelLog;

// If the reporting unit is declaring completion/failure, move the incident into
// the "SITREP -> wait for higher" phase (TOC closure remains manual).
if (!_updateOnly && { _recU in ["SUCCEEDED", "FAILED"] }) then
{
    private _detail = if (_details isEqualTo "") then
    {
        format ["SITREP received from %1. Recommended: %2.", _from, _recU]
    }
    else
    {
        format ["SITREP received from %1. Recommended: %2. Details: %3", _from, _recU, _details]
    };

    [_recU, "SITREP", _detail, _pos] call ARC_fnc_incidentMarkReadyToClose;
};

// Persist after SITREP so restarts preserve the gating and the audit trail
[] call ARC_fnc_stateSave;

// Phase 6: force-save CIVSUB on SITREP submission (best-effort)
if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
{
    if (!isNil "ARC_fnc_civsubPersistSave") then { [] call ARC_fnc_civsubPersistSave; };
};

true
