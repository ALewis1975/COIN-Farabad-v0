/*
    Threat v0: append a bounded ThreatEvent envelope for UI/ops consumers.

    Params:
        0: STRING event name
        1: STRING threat_id
        2: ARRAY  payload pairs
        3: ARRAY  opts pairs [["producer","..."], ["rev", N]]

    Returns:
        ARRAY event envelope (pairs), [] on failure

    Notes:
        - Server-only single writer.
        - Replicates a bounded public tail for JIP-safe read-only clients.
        - Envelope v=1 is append-only: consumers must ignore unknown keys; removing
          or renaming existing top-level keys requires a future version number.
*/

if (!isServer) exitWith {[]};

params [
    ["_eventName", "", [""]],
    ["_threatId", "", [""]],
    ["_payload", [], [[]]],
    ["_opts", [], [[]]]
];

private _trimFn = compile "params ['_s']; trim _s";

_eventName = toUpper ([_eventName] call _trimFn);
_threatId = [_threatId] call _trimFn;

if (_eventName isEqualTo "") exitWith {[]};

private _kvGet = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith {_default};
    private _idx = -1;
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith
        {
            _idx = _forEachIndex;
        };
    } forEach _pairs;
    if (_idx < 0) exitWith {_default};
    private _entry = _pairs select _idx;
    private _v = _entry select 1;
    if (isNil "_v") exitWith {_default};
    _v
};

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {[]};

private _seq = ["threat_v0_event_seq", 0] call ARC_fnc_stateGet;
if (!(_seq isEqualType 0) || { _seq < 0 }) then { _seq = 0; };
_seq = _seq + 1;
["threat_v0_event_seq", _seq] call ARC_fnc_stateSet;

private _producer = [_opts, "producer", "ARC_fnc_threatEmitEvent"] call _kvGet;
if (!(_producer isEqualType "")) then { _producer = "ARC_fnc_threatEmitEvent"; };

private _rev = [_opts, "rev", 0] call _kvGet;
if (!(_rev isEqualType 0)) then { _rev = 0; };

private _now = serverTime;
// Keep common filter keys at the top level for low-cost UI scans while retaining
// the complete producer payload for audit/debug detail.
private _districtIdSource = [_payload, "district_id_source", ""] call _kvGet;
if (!(_districtIdSource isEqualType "")) then { _districtIdSource = ""; };
private _districtId = [_payload, "district_id", ""] call _kvGet;
if (!(_districtId isEqualType "")) then { _districtId = ""; };
private _stateFrom = [_payload, "state_from", ""] call _kvGet;
if (!(_stateFrom isEqualType "")) then { _stateFrom = ""; };
private _stateTo = [_payload, "state_to", ""] call _kvGet;
if (!(_stateTo isEqualType "")) then { _stateTo = ""; };

private _envelope = [
    ["v", 1],
    ["seq", _seq],
    ["ts", _now],
    ["event", _eventName],
    ["threat_id", _threatId],
    ["district_id_source", _districtIdSource],
    ["district_id", _districtId],
    ["state_from", _stateFrom],
    ["state_to", _stateTo],
    ["rev", _rev],
    ["producer", _producer],
    ["payload", _payload]
];

private _events = ["threat_v0_events", []] call ARC_fnc_stateGet;
if (!(_events isEqualType [])) then { _events = []; };
_events pushBack _envelope;

private _max = ["threat_v0_events_max", 64] call ARC_fnc_stateGet;
if (!(_max isEqualType 0) || { _max < 16 }) then { _max = 64; };
_max = (_max max 16) min 256;

while { (count _events) > _max } do
{
    _events deleteAt 0;
};

["threat_v0_events", _events] call ARC_fnc_stateSet;
missionNamespace setVariable ["threat_v0_debug_last_event", _envelope];
missionNamespace setVariable ["threat_v0_events_public", _events, true];

diag_log format ["[ARC][INFO] ARC_fnc_threatEmitEvent: event=%1 threat_id=%2 seq=%3 producer=%4", _eventName, _threatId, _seq, _producer];

_envelope
