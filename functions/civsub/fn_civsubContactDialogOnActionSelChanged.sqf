/*
    ARC_fnc_civsubContactDialogOnActionSelChanged

    Handles ActionsList selection changes:
      - Sets lastPane to "A"
      - Switches mode to Questions when ASK_QUESTIONS selected
      - Updates the right pane with action-specific instructions/status.
*/

if (!hasInterface) exitWith { true };

params [["_ctrl", controlNull, [controlNull]], ["_idx", -1, [0]]];

private _d = ctrlParent _ctrl;
if (isNull _d) exitWith { true };

private _lbA = _d displayCtrl 78310;
if (isNull _lbA) exitWith { true };

private _actionId = "";
if (_idx >= 0) then { _actionId = _lbA lbData _idx; };

// Fail-soft: if a prior action hung (no server response), allow the user to recover by selecting a new action.
private _inProg = uiNamespace getVariable ["ARC_civsubInteract_actionInProgress", false];
if (_inProg) then {
    private _t0 = uiNamespace getVariable ["ARC_civsubInteract_actionStartedAt", 0];
    if ((diag_tickTime - _t0) > 3) then { uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", false]; };
};

uiNamespace setVariable ["ARC_civsubInteract_lastPane", "A"];

if (_actionId isEqualTo "ASK_QUESTIONS") then {
    uiNamespace setVariable ["ARC_civsubInteract_mode", "Q"];
} else {
    uiNamespace setVariable ["ARC_civsubInteract_mode", "A"];
    // clear any question selection when entering Action mode
    private _lbQ = _d displayCtrl 78311;
    if (!isNull _lbQ) then { _lbQ lbSetCurSel -1; };
};

[_actionId] call ARC_fnc_civsubContactDialogUpdateRightPane;

true
