/*
    ARC_fnc_intelUiQueueManagerDecideSelected

    Client UI: approve/reject the currently selected queue item.

    Params:
        0: BOOL - approve? (true = approve, false = reject)
*/

params [ ["_approve", true, [true]] ];

if (!hasInterface) exitWith {false};
if !([player] call ARC_fnc_rolesCanApproveQueue) exitWith
{
    ["TOC Queue", "Only S3/Command can approve/reject queue items."] call ARC_fnc_clientHint;
    false
};

private _disp = uiNamespace getVariable ["ARC_queueMgr_display", displayNull];
if (isNull _disp) then { _disp = findDisplay 61000; };
if (isNull _disp) exitWith {false};

private _lb = _disp displayCtrl 61001;
private _sel = lbCurSel _lb;
if (_sel < 0) exitWith {false};

private _qid = _lb lbData _sel;
if (_qid isEqualTo "") exitWith {false};


// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
// Validate status client-side so we don't spam the server with invalid decisions.
private _q = missionNamespace getVariable ["ARC_pub_queueTail", []];
if (!(_q isEqualType [])) then { _q = []; };
if (_q isEqualTo []) then
{
    _q = missionNamespace getVariable ["ARC_pub_queue", []];
    if (!(_q isEqualType [])) then { _q = []; };
};

private _it = [];
{
    if (_x isEqualType [] && { (count _x) >= 12 } && { (_x select 0) isEqualTo _qid }) exitWith { _it = _x; };
} forEach _q;

if (_it isEqualTo []) exitWith
{
    ["TOC Queue", "Queue item not present in client snapshot (old / out of range)."] call ARC_fnc_clientHint;
    false
};

private _stU = toUpper (_it select 2);
if (!(_stU isEqualTo "PENDING")) exitWith
{
    ["TOC Queue", format ["%1 is %2 (not pending).", _qid, _stU]] call ARC_fnc_clientHint;
    false
};

// Read note field.
private _note = ctrlText (_disp displayCtrl 61004);
if !(_note isEqualType "") then { _note = ""; };
_note = [_note] call _trimFn;

// Push decision to server.
[player, _qid, _approve, _note] remoteExecCall ["ARC_fnc_intelQueueDecide", 2];

private _verb = if (_approve) then { "APPROVED" } else { "REJECTED" };
["TOC Queue", format ["%1: %2", _verb, _qid]] call ARC_fnc_clientHint;

// Clear note field after submission.
(_disp displayCtrl 61004) ctrlSetText "";

// Refresh shortly after (server will broadcast, but this keeps the UI feeling responsive).
[] spawn { uiSleep 0.6; [] call ARC_fnc_intelUiQueueManagerRefresh; };

true
