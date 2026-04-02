/*
    ARC_fnc_uiConsoleActionHQPrimary

    UI09: Primary action for Headquarters (Admin) tab.
    Executes the selected admin tool.
*/

if (!hasInterface) exitWith {false};

// UI event handlers are unscheduled; BIS_fnc_guiMessage requires scheduled.
if (!canSuspend) exitWith { _this spawn ARC_fnc_uiConsoleActionHQPrimary; false };

private _disp = findDisplay 78000;
if (isNull _disp) exitWith {false};

private _list = _disp displayCtrl 78011;
if (isNull _list) exitWith {false};

private _sel = lbCurSel _list;
if (_sel < 0) exitWith {false};

private _data = toUpper (_list lbData _sel);
if (_data isEqualTo "" || { _data isEqualTo "HDR" }) exitWith {false};

private _hqMode = ["ARC_console_hqMode", "TOOLS"] call ARC_fnc_uiNsGetString;
_hqMode = toUpper _hqMode;

// INCIDENT PICKER mode: spawn selected catalog incident.
if (_hqMode isEqualTo "INCIDENTS") exitWith
{
    private _raw = _list lbData _sel;
    if (!(_raw isEqualType "")) then { _raw = ""; };
    if (_raw isEqualTo "" || { (toUpper _raw) isEqualTo "HDR" }) exitWith {false};

    private _parts = _raw splitString "|";
    if ((count _parts) < 3) exitWith
    {
        ["HQ", "Invalid incident selection."] call ARC_fnc_clientToast;
        false
    };

    private _mkr = _parts # 0;
    private _typ = _parts # 1;
    private _disp = _parts # 2;

    // Do not spam while an incident is active.
    private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""]; 
    if (!(_taskId isEqualType "")) then { _taskId = ""; };
    if (_taskId isNotEqualTo "") exitWith
    {
        ["HQ", "An incident is already active. Close it (and complete SITREP) before spawning a new one."] call ARC_fnc_clientToast;
        false
    };

    private _ok = [
        format ["Spawn incident now?\n\n%1\nType: %2\nMarker: %3", _disp, toUpper _typ, _mkr],
        "HQ / INCIDENT PICKER",
        true,
        true
    ] call BIS_fnc_guiMessage;

    if (!_ok) exitWith {false};

    [player, _mkr, _disp, _typ] remoteExec ["ARC_fnc_tocRequestForceIncident", 2];
    ["HQ", "Incident spawn requested (server)."] call ARC_fnc_clientToast;
    true
};

