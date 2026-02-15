/*
    ARC_fnc_intelUiQueueManagerOnLoad

    Client UI: called by the queue manager dialog onLoad.
*/

params [ ["_display", displayNull, [displayNull]] ];
if (isNull _display) exitWith {false};

// Cache display for convenience.
uiNamespace setVariable ["ARC_queueMgr_display", _display];

private _lb = _display displayCtrl 61001;

// Update details when selection changes.
_lb ctrlAddEventHandler ["LBSelChanged", {
    params ["_ctrl", "_idx"]; 
    [_ctrl, _idx] call ARC_fnc_intelUiQueueManagerUpdateDetails;
}];

// Disable approve/reject if somehow opened by a non-approver.
private _canDecide = [player] call ARC_fnc_rolesCanApproveQueue;
(_display displayCtrl 61011) ctrlEnable _canDecide;
(_display displayCtrl 61012) ctrlEnable _canDecide;

[] call ARC_fnc_intelUiQueueManagerRefresh;

true
