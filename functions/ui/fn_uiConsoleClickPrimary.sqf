/*
    ARC_fnc_uiConsoleClickPrimary

    Client: primary button handler for the Farabad Console.

    We keep the dialog button "action" static and route behavior here based
    on the currently selected tab.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

private _tab = ["ARC_console_activeTab", "HANDOFF"] call ARC_fnc_uiNsGetString;
_tab = toUpper _tab;

switch (_tab) do
{
    case "HANDOFF": { [] spawn ARC_fnc_uiConsoleActionIntelDebrief; };

    case "INTEL":   {
        // Field-request rows (relocated from the player action menu) are intercepted
        // here so they can close the console first — the underlying JTAC/SHADOW/TNP
        // functions read an in-world marking context (laser/cursor target) that is
        // only valid once the fullscreen console is closed. All other INTEL rows fall
        // through to the standard S2 primary dispatch.
        private _handled = false;
        private _disp = uiNamespace getVariable ["ARC_console_display", displayNull];
        if (isNull _disp) then { _disp = findDisplay 78000; };
        if (!isNull _disp) then
        {
            private _list = _disp displayCtrl 78011;
            if (!isNull _list) then
            {
                private _sel = lbCurSel _list;
                private _data = if (_sel >= 0) then { _list lbData _sel } else { "" };
                if (!(_data isEqualType "")) then { _data = ""; };

                switch (_data) do
                {
                    case "FIELD_JTAC_CAS":
                    {
                        _handled = true;
                        closeDialog 0;
                        ["CASREQ", "Console closed - lase/aim at target to continue."] call ARC_fnc_clientToast;
                        [] spawn ARC_fnc_casreqJtacPrefill;
                    };
                    case "FIELD_SHADOW_ISR":
                    {
                        _handled = true;
                        closeDialog 0;
                        ["ISR", "Console closed - lase/cursor the contact to continue."] call ARC_fnc_clientToast;
                        [] spawn ARC_fnc_intelShadowLeadBridge;
                    };
                    case "FIELD_TNP_PARTNERED":
                    {
                        _handled = true;
                        closeDialog 0;
                        ["TNP", "Console closed - aim at the location to continue."] call ARC_fnc_clientToast;
                        [] spawn ARC_fnc_opsTnpPartneredRequest;
                    };
                };
            };
        };

        if (!_handled) then { [] spawn ARC_fnc_uiConsoleActionS2Primary; };
    };

    case "OPS":
    {
        // Context-sensitive: Accept Incident / Accept Order / Send SITREP
        [] spawn ARC_fnc_uiConsoleActionOpsPrimary;
    };

    case "AIR":   { [] spawn ARC_fnc_uiConsoleActionAirPrimary; };

    case "CMD":
    {
        private _cmdMode = ["ARC_console_cmdMode", "OVERVIEW"] call ARC_fnc_uiNsGetString;
        _cmdMode = toUpper _cmdMode;

        if (_cmdMode isEqualTo "QUEUE") then
        {
            private _canDecide = [player] call ARC_fnc_rolesCanApproveQueue;
            private _queuePending = ["ARC_console_cmdQueueSelectedPending", false] call ARC_fnc_uiNsGetBool;

            if (_canDecide && _queuePending) then
            {
                [] spawn {
                    private _qid = ["ARC_console_cmdQueueSelectedQid", ""] call ARC_fnc_uiNsGetString;
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

    case "COMMS":
    {
        private _disp = findDisplay 78000;
        if (!isNull _disp) then { [_disp] call ARC_fnc_uiConsoleRefresh; };
        ["COMMS", "SOI and medical C2 snapshot refreshed."] call ARC_fnc_clientToast;
    };

    case "HQ":      { [] spawn ARC_fnc_uiConsoleActionHQPrimary; };

    case "S1":
    {
        private _disp = findDisplay 78000;
        if (!isNull _disp) then { [_disp] call ARC_fnc_uiConsoleRefresh; };
        ["S-1", "Roster snapshot refreshed."] call ARC_fnc_clientToast;
    };

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
