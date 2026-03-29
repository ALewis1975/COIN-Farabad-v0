/*
    Client-side: send a SITREP to TOC / server.

    Workflow intent:
      - Assignment -> Movement -> Maneuver -> (SITREP) -> Wait for higher (TOC closure)

    Params:
        0: STRING - recommendation: "SUCCEEDED" | "FAILED" | "" (optional)
        1: BOOL   - updateOnly (default false). If true, does NOT mark the incident
                   as ready-to-close; it only logs the SITREP to the OPS feed.

    Returns:
        BOOL
*/

if (!hasInterface) exitWith {false};

if (!canSuspend) exitWith { _this spawn ARC_fnc_clientSendSitrep; false };

// Fail-safe: ensure role helper functions exist even if CfgFunctions.hpp was not updated.
if (isNil "ARC_fnc_rolesIsAuthorized") then { ARC_fnc_rolesIsAuthorized = compile preprocessFileLineNumbers "functions\\core\\fn_rolesIsAuthorized.sqf"; };

params [
    ["_recommend", ""],
    ["_updateOnly", false]
];

private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""];
if (_taskId isEqualTo "") exitWith
{
    ["No active incident to SITREP.", "WARN", "TOAST"] call ARC_fnc_clientHint;
    false
};


// Gate SITREPs until the active incident has been accepted
if (!(missionNamespace getVariable ["ARC_activeIncidentAccepted", false])) exitWith
{
    ["Active incident has not been accepted yet.", "WARN", "TOAST"] call ARC_fnc_clientHint;
    false
};

// Prevent duplicate SITREPs for this incident
if (missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false]) exitWith
{
    ["SITREP already submitted for this incident.", "INFO", "TOAST"] call ARC_fnc_clientHint;
    false
};

// Gate closure SITREPs until the incident is ready to close (timer expired or objective complete).
// NOTE: IED incidents are allowed to submit earlier because TOC disposition/approval may be required
// before the incident reaches close-ready state. This mirrors server-side validation in
// ARC_fnc_tocReceiveSitrep and keeps client/server gating consistent.
private _iTypU = missionNamespace getVariable ["ARC_activeIncidentType", ""]; if (!(_iTypU isEqualType "")) then { _iTypU = ""; }; _iTypU = toUpper (trim _iTypU);
private _closeReady = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false];
if (!(_closeReady isEqualType true) && !(_closeReady isEqualType false)) then { _closeReady = false; };

private _recordClientGate = {
    params ["_reason", "_typeU", "_closeReadyV", "_updateOnlyV"];

    // Lightweight breadcrumb for diagnostics tooling / quick console inspection.
    missionNamespace setVariable ["ARC_sitrepClientLastGateReason", [_reason, _typeU, _closeReadyV, diag_tickTime]];

    // Keep RPT noise controllable: only emit when ARC debug logging is enabled.
    private _dbg = missionNamespace getVariable ["ARC_debugLogEnabled", false];
    if (!(_dbg isEqualType true)) then { _dbg = false; };
    if (_dbg) then
    {
        diag_log format ["[ARC][SITREP][CLIENT] Gate blocked: reason=%1 type=%2 closeReady=%3 updateOnly=%4", _reason, _typeU, _closeReadyV, _updateOnlyV];
    };
};

if (!_updateOnly && { !_closeReady } && { !(_iTypU isEqualTo "IED") }) exitWith
{
    ["NOT_CLOSE_READY", _iTypU, _closeReady, _updateOnly] call _recordClientGate;
    ["SITREP unavailable: incident still in progress. Complete the objective or wait for the incident timer to expire.", "WARN", "TOAST"] call ARC_fnc_clientHint;
    false
};

// Role + proximity gating (server re-checks; this is UX).
if !([player] call ARC_fnc_rolesIsAuthorized) exitWith
{
    ["You are not authorized to send SITREPs.", "ERROR", "BOTH"] call ARC_fnc_clientHint;
    false
};

if !([player] call ARC_fnc_clientCanSendSitrep) exitWith
{
    private _prox = missionNamespace getVariable ["ARC_sitrepProximityM", 350];
    if (!(_prox isEqualType 0)) then { _prox = 350; };
    [format ["SITREP unavailable: move within %1m of the active task / objective / convoy.", round _prox], "WARN", "TOAST"] call ARC_fnc_clientHint;
    false
};

private _disp = missionNamespace getVariable ["ARC_activeIncidentDisplayName", "Active Incident"];
private _type = missionNamespace getVariable ["ARC_activeIncidentType", ""];

