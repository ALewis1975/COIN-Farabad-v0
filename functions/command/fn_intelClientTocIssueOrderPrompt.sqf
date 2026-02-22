/*
    ARC_fnc_intelClientTocIssueOrderPrompt

    Client: prompt for an optional note and issue a TOC order to the last tasked
    group (or current active group).

    Params:
      0: STRING order (RTB|HOLD|PROCEED)
      1: STRING purpose (REFIT|INTEL|EPW) - RTB only

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

if (!canSuspend) exitWith { _this spawn ARC_fnc_intelClientTocIssueOrderPrompt; false };

params [
    ["_order", "RTB"],
    ["_purpose", "REFIT"]
];

if (!([player] call ARC_fnc_rolesIsAuthorized)) exitWith {false};

_order = toUpper (trim _order);
_purpose = toUpper (trim _purpose);

private _sum = format ["Issue TOC Order: %1%2", _order, if (_order isEqualTo "RTB") then { format [" (%1)", _purpose] } else { "" }];
private _def = "Optional note to the unit.";

private _res = ["ISSUE TOC ORDER", _sum, _def] call ARC_fnc_clientIntelPrompt;
_res params ["_ok", "_s", "_d"];
if (!_ok) exitWith {false};

[player, _order, _purpose, _d] remoteExec ["ARC_fnc_intelTocIssueOrder", 2];

["Order sent to server.", "INFO", "TOAST"] call ARC_fnc_clientHint;
true
