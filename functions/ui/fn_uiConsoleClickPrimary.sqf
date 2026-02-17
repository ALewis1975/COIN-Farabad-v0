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

    case "CMD":     { [] spawn ARC_fnc_uiConsoleActionOpenTocQueue; };

    case "BOARDS":  { [] spawn ARC_fnc_uiConsoleActionToggleTaskingAvailability; };

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
