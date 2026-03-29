/*
    ARC_fnc_civsubBundleMake

    Phase 5.5: Normalize CIVSUB emissions to the v1 delta bundle contract.
    Builds the contract envelope while also providing backward-compatible
    aliases used by existing mission code.
*/

params [
    ["_districtId", "", [""]],
    ["_pos", [], [[]]],
    ["_sourceModule", "", [""]],
    ["_event", "", [""]],
    ["_payload", createHashMap, [createHashMap]],
    ["_effects", [], [[]]],
    ["_influenceDelta", createHashMap, [createHashMap]],
    ["_leadEmit", createHashMap, [createHashMap]],
    ["_tags", [], [[]]],
    ["_actorUid", "", [""]],
    ["_actorType", "AI", [""]],
    ["_actorNetId", "", [""]],
    ["_actorSide", "", [""]],
    ["_targetCivUid", "", [""]],
    ["_targetNetId", "", [""]]
];

if (_districtId isEqualTo "") exitWith {createHashMap};

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

private _ts = serverTime;
private _uuid = [] call ARC_fnc_civsubUuid;
private _eventId = format ["%1:%2:%3", _districtId, (_ts toFixed 3), (_uuid select [0,6])];

// Default position: district centroid
private _centroid = [0,0];
private _d = (missionNamespace getVariable ["civsub_v1_districts", createHashMap]) getOrDefault [_districtId, createHashMap];
if (_d isEqualType createHashMap) then {
    _centroid = _d getOrDefault ["centroid", [0,0]];
};

private _p3 = [(_centroid select 0), (_centroid select 1), 0];
if (_pos isEqualType [] && {count _pos >= 2}) then {
    private _x = _pos select 0;
    private _y = _pos select 1;
    private _z = 0;
    if (count _pos >= 3) then { _z = _pos select 2; };
    _p3 = [_x, _y, _z];
};

private _src = [[
    ["system", "CIVSUB"],
    ["module", _sourceModule],
    ["event", _event],
    // Backward-compat: older bundles stored actor_uid here
    ["actor_uid", _actorUid]
]] call _hmCreate;

private _actor = [[
    ["type", _actorType],
    ["uid", _actorUid],
    ["unit_net_id", _actorNetId],
    ["side", _actorSide]
]] call _hmCreate;

private _target = [[
    ["civ_uid", _targetCivUid],
    ["unit_net_id", _targetNetId]
]] call _hmCreate;

// Normalize influence deltas to contract keys (W/R/G), while still emitting backward-compatible aliases (dW/dR/dG).
private _dW = [_influenceDelta, "W", ([_influenceDelta, "dW", 0] call _hg)] call _hg;
private _dR = [_influenceDelta, "R", ([_influenceDelta, "dR", 0] call _hg)] call _hg;
private _dG = [_influenceDelta, "G", ([_influenceDelta, "dG", 0] call _hg)] call _hg;

private _coerceScalar = {
    params ["_value"];
    if (_value isEqualType 0) exitWith {_value};
    0
};
_dW = [_dW] call _coerceScalar;
_dR = [_dR] call _coerceScalar;
_dG = [_dG] call _coerceScalar;

private _influenceContract = [[
    // Contract
    ["W", _dW],
    ["R", _dR],
    ["G", _dG],

    // Backward-compatible aliases
    ["dW", _dW],
    ["dR", _dR],
    ["dG", _dG]
]] call _hmCreate;

private _bundle = [[
    // Contract
    ["v", 1],
    ["event_id", _eventId],
    ["ts", _ts],
    ["district_id", _districtId],
    ["pos", _p3],
    ["source", _src],
    ["actor", _actor],
    ["target", _target],
    ["payload", _payload],
    ["effects", _effects],
    ["influence_delta", _influenceContract],
    ["lead_emit", _leadEmit],
    ["tags", _tags],

    // Backward-compatible aliases
    ["bundle_id", _eventId],
    ["districtId", _districtId]
]] call _hmCreate;

_bundle
