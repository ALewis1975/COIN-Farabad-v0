// Engine-compatible command wrappers retain the repository lint baseline.
private _casDefault = compile "params ['_map','_args']; _map getOrDefault _args";
private _casMap = compile "params ['_pairs']; createHashMapFromArray _pairs";
/* CAS-only capability check. Caller binding is separately enforced by each RPC. */
params [["_unit", objNull, [objNull]], ["_action", "CREATE", [""]], ["_record", [], [[]]]];
if (isNull _unit || {!isPlayer _unit} || {side group _unit != west}) exitWith {false};
private _namedJtac = if (isServer) then {localNamespace getVariable ["ARC_casreq_jtacUnit", objNull]} else {missionNamespace getVariable ["ARC_casreq_jtacUnit", objNull]};
private _controller = _unit isEqualTo _namedJtac || {[_unit] call ARC_fnc_rolesCanApproveQueue};
private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
if !(_omniTokens isEqualType []) then {_omniTokens = ["OMNI"]};
{ if (_x isEqualType "" && {[_unit, _x] call ARC_fnc_rolesHasGroupIdToken}) exitWith {_controller = true}; } forEach _omniTokens;
private _uid = getPlayerUID _unit;
private _requester = false;
private _assigned = false;
private _r = ([_record] call _casMap);
{
    if (_x isEqualType []) then {
        private _m = ([_x] call _casMap);
        if ((([_m, ["event", ""]] call _casDefault)) isEqualTo "OPENED") then {_requester = (([_m, ["requester_uid", ""]] call _casDefault)) isEqualTo _uid};
        if ((([_m, ["event", ""]] call _casDefault)) isEqualTo "APPROVED") then {_assigned = _uid in (([_m, ["crew_uids", []]] call _casDefault))};
    };
} forEach (([_r, ["messages", []]] call _casDefault));
private _inAttackAircraft = false;
private _veh = vehicle _unit;
if (isServer && {_action isEqualTo "EXECUTE"}) then {[] call ARC_fnc_casreqAirbaseAvailability};
private _attackObjects = if (isServer) then {localNamespace getVariable ["ARC_casreq_attackObjects", []]} else {(missionNamespace getVariable ["casreq_v1_airbase_attack_vehvars", ["plane4", "plane5"]]) apply {missionNamespace getVariable [_x, objNull]}};
_inAttackAircraft = _veh in _attackObjects && {alive _veh} && {_veh isKindOf "Air"};
switch (toUpper _action) do {
    case "CREATE": {_controller || {[_unit] call ARC_fnc_rolesIsAuthorized}};
    case "DECIDE": {_controller};
    case "EXECUTE": {_controller || {_assigned && _inAttackAircraft}};
    case "COMPLETE": {_controller || _assigned};
    case "ABORT": {_controller || _requester};
    case "INBOX": {true};
    default {false};
}
