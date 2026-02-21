/*
    ARC_fnc_civsubContactActionCheckId

    Server-side: cooperative "Check ID" for the CIV INTERACT dialog.

    Mirrors ARC_fnc_civsubInteractShowPapers logic but DOES NOT open the standalone ID card (cutRsc).
    Instead, returns the ID payload to the dialog client for embedded display.

    Params:
      0: actor (object) - player who initiated
      1: civ (object)   - target civilian

    Returns:
      [boolSuccess, payloadHashMapOrEmpty]
*/

if (!isServer) exitWith {[false, createHashMap]};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {[false, createHashMap]};

params [
    ["_actor", objNull, [objNull]],
    ["_civ", objNull, [objNull]]
];

if (isNull _actor || {isNull _civ}) exitWith {[false, createHashMap]};
if !(isPlayer _actor) exitWith {[false, createHashMap]};

private _did = _civ getVariable ["civsub_districtId", ""];
if (_did isEqualTo "") exitWith {
    ["<t size='0.9'>This civilian has no district id.</t>"] remoteExecCall ["ARC_fnc_civsubContactClientReceiveResult", _actor];
    [false, createHashMap]
};

private _d = [_did] call ARC_fnc_civsubDistrictsGetById;
if (_d isEqualType []) then { _d = createHashMapFromArray _d; };
if !(_d isEqualType createHashMap) exitWith {[false, createHashMap]};

private _scores = [_d] call ARC_fnc_civsubScoresCompute;
private _Scoop = _scores getOrDefault ["S_COOP", 0];

// Locked baseline mapping
private _pCoop = 0.10 + (0.008 * _Scoop);
if (_pCoop < 0.10) then { _pCoop = 0.10; };
if (_pCoop > 0.90) then { _pCoop = 0.90; };

private _force = missionNamespace getVariable ["civsub_v1_showPapers_forceCoop", false];
private _cooperative = _force || { (random 1) < _pCoop };

if !(_cooperative) exitWith {
    // keep dialog feedback only (avoid extra chat spam)
    [false, createHashMap]
};

// Ensure stable civ_uid and touch identity
private _actorUid = getPlayerUID _actor;
private _civUid = _civ getVariable ["civ_uid", ""];
if (_civUid isEqualTo "") then {
    _civUid = [_did] call ARC_fnc_civsubIdentityGenerateUid;
    _civ setVariable ["civ_uid", _civUid, true];
};

private _rec = [_did, _actorUid, _civUid, getPosATL _civ] call ARC_fnc_civsubIdentityTouch;
if !(_rec isEqualType createHashMap) exitWith {[false, createHashMap]};

private _first = _rec getOrDefault ["first_name", ""];
private _last  = _rec getOrDefault ["last_name", ""];
private _serial = _rec getOrDefault ["passport_serial", ""];

private _normalizeNamePart = {
    params ["_v"];
    if !(_v isEqualType "") exitWith { "" };
    private _parts = (trim _v) splitString " \t\r\n";
    if ((count _parts) <= 0) exitWith { "" };
    _parts joinString " "
};

_first = [_first] call _normalizeNamePart;
_last = [_last] call _normalizeNamePart;

private _name = [_first, _last] select {!(_x isEqualTo "")} joinString " ";
if (_name isEqualTo "") then {
    _name = format ["Unknown (%1)", _did];
};

private _dob = _rec getOrDefault ["dob_iso", ""];
private _job = _rec getOrDefault ["occupation", ""];
private _homePos = _rec getOrDefault ["home_pos", getPosATL _civ];
if !(_homePos isEqualType [] && {(count _homePos) >= 2}) then { _homePos = getPosATL _civ; };

// compute age (approx)
private _age = -1;
if (_dob isEqualType "" && {(count _dob) >= 4}) then {
    private _y = parseNumber (_dob select [0,4]);
    private _dNow = date;
    private _cy = _dNow # 0;
    private _cm = _dNow # 1;
    private _cd = _dNow # 2;
    private _bm = if ((count _dob) >= 7) then { parseNumber (_dob select [5,2]) } else { 1 };
    private _bd = if ((count _dob) >= 10) then { parseNumber (_dob select [8,2]) } else { 1 };
    _age = _cy - _y;
    if ((_cm < _bm) || {(_cm == _bm) && {_cd < _bd}}) then { _age = _age - 1; };
};

// nearest named location
private _homeName = "";
private _named = missionNamespace getVariable ["ARC_worldNamedLocations", []];
if (_named isEqualType [] && {(count _named) > 0}) then {
    private _bestD = 1e12;
    private _hx = _homePos # 0;
    private _hy = _homePos # 1;
    {
        if (_x isEqualType [] && {(count _x) >= 3}) then {
            _x params ["_id","_dn","_p"];
            if (_p isEqualType [] && {(count _p) >= 2}) then {
                private _dx = (_p # 0) - _hx;
                private _dy = (_p # 1) - _hy;
                private _dd = (_dx * _dx) + (_dy * _dy);
                if (_dd < _bestD) then { _bestD = _dd; _homeName = _dn; };
            };
        };
    } forEach _named;
};

private _homeGrid = mapGridPosition _homePos;

// flags
private _wanted = _rec getOrDefault ["wanted_level", 0];
private _detained = _rec getOrDefault ["status_detained", false];
private _poi = _rec getOrDefault ["poi_id", ""];
private _charges = _rec getOrDefault ["charges", []];
private _knownDb = !(_poi isEqualTo "") || {(_charges isEqualType []) && {(count _charges) > 0}};

private _flags = [];
if ((_wanted isEqualType 0) && {_wanted > 0}) then { _flags pushBack format ["WANTED(%1)", _wanted]; };
if (_detained isEqualType true && {_detained}) then { _flags pushBack "DETained"; };
if (_knownDb) then { _flags pushBack "KNOWN_DB"; };

private _payload = createHashMapFromArray [
    ["cooperative", true],
    ["shown", "ID"],
    ["passport_serial", _serial],
    ["civ_netId", netId _civ],
    ["name", _name],
    ["age", _age],
    ["occupation", _job],
    ["home", _homeName],
    ["home_grid", _homeGrid],
    ["districtId", _did],
    ["flags", _flags]
];

// Emit baseline delta
[_did, "SHOW_PAPERS", "IDENTITY", _payload, _actorUid] call ARC_fnc_civsubEmitDelta;

[true, _payload]
