/*
    ARC_fnc_civsubContactClientReceiveResult

    Client-side: receives the result of a dialog action and writes it to the response pane.
    Also supports embedded ID card overlay for CHECK_ID results.

    Params:
      0: html text (string) OR result object (HashMap/Array pairs)
*/

if (!hasInterface) exitWith { true };

params [
    ["_in", "", ["", createHashMap, []]]
];

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
private _hg      = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _trimFn  = compile "params ['_s']; trim _s";

private _d = uiNamespace getVariable ["ARC_civsubInteract_display", displayNull];
private _resp = controlNull;
if (!isNull _d) then { _resp = _d displayCtrl 78320; };

private _html = "";
private _type = "";
private _ok = false;
private _payload = createHashMap;
private _raw = _in;

if (_in isEqualType "") then {
    _html = _in;
} else {
    private _hm = _in;
    if (_hm isEqualType []) then { _hm = [_hm] call _hmCreate; };
    if (_hm isEqualType createHashMap) then {
        _html = [_hm, "html", ""] call _hg;
        _type = [_hm, "type", ""] call _hg;
        _ok = [_hm, "ok", false] call _hg;
        _payload = [_hm, "payload", createHashMap] call _hg;
        if (_payload isEqualType []) then { _payload = [_payload] call _hmCreate; };
    };
};

if (_type isEqualType "") then { _type = toUpper ([_type] call _trimFn); };

private _st = systemTime;
private _pad2 = {
    params ["_n"];
    private _v = _n;
    if !(_v isEqualType 0) then { _v = 0; };
    if (_v < 10) exitWith { format ["0%1", _v] };
    str _v
};
private _stamp = if (_st isEqualType [] && {(count _st) >= 6}) then {
    format ["%1:%2:%3", [(_st select 3)] call _pad2, [(_st select 4)] call _pad2, [(_st select 5)] call _pad2]
} else {
    "--:--:--"
};

uiNamespace setVariable ["ARC_console_civsubLastResult", [[
    ["raw", _raw],
    ["html", _html],
    ["type", _type],
    ["ok", _ok],
    ["payload", _payload],
    ["updatedAtText", _stamp],
    ["updatedAtTick", diag_tickTime]
]] call _hmCreate];

if (!isNull _resp && {!(_html isEqualTo "")}) then {
    _resp ctrlSetStructuredText parseText _html;
};

// Mark user output and clear in-progress flag as soon as a result arrives.
uiNamespace setVariable ["ARC_civsubInteract_hasUserOutput", true];
uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", false];
if !(_type isEqualTo "") then { uiNamespace setVariable ["ARC_civsubInteract_lastResultType", _type]; };

// If the result payload contains updated need/outlook values, merge them into the current snapshot and refresh the header.
if (_payload isEqualType createHashMap) then {
    private _snap = uiNamespace getVariable ["ARC_civsubInteract_snapshot", createHashMap];
    if (_snap isEqualType createHashMap) then {
        {
            private _k = _x;
            if (_k in ["need_satiation_after","need_hydration_after","outlook_after"]) then {
                private _v = [_payload, _k, -1] call _hg;
                if (_v isEqualType 0 && {_v >= 0}) then {
                    if (_k isEqualTo "need_satiation_after") then { _snap set ["need_satiation", _v]; };
                    if (_k isEqualTo "need_hydration_after") then { _snap set ["need_hydration", _v]; };
                    if (_k isEqualTo "outlook_after") then { _snap set ["outlook_blufor", _v]; };
                };
            };
        } forEach ["need_satiation_after","need_hydration_after","outlook_after"];

        uiNamespace setVariable ["ARC_civsubInteract_snapshot", _snap];

        // refresh header with updated snapshot + supplies counts (dialog only)
        if (!isNull _d) then { [_d, _snap] call ARC_fnc_civsubInteractUpdateHeaderStats; };
    };
};


