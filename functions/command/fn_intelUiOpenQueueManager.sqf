/*
    ARC_fnc_intelUiOpenQueueManager

    Legacy compatibility wrapper.
    Queue workflow now lives in ARC_FarabadConsoleDialog (CMD / QUEUE mode).
*/

if (!hasInterface) exitWith {false};
if !([player] call ARC_fnc_rolesIsAuthorized) exitWith { false };

private _disp = uiNamespace getVariable ["ARC_console_display", displayNull];
if (isNull _disp) then { _disp = findDisplay 78000; };

if (!isNull _disp) then
{
    uiNamespace setVariable ["ARC_console_activeTab", "CMD"];
    uiNamespace setVariable ["ARC_console_cmdMode", "QUEUE"];
    uiNamespace setVariable ["ARC_console_cmdQueueForceRebuild", true];
    [_disp] call ARC_fnc_uiConsoleRefresh;
}
else
{
    uiNamespace setVariable ["ARC_console_forceTab", "CMD"];
    [] call ARC_fnc_uiConsoleOpen;
    uiNamespace setVariable ["ARC_console_cmdMode", "QUEUE"];
    uiNamespace setVariable ["ARC_console_cmdQueueForceRebuild", true];
};

private _canDecide = [player] call ARC_fnc_rolesCanApproveQueue;
if (!_canDecide) then
{
    ["TOC Queue", "View-only: Approve/Reject disabled (S3/Command only)."] call ARC_fnc_clientHint;
};

true
