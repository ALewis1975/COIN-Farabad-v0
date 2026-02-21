/*
    ARC_fnc_civsubInteractShowPapers

    Server-side handler for ACE interaction: cooperative "Show Papers".

    Params:
      0: actor (object) - player who initiated
      1: civ (object)   - target civilian

    Emits:
      SHOW_PAPERS delta bundle (if cooperative)
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

params [
    ["_actor", objNull, [objNull]],
    ["_civ", objNull, [objNull]]
];

if (isNull _actor || {isNull _civ}) exitWith {false};
if !(isPlayer _actor) exitWith {false};

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; [(_h), _k, _d] call _hg";
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";

// Dedicated MP hardening:
// If invoked via remoteExec, bind actor identity to network sender.
if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        if ((owner _actor) != _reo) exitWith
        {
            diag_log format ["[CIVSUB][SEC] %1 denied: sender-owner mismatch reo=%2 actorOwner=%3 actor=%4",
                "ARC_fnc_civsubInteractShowPapers",
                _reo,
                owner _actor,
                name _actor
            ];
            false
        };
    };
};

private _did = _civ getVariable ["civsub_districtId", ""];
if (_did isEqualTo "") exitWith {
    ["CIVSUB: This civilian has no district id.", "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
    false
};

private _d = [_did] call ARC_fnc_civsubDistrictsGetById;
if (_d isEqualType []) then { _d = [_d] call _hmFrom; };
if !(_d isEqualType createHashMap) exitWith {false};

private _scores = [_d] call ARC_fnc_civsubScoresCompute;
private _Scoop = [_scores, "S_COOP", 0] call _hg;

// Locked baseline mapping
private _pCoop = 0.10 + (0.008 * _Scoop);
if (_pCoop < 0.10) then { _pCoop = 0.10; };
if (_pCoop > 0.90) then { _pCoop = 0.90; };

private _force = missionNamespace getVariable ["civsub_v1_showPapers_forceCoop", false];
private _cooperative = _force || { (random 1) < _pCoop };

if !(_cooperative) exitWith {
    ["CIVSUB: Civilian refuses to show papers.", "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
    false
};

// Ensure unit has a stable civ_uid (assigned at spawn) and touch identity only now.
private _actorUid = getPlayerUID _actor;
private _civUid = _civ getVariable ["civ_uid", ""];
if (_civUid isEqualTo "") then {
    _civUid = [_did] call ARC_fnc_civsubIdentityGenerateUid;
    _civ setVariable ["civ_uid", _civUid, true];
};

private _rec = [_did, _actorUid, _civUid, getPosATL _civ] call ARC_fnc_civsubIdentityTouch;
if !(_rec isEqualType createHashMap) exitWith {false};

private _first = [_rec, "first_name", ""] call _hg;
private _last = [_rec, "last_name", ""] call _hg;
private _serial = [_rec, "passport_serial", ""] call _hg;


private _dob = [_rec, "dob_iso", ""] call _hg;
private _job = [_rec, "occupation", ""] call _hg;
private _homePos = [_rec, "home_pos", getPosATL _civ] call _hg;

// --- compute age (approx, yyyy-mm-dd) -----------------
private _age = -1;
if (_dob isEqualType "" && {(count _dob) >= 4}) then {
    private _y = parseNumber (_dob select [0,4]);
    private _dNow = date; // [year, month, day, hour, minute]
    private _cy = _dNow select 0;
    private _cm = _dNow select 1;
    private _cd = _dNow select 2;
    private _bm = if ((count _dob) >= 7) then { parseNumber (_dob select [5,2]) } else { 1 };
    private _bd = if ((count _dob) >= 10) then { parseNumber (_dob select [8,2]) } else { 1 };
    _age = _cy - _y;
    if ((_cm < _bm) || {(_cm == _bm) && {_cd < _bd}}) then { _age = _age - 1; };
};

// --- nearest named location name ----------------------
private _homeName = "";
private _named = missionNamespace getVariable ["ARC_worldNamedLocations", []];
if (_named isEqualType [] && {(count _named) > 0}) then {
    private _bestD = 1e12;
    private _hx = _homePos select 0;
    private _hy = _homePos select 1;
    {
        _x params ["_id","_dn","_p"];
        private _dx = (_p select 0) - _hx;
        private _dy = (_p select 1) - _hy;
        private _dd = (_dx * _dx) + (_dy * _dy);
        if (_dd < _bestD) then { _bestD = _dd; _homeName = _dn; };
    } forEach _named;
};

private _homeGrid = mapGridPosition _homePos;

// --- flags --------------------------------------------
private _wanted = [_rec, "wanted_level", 0] call _hg;
private _detained = [_rec, "status_detained", false] call _hg;
private _poi = [_rec, "poi_id", ""] call _hg;
private _charges = [_rec, "charges", [] call _hg];
private _knownDb = !(_poi isEqualTo "") || {(_charges isEqualType []) && {(count _charges) > 0}};

private _flags = [];
if ((_wanted isEqualType 0) && {_wanted > 0}) then { _flags pushBack format ["WANTED(%1)", _wanted]; };
if (_detained isEqualType true && {_detained}) then { _flags pushBack "DETained"; };
if (_knownDb) then { _flags pushBack "KNOWN_DB"; };

private _payload = [[
    ["cooperative", true],
    ["shown", "ID"],
    ["passport_serial", _serial],
    ["civ_netId", netId _civ],
    ["name", format ["%1 %2", _first, _last]],
    ["age", _age],
    ["occupation", _job],
    ["home", _homeName],
    ["home_grid", _homeGrid],
    ["districtId", _did],
    ["flags", _flags]
]] call _hmFrom;

[_did, "SHOW_PAPERS", "IDENTITY", _payload, _actorUid] call ARC_fnc_civsubEmitDelta;

[_payload] remoteExecCall ["ARC_fnc_civsubClientShowIdCard", _actor];

[format ["CIVSUB: ID verified for %1 %2 (Serial %3).", _first, _last, _serial], "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
true