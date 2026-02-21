/*
    ARC_fnc_civsubContactDialogExecute

    Client-side: executes the selected action (wired actions only).

    Stable UI hotfix (UI-LOCK v1):
      - Use uiNamespace display handle first (avoid findDisplay timing issues)
      - No chat output; results render in dialog via civsubContactClientReceiveResult

    Wired:
      - CHECK_ID
      - BACKGROUND_CHECK

    Questions remain placeholders (Step 4).
*/
if (!hasInterface) exitWith { true };

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";

private _d = uiNamespace getVariable ["ARC_civsubInteract_display", displayNull];
if (isNull _d) exitWith { true };

private _lbA  = _d displayCtrl 78310;
private _lbQ  = _d displayCtrl 78311;
private _resp = _d displayCtrl 78320;

if (isNull _lbA || isNull _lbQ || isNull _resp) exitWith { true };

private _selA = lbCurSel _lbA;
private _selQ = lbCurSel _lbQ;

private _mode = uiNamespace getVariable ["ARC_civsubInteract_mode", "A"];
private _civ = uiNamespace getVariable ["ARC_civsubInteract_target", objNull];
if (isNull _civ) exitWith {
    _resp ctrlSetStructuredText parseText "<t size='0.9'>No civilian selected.</t>";
    uiNamespace setVariable ["ARC_civsubInteract_hasUserOutput", true];
    uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", false];
};

// Local watchdog: if the server action script errors out and never returns a result,
// the dialog can get stuck in a perceived "dead" state. This timer fail-softs back to ready.
private _kickWatchdog = {
    params [["_actionName","ACTION",[""]]];

    private _tok = (uiNamespace getVariable ["ARC_civsubInteract_actionToken", 0]) + 1;
    uiNamespace setVariable ["ARC_civsubInteract_actionToken", _tok];
    uiNamespace setVariable ["ARC_civsubInteract_actionStartedAt", diag_tickTime];

    [_tok, _actionName] spawn {
        params ["_tok","_name"];
        sleep 10;

        private _d = uiNamespace getVariable ["ARC_civsubInteract_display", displayNull];
        if (isNull _d) exitWith {};
        if !(uiNamespace getVariable ["ARC_civsubInteract_actionInProgress", false]) exitWith {};
        if ((uiNamespace getVariable ["ARC_civsubInteract_actionToken", -1]) != _tok) exitWith {};

        private _resp = _d displayCtrl 78320;
        if (!isNull _resp) then {
            _resp ctrlSetStructuredText parseText format [
                "<t size='0.95' color='#CFE8FF'>%1</t><br/>" +
                "<t size='0.9' color='#FFD36A'>Timed out waiting for server response.</t><br/>" +
                "<t size='0.85'>Try again. If it keeps happening, close and reopen the dialog.</t>",
                _name
            ];
        };

        uiNamespace setVariable ["ARC_civsubInteract_hasUserOutput", true];
        uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", false];
    };
};

private _lastPane = uiNamespace getVariable ["ARC_civsubInteract_lastPane", "A"];
private _actionIdSel = "";
if (_selA >= 0) then { _actionIdSel = _lbA lbData _selA; };
if (_selQ >= 0 && {_lastPane isEqualTo "Q"} && {(_selA < 0) || {_actionIdSel isEqualTo "ASK_QUESTIONS"}}) exitWith {
    private _qid = uiNamespace getVariable ["ARC_civsubInteract_selectedQid", ""];
    if (_qid isEqualTo "") then { _qid = _lbQ lbData _selQ; };
    private _qlbl = _lbQ lbText _selQ;

    if (_qid isEqualTo "") exitWith {
        _resp ctrlSetStructuredText parseText "<t size='0.9'>No question selected.</t>";
        uiNamespace setVariable ["ARC_civsubInteract_hasUserOutput", true];
        uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", false];
        true
    };

    uiNamespace setVariable ["ARC_civsubInteract_hasUserOutput", true];
    uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", true];

    _resp ctrlSetStructuredText parseText format ["QUESTION: %1\nAsking...", _qlbl];

    private _pl = [[["qid", _qid], ["label", _qlbl]]] call _hmFrom;
            ["QUESTION"] call _kickWatchdog;
    [_civ, player, "QUESTION", _pl] remoteExecCall ["ARC_fnc_civsubContactReqAction", 2];

    true
};

