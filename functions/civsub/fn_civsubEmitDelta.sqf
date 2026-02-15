/*
    ARC_fnc_civsubEmitDelta

    Phase 2: emit a CIVSUB delta bundle and apply it atomically to the district state.

    Params:
      0: districtId (string "D01".."D20")
      1: event (string, e.g. "SHOW_PAPERS", "CHECK_PAPERS")
      2: sourceModule (string, e.g. "IDENTITY")
      3: payload (hashmap or [ [k,v], ... ])
      4: actorUid (string, optional)

    Returns:
      delta bundle (hashmap) or createHashMap if rejected.
*/

if (!isServer) exitWith {createHashMap};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {createHashMap};

params [
    ["_districtId", "", [""]],
    ["_event", "", [""]],
    ["_sourceModule", "", [""]],
    ["_payload", createHashMap, [createHashMap, []]],
    ["_actorUid", "", [""]]
];

if (_districtId isEqualTo "" || { _event isEqualTo "" }) exitWith {createHashMap};

if !([_event, _payload] call ARC_fnc_civsubDeltaValidate) exitWith {createHashMap};

// Normalize payload into a hashmap.
private _p = createHashMap;
if (_payload isEqualType createHashMap) then
{
    _p = _payload;
}
else
{
    // Array of pairs
    {
        if (_x isEqualType [] && { (count _x) == 2 }) then { _p set [_x # 0, _x # 1]; };
    } forEach _payload;
};

private _bundle = [_districtId, _event, _sourceModule, _p, _actorUid] call ARC_fnc_civsubDeltaBuildEnvelope;
if !(_bundle isEqualType createHashMap) exitWith {createHashMap};

// Apply influence delta to district
[_bundle] call ARC_fnc_civsubDeltaApplyToDistrict;

// Track last emission for debug inspector
missionNamespace setVariable ["civsub_v1_lastDelta_id", _bundle getOrDefault ["bundle_id", ""], true];
missionNamespace setVariable ["civsub_v1_lastDelta_ts", serverTime, true];

_bundle
