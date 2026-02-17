/*
    ARC_fnc_uiConsoleClickPrimary

    Client: primary button handler for the Farabad Console.

    We keep the dialog button "action" static and route behavior here based
    on the currently selected tab.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

private _tab = uiNamespace getVariable ["ARC_console_activeTab", "HANDOFF"];
if (!(_tab isEqualType "")) then { _tab = "HANDOFF"; };
_tab = toUpper _tab;

switch (_tab) do
{
    case "HANDOFF": { [] spawn ARC_fnc_uiConsoleActionIntelDebrief; };

    case "INTEL":   { [] spawn ARC_fnc_uiConsoleActionS2Primary; };

    case "OPS":
    {
        // Context-sensitive: Accept Incident / Accept Order / Send SITREP
        [] spawn ARC_fnc_uiConsoleActionOpsPrimary;
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
                    [player, _qid, true, ""] remoteExecCall ["ARC_fnc_intelQueueDecide", 2];
                    ["TOC Queue", format ["APPROVED: %1", _qid]] call ARC_fnc_clientToast;
                    uiNamespace setVariable ["ARC_console_cmdQueueForceRebuild", true];
                    private _disp = findDisplay 78000;
                    if (!isNull _disp) then { [_disp] call ARC_fnc_uiConsoleRefresh; };
                };
            }
            else
            {
                private _disp = findDisplay 78000;
                if (!isNull _disp) then
                {
                    uiNamespace setVariable ["ARC_console_cmdQueueForceRebuild", true];
                    [_disp] call ARC_fnc_uiConsoleRefresh;
                };
            };
        }
        else
        {
            [] spawn ARC_fnc_uiConsoleActionOpenTocQueue;
        };
    };

    case "BOARDS":  { [] spawn ARC_fnc_uiConsoleActionOpenTocQueue; };

    case "HQ":      { [] spawn ARC_fnc_uiConsoleActionHQPrimary; };

    case "DASH":
    {
        // Dashboard is passive. Users can switch tabs for actions.
        ["Dashboard", "Select a functional tab to take action."] call ARC_fnc_clientToast;
    };

    default
    {
        ["Console", "No primary action for this tab."] call ARC_fnc_clientToast;
    };
};

true
