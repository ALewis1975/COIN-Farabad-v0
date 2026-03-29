/*
    ARC_fnc_civsubContactClientReceiveSnapshot

    Client-side: receives a server snapshot for the currently opened CIV interact dialog.

    Params:
      0: snapshot (HashMap)

    Snapshot keys (v1):
      need_satiation (number 0-100)
      need_hydration (number 0-100)
      outlook_blufor (number 0-100)
      name_display (string)
      passport_serial (string)
      districtId (string)
      detained (bool)
      known (bool)
*/

if (!hasInterface) exitWith { true };

params [
    ["_snap", createHashMap, [createHashMap]]
];

uiNamespace setVariable ["ARC_civsubInteract_snapshot", _snap];

private _d = uiNamespace getVariable ["ARC_civsubInteract_display", displayNull];
private _resp = controlNull;
private _lbA = controlNull;
if (!isNull _d) then {
    _resp = _d displayCtrl 78320;
    _lbA = _d displayCtrl 78310;
};

private _name = _snap getOrDefault ["name_display", "Unknown"]; 
private _serial = _snap getOrDefault ["passport_serial", ""]; 
private _did = _snap getOrDefault ["districtId", ""]; 
private _det = _snap getOrDefault ["detained", false];
private _known = _snap getOrDefault ["known", false];

private _serialLine = if (_serial isEqualTo "") then {"Serial: N/A"} else {format ["Serial: %1", _serial]};
private _knownLine = if (_known) then {"Status: VERIFIED"} else {"Status: UNVERIFIED"};
private _detLine = if (_det) then {"Custody: DETAINED"} else {"Custody: NOT DETAINED"};
private _didLine = if (_did isEqualTo "") then {"District: N/A"} else {format ["District: %1", _did]};

// Header formatting (includes supplies + needs)
if (!isNull _d) then { [_d, _snap] call ARC_fnc_civsubInteractUpdateHeaderStats; };


// Enable/disable custody actions based on detained flag (UI-only for now)
// Find indices by label since listbox is rebuilt onLoad.
if (!isNull _lbA) then {
    private _cnt = lbSize _lbA;
    for "_i" from 0 to (_cnt - 1) do {
        private _lbl = _lbA lbText _i;
        if (_lbl isEqualTo "Detain") then { _lbA lbSetColor [_i, if (_det) then {[0.6,0.6,0.6,1]} else {[1,1,1,1]}]; };
        if (_lbl isEqualTo "Release") then { _lbA lbSetColor [_i, if (_det) then {[1,1,1,1]} else {[0.6,0.6,0.6,1]}]; };
    };
};

// Do not overwrite the response pane if the user has executed actions or if an action is in progress.
// Only clear the initial "Loading civilian record" message once, after the first snapshot arrives.
private _inInit = uiNamespace getVariable ["ARC_civsubInteract_initializing", false];
private _hasOutput = uiNamespace getVariable ["ARC_civsubInteract_hasUserOutput", false];
private _inProg = uiNamespace getVariable ["ARC_civsubInteract_actionInProgress", false];

if (_inInit && {!_hasOutput} && {!_inProg} && {!isNull _resp}) then {
    _resp ctrlSetStructuredText parseText "<t size='0.9'>Ready.</t>";
    uiNamespace setVariable ["ARC_civsubInteract_initializing", false];
};

private _console = uiNamespace getVariable ["ARC_console_display", displayNull];
private _ctxCiv = uiNamespace getVariable ["ARC_civsubInteract_target", objNull];
if (!isNull _console && {!isNull _ctxCiv}) then {
    [_console, true] call ARC_fnc_uiConsoleIntelPaint;
};

true