private _pos = getPosATL player;
private _grid = mapGridPosition _pos;

private _recU = "";
if (_recommend isEqualType "") then
{
    _recU = toUpper _recommend;
    if !(_recU in ["SUCCEEDED", "FAILED"]) then { _recU = ""; };
};

private _prefix = if (_recU isEqualTo "") then { "SITREP" } else { format ["SITREP (%1)", _recU] };

private _defaultSummary = if (_type isEqualTo "") then
{
    format ["%1: %2 @ %3", _prefix, _disp, _grid]
}
else
{
    format ["%1: %2 (%3) @ %4", _prefix, _disp, _type, _grid]
};

private _hdr = format [
    "<t size='1.15' color='#FFFFFF'>%1</t><br/>" +
    "<t size='0.95' color='#DDDDDD'>%2</t><br/>" +
    "<t size='0.85' color='#AAAAAA'>Grid %3 | Use plain English + doctrinal acronyms. ACE uses GREEN / YELLOW / RED.</t>",
    _prefix,
    _disp,
    _grid
];

// Prompt user for a structured SITREP (segmented inputs)
private _res = [_hdr, _defaultSummary, "", "", "", [0,0,0], "", ""] call ARC_fnc_clientSitrepPrompt;
if (!(_res isEqualType []) || { (count _res) < 10 }) exitWith {false};

_res params ["_ok", "_sum", "_enemy", "_friendly", "_task", "_aceAmmo", "_aceCas", "_aceEq", "_req", "_notes"];
if (!_ok) exitWith {false};

_sum = trim _sum;
if (_sum isEqualTo "") then { _sum = _defaultSummary; };

private _gid = groupId group player;
if (!(_gid isEqualType "")) then { _gid = ""; };
private _from = if (_gid isEqualTo "") then { name player } else { format ["%1 (%2)", name player, _gid] };

private _detLines = [];
_detLines pushBack format ["FROM: %1", _from];
_detLines pushBack format ["LOCATION: %1", _grid];
if (!(_recU isEqualTo "")) then { _detLines pushBack format ["RECOMMEND: %1", _recU]; };

_detLines pushBack format ["ENEMY: %1", if (trim _enemy isEqualTo "") then {"N/A"} else {trim _enemy}];
_detLines pushBack format ["FRIENDLY: %1", if (trim _friendly isEqualTo "") then {"N/A"} else {trim _friendly}];

	// IED/EOD integration: include basic disposition status in SITREP details (informational only).
	private _typeU2 = toUpper (trim _type);
	if (_typeU2 isEqualTo "IED") then
	{
		private _eod = "PENDING";
		private _closeReady = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false];
		if (!(_closeReady isEqualType true) && !(_closeReady isEqualType false)) then { _closeReady = false; };
		if (_closeReady) then { _eod = "CLEARED (OBJECTIVE COMPLETE)"; };

		private _evCol = missionNamespace getVariable ["ARC_activeIedEvidenceCollected", false];
		if (!(_evCol isEqualType true) && !(_evCol isEqualType false)) then { _evCol = false; };
		if (!_closeReady && _evCol) then { _eod = "EVIDENCE COLLECTED (DEVICE PENDING)"; };

		_detLines pushBack format ["EOD: %1", _eod];
	};
_detLines pushBack format ["TASK: %1", if (trim _task isEqualTo "") then {"N/A"} else {trim _task}];
_detLines pushBack format ["ACE: AMMO=%1 | CAS=%2 | EQUIP=%3", _aceAmmo, _aceCas, _aceEq];
_detLines pushBack format ["REQUESTS: %1", if (trim _req isEqualTo "") then {"N/A"} else {trim _req}];
if (trim !(_notes isEqualTo "")) then { _detLines pushBack format ["NOTES: %1", trim _notes]; };

private _det = _detLines joinString "\n";

// Integrated follow-on request (optional) for closure SITREPs.
private _foReq = "";
private _foPurpose = "";
private _foRationale = "";
private _foConstraints = "";
private _foSupport = "";
private _foNotes = "";
private _foHoldIntent = "";
private _foHoldMinutes = -1;
private _foProceedIntent = "";

