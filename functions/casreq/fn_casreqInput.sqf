/* Shared scheduled three-field form. Escape, Cancel and unload default to no submission. */
if (!hasInterface || {!canSuspend}) exitWith {[false, "", "", ""]};
disableSerialization;
params [["_title", "Request details", [""]], ["_labels", [], [[]]], ["_defaults", [], [[]]], ["_limits", [240,240,500], [[]]]];
if (!isNull findDisplay 78510) exitWith {[false, "", "", ""]};
uiNamespace setVariable ["ARC_casreqInput_result", [false, "", "", ""]];
if !(createDialog "ARC_CasreqInputDialog") exitWith {[false, "", "", ""]};
private _d = findDisplay 78510;
(_d displayCtrl 1000) ctrlSetText _title;
for "_i" from 0 to 2 do {
    (_d displayCtrl (1100 + _i)) ctrlSetText (_labels param [_i, ""]);
    (_d displayCtrl (1400 + _i)) ctrlSetText (_defaults param [_i, ""]);
};
waitUntil {sleep 0.05; isNull findDisplay 78510};
private _result = uiNamespace getVariable ["ARC_casreqInput_result", [false, "", "", ""]];
if !(_result select 0) exitWith {_result};
private _valid = true;
for "_i" from 0 to 2 do {if (count (_result select (_i + 1)) > (_limits param [_i, 500])) then {_valid = false}};
if (!_valid) exitWith {["Request", "Text exceeds the displayed limits. Nothing was submitted."] call ARC_fnc_clientToast; [false, "", "", ""]};
_result