switch (_data) do
{
    case "ADMIN_INCIDENTS":
    {
        uiNamespace setVariable ["ARC_console_hqMode", "INCIDENTS"];
        private _disp = findDisplay 78000;
        if (!isNull _disp) then { [_disp, true] call ARC_fnc_uiConsoleHQPaint; };
        ["HQ", "Incident picker opened."] call ARC_fnc_clientToast;
    };

    case "ADMIN_SAVE":
    {
        [] remoteExec ["ARC_fnc_tocRequestSave", 2];
        ["HQ", "Save requested (server persistence)."] call ARC_fnc_clientToast;
    };

    case "ADMIN_SCORE":
    {
        [player] remoteExec ["ARC_fnc_missionScoreGenerate", 2];
        ["HQ", "COIN score report requested (server). Report will appear in this pane."] call ARC_fnc_clientToast;
    };

    case "ADMIN_CIVSUB_SAVE":
    {
        [player] remoteExec ["ARC_fnc_tocRequestCivsubSave", 2];
        ["HQ", "CIVSUB save requested (server)."] call ARC_fnc_clientToast;
    };

    case "ADMIN_FORCE_CLOSE_SUCC":
    {
        private _ok = ["Force-close active incident as SUCCEEDED?", "HQ / ADMIN", true, true] call BIS_fnc_guiMessage;
        if (_ok) then { ["SUCCEEDED", true, player] remoteExec ["ARC_fnc_tocRequestCloseIncident", 2]; };
    };

    case "ADMIN_FORCE_CLOSE_FAIL":
    {
        private _ok = ["Force-close active incident as FAILED?", "HQ / ADMIN", true, true] call BIS_fnc_guiMessage;
        if (_ok) then { ["FAILED", true, player] remoteExec ["ARC_fnc_tocRequestCloseIncident", 2]; };
    };

    case "ADMIN_RESET":
    {
        // Confirmation dialog; must run scheduled
        [] spawn {
            // Use the standard (bool) guiMessage signature; button labels are not critical here.
            // Prevents silent failures from unexpected parameter shapes.
            private _ok = [
                "Reset all persistent state and clear active tasks?\n\nThis is destructive and intended for testing.",
                "Confirm Reset",
                true,
                true
            ] call BIS_fnc_guiMessage;

            if (_ok) then
            {
                [] remoteExec ["ARC_fnc_tocRequestResetAll", 2];
                ["HQ", "Reset requested (server)."] call ARC_fnc_clientToast;
            } else {
                ["HQ", "Reset cancelled."] call ARC_fnc_clientToast;
            };
        };
    };

    case "ADMIN_AIRBASE_RESET_CTRL":
    {
        [] spawn {
            private _ok = [
                "Reset AIRBASE control state?\n\nThis clears runway lock state, queue, pending clearance requests, and hold/manual-priority controls while preserving history/events by default.",
                "Confirm AIRBASE Control Reset",
                true,
                true
            ] call BIS_fnc_guiMessage;

            if (_ok) then
            {
                [player, true] remoteExec ["ARC_fnc_tocRequestAirbaseResetControlState", 2];
                ["HQ", "AIRBASE control reset requested (server)."] call ARC_fnc_clientToast;
            } else {
                ["HQ", "AIRBASE control reset cancelled."] call ARC_fnc_clientToast;
            };
        };
    };

    case "ADMIN_CIVSUB_RESET":
    {
        [] spawn {
            private _ok = [
                "Reset CIVSUB campaign persistence?\n\nThis will clear CIVSUB saved state and start a new CIVSUB campaign_id.",
                "Confirm CIVSUB Reset",
                true,
                true
            ] call BIS_fnc_guiMessage;

            if (_ok) then
            {
                [player] remoteExec ["ARC_fnc_tocRequestCivsubReset", 2];
                ["HQ", "CIVSUB reset requested (server)."] call ARC_fnc_clientToast;
            } else {
                ["HQ", "CIVSUB reset cancelled."] call ARC_fnc_clientToast;
            };
        };
    };

    case "ADMIN_REBUILD_ACTIVE":
    {
        [] remoteExec ["ARC_fnc_tocRequestRebuildActive", 2];
        ["HQ", "Rebuild active incident requested."] call ARC_fnc_clientToast;
    };

    case "ADMIN_BROADCAST":
    {
        [] remoteExec ["ARC_fnc_publicBroadcastState", 2];
        ["HQ", "Broadcast requested."] call ARC_fnc_clientToast;
    };

    case "ADMIN_COVERAGE":
    {
        [] remoteExec ["ARC_fnc_uiCoverageAuditServer", 2];
        ["HQ", "UI coverage audit requested."] call ARC_fnc_clientToast;
    };

    case "ADMIN_QA":
    {
        [player] remoteExec ["ARC_fnc_uiConsoleQAAuditServer", 2];
        ["HQ", "Console QA audit requested."] call ARC_fnc_clientToast;
    };

    case "ADMIN_COMPILE":
    {
        [player] remoteExec ["ARC_fnc_devCompileAuditServer", 2];
        ["HQ", "Compile audit requested."] call ARC_fnc_clientToast;
    };

    case "ADMIN_DUMP_LEADS":
    {
        [] call ARC_fnc_tocShowLeadPoolLocal;
    };

    case "ADMIN_DUMP_INTEL":
    {
        [] call ARC_fnc_tocShowLatestIntel;
    };

    case "ADMIN_DIAG_STATUS":
    {
        [player] remoteExec ["ARC_fnc_devDiagnosticsSnapshot", 2];
        ["HQ", "Diagnostics snapshot requested (server)."] call ARC_fnc_clientToast;
    };

    case "ADMIN_DIAG_TOGGLE_DEBUG":
    {
        [player] remoteExec ["ARC_fnc_devToggleDebugMode", 2];
        ["HQ", "Debug mode toggle requested (server)."] call ARC_fnc_clientToast;
    };

    default
    {
        ["HQ", "No admin action selected."] call ARC_fnc_clientToast;
    };
};

true