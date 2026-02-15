/*
    ARC_fnc_uiConsoleOpsSelChanged

    UI09: selection handler for Ops (S3) frame lists.

    Called from onLBSelChanged of:
      78032 - Incidents list
      78035 - Orders list
      78038 - Leads list
*/

if (!hasInterface) exitWith {false};

params ["_ctrl", "_idx"];
if (isNull _ctrl) exitWith {false};

private _disp = ctrlParent _ctrl;
if (isNull _disp) exitWith {false};

private _idc = ctrlIDC _ctrl;

switch (_idc) do
{
    case 78032:
    {
        uiNamespace setVariable ["ARC_console_opsFocus", "INCIDENT"];
        if (_idx >= 0) then { uiNamespace setVariable ["ARC_console_opsSel_inc", _ctrl lbData _idx]; };
    };
    case 78035:
    {
        uiNamespace setVariable ["ARC_console_opsFocus", "ORDER"];
        if (_idx >= 0) then { uiNamespace setVariable ["ARC_console_opsSel_ord", _ctrl lbData _idx]; };
    };
    case 78038:
    {
        uiNamespace setVariable ["ARC_console_opsFocus", "LEAD"];
        if (_idx >= 0) then { uiNamespace setVariable ["ARC_console_opsSel_lead", _ctrl lbData _idx]; };
    };
};

[_disp, false] call ARC_fnc_uiConsoleOpsPaint;
true
