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
        // Issue the selected lead to the active field group as a PROCEED/LEAD order.
        private _disp = findDisplay 78000;
        private _cLead = if (!isNull _disp) then { _disp displayCtrl 78038 } else { controlNull };
        private _sel = if (!isNull _cLead) then { lbCurSel _cLead } else { -1 };
        private _lbData = if (_sel >= 0) then { _cLead lbData _sel } else { "NONE" };
        private _parts = _lbData splitString "|";
        private _leadId = if ((count _parts) > 1) then { _parts select 1 } else { "" };
        private _ok = (!isNull _disp) && { !isNull _cLead } && { _sel >= 0 } && { !(_lbData isEqualTo "") } && { !(_lbData isEqualTo "NONE") } && { !(_leadId isEqualTo "") };

        if (_ok) then
        {
            [player, _leadId, ""] remoteExecCall ["ARC_fnc_intelTocIssueLead", 2];
            ["Operations", format ["LEAD ORDER issued: %1", _leadId]] call ARC_fnc_clientToast;
        }
        else
        {
            private _msg = "Could not issue lead.";
            if (isNull _disp)    then { _msg = "Console not found."; } else {
            if (isNull _cLead)   then { _msg = "Lead list not found."; } else {
            if (_sel < 0)        then { _msg = "Select a lead from the list first."; } else {
            if (_lbData isEqualTo "NONE") then { _msg = "No leads available."; };
            };};};
            ["Operations", _msg] call ARC_fnc_clientToast;
        };
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
