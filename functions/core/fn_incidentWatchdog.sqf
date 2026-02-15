/*
    ARC_fnc_incidentWatchdog

    Server-side stall detector for the active incident.
    This does NOT auto-close incidents by default.
    It only marks the incident as "ready to close" and provides:
      - activeIncidentCloseReason
      - activeIncidentSuggestedResult
      - activeIncidentCloseMarkedAt

    Config (missionNamespace, server authoritative; set before/after bootstrap):
      ARC_wd_enabled            BOOL   (default true)
      ARC_wd_graceSeconds       NUMBER (default 120)  // don't evaluate immediately after creation
      ARC_wd_unacceptedTimeout  NUMBER (default 900)  // seconds since created
      ARC_wd_acceptedTimeout    NUMBER (default 1800) // seconds since last progress / accepted
      ARC_wd_suggestResult      STRING (default "FAILED") // suggested close result
      ARC_wd_debugLog           BOOL   (default false) // extra diag_log noise

    Notes:
      - Keeps logic intentionally "boring" and conservative.
      - Uses existing ARC_state keys; does not mutate anything beyond close-ready suggestion fields.
*/

if (!isServer) exitWith {false};

private _enabled = missionNamespace getVariable ["ARC_wd_enabled", true];
if !(_enabled isEqualType true) then { _enabled = true; };
if (!_enabled) exitWith {false};

private _dbg = missionNamespace getVariable ["ARC_wd_debugLog", false];
if !(_dbg isEqualType true) then { _dbg = false; };

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (_taskId isEqualTo "") exitWith {false};

private _created = ["activeIncidentCreatedAt", -1] call ARC_fnc_stateGet;
if !(_created isEqualType 0) then { _created = -1; };
if (_created < 0) exitWith {false};

private _now = serverTime;
private _age = _now - _created;

private _grace = missionNamespace getVariable ["ARC_wd_graceSeconds", 120];
if !(_grace isEqualType 0) then { _grace = 120; };
if (_age < _grace) exitWith {false};

private _already = ["activeIncidentCloseReady", false] call ARC_fnc_stateGet;
if (_already isEqualType true && { _already }) exitWith {true};

private _suggest = missionNamespace getVariable ["ARC_wd_suggestResult", "FAILED"];
if !(_suggest isEqualType "") then { _suggest = "FAILED"; };

private _mark = {
    params ["_suggestedResult", "_reason"];

    ["activeIncidentCloseReady", true] call ARC_fnc_stateSet;
    ["activeIncidentSuggestedResult", _suggestedResult] call ARC_fnc_stateSet;
    ["activeIncidentCloseReason", _reason] call ARC_fnc_stateSet;
    ["activeIncidentCloseMarkedAt", serverTime] call ARC_fnc_stateSet;

    // Publish updated snapshot so clients (briefing/TOC) can reflect the suggestion.
    if (!isNil "ARC_fnc_publicBroadcastState") then { [] call ARC_fnc_publicBroadcastState; };

    diag_log format ["[ARC][WD] Incident %1 marked close-ready (suggest=%2 reason=%3)", _taskId, _suggestedResult, _reason];
};

private _accepted = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
if !(_accepted isEqualType true) then { _accepted = false; };

if (!_accepted) then
{
    private _t = missionNamespace getVariable ["ARC_wd_unacceptedTimeout", 900];
    if !(_t isEqualType 0) then { _t = 900; };

    if (_age >= _t) then
    {
        private _mins = round (_age / 60);
        [_suggest, format ["Unaccepted for %1 min", _mins]] call _mark;
        true
    }
    else
    {
        if (_dbg) then { diag_log format ["[ARC][WD][DBG] Incident %1 not accepted yet (age=%2s < %3s)", _taskId, _age, _t]; };
        false
    };
}
else
{
    // Prefer progress marker if available; fall back to acceptedAt/createdAt.
    private _lastProg = ["activeExecLastProg", -1] call ARC_fnc_stateGet;
    if !(_lastProg isEqualType 0) then { _lastProg = -1; };

    private _acceptedAt = ["activeIncidentAcceptedAt", -1] call ARC_fnc_stateGet;
    if !(_acceptedAt isEqualType 0) then { _acceptedAt = -1; };

    private _stallAge = -1;
    if (_lastProg >= 0) then { _stallAge = _now - _lastProg; }
    else
    {
        if (_acceptedAt >= 0) then { _stallAge = _now - _acceptedAt; }
        else { _stallAge = _age; };
    };

    private _t = missionNamespace getVariable ["ARC_wd_acceptedTimeout", 1800];
    if !(_t isEqualType 0) then { _t = 1800; };

    if (_stallAge >= _t) then
    {
        private _mins = round (_stallAge / 60);
        [_suggest, format ["No progress for %1 min", _mins]] call _mark;
        true
    }
    else
    {
        if (_dbg) then { diag_log format ["[ARC][WD][DBG] Incident %1 accepted; stallAge=%2s < %3s", _taskId, _stallAge, _t]; };
        false
    };
};
