/*
    Threat System v0 init (server-only).

    Ensures threat_v0_* keys exist in persistent state and creates a campaign_id if missing.
    Also seeds debug snapshot variables for the inspector.
*/

if (!isServer) exitWith {false};

// Enable flag (server authority)
private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
["threat_v0_enabled", _enabled] call ARC_fnc_stateSet;

// Version (schema for this threat blob)
private _ver = ["threat_v0_version", 0] call ARC_fnc_stateGet;
if (!(_ver isEqualType 0)) then { _ver = 0; };
["threat_v0_version", _ver] call ARC_fnc_stateSet;

// Campaign ID (stable per persistence reset)
private _cid = ["threat_v0_campaign_id", ""] call ARC_fnc_stateGet;
if (!(_cid isEqualType "")) then { _cid = ""; };

if (_cid isEqualTo "") then
{
    _cid = if (!isNil "BIS_fnc_guid") then { call BIS_fnc_guid } else { format ["CID-%1-%2", diag_tickTime, floor (random 1e6)] };
    ["threat_v0_campaign_id", _cid] call ARC_fnc_stateSet;
};

// Sequence (monotonic)
private _seq = ["threat_v0_seq", 0] call ARC_fnc_stateGet;
if (!(_seq isEqualType 0) || { _seq < 0 }) then { _seq = 0; };
["threat_v0_seq", _seq] call ARC_fnc_stateSet;

// Records + indexes (safe defaults)
private _recs = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_recs isEqualType [])) then { _recs = []; ["threat_v0_records", _recs] call ARC_fnc_stateSet; };

private _open = ["threat_v0_open_index", []] call ARC_fnc_stateGet;
if (!(_open isEqualType [])) then { _open = []; ["threat_v0_open_index", _open] call ARC_fnc_stateSet; };

private _closed = ["threat_v0_closed_index", []] call ARC_fnc_stateGet;
if (!(_closed isEqualType [])) then { _closed = []; ["threat_v0_closed_index", _closed] call ARC_fnc_stateSet; };

private _closedMax = ["threat_v0_closed_max", 200] call ARC_fnc_stateGet;
if (!(_closedMax isEqualType 0) || { _closedMax < 50 }) then { _closedMax = 200; };
["threat_v0_closed_max", _closedMax] call ARC_fnc_stateSet;

// Seed debug vars (not persisted)
if (isNil { missionNamespace getVariable "threat_v0_debug_last_event" }) then
{
    missionNamespace setVariable ["threat_v0_debug_last_event", []];
};

[] call ARC_fnc_threatDebugSnapshot;

// Threat Economy v0: seed economy keys (idempotent)
[] call ARC_fnc_threatEconomyInit;

true