// Prefer Actions; fall back to Questions
if (_selA >= 0) then {
    private _actionId = _lbA lbData _selA;
    private _label    = _lbA lbText _selA;

    // Any action execution counts as user output; do not let snapshots overwrite the response pane.
    uiNamespace setVariable ["ARC_civsubInteract_hasUserOutput", true];
    uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", true];
    uiNamespace setVariable ["ARC_civsubInteract_lastPane", "A"]; 

    // Hide embedded overlay before running new actions
    [] call ARC_fnc_civsubContactDialogHideIdOverlay;

    switch (_actionId) do {
        case "CHECK_ID": {
             _resp ctrlSetStructuredText parseText "<t size='0.9'>Running Check ID...</t>";
            ["CHECK ID"] call _kickWatchdog;
            [_civ, player, "CHECK_ID", []] remoteExecCall ["ARC_fnc_civsubContactReqAction", 2];
        };
        case "BACKGROUND_CHECK": {
             _resp ctrlSetStructuredText parseText "<t size='0.9'>Running Background Check...</t>";
            ["BACKGROUND CHECK"] call _kickWatchdog;
            [_civ, player, "BACKGROUND_CHECK", []] remoteExecCall ["ARC_fnc_civsubContactReqAction", 2];
        };
        case "ASK_QUESTIONS": {
            uiNamespace setVariable ["ARC_civsubInteract_lastPane", "Q"];
            uiNamespace setVariable ["ARC_civsubInteract_mode", "Q"];
            _resp ctrlSetStructuredText parseText "<t size='0.9'>Select a question, then press Execute.</t>";
            ctrlSetFocus _lbQ;
            uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", false];
        };
        case "DETAIN": {
            private _snap = uiNamespace getVariable ["ARC_civsubInteract_snapshot", createHashMap];
            private _det = false;
            if (_snap isEqualType createHashMap) then { _det = [_snap, "detained", false] call _hg; };
            if (_det) exitWith {
                _resp ctrlSetStructuredText parseText "<t size='0.9'>Civilian is already detained.</t>";
                uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", false];
            };
            _resp ctrlSetStructuredText parseText "<t size='0.9'>Detaining civilian...</t>";
            ["DETAIN"] call _kickWatchdog;
            [_civ, player, "DETAIN", []] remoteExecCall ["ARC_fnc_civsubContactReqAction", 2];
        };
        case "RELEASE": {
            private _snap = uiNamespace getVariable ["ARC_civsubInteract_snapshot", createHashMap];
            private _det = false;
            if (_snap isEqualType createHashMap) then { _det = [_snap, "detained", false] call _hg; };
            if (!_det) exitWith {
                _resp ctrlSetStructuredText parseText "<t size='0.9'>Civilian is not detained.</t>";
                uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", false];
            };
            _resp ctrlSetStructuredText parseText "<t size='0.9'>Releasing civilian...</t>";
            ["RELEASE"] call _kickWatchdog;
            [_civ, player, "RELEASE", []] remoteExecCall ["ARC_fnc_civsubContactReqAction", 2];
        };

        case "AID_RATIONS": {
            _resp ctrlSetStructuredText parseText "<t size='0.9'>Giving food...</t>";
            ["AID RATIONS"] call _kickWatchdog;
            [_civ, player, "AID_RATIONS", []] remoteExecCall ["ARC_fnc_civsubContactReqAction", 2];
        };
        case "AID_WATER": {
            _resp ctrlSetStructuredText parseText "<t size='0.9'>Giving water...</t>";
            ["AID WATER"] call _kickWatchdog;
            [_civ, player, "AID_WATER", []] remoteExecCall ["ARC_fnc_civsubContactReqAction", 2];
        };

        default {
            _resp ctrlSetStructuredText parseText format [
                "<t size='0.9'>%1</t><br/><t size='0.85'>Not wired yet.</t>",
                _label
            ];
            uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", false];
        };
    };
} else {
    if (_selQ >= 0) then {
        private _qid = _lbQ lbData _selQ;
        private _qlbl = _lbQ lbText _selQ;

        uiNamespace setVariable ["ARC_civsubInteract_hasUserOutput", true];
        uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", true];

        _resp ctrlSetStructuredText parseText format [
            "<t size='0.95' color='#CFE8FF'>QUESTION</t><br/><t size='0.9'>%1</t><br/><t size='0.85'>Asking...</t>",
            _qlbl
        ];

        private _pl = [[["qid", _qid], ["label", _qlbl]]] call _hmFrom;
            ["QUESTION"] call _kickWatchdog;
        [_civ, player, "QUESTION", _pl] remoteExecCall ["ARC_fnc_civsubContactReqAction", 2];
    } else {
        _resp ctrlSetStructuredText parseText "<t size='0.9'>Select an action or question first.</t>";
        uiNamespace setVariable ["ARC_civsubInteract_hasUserOutput", true];
        uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", false];
    };
};

true
