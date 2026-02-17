/*
    ARC_fnc_uiConsoleActionOpenTocQueue

    Client: switch the TOC/CMD console into integrated queue mode.

    UI rule:
      - Authorized roles may open the queue in view-only mode.
      - Approvers (S3/Command/OMNI) can approve/reject pending items.
*/

if (!hasInterface) exitWith {false};

if !([player] call ARC_fnc_rolesIsAuthorized) exitWith
{
    ["TOC Queue", "Access denied (authorized roles only)."] call ARC_fnc_clientToast;
    false
};

uiNamespace setVariable ["ARC_console_cmdMode", "QUEUE"];
uiNamespace setVariable ["ARC_console_forceTab", "CMD"];
uiNamespace setVariable ["ARC_console_cmdQueueForceRebuild", true];

private _display = uiNamespace getVariable ["ARC_console_display", displayNull];
if (isNull _display) then { _display = findDisplay 78000; };
if (!isNull _display) then
{
    // Keep the visible tabs listbox in sync when forcing CMD programmatically.
    // This triggers the normal selection-change path (active tab + refresh).
    ["CMD", _display] call ARC_fnc_uiConsoleSelectTab;
}
else
{
    // Fallback state for opens before the console display exists.
    uiNamespace setVariable ["ARC_console_activeTab", "CMD"];
};

private _canDecide = [player] call ARC_fnc_rolesCanApproveQueue;
private _msg = if (_canDecide) then
{
    "Queue view open. Select a pending item to APPROVE / REJECT."
}
else
{
    "Queue view open (view-only)."
};
["TOC Queue", _msg] call ARC_fnc_clientToast;

true
