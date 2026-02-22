/*
    ARC_fnc_uiConsoleActionWorkboardPrimary

    Client: Workboard primary action.
      - If an incident is selected:
          * pending -> accept incident
          * accepted -> send SITREP (if available)
*/

if (!hasInterface) exitWith {false};

private _display = uiNamespace getVariable ["ARC_console_display", displayNull];
if (isNull _display) exitWith {false};

private _ctrlList = _display displayCtrl 78011;
if (isNull _ctrlList) exitWith {false};

private _sel = lbCurSel _ctrlList;
private _data = if (_sel >= 0) then { _ctrlList lbData _sel } else { "" };
if (!(_data isEqualType "")) then { _data = ""; };

private _parts = _data splitString "|";
private _kind = if ((count _parts) > 0) then { toUpper (_parts # 0) } else { "" };

if (_kind isNotEqualTo "INCIDENT") exitWith
{
    ["Workboard", "No primary action is available for this item."] call ARC_fnc_clientToast;
    false
};

private _accepted = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
if (!(_accepted isEqualType true) && !(_accepted isEqualType false)) then { _accepted = false; };

if (!_accepted) then
{
    [] call ARC_fnc_uiConsoleActionAcceptIncident;
}
else
{
    [] call ARC_fnc_uiConsoleActionSendSitrep;
};

true