if (!_updateOnly) then
{
    // Prompt the unit for a follow-on request as part of the SITREP flow.
    // Apply closure SITREP defaults for the follow-on dialog (field units should not default to PROCEED/NEXT TASK).
    private _prevDefaults = [
        uiNamespace getVariable ["ARC_followOn_defaultRequest", nil],
        uiNamespace getVariable ["ARC_followOn_defaultPurpose", nil],
        uiNamespace getVariable ["ARC_followOn_defaultRationale", nil],
        uiNamespace getVariable ["ARC_followOn_defaultConstraints", nil],
        uiNamespace getVariable ["ARC_followOn_defaultSupport", nil],
        uiNamespace getVariable ["ARC_followOn_defaultNotes", nil],
        uiNamespace getVariable ["ARC_followOn_defaultHoldIntent", nil],
        uiNamespace getVariable ["ARC_followOn_defaultHoldMinutes", nil],
        uiNamespace getVariable ["ARC_followOn_defaultProceedIntent", nil]
    ];

    uiNamespace setVariable ["ARC_followOn_defaultRequest", "HOLD"];
    uiNamespace setVariable ["ARC_followOn_defaultHoldIntent", "SECURITY"];
    uiNamespace setVariable ["ARC_followOn_defaultHoldMinutes", 30];

    private _fo = [] call ARC_fnc_uiFollowOnPrompt;
    // Restore previous defaults (TOC order workflows may override these).
    // Inline restore avoids variable case-sensitivity regressions (e.g., _dreq vs _dReq).
    uiNamespace setVariable ["ARC_followOn_defaultRequest",     _prevDefaults param [0, nil]];
    uiNamespace setVariable ["ARC_followOn_defaultPurpose",     _prevDefaults param [1, nil]];
    uiNamespace setVariable ["ARC_followOn_defaultRationale",   _prevDefaults param [2, nil]];
    uiNamespace setVariable ["ARC_followOn_defaultConstraints", _prevDefaults param [3, nil]];
    uiNamespace setVariable ["ARC_followOn_defaultSupport",     _prevDefaults param [4, nil]];
    uiNamespace setVariable ["ARC_followOn_defaultNotes",       _prevDefaults param [5, nil]];
    uiNamespace setVariable ["ARC_followOn_defaultHoldIntent",  _prevDefaults param [6, nil]];
    uiNamespace setVariable ["ARC_followOn_defaultHoldMinutes", _prevDefaults param [7, nil]];
    uiNamespace setVariable ["ARC_followOn_defaultProceedIntent",_prevDefaults param [8, nil]];


    if (_fo isEqualType [] && { (count _fo) >= 10 }) then
    {
        _fo params ["_okFo", "_r", "_p", "_rat", "_con", "_sup", "_n", "_hIntent", "_hMin", "_pIntent"];
        if (!_okFo) exitWith {
            diag_log format ["[ARC][SITREP][CLIENT] Follow-on cancelled -> SITREP aborted | taskId=%1", missionNamespace getVariable ["ARC_activeTaskId", ""]];
            ["SITREP cancelled.", "INFO", "TOAST"] call ARC_fnc_clientHint;
            false
        };
        if (_okFo) then
        {
            if (_r isEqualType "") then { _foReq = toUpper (trim _r); };
            if (_p isEqualType "") then { _foPurpose = toUpper (trim _p); };
            if (_rat isEqualType "") then { _foRationale = trim _rat; };
            if (_con isEqualType "") then { _foConstraints = trim _con; };
            if (_sup isEqualType "") then { _foSupport = trim _sup; };
            if (_n isEqualType "") then { _foNotes = trim _n; };
            if (_hIntent isEqualType "") then { _foHoldIntent = trim _hIntent; };
            if (_hMin isEqualType 0) then { _foHoldMinutes = _hMin; };
            if (_pIntent isEqualType "") then { _foProceedIntent = trim _pIntent; };
        };
    };
};

// Send to server / TOC
[player, _recU, _sum, _det, _pos, _updateOnly, _foReq, _foPurpose, _foRationale, _foConstraints, _foSupport, _foNotes, _foHoldIntent, _foHoldMinutes, _foProceedIntent] remoteExec ["ARC_fnc_tocReceiveSitrep", 2];

// Hide SITREP options immediately for the sender (server will broadcast the authoritative flag).
// Do not set ARC_activeIncidentSitrepSent client-side.
// The server will broadcast authoritative SITREP state; keeping the option visible avoids false-lockouts.
missionNamespace setVariable ["ARC_activeIncidentSitrepSentPending", true];
missionNamespace setVariable ["ARC_activeIncidentSitrepSentPendingAt", diag_tickTime];

["SITREP", "SUBMITTING", "", 10] call ARC_fnc_uiConsoleOpsActionStatus;
true
