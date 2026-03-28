/*
    ARC_fnc_intelQueuePromptDecision

    Client: prompt for a queueId and submit an approve/reject decision to server.

    Params:
      0: BOOL approve (true=approve, false=reject)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

if (!canSuspend) exitWith { _this spawn ARC_fnc_intelQueuePromptDecision; false };

params [["_approve", true]];
if (!(_approve isEqualType true)) then { _approve = true; };

private _cat = if (_approve) then {"QUEUE APPROVE"} else {"QUEUE REJECT"};
private _help = "Enter Queue ID (ARC_q_#) in the Summary. Optional note in Details.";

private _res = [_cat, "", _help] call ARC_fnc_clientIntelPrompt;
_res params ["_ok", "_sum", "_det"];
if (!_ok) exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";

private _qid = [_sum] call _trimFn;
if (_qid isEqualTo "") exitWith
{
    ["No queue ID provided.", "WARN", "TOAST"] call ARC_fnc_clientHint;
    false
};

[player, _qid, _approve, _det] remoteExec ["ARC_fnc_intelQueueDecide", 2];

[format ["Queue decision sent: %1 %2", if (_approve) then {"APPROVE"} else {"REJECT"}, _qid], "INFO", "TOAST"] call ARC_fnc_clientHint;
true
