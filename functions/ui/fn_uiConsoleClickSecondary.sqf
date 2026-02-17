/*
    ARC_fnc_uiConsoleClickSecondary

    Client: secondary button handler for the Farabad Console.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

private _tab = uiNamespace getVariable ["ARC_console_activeTab", "HANDOFF"];
if (!(_tab isEqualType "")) then { _tab = "HANDOFF"; };
_tab = toUpper _tab;

switch (_tab) do
{
    case "HANDOFF": { [] spawn ARC_fnc_uiConsoleActionEpwProcess; };

    case "INTEL":   { [] spawn ARC_fnc_uiConsoleActionS2Secondary; };

    case "OPS":
    {
        private _typ = missionNamespace getVariable ["ARC_activeIncidentType", ""]; if (!(_typ isEqualType "")) then { _typ = ""; };
        private _sit = missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false]; if (!(_sit isEqualType true) && !(_sit isEqualType false)) then { _sit = false; };
        if ((toUpper (trim _typ)) isEqualTo "IED" && { !_sit }) then
        {
            [] spawn ARC_fnc_uiConsoleActionRequestEodDispo;
        }
        else
        {
            [] spawn ARC_fnc_uiConsoleActionRequestFollowOn;
        };
    };

    case "CMD":
    {
        private _cmdMode = uiNamespace getVariable ["ARC_console_cmdMode", "OVERVIEW"];
        if (!(_cmdMode isEqualType "")) then { _cmdMode = "OVERVIEW"; };
        _cmdMode = toUpper (trim _cmdMode);

        if (_cmdMode isEqualTo "QUEUE") then
        {
            private _canDecide = [player] call ARC_fnc_rolesCanApproveQueue;
            private _queuePending = uiNamespace getVariable ["ARC_console_cmdQueueSelectedPending", false];

            if (_canDecide && _queuePending) then
            {
                [] spawn {
                    private _qid = uiNamespace getVariable ["ARC_console_cmdQueueSelectedQid", ""];
                    if (_qid isEqualTo "") exitWith { ["TOC Queue", "Select a queue item first."] call ARC_fnc_clientToast; };
                    [player, _qid, false, ""] remoteExecCall ["ARC_fnc_intelQueueDecide", 2];
                    ["TOC Queue", format ["REJECTED: %1", _qid]] call ARC_fnc_clientToast;
                    uiNamespace setVariable ["ARC_console_cmdQueueForceRebuild", true];
                    private _disp = findDisplay 78000;
                    if (!isNull _disp) then { [_disp] call ARC_fnc_uiConsoleRefresh; };
                };
            }
            else
            {
                uiNamespace setVariable ["ARC_console_cmdMode", "OVERVIEW"];
                uiNamespace setVariable ["ARC_console_cmdQueueForceRebuild", true];
                private _disp = findDisplay 78000;
                if (!isNull _disp) then { [_disp] call ARC_fnc_uiConsoleRefresh; };
                ["TOC Queue", "Returned to TOC overview."] call ARC_fnc_clientToast;
            };
        }
        else
        {
            [] spawn ARC_fnc_uiConsoleActionTocSecondary;
        };
    };

    case "BOARDS":  { [] spawn ARC_fnc_uiConsoleActionTocSecondary; };

    case "HQ":
    {
        private _hqMode = uiNamespace getVariable ["ARC_console_hqMode", "TOOLS"];
        if (!(_hqMode isEqualType "")) then { _hqMode = "TOOLS"; };
        _hqMode = toUpper (trim _hqMode);

        if (_hqMode isEqualTo "INCIDENTS") then
        {
            uiNamespace setVariable ["ARC_console_hqMode", "TOOLS"];
            private _disp = findDisplay 78000;
            if (!isNull _disp) then { [_disp, true] call ARC_fnc_uiConsoleHQPaint; };
            ["HQ", "Incident picker closed."] call ARC_fnc_clientToast;
        }
        else
        {
            // Secondary in HQ reserved for future (confirm flows, log export, etc.)
            ["Headquarters", "Select an admin action and use EXECUTE."] call ARC_fnc_clientToast;
        };
    };

    case "DASH":
    {
        // Allow users to force a refresh without changing tabs
        private _disp = findDisplay 78000;
        if (!isNull _disp) then { [_disp] call ARC_fnc_uiConsoleRefresh; };
    };

    default
    {
        ["Console", "No secondary action for this tab."] call ARC_fnc_clientToast;
    };
};

true