// CHECK_ID: build an ID card panel string and keep it in the right DETAILS pane.
// We intentionally do NOT use a full-screen overlay; this avoids z-order/"Back" regressions.
if (_type isEqualTo "CHECK_ID" && {_ok} && {_payload isEqualType createHashMap}) then {
    private _name = [_payload, "name", ""] call _hg;
    private _serial = [_payload, "passport_serial", ""] call _hg;
    private _age = [_payload, "age", -1] call _hg;
    private _occ = [_payload, "occupation", ""] call _hg;
    private _home = [_payload, "home", ""] call _hg;
    private _grid = [_payload, "home_grid", ""] call _hg;
    private _did = [_payload, "districtId", ""] call _hg;
    private _flags = [_payload, "flags", []] call _hg;

    private _didS = if (_did isEqualTo "") then { "--" } else { _did };
    private _nameParts = if (_name isEqualType "") then { ([_name] call _trimFn) splitString " \t\r\n" } else { [] };
    private _nameS = if ((count _nameParts) > 0) then { _nameParts joinString " " } else { format ["Unknown (%1)", _didS] };

    private _ageS = if (_age isEqualType 0 && {_age >= 0}) then { str _age } else { "N/A" };
    private _occS = if (_occ isEqualType "" && {!(_occ isEqualTo "")}) then { _occ } else { "N/A" };
    private _homeS = if (_home isEqualType "" && {!(_home isEqualTo "")}) then { _home } else { "Unknown" };
    private _gridS = if (_grid isEqualType "" && {!(_grid isEqualTo "")}) then { _grid } else { "----" };
    private _flagsS = "";
    if (_flags isEqualType [] && {(count _flags) > 0}) then { _flagsS = _flags joinString ", "; };

    private _header = "<t size='0.92' font='PuristaMedium' align='center' color='#C0D0C0'>TAKISTAN CIV ID</t>";
    private _body = format [
        "<t size='0.86' color='#B8B8B8'>NAME</t> <t size='0.90' color='#FFFFFF'>%1</t><br/>" +
        "<t size='0.86' color='#B8B8B8'>SERIAL</t> <t size='0.90' color='#FFFFFF'>%2</t><br/>" +
        "<t size='0.86' color='#B8B8B8'>AGE</t> <t size='0.90' color='#FFFFFF'>%3</t><br/>" +
        "<t size='0.86' color='#B8B8B8'>OCC</t> <t size='0.90' color='#FFFFFF'>%4</t><br/>" +
        "<t size='0.86' color='#B8B8B8'>HOME</t> <t size='0.90' color='#FFFFFF'>%5</t><br/>" +
        "<t size='0.86' color='#B8B8B8'>GRID</t> <t size='0.90' color='#FFFFFF'>%6</t><br/>" +
        "<t size='0.86' color='#B8B8B8'>DIST</t> <t size='0.90' color='#FFFFFF'>%7</t>",
        _nameS, _serial, _ageS, _occS, _homeS, _gridS, _didS
    ];

    private _flagsLine = if (_flagsS isEqualTo "") then {
        "<t size='0.84' color='#9FD39F'>STATUS: CLEAR</t>"
    } else {
        format ["<t size='0.84' color='#FF9090'>STATUS: %1</t>", _flagsS]
    };

    private _cardHtml = format ["%1<br/><br/>%2<br/><br/>%3", _header, _body, _flagsLine];
    uiNamespace setVariable ["ARC_civsubInteract_idCardHtml", _cardHtml];

    // If the player is currently on CHECK_ID in the standalone dialog, refresh details there.
    if (!isNull _d) then { ["CHECK_ID"] call ARC_fnc_civsubContactDialogUpdateRightPane; };
};

// Console-routed CIVSUB mode: repaint S2 details + user feedback.
private _console = uiNamespace getVariable ["ARC_console_display", displayNull];
private _ctxCiv = uiNamespace getVariable ["ARC_civsubInteract_target", objNull];
if (!isNull _console && {!isNull _ctxCiv}) then {
    [_console, false] call ARC_fnc_uiConsoleIntelPaint;
    if !(_type isEqualTo "") then {
        private _msg = if (_ok) then { format ["%1 complete.", _type] } else { format ["%1 returned a warning.", _type] };
        ["CIVSUB", _msg] call ARC_fnc_clientToast;
    };
};

true
