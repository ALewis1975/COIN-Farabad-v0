/*
    ARC_fnc_civsubContactDialogOnLoad

    Client-side: populates the CIV interact dialog controls.

    Contract:
      - Populates Actions list (left pane).
      - Right pane is context: details/instructions in Action mode, questions list in Questions mode.
      - Uses uiNamespace display handle first (Arma onLoad timing).
      - Hides embedded ID overlay by default.
      - Distance watcher auto-closes when player leaves the civ.
*/
if (!hasInterface) exitWith { true };

private _d = uiNamespace getVariable ["ARC_civsubInteract_display", displayNull];
if (isNull _d) exitWith {
    private _tries = uiNamespace getVariable ["ARC_civsubInteract_onLoadTries", 0];

    if (_tries > 10) then {
        diag_log "[CIVSUB][UI] Interact OnLoad: display handle not ready after 10 tries.";
        uiNamespace setVariable ["ARC_civsubInteract_onLoadTries", 0];
    } else {
        uiNamespace setVariable ["ARC_civsubInteract_onLoadTries", _tries + 1];
        [] spawn {
            uiSleep 0.01;
            [] call ARC_fnc_civsubContactDialogOnLoad;
        };
    };

    true
};

uiNamespace setVariable ["ARC_civsubInteract_onLoadTries", 0];

private _civ = uiNamespace getVariable ["ARC_civsubInteract_target", objNull];

private _hdr  = _d displayCtrl 78392;
private _lbA  = _d displayCtrl 78310;
private _lbQ  = _d displayCtrl 78311;
private _resp = _d displayCtrl 78320;

private _ovBG   = _d displayCtrl 78360;
private _ovCard = _d displayCtrl 78361;
private _ovBack = _d displayCtrl 78362;

if (isNull _hdr || isNull _lbA || isNull _lbQ || isNull _resp) exitWith {
    diag_log "[CIVSUB][UI] Interact OnLoad: missing one or more core controls (hdr/lbA/lbQ/resp).";
    true
};

// Hide embedded ID overlay by default
if (!isNull _ovBG) then { _ovBG ctrlShow false; };
if (!isNull _ovCard) then { _ovCard ctrlShow false; _ovCard ctrlSetStructuredText parseText ""; };
if (!isNull _ovBack) then { _ovBack ctrlShow false; };

lbClear _lbA;
lbClear _lbQ;

// Header (authoritative snapshot overwrites later)
private _name = if (!isNull _civ) then { name _civ } else { "Unknown" };
private _nid  = if (!isNull _civ) then { netId _civ } else { "N/A" };
_hdr ctrlSetStructuredText parseText format [
    "<t size='1.1'>Civilian: %1</t><br/><t size='0.85'>NetId: %2</t>",
    _name,
    _nid
];

// Actions
private _idx = -1;

_idx = _lbA lbAdd "Check ID";
_lbA lbSetData [_idx, "CHECK_ID"];

_idx = _lbA lbAdd "Background Check";
_lbA lbSetData [_idx, "BACKGROUND_CHECK"];

_idx = _lbA lbAdd "Ask Questions";
_lbA lbSetData [_idx, "ASK_QUESTIONS"];

_idx = _lbA lbAdd "Detain";
_lbA lbSetData [_idx, "DETAIN"];

_idx = _lbA lbAdd "Release";
_lbA lbSetData [_idx, "RELEASE"];

_idx = _lbA lbAdd "Give Food";
_lbA lbSetData [_idx, "AID_RATIONS"];

_idx = _lbA lbAdd "Give Water";
_lbA lbSetData [_idx, "AID_WATER"];

// Event handlers (prevent duplicate EHs on retries)
if (isNil { uiNamespace getVariable "ARC_civsubInteract_ehBound" }) then { uiNamespace setVariable ["ARC_civsubInteract_ehBound", false]; };

if !(uiNamespace getVariable ["ARC_civsubInteract_ehBound", false]) then {
    _lbA ctrlAddEventHandler ["LBSelChanged", { _this call ARC_fnc_civsubContactDialogOnActionSelChanged; }];
    _lbQ ctrlAddEventHandler ["LBSelChanged", { _this call ARC_fnc_civsubContactDialogOnQuestionSelChanged; }];
    uiNamespace setVariable ["ARC_civsubInteract_ehBound", true];
};

// Default mode: Action details
uiNamespace setVariable ["ARC_civsubInteract_mode", "A"];
uiNamespace setVariable ["ARC_civsubInteract_lastPane", "A"];

[""] call ARC_fnc_civsubContactDialogUpdateRightPane;

_resp ctrlSetStructuredText parseText "<t size='0.9'>Ready.</t>";

// Request snapshot (authoritative)
if (!isNull _civ) then {
    [_civ, player] remoteExecCall ["ARC_fnc_civsubContactReqSnapshot", 2];
};

// Distance watcher
uiNamespace setVariable ["ARC_civsubInteract_watchStop", false];

[_civ] spawn {
    params ["_civ"];
    private _stopVar = "ARC_civsubInteract_watchStop";

    while { !(uiNamespace getVariable [_stopVar, false]) } do {
        uiSleep 0.5;

        private _dLocal = uiNamespace getVariable ["ARC_civsubInteract_display", displayNull];
        if (isNull _dLocal) exitWith { true };
        if (isNull _civ) exitWith { closeDialog 0; true };
        if (!alive player || {!alive _civ}) exitWith { closeDialog 0; true };
        if (player distance _civ > 5) exitWith { closeDialog 0; true };
    };
};

true
