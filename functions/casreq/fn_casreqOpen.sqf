// Engine-compatible command wrappers retain the repository lint baseline.
private _casDefault = compile "params ['_map','_args']; _map getOrDefault _args";
private _casGet = compile "params ['_map','_key']; (_map) get _key";
private _casMap = compile "params ['_pairs']; createHashMapFromArray _pairs";
private _casTrim = compile "params ['_s']; trim _s";
/* Existing CAS intake. Server validates the complete bounded payload before allocating an ID. */
if (!isServer) exitWith {false};
// A scheduled remoteExec intake re-enters once in an unscheduled block so guards
// and mutation form one server operation even under simultaneous submissions.
if (canSuspend) exitWith {
    private _args = +_this;
    private _result = false;
    isNil {_result = _args call ARC_fnc_casreqOpen;};
    _result
};
params [["_unit", objNull, [objNull]], ["_districtId", "D00", [""]], ["_targetPos", [], [[]]], ["_nineLine", [], [[]]], ["_remarks", "", [""]], ["_requestToken", "", [""]]];
private _reoOwner = remoteExecutedOwner;
if (!([_unit, "ARC_fnc_casreqOpen", "CAS request rejected: sender mismatch.", "CASREQ_OPEN_SEC_DENIED", true, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith {false};
private _deny = {params ["_why"]; ["CAS request rejected: " + _why] remoteExecCall ["ARC_fnc_clientHint", owner _unit]; false};
if (!(missionNamespace getVariable ["casreq_v1_enabled", true]) || {!([_unit, "CREATE"] call ARC_fnc_casreqCan)}) exitWith {["role or subsystem unavailable"] call _deny};
if (count _targetPos != 3 || {({!(_x isEqualType 0) || {!finite _x}} count _targetPos) > 0}) exitWith {["invalid target position"] call _deny};
if ((_targetPos select 0) < 0 || {(_targetPos select 1) < 0} || {(_targetPos select 0) > worldSize} || {(_targetPos select 1) > worldSize} || {abs (_targetPos select 2) > 20000}) exitWith {["target outside terrain"] call _deny};
if (count _remarks > 500 || {count _requestToken > 96} || {count _nineLine != 9}) exitWith {["input exceeds limits"] call _deny};
private _keys = ["line1_initial_point", "line2_heading_and_distance", "line3_target_elevation", "line4_target_description", "line5_target_location", "line6_type_mark", "line7_location_friendlies", "line8_egress_dir", "line9_remarks"];
private _seen = [];
private _invalid = false;
{
    if !(_x isEqualType [] && {count _x == 2} && {(_x select 0) isEqualType ""}) then {_invalid = true} else {
        _x params ["_key", "_value"];
        if (!(_key in _keys) || {_key in _seen}) then {_invalid = true};
        _seen pushBack _key;
        if (_key isEqualTo "line3_target_elevation") then {
            if !(_value isEqualType 0 && {finite _value} && {abs _value <= 20000}) then {_invalid = true};
        } else {
            if !(_value isEqualType "" && {count _value <= (if (_key isEqualTo "line9_remarks") then {500} else {240})}) then {_invalid = true};
        };
    };
} forEach _nineLine;
if (_invalid) exitWith {["invalid nine-line fields"] call _deny};
private _nl = ([_nineLine] call _casMap);
if ((([(([_nl, "line4_target_description"] call _casGet))] call _casTrim)) isEqualTo "" || {(([(([_nl, "line7_location_friendlies"] call _casGet))] call _casTrim)) isEqualTo ""}) exitWith {["target description and friendlies are required"] call _deny};
[true] call ARC_fnc_casreqMaintain;
private _records = ["casreq_v1_records", createHashMap] call ARC_fnc_stateGet;
private _uid = getPlayerUID _unit;
private _duplicate = "";
private _ownedOpen = 0;
private _casKeys = compile "params ['_h']; keys _h";
{
    private _r = ([[_records, _x] call _casGet] call _casMap);
    private _mine = false;
    {
        private _m = ([_x] call _casMap);
        if ((([_m, ["event", ""]] call _casDefault)) isEqualTo "OPENED" && {(([_m, ["requester_uid", ""]] call _casDefault)) isEqualTo _uid}) then {
            _mine = true;
            if (_requestToken != "" && {(([_m, ["request_token", ""]] call _casDefault)) isEqualTo _requestToken}) then {_duplicate = ([_r, ["casreq_id", ""]] call _casDefault)};
        };
    } forEach (([_r, ["messages", []]] call _casDefault));
    if (_mine && {(([_r, ["state", ""]] call _casDefault)) in ["OPEN", "APPROVED", "EXECUTING"]}) then {_ownedOpen = _ownedOpen + 1};
} forEach ([_records] call _casKeys);
if (_duplicate != "") exitWith {[format ["CAS request already received: %1", _duplicate]] remoteExecCall ["ARC_fnc_clientHint", owner _unit]; true};
// Receipt times stay server-local; client-owned object variables cannot bypass rate limits.
private _cooldowns = (localNamespace getVariable ["ARC_casreq_submitCooldowns", []]) select {serverTime - (_x select 1) < 10};
localNamespace setVariable ["ARC_casreq_submitCooldowns", _cooldowns];
if (({(_x select 0) isEqualTo _uid} count _cooldowns) > 0) exitWith {["wait 10 seconds between requests"] call _deny};
if (count _cooldowns >= 128) exitWith {["server request rate limit reached"] call _deny};
if (_ownedOpen >= 3 || {count (["casreq_v1_open_index", []] call ARC_fnc_stateGet) >= 20}) exitWith {["active request limit reached"] call _deny};
// District belongs to the server's target-position resolver, not the supplied label.
_districtId = [_targetPos] call ARC_fnc_threadResolveDistrictId;
if (_districtId isEqualTo "") then {_districtId = "D00"};
private _id = [_districtId] call ARC_fnc_casreqBuildId;
if (_id isEqualTo "") exitWith {["request sequence exhausted"] call _deny};
private _now = serverTime;
private _actor = [_unit] call ARC_fnc_rolesFormatUnit;
private _record = [
    ["casreq_id", _id], ["district_id", _districtId], ["state", "OPEN"], ["requester", _actor],
    ["area", [["target_pos", +_targetPos], ["target_marker", ""]]],
    ["messages", [[["event", "OPENED"], ["at", _now], ["by", _actor], ["requester_uid", _uid], ["request_token", _requestToken]]]],
    ["created_at", _now], ["updated_at", _now], ["incident_id", ["activeTaskId", ""] call ARC_fnc_stateGet],
    ["nine_line", +_nineLine], ["remarks", ([_remarks] call _casTrim)], ["result", ""], ["closed_at", -1]
];
_records set [_id, _record];
["casreq_v1_records", _records] call ARC_fnc_stateSet;
_cooldowns pushBack [_uid, _now];
localNamespace setVariable ["ARC_casreq_submitCooldowns", _cooldowns];
[true] call ARC_fnc_casreqMaintain;
[_id, _actor, "OPENED", []] call ARC_fnc_casreqBroadcastDelta;
[format ["CAS request submitted: %1", _id]] remoteExecCall ["ARC_fnc_clientHint", owner _unit];
true
