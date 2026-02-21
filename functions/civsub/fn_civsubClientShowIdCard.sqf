/*
    ARC_fnc_civsubClientShowIdCard

    Client-side: displays a lightweight CIV ID card UI using RscTitles.

    Params:
      0: payload (HashMap or Array pairs)
*/
if (!hasInterface) exitWith {false};

params [
    ["_payload", createHashMap, [createHashMap, []]]
];

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";

if (_payload isEqualType []) then { _payload = [_payload] call _hmFrom; };
if !(_payload isEqualType createHashMap) exitWith {false};

uiNamespace setVariable ["ARC_civsub_lastIdCardPayload", _payload];

cutRsc ["ARC_CivIdCard", "PLAIN", 0, false];

private _disp = uiNamespace getVariable ["ARC_CivIdCard_display", displayNull];
if (isNull _disp) exitWith {false};

private _ctrl = _disp displayCtrl 86101;
if (isNull _ctrl) exitWith {false};

private _name = [_payload, "name", "Unknown"] call _hg;
private _serial = [_payload, "passport_serial", ""] call _hg;
private _age = [_payload, "age", -1] call _hg;
private _occ = [_payload, "occupation", ""] call _hg;
private _home = [_payload, "home", ""] call _hg;
private _grid = [_payload, "home_grid", ""] call _hg;
private _did = [_payload, "districtId", ""] call _hg;
private _flags = [_payload, "flags", []];

private _ageS = if (_age isEqualType 0 && {_age >= 0}) then { str _age } else { "N/A" };
private _occS = if (_occ isEqualType "" && {!(_occ isEqualTo "")}) then { _occ } else { "N/A" };
private _homeS = if (_home isEqualType "" && {!(_home isEqualTo "")}) then { _home } else { "Unknown" };
private _gridS = if (_grid isEqualType "" && {!(_grid isEqualTo "")}) then { _grid } else { "----" };
private _didS = if (_did isEqualType "" && {!(_did isEqualTo "")}) then { _did } else { "--" };

private _flagsS = "";
if (_flags isEqualType [] && {(count _flags) > 0}) then {
    _flagsS = _flags joinString ", ";
};

private _header = "<t size='1.10' font='PuristaMedium' align='center' color='#1E2A1E'>ISLAMIC REPUBLIC OF TAKISTAN</t><br/>" +
                  "<t size='0.92' font='PuristaLight' align='center' color='#2F3B2F'>Ministry of Interior • Civil Identification</t>";

private _body = format [
    "<t size='0.92' font='PuristaLight' color='#2B2B2B'>NAME</t> <t size='0.98' font='PuristaMedium' color='#0F0F0F'>%1</t><br/>" +
    "<t size='0.92' font='PuristaLight' color='#2B2B2B'>AGE</t> <t size='0.98' font='PuristaMedium' color='#0F0F0F'>%2</t><br/>" +
    "<t size='0.92' font='PuristaLight' color='#2B2B2B'>OCC</t> <t size='0.98' font='PuristaMedium' color='#0F0F0F'>%3</t><br/>" +
    "<t size='0.92' font='PuristaLight' color='#2B2B2B'>HOME</t> <t size='0.98' font='PuristaMedium' color='#0F0F0F'>%4</t><br/>" +
    "<t size='0.92' font='PuristaLight' color='#2B2B2B'>GRID</t> <t size='0.98' font='PuristaMedium' color='#0F0F0F'>%5</t><br/>" +
    "<t size='0.92' font='PuristaLight' color='#2B2B2B'>DIST</t> <t size='0.98' font='PuristaMedium' color='#0F0F0F'>%6</t><br/>" +
    "<t size='0.92' font='PuristaLight' color='#2B2B2B'>SERIAL</t> <t size='0.98' font='PuristaMedium' color='#0F0F0F'>%7</t>",
    _name, _ageS, _occS, _homeS, _gridS, _didS, _serial
];

private _flagsLine = if (_flagsS isEqualTo "") then {
    "<t size='0.88' font='PuristaLight' color='#3A3A3A'>STATUS: CLEAR</t>"
} else {
    format ["<t size='0.88' font='PuristaMedium' color='#7A1010'>STATUS: %1</t>", _flagsS]
};

private _footer = "<t size='0.72' font='PuristaLight' color='#3A3A3A'>Valid only with official stamp. Tampering is a criminal offense.</t>";

private _html = format ["%1<br/><br/>%2<br/><br/>%3<br/><br/>%4", _header, _body, _flagsLine, _footer];
_ctrl ctrlSetStructuredText parseText _html;

true
