/*
    ARC_fnc_uiConsoleOpsActionStatus

    Client helper: standardized transient status toasts for OPS tab actions.

    Params:
      0: STRING action key (INCIDENT_ACCEPT | ORDER_ACCEPT | SITREP)
      1: STRING stage (SUBMITTING | ACCEPTED | REJECTED | TIMEOUT)
      2: STRING detail/reason (optional)
      3: NUMBER timeout seconds (SUBMITTING only, optional)

    Returns:
      BOOL
*/

// Notification cooldown keys (ARC_fnc_clientNotifyGate):
// - ARC_console_ops_submit_<ACTION>: SUBMITTING toast dedupe (5s)
// - ARC_console_ops_timeout_<ACTION>: TIMEOUT toast dedupe (10s)

if (!hasInterface) exitWith {false};

params [
    ["_action", ""],
    ["_stage", ""],
    ["_detail", ""],
    ["_timeoutS", 8]
];

private _trimFn = compile "params ['_s']; trim _s";

_action = toUpper ([_action] call _trimFn);
_stage = toUpper ([_stage] call _trimFn);
if (!(_detail isEqualType "")) then { _detail = str _detail; };
if (!(_timeoutS isEqualType 0)) then { _timeoutS = 8; };
_timeoutS = (_timeoutS max 3) min 20;

private _title = switch (_action) do
{
    case "INCIDENT_ACCEPT": { "Incident" };
    case "ORDER_ACCEPT": { "Orders" };
    case "SITREP": { "SITREP" };
    default { "Operations" };
};

private _pendingKey = format ["ARC_console_opsPending_%1", _action];

switch (_stage) do
{
    case "SUBMITTING":
    {
        private _token = diag_tickTime;
        uiNamespace setVariable [_pendingKey, _token];

        private _submitMsg = "Submitting to server...";
        if ([format ["ARC_console_ops_submit_%1", _action], 5, _submitMsg] call ARC_fnc_clientNotifyGate) then
        {
            [_title, _submitMsg] call ARC_fnc_clientToast;
        };

        [_action, _pendingKey, _token, _timeoutS] spawn
        {
            params ["_action2", "_pendingKey2", "_token2", "_timeoutS2"];
            uiSleep _timeoutS2;

            private _activeToken = uiNamespace getVariable [_pendingKey2, -1];
            if !(_activeToken isEqualTo _token2) exitWith {};

            uiNamespace setVariable [_pendingKey2, nil];
            [_action2, "TIMEOUT", "No server acknowledgement yet. Retry if needed."] call ARC_fnc_uiConsoleOpsActionStatus;
        };
    };

    case "ACCEPTED":
    {
        uiNamespace setVariable [_pendingKey, nil];
        private _msg = if (_detail isEqualTo "") then { "Request accepted." } else { _detail };
        [_title, _msg] call ARC_fnc_clientToast;
    };

    case "REJECTED":
    {
        uiNamespace setVariable [_pendingKey, nil];
        private _msg = if (_detail isEqualTo "") then { "Request rejected." } else { _detail };
        [_title, _msg] call ARC_fnc_clientToast;
    };

    case "TIMEOUT":
    {
        private _msg = if (_detail isEqualTo "") then { "No server acknowledgement yet. Retry if needed." } else { _detail };
        if ([format ["ARC_console_ops_timeout_%1", _action], 10, _msg] call ARC_fnc_clientNotifyGate) then
        {
            [_title, _msg] call ARC_fnc_clientToast;
        };
    };

    default { false };
};

true
