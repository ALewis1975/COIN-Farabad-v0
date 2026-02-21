/*
    ARC_fnc_civsubContactReqSnapshot

    Server-side: builds an authoritative dialog snapshot for a CIVSUB-managed civilian and sends it
    back to the requesting client.

    Params:
      0: civ (object)
      1: actor (object)

    Snapshot keys (v1):
      name_display (string)
      passport_serial (string)
      districtId (string)
      detained (bool)
      known (bool)

    Returns: bool
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

params [
    ["_civ", objNull, [objNull]],
    ["_actor", objNull, [objNull]]
];

if (isNull _civ || {isNull _actor}) exitWith {false};
if !(isPlayer _actor) exitWith {false};
if !(_civ getVariable ["civsub_v1_isCiv", false]) exitWith {false};

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _keysFn   = compile "params ['_m']; keys _m";
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";

// Dedicated MP hardening:
// If this function was invoked via remoteExec, bind actor identity to the network sender.
if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        if ((owner _actor) != _reo) exitWith
        {
            diag_log format ["[CIVSUB][SEC] SNAPSHOT denied: sender-owner mismatch reo=%1 actorOwner=%2 actor=%3 civ=%4",
                _reo,
                owner _actor,
                name _actor,
                _civ getVariable ["civ_uid", ""]
            ];
            false
        };
    };
};

private _did = _civ getVariable ["civsub_districtId", ""];
private _civUid = _civ getVariable ["civ_uid", ""]; // assigned at spawn

private _rec = createHashMap;
if !(_civUid isEqualTo "") then {
    _rec = [_civUid] call ARC_fnc_civsubIdentityGet;
};

private _known = (_rec isEqualType createHashMap) && {(count ([_rec] call _keysFn)) > 0};
private _detained = false;
private _nameDisplay = "Unknown";
private _serial = "";

if (_known) then {
    private _first = [_rec, "first_name", ""] call _hg;
    private _last  = [_rec, "last_name", ""] call _hg;
    _serial = [_rec, "passport_serial", ""] call _hg;
    _detained = [_rec, "status_detained", false] call _hg;

    private _nm = format ["%1 %2", _first, _last];
    _nameDisplay = if (_nm isEqualTo " ") then {"Unknown"} else {_nm};
} else {
    // Until touched via Check ID / other cooperative actions, we don't reveal the generated profile.
    _nameDisplay = "Unknown";
    _serial = "";
    _detained = false;
};


// Needs / outlook (observable, does not require ID verification)
private _sat = _civ getVariable ["civsub_need_satiation", -1];
if !(_sat isEqualType 0) then { _sat = -1; };
if (_sat < 0) then {
    _sat = 30 + floor (random 41); // 30-70
    _civ setVariable ["civsub_need_satiation", _sat, true];
};

private _hyd = _civ getVariable ["civsub_need_hydration", -1];
if !(_hyd isEqualType 0) then { _hyd = -1; };
if (_hyd < 0) then {
    _hyd = 30 + floor (random 41); // 30-70
    _civ setVariable ["civsub_need_hydration", _hyd, true];
};

private _out = _civ getVariable ["civsub_outlook_blufor", -1];
if !(_out isEqualType 0) then { _out = -1; };
if (_out < 0) then {
    _out = 45 + floor (random 21); // 45-65 baseline
    _civ setVariable ["civsub_outlook_blufor", _out, true];
};

private _snap = [[
    ["name_display", _nameDisplay],
    ["passport_serial", _serial],
    ["districtId", _did],
    ["detained", _detained],
    ["known", _known],
    ["need_satiation", _sat],
    ["need_hydration", _hyd],
    ["outlook_blufor", _out]
]] call _hmFrom;

[_snap] remoteExecCall ["ARC_fnc_civsubContactClientReceiveSnapshot", _actor];
true
