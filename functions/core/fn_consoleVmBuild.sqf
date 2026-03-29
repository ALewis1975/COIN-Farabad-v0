/*
    ARC_fnc_consoleVmBuild

    Server-side: builds the Console VM v1 envelope from authoritative state.

    Reference: docs/architecture/Console_VM_v1.md

    The VM envelope provides a normalized, versioned snapshot of all console-relevant
    state in a single payload. Client UI tabs read from this structure instead of
    querying missionNamespace variables directly.

    Returns:
        ARRAY (pairs) - Console_VM_v1 envelope
*/

if (!isServer) exitWith { [] };

// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";

private _now = serverTime;

// --- Section: incident (active task state) ----------------------------------
private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _incType = ["activeIncidentType", ""] call ARC_fnc_stateGet;
if (!(_incType isEqualType "")) then { _incType = ""; };
private _incDisplay = ["activeIncidentDisplayName", ""] call ARC_fnc_stateGet;
if (!(_incDisplay isEqualType "")) then { _incDisplay = ""; };
private _incPos = ["activeIncidentPos", []] call ARC_fnc_stateGet;
if (!(_incPos isEqualType [])) then { _incPos = []; };
private _incAccepted = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
if (!(_incAccepted isEqualType true) && !(_incAccepted isEqualType false)) then { _incAccepted = false; };
private _closeReady = ["activeIncidentCloseReady", false] call ARC_fnc_stateGet;
if (!(_closeReady isEqualType true) && !(_closeReady isEqualType false)) then { _closeReady = false; };
private _sitrepSent = ["activeIncidentSitrepSent", false] call ARC_fnc_stateGet;
if (!(_sitrepSent isEqualType true) && !(_sitrepSent isEqualType false)) then { _sitrepSent = false; };
private _incZone = ["activeIncidentZone", ""] call ARC_fnc_stateGet;
if (!(_incZone isEqualType "")) then { _incZone = ""; };
private _incMarker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
if (!(_incMarker isEqualType "")) then { _incMarker = ""; };
private _createdAt = ["activeIncidentCreatedAt", -1] call ARC_fnc_stateGet;
if (!(_createdAt isEqualType 0)) then { _createdAt = -1; };
private _acceptedBy = ["activeIncidentAcceptedBy", ""] call ARC_fnc_stateGet;
if (!(_acceptedBy isEqualType "")) then { _acceptedBy = ""; };
private _acceptedAt = ["activeIncidentAcceptedAt", -1] call ARC_fnc_stateGet;
if (!(_acceptedAt isEqualType 0)) then { _acceptedAt = -1; };
private _suggestedResult = ["activeIncidentSuggestedResult", ""] call ARC_fnc_stateGet;
if (!(_suggestedResult isEqualType "")) then { _suggestedResult = ""; };
private _activeLeadId = ["activeLeadId", ""] call ARC_fnc_stateGet;
if (!(_activeLeadId isEqualType "")) then { _activeLeadId = ""; };
private _activeThreadId = ["activeThreadId", ""] call ARC_fnc_stateGet;
if (!(_activeThreadId isEqualType "")) then { _activeThreadId = ""; };
private _activeLeadTag = ["activeLeadTag", ""] call ARC_fnc_stateGet;
if (!(_activeLeadTag isEqualType "")) then { _activeLeadTag = ""; };

private _sectionIncident = [
    ["id", _taskId],
    ["displayName", _incDisplay],
    ["type", _incType],
    ["posATL", _incPos],
    ["zone", _incZone],
    ["marker", _incMarker],
    ["accepted", _incAccepted],
    ["acceptedBy", _acceptedBy],
    ["acceptedAt", _acceptedAt],
    ["closeReady", _closeReady],
    ["sitrepSent", _sitrepSent],
    ["suggestedResult", _suggestedResult],
    ["createdAt", _createdAt],
    ["leadId", _activeLeadId],
    ["threadId", _activeThreadId],
    ["leadTag", _activeLeadTag],
    ["updatedAt", _now],
    ["source", "ARC_state"],
    ["staleAfterS", 5]
];

