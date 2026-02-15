/*
    ARC_fnc_civsubContactActionRelease

    Server-side: dialog action wrapper for Release.

    HF5:
      - Clears CIVSUB detain state.
      - Restores AI PATH.
      - Clears ACE surrendered state if present.
      - Does not forcibly remove handcuffs (player should do that), but will stop forcing surrender animations.

    Params:
      0: actor (object)
      1: civ (object)

    Returns:
      [ok(bool), html(string)]
*/

if (!isServer) exitWith { [false, "<t size='0.9'>Release failed (not server).</t>"] };
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith { [false, "<t size='0.9'>Release failed (CIVSUB disabled).</t>"] };

params [
    ["_actor", objNull, [objNull]],
    ["_civ", objNull, [objNull]]
];

if (isNull _actor || {isNull _civ}) exitWith { [false, "<t size='0.9'>Release failed (invalid target).</t>"] };
if !(isPlayer _actor) exitWith { [false, "<t size='0.9'>Release failed (invalid actor).</t>"] };
if !(_civ getVariable ["civsub_v1_isCiv", false]) exitWith { [false, "<t size='0.9'>Release failed (not a CIVSUB civilian).</t>"] };

private _civUid = _civ getVariable ["civ_uid", ""];
if (!(_civUid isEqualTo "")) then {
    private _rec = [_civUid] call ARC_fnc_civsubIdentityGet;
    if (_rec isEqualType createHashMap) then {
        _rec set ["status_detained", false];
        _rec set ["status_detained_ts", serverTime];
        [_civUid, _rec] call ARC_fnc_civsubIdentitySet;
    };
};

_civ setVariable ["civsub_detained", false, true];
_civ setVariable ["civsub_detained_by", "", true];

_civ setCaptive false;
_civ enableAI "PATH";
_civ enableAI "MOVE";

private _cuffed = (_civ getVariable ["ace_captives_isHandcuffed", false]) || (_civ getVariable ["ACE_captives_isHandcuffed", false]);

if (!isNil "ace_captives_fnc_setSurrendered") then {
    [_civ, false] call ace_captives_fnc_setSurrendered;
} else {
    // clear any forced anim
    _civ switchMove "";
};

private _html = if (_cuffed) then {
    "<t size='0.95' color='#CFE8FF'>RELEASE</t><br/><t size='0.9'>Released from CIVSUB detention. Note: ACE handcuffs still applied.</t>"
} else {
    "<t size='0.95' color='#CFE8FF'>RELEASE</t><br/><t size='0.9'>Civilian released.</t>"
};

[true, _html]
