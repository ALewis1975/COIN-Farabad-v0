/*
    ARC_fnc_civsubContactActionDetain

    Server-side: dialog action wrapper for Detain.

    HF5:
      - Stop fighting ACE captives/handcuffs.
      - Do NOT disable MOVE.
      - Disable PATH while un-cuffed so the civ stays put.
      - When ACE handcuffed is detected, re-enable PATH (so escort can work) and let ACE own cuff pose.

    Params:
      0: actor (object)
      1: civ (object)

    Returns:
      [ok(bool), html(string)]
*/

if (!isServer) exitWith { [false, "<t size='0.9'>Detain failed (not server).</t>"] };
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith { [false, "<t size='0.9'>Detain failed (CIVSUB disabled).</t>"] };

params [
    ["_actor", objNull, [objNull]],
    ["_civ", objNull, [objNull]]
];

if (isNull _actor || {isNull _civ}) exitWith { [false, "<t size='0.9'>Detain failed (invalid target).</t>"] };
if !(isPlayer _actor) exitWith { [false, "<t size='0.9'>Detain failed (invalid actor).</t>"] };
if !(_civ getVariable ["civsub_v1_isCiv", false]) exitWith { [false, "<t size='0.9'>Detain failed (not a CIVSUB civilian).</t>"] };

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _did = _civ getVariable ["civsub_districtId", ""];
private _actorUid = getPlayerUID _actor;

private _civUid = _civ getVariable ["civ_uid", ""];
if (!(_civUid isEqualTo "")) then {
    private _rec = [_civUid] call ARC_fnc_civsubIdentityGet;
    if (_rec isEqualType createHashMap) then {
        if ([_rec, "status_detained", false] call _hg) exitWith {
            [false, "<t size='0.95' color='#CFE8FF'>DETAIN</t><br/><t size='0.9'>Civilian is already detained.</t>"]
        };
    };
};

// Persist identity "detained" state if possible
if (!(_civUid isEqualTo "")) then {
    private _rec2 = [_civUid] call ARC_fnc_civsubIdentityGet;
    if (_rec2 isEqualType createHashMap) then {
        _rec2 set ["status_detained", true];
        _rec2 set ["status_detained_ts", serverTime];
        [_civUid, _rec2] call ARC_fnc_civsubIdentitySet;
    };
};

_civ setVariable ["civsub_detained", true, true];
_civ setVariable ["civsub_detained_by", _actorUid, true];
_civ setCaptive true;

// Hold in place initially (but keep MOVE enabled so ACE can animate/cuff)
_civ disableAI "PATH";
_civ enableAI "MOVE";
doStop _civ;

// If ACE captives is available, use it to set surrendered.
private _hasAceSurrender = !isNil "ace_captives_fnc_setSurrendered";
if (_hasAceSurrender) then {
    [_civ, true] call ace_captives_fnc_setSurrendered;
} else {
    // Fallback surrender pose if ACE is not present
    _civ switchMove "AmovPercMstpSsurWnonDnon";
};

// Spawn a short monitor to hand-off to ACE when cuffed
[_civ] spawn {
    params ["_u"];
    if (isNull _u) exitWith {};
    private _t0 = time;
    while {alive _u && {time < (_t0 + 20)}} do {
        private _cuffed = (_u getVariable ["ace_captives_isHandcuffed", false]) || (_u getVariable ["ACE_captives_isHandcuffed", false]);
        if (_cuffed) exitWith {
            // Let ACE own cuff pose; ensure surrendered is cleared
            if (!isNil "ace_captives_fnc_setHandcuffed") then { [_u, true] call ace_captives_fnc_setHandcuffed; };
            if (!isNil "ace_captives_fnc_setSurrendered") then { [_u, false] call ace_captives_fnc_setSurrendered; };
            // Re-enable PATH so escort/follow behavior can function
            _u enableAI "PATH";
        };
        uiSleep 1;
    };
};

private _aceCuffed = (_civ getVariable ["ace_captives_isHandcuffed", false]) || (_civ getVariable ["ACE_captives_isHandcuffed", false]);
private _cuffLine = if (_aceCuffed) then {"<t size='0.85'>ACE: Handcuffed</t>"} else {"<t size='0.85'>ACE: Not handcuffed</t>"};

private _html = format [
    "<t size='0.95' color='#CFE8FF'>DETAIN</t><br/>" +
    "<t size='0.9'>Civilian detained.</t><br/>" +
    "<t size='0.85'>Tip: Apply ACE handcuffs to escort; otherwise they remain held in place.</t><br/>%1",
    _cuffLine
];

[true, _html]