// --- Section: followOn ------------------------------------------------------
private _foRequest = ["activeIncidentFollowOnRequest", []] call ARC_fnc_stateGet;
if (!(_foRequest isEqualType [])) then { _foRequest = []; };
private _foSummary = ["activeIncidentFollowOnSummary", ""] call ARC_fnc_stateGet;
if (!(_foSummary isEqualType "")) then { _foSummary = ""; };
private _foDetails = ["activeIncidentFollowOnDetails", ""] call ARC_fnc_stateGet;
if (!(_foDetails isEqualType "")) then { _foDetails = ""; };
private _foAt = ["activeIncidentFollowOnAt", -1] call ARC_fnc_stateGet;
if (!(_foAt isEqualType 0)) then { _foAt = -1; };

private _sectionFollowOn = [
    ["request", _foRequest],
    ["summary", _foSummary],
    ["details", _foDetails],
    ["at", _foAt],
    ["updatedAt", _now],
    ["source", "ARC_state"],
    ["staleAfterS", 10]
];

// --- Section: ops (queue, orders, intel, leads) -----------------------------
private _tocQueue = ["tocQueue", []] call ARC_fnc_stateGet;
if (!(_tocQueue isEqualType [])) then { _tocQueue = []; };
private _tocOrders = ["tocOrders", []] call ARC_fnc_stateGet;
if (!(_tocOrders isEqualType [])) then { _tocOrders = []; };
private _intelLog = ["intelLog", []] call ARC_fnc_stateGet;
if (!(_intelLog isEqualType [])) then { _intelLog = []; };
private _leadPool = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_leadPool isEqualType [])) then { _leadPool = []; };

// Tail the intel log for efficiency
private _logCount = count _intelLog;
private _logStart = (_logCount - 25) max 0;
private _logTail = _intelLog select [_logStart, _logCount - _logStart];

private _sectionOps = [
    ["queuePending", _tocQueue],
    ["ordersActive", _tocOrders],
    ["intelLogTail", _logTail],
    ["intelLogCount", _logCount],
    ["leadPool", _leadPool],
    ["leadPoolCount", count _leadPool],
    ["updatedAt", _now],
    ["source", "ARC_pub_state"],
    ["staleAfterS", 10]
];

// --- Section: stateSummary --------------------------------------------------
private _pairs = missionNamespace getVariable ["ARC_pub_state", []];
if (!(_pairs isEqualType [])) then { _pairs = []; };

private _sectionSummary = [
    ["pairs", _pairs],
    ["updatedAt", _now],
    ["source", "ARC_pub_state"],
    ["staleAfterS", 20]
];

// --- Section: access (config/tokens) ----------------------------------------
private _omniTokens = missionNamespace getVariable ["ARC_omniTokens", []];
if (!(_omniTokens isEqualType [])) then { _omniTokens = []; };
private _hqTokens = missionNamespace getVariable ["ARC_hqTokens", []];
if (!(_hqTokens isEqualType [])) then { _hqTokens = []; };

private _sectionAccess = [
    ["omniTokens", _omniTokens],
    ["hqTokens", _hqTokens],
    ["updatedAt", _now],
    ["source", "config"],
    ["staleAfterS", 60]
];

// --- Section: civsub --------------------------------------------------------
private _civEnabled = missionNamespace getVariable ["civsub_v1_enabled", false];
if (!(_civEnabled isEqualType true) && !(_civEnabled isEqualType false)) then { _civEnabled = false; };

private _sectionCivsub = [
    ["enabled", _civEnabled],
    ["updatedAt", _now],
    ["source", "civsub_v1"],
    ["staleAfterS", 120]
];

// --- Build envelope ---------------------------------------------------------
private _sections = createHashMap;
_sections set ["incident", _sectionIncident];
_sections set ["followOn", _sectionFollowOn];
_sections set ["ops", _sectionOps];
_sections set ["stateSummary", _sectionSummary];
_sections set ["access", _sectionAccess];
_sections set ["civsub", _sectionCivsub];

private _envelope = [
    ["schema", "Console_VM_v1"],
    ["version", [1, 0, 0]],
    ["builtAtServerTime", _now],
    ["sections", _sections]
];

_envelope
