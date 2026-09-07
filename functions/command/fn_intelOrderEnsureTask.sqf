/* Server view renderer. Existing accepted record in, missing BIS task out. */
if (!isServer) exitWith {false};
params [["_record",[],[[]]],["_focus",false,[true]],["_joiner",objNull,[objNull]]];
private _spec = [_record] call ARC_fnc_intelOrderTaskSpec;
if (_spec isEqualTo []) exitWith {false};
_spec params ["_taskId","_groupId","_title","_desc","_pos","_icon"];
private _group = grpNull;
{if ((groupId _x) isEqualTo _groupId) exitWith {_group = _x;};} forEach allGroups;
if (isNull _group) exitWith {false};
private _exists = [_taskId] call BIS_fnc_taskExists;
if (!_exists) then
{
    [_group,_taskId,[[_desc],_title,""],_pos,"ASSIGNED",1,_focus,_icon,false] call BIS_fnc_taskCreate;
    diag_log format ["[ARC][ORDER] TOC_ORDER_REHYDRATED task=%1 group=%2 grid=%3 ts=%4",_taskId,_groupId,mapGridPosition _pos,serverTime];
};
// A reconnect may recreate the same callsign as a different group object.
// Refresh its owner through the documented task upsert without replaying acceptance.
if (_exists && {!isNull _joiner} && {(group _joiner) isEqualTo _group}) then
{
    [_taskId,_group,[[_desc],_title,""],_pos,"ASSIGNED",1,false,true,_icon,false] call BIS_fnc_setTask;
};
private _active = ["activeTaskId",""] call ARC_fnc_stateGet;
private _activeAccepted = ["activeIncidentAccepted",false] call ARC_fnc_stateGet;
private _activeGroup = ["activeIncidentAcceptedByGroup",""] call ARC_fnc_stateGet;
private _mayFocus = _focus || {_active isEqualTo ""} || {!_activeAccepted} || {!(_activeGroup isEqualTo _groupId)};

// The Task Framework handles task replication. ATH focus is delivered once on
// creation/acceptance or explicitly to a late joiner, never on every tick.
private _targets = if (!isNull _joiner) then {[_joiner]} else {if (_focus || {!_exists}) then {units _group} else {[]}};
{
    if (_mayFocus && {isPlayer _x} && {(group _x) isEqualTo _group}) then
    {
        [_taskId,[["kind","ORDER"],["title",_title],["pos",_pos]]] remoteExec ["ARC_fnc_clientSetCurrentTask",_x];
    };
} forEach _targets;
!_exists
