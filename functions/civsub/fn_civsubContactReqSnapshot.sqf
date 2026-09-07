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

private _compatGetDefault = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k,_d]";
private _compatKeys = compile "params ['_h']; keys _h";
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

params [
    ["_civ", objNull, [objNull]],
    ["_actor", objNull, [objNull]]
];

if (isNull _civ || {isNull _actor}) exitWith {false};
if !(isPlayer _actor) exitWith {false};
if !(_civ getVariable ["civsub_v1_isCiv", false]) exitWith {false};

// Dedicated MP hardening:
// If this function was invoked via remoteExec, bind actor identity to the network sender.

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

private _reoOwner = remoteExecutedOwner;
if (!([_actor, "ARC_fnc_civsubContactReqSnapshot", "Request rejected: sender verification failed.", "CIVSUBCONTACTREQSNAPSHOT_SECURITY_DENIED", false, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith {false};

private _did = _civ getVariable ["civsub_districtId", ""];
private _civUid = _civ getVariable ["civ_uid", ""]; // assigned at spawn

private _rec = createHashMap;
if !(_civUid isEqualTo "") then {
    _rec = [_civUid] call ARC_fnc_civsubIdentityGet;
};

private _known = (_rec isEqualType createHashMap) && {(count (([_rec] call _compatKeys))) > 0};
private _detained = false;
private _nameDisplay = "Unknown";
private _serial = "";

if (_known) then {
    private _first = [_rec,"first_name",""] call _compatGetDefault;
    private _last  = [_rec,"last_name",""] call _compatGetDefault;
    _serial = [_rec,"passport_serial",""] call _compatGetDefault;
    _detained = [_rec,"status_detained",false] call _compatGetDefault;

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
]] call _hmCreate;

[_snap] remoteExecCall ["ARC_fnc_civsubContactClientReceiveSnapshot", _actor];
true
