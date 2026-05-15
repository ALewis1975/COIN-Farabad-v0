/*
    ARC_fnc_recruitServerPublishContainers

    Server: publish opt-in recruitment container netIds for client addAction replay.

    The primary opt-in path is the Eden Variable Name "recruitment_01" via
    ARC_recruitContainerNames. Object Init flags remain supported for existing
    Huron-container setups:
      this setVariable ["ARC_isRecruitContainer", true, true];

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

if (!(missionNamespace getVariable ["ARC_recruitContainerEnabled", true])) exitWith {false};

private _classes = missionNamespace getVariable ["ARC_recruitContainerClasses", ["B_Slingload_01_Cargo_F"]];
if (!(_classes isEqualType [])) then { _classes = ["B_Slingload_01_Cargo_F"]; };

private _ids = [];

// Resolve Eden Variable Name opt-ins and mark them as recruit objects.
private _names = missionNamespace getVariable ["ARC_recruitContainerNames", []];
if (!(_names isEqualType [])) then { _names = []; };
{
    private _name = _x;
    if (!(_name isEqualType "") || { _name isEqualTo "" }) then { continue; };
    private _obj = missionNamespace getVariable [_name, objNull];
    if (isNull _obj) then { continue; };
    if (!(_obj isEqualType objNull)) then { continue; };
    if (!(_obj getVariable ["ARC_isRecruitContainer", false])) then
    {
        _obj setVariable ["ARC_isRecruitContainer", true, true];
        diag_log format ["[ARC][INFO] ARC_fnc_recruitServerPublishContainers: marked named recruitment object '%1' netId=%2 type=%3", _name, netId _obj, typeOf _obj];
    };

    private _namedNetId = netId _obj;
    if (!(_namedNetId isEqualType "") || { _namedNetId isEqualTo "" }) then { continue; };
    _ids pushBackUnique _namedNetId;

    [_obj] remoteExec ["ARC_fnc_recruitClientAddActions", 0, _obj];
} forEach _names;

{
    private _class = _x;
    if (!(_class isEqualType "")) then { continue; };
    {
        private _container = _x;
        if (isNull _container) then { continue; };
        if (!(_container getVariable ["ARC_isRecruitContainer", false])) then { continue; };

        private _netId = netId _container;
        if (!(_netId isEqualType "") || { _netId isEqualTo "" }) then { continue; };
        _ids pushBackUnique _netId;

        [_container] remoteExec ["ARC_fnc_recruitClientAddActions", 0, _container];
    } forEach (allMissionObjects _class);
} forEach _classes;

private _oldIds = missionNamespace getVariable ["ARC_recruitContainerNetIds", []];
if (!(_oldIds isEqualType [])) then { _oldIds = []; };

if (!(_oldIds isEqualTo _ids)) then
{
    diag_log format ["[ARC][INFO] ARC_fnc_recruitServerPublishContainers: published recruitment containers count=%1 netIds=%2", count _ids, _ids];
};

missionNamespace setVariable ["ARC_recruitContainerNetIds", _ids, true];

true
