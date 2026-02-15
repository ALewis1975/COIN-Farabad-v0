/*
    ARC_fnc_uiConsoleActionOpenTocQueue

    Client: open the TOC Queue Manager dialog.

    UI rule:
      - Authorized roles may open the queue in view-only mode.
      - Approvers (S3/Command/OMNI) can approve/reject.
*/

if (!hasInterface) exitWith {false};

if !([player] call ARC_fnc_rolesIsAuthorized) exitWith
{
    ["TOC Queue", "Access denied (authorized roles only)."] call ARC_fnc_clientToast;
    false
};

[] spawn ARC_fnc_intelUiOpenQueueManager;
true
