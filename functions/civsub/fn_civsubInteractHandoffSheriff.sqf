/*
    ARC_fnc_civsubInteractHandoffSheriff

    Server-side: confirm detainee handoff at SHERIFF holding (25m).

    Milestone 3 (detention choreography):
      - Require cuffs removed (ACE captives handcuffs flag, if present)
      - Trigger surrender animation + hold in place
      - Transfer to EPW holding after a delay (default 300s)
      - Apply bounded "camp" behavior at EPW holding (LAMBS garrison if available)

    Params:
      0: actor (object)
      1: civ (object)

    Emits:
      DETENTION_HANDOFF (IDENTITY)
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

params [
    ["_actor", objNull, [objNull]],
    ["_civ", objNull, [objNull]]
];

if (isNull _actor || {isNull _civ}) exitWith {false};
if !(isPlayer _actor) exitWith {false};

// Dedicated MP hardening: bind actor identity to network sender.
if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        if ((owner _actor) != _reo) exitWith
        {
            diag_log format ["[CIVSUB][SEC] %1 denied: sender-owner mismatch reo=%2 actorOwner=%3 actor=%4",
                "ARC_fnc_civsubInteractHandoffSheriff", _reo, owner _actor, name _actor];
            false
        };
    };
};

private _resolveMarker = {
    params ["_name"];
    if (!isNil "ARC_fnc_worldResolveMarker") exitWith { [_name] call ARC_fnc_worldResolveMarker };
    _name
};

// Validate proximity to SHERIFF holding (or legacy EPW holding markers)
private _holdingCandidates = ["epw_holding", "mkr_SHERIFF_HOLDING"];
private _posList = [];
{
    private _m = [_x] call _resolveMarker;
    if !((markerType _m) isEqualTo "") then {
        private _p = getMarkerPos _m; _p resize 3;
        _posList pushBack _p;
    };
} forEach _holdingCandidates;

if ((count _posList) isEqualTo 0) exitWith {
    ["CIVSUB: No holding marker found (epw_holding).", "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
    false
};

private _minDist = {
    params ["_obj", "_poses"];
    private _min = 1e12;
    { _min = _min min (_obj distance2D _x); } forEach _poses;
    _min
};

private _dActor = [_actor, _posList] call _minDist;
private _dCiv   = [_civ, _posList] call _minDist;

if ((_dActor > 25) && { _dCiv > 25 }) exitWith {
    [format ["CIVSUB: Move within 25m of epw_holding. Dist(actor)=%.1fm Dist(detainee)=%.1fm", _dActor, _dCiv], "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
    false
};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
private _keysFn = compile "params ['_m']; keys _m";

private _did = _civ getVariable ["civsub_districtId", ""];
if (_did isEqualTo "") exitWith {false};

private _actorUid = getPlayerUID _actor;
private _civUid = _civ getVariable ["civ_uid", ""];
if (_civUid isEqualTo "") exitWith {
    ["CIVSUB: Unknown civilian identity.", "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
    false
};

private _rec = [_civUid] call ARC_fnc_civsubIdentityGet;

// IdentityGet returns an empty HashMap when missing; treat empty as missing and rebuild via touch.
if (!(_rec isEqualType createHashMap) || {(count ([_rec] call _keysFn)) isEqualTo 0}) then {
    _rec = [_did, _actorUid, _civUid, getPosATL _civ] call ARC_fnc_civsubIdentityTouch;
};

// If the unit is already in the custody pipeline (pinned), but the record lost the detained flag,
// restore it so handoff cannot fail due to a persistence/eviction edge case.
if ((_civ getVariable ["civsub_v1_pinned", false]) && {_rec isEqualType createHashMap}) then {
    if (!([_rec, "status_detained", false] call _hg)) then {
        _rec set ["status_detained", true];
        _rec set ["status_detainedAt", ([_rec, "status_detainedAt", serverTime] call _hg)];
        _rec set ["status_detainedDistrictId", ([_rec, "status_detainedDistrictId", _did] call _hg)];
        [_civUid, _rec] call ARC_fnc_civsubIdentitySet;
    };
};

if !(_rec isEqualType createHashMap) exitWith {false};
private _wl = [_rec, "wanted_level", 0] call _hg;
if !(_wl isEqualType 0) then { _wl = 0; };
private _detained = [_rec, "status_detained", false] call _hg;
if !(_detained) exitWith {
    ["CIVSUB: Civilian is not marked detained.", "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
    false
};

// Require cuffs removed (best-effort with ACE captives). We want the player to uncuff before handoff.
if (_civ getVariable ["ace_captives_isHandcuffed", false]) exitWith {
    // Keep detainee protected while player removes cuffs (prevents cleanup race)
    _civ setVariable ["civsub_v1_pinned", true, true];
    _civ setCaptive true;

    ["CIVSUB: Remove handcuffs before handoff.", "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
    false
};


// Ensure the unit is not inside a vehicle.
if (vehicle _civ != _civ) then {
    unassignVehicle _civ;
    moveOut _civ;
};

// Mark handoff in identity state + district counters
_rec set ["status_handedOff", true];
_rec set ["status_handedOffAt", serverTime];
_rec set ["status_handedOffTo", "SHERIFF"]; 
[_civUid, _rec] call ARC_fnc_civsubIdentitySet;

private _bundle = [_did, "DETENTION_HANDOFF", "IDENTITY", [[["civ_uid", _civUid], ["to", "SHERIFF"], ["wanted_level", _wl]]] call _hmCreate, _actorUid] call ARC_fnc_civsubEmitDelta;
if !(_bundle isEqualType createHashMap) then { _bundle = createHashMap; };
if ((count ([_bundle] call _keysFn)) isEqualTo 0) exitWith {
    ["CIVSUB: Handoff failed (delta rejected).", "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
    false
};

// Pin + hold at sheriff area (pre-transfer). This prevents despawn and keeps the scene stable.
_civ setVariable ["civsub_v1_pinned", true, true];
_civ setCaptive true;
_civ disableAI "MOVE";
_civ disableAI "PATH";
_civ setVariable ["ARC_epw_stage", "SHERIFF_HOLDING", true];
_civ setVariable ["ARC_epw_handedOffAt", serverTime, true];

// Surrender animation (locality-safe): execute where the detainee is local.
if (local _civ) then
{
    _civ switchMove "AmovPercMstpSsurWnonDnon";
}
else
{
    [_civ, "AmovPercMstpSsurWnonDnon"] remoteExecCall ["switchMove", owner _civ];
};

private _transferDelay = missionNamespace getVariable ["civsub_v1_detention_transfer_to_epw_delay_s", 300];
if (!(_transferDelay isEqualType 0)) then { _transferDelay = 300; };
_transferDelay = (_transferDelay max 30) min 3600;

[format ["CIVSUB: Handoff accepted. Detainee will be transferred to EPW holding in %1 seconds.", _transferDelay], "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];

// Deferred transfer to EPW holding + camp behavior
[_civ, _transferDelay] spawn {
    params ["_u", "_delay"]; 
    sleep _delay;

    if (isNull _u) exitWith {};
    if (!alive _u) exitWith {};
    if !(_u getVariable ["civsub_v1_pinned", false]) exitWith {};
    if !((_u getVariable ["ARC_epw_stage", ""]) isEqualTo "SHERIFF_HOLDING") exitWith {};

    private _resolveMarker = {
        params ["_name"];
        if (!isNil "ARC_fnc_worldResolveMarker") exitWith { [_name] call ARC_fnc_worldResolveMarker };
        _name
    };

    // Prefer EPW holding, fallback to sheriff holding
    private _mHold = "";
    {
        private _m = [_x] call _resolveMarker;
        if !((markerType _m) isEqualTo "") exitWith { _mHold = _m; };
    } forEach ["epw_holding", "mkr_SHERIFF_HOLDING"];

    private _holdPos = getPosATL _u;
    if (!(_mHold isEqualTo "")) then { _holdPos = getMarkerPos _mHold; };
    _holdPos resize 3;

    private _offX = (random 10) - 5;
    private _offY = (random 10) - 5;
    private _hp = [(_holdPos select 0) + _offX, (_holdPos select 1) + _offY, 0];

    // Ensure not in vehicle
    if (vehicle _u != _u) then {
        unassignVehicle _u;
        moveOut _u;
    };

    _u setPosATL _hp;
    _u setVariable ["ARC_epw_stage", "EPW_HOLDING", true];
    _u setVariable ["ARC_epw_inHolding", true, true];
    _u setVariable ["ARC_epw_processedAt", serverTime, true];

    // Camp behavior: if LAMBS garrison exists, allow limited movement in a small radius.
    private _useLambs = missionNamespace getVariable ["civsub_v1_detention_useLambs", true];
    private _campR = missionNamespace getVariable ["civsub_v1_detention_camp_radius_m", 15];
    if (!(_campR isEqualType 0)) then { _campR = 15; };
    _campR = (_campR max 5) min 50;

    if (_useLambs && { !isNil "lambs_wp_fnc_taskGarrison" }) then {
        _u enableAI "MOVE";
        _u enableAI "PATH";

        private _grp = group _u;
        if (isNull _grp) then {
            _grp = createGroup [civilian, true];
            [_u] joinSilent _grp;
        };

        // Keep it tight to avoid weird behavior (detainee should stay local)
        [_grp, _holdPos, _campR, [], false, true, 3, false] spawn lambs_wp_fnc_taskGarrison;
    } else {
        // No LAMBS: keep frozen in place
        _u disableAI "MOVE";
        _u disableAI "PATH";
    };

    // Optional: virtual transfer to Division after a delay (existing mission tuning var)
    private _delay2 = missionNamespace getVariable ["ARC_epwTransferToDivisionAfterSec", 1800];
    if (!(_delay2 isEqualType 0)) then { _delay2 = 1800; };
    _delay2 = (_delay2 max 60) min 21600;

    [_u, _delay2] spawn {
        params ["_uu", "_d2"]; 
        sleep _d2;
        if (isNull _uu) exitWith {};
        if (!alive _uu) exitWith {};
        if !(_uu getVariable ["ARC_epw_inHolding", false]) exitWith {};

        if (!isNil "ARC_fnc_intelLog") then {
            private _pos = getPosATL _uu;
            ["OPS", format ["EPW transferred to Division (%1).", name _uu], _pos, [["event", "EPW_TRANSFERRED_TO_DIV"], ["unit", name _uu]]] call ARC_fnc_intelLog;
        };

        deleteVehicle _uu;
    };
};

true
