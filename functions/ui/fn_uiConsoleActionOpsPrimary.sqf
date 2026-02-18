/*
    ARC_fnc_uiConsoleActionOpsPrimary

    UI09: Primary action for Operations (S3) tab.

    Context-driven based on the Ops focus list:
      INCIDENT:
        - Accept Incident (if not accepted)
        - Send SITREP (if accepted and available)
      ORDER:
        - Accept next issued order (for your group)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

private _focus = ["ARC_console_opsFocus", "INCIDENT"] call ARC_fnc_uiNsGetString;
_focus = toUpper _focus;

switch (_focus) do
{
    case "ORDER":
    {
        // Accept next issued order for the group
        [] spawn ARC_fnc_uiConsoleActionAcceptOrder;
    };

    case "LEAD":
    {
        ["Operations", "Leads are actionable via follow-on requests or TOC tasking."] call ARC_fnc_clientToast;
    };

    default
    {
        // Incident focused
        private _accepted = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
        if (!_accepted) exitWith
        {
            [] spawn ARC_fnc_uiConsoleActionAcceptIncident;
        };

        private _canSitrep = [] call ARC_fnc_clientCanSendSitrep;
        if (_canSitrep) exitWith
        {
            [] spawn ARC_fnc_uiConsoleActionSendSitrep;
        };

        ["Operations", "No primary action available (SITREP not available yet)."] call ARC_fnc_clientToast;
    };
};

true
