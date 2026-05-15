/*
    ARC_fnc_recruitServerPublishContainers

    Server: publish opt-in recruitment container netIds for client addAction replay.

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

if (!(missionNamespace getVariable ["ARC_recruitContainerEnabled", true])) exitWith {false};

private _classes = missionNamespace getVariable ["ARC_recruitContainerClasses", ["B_Slingload_01_Cargo_F"]];
if (!(_classes isEqualType [])) then { _classes = ["B_Slingload_01_Cargo_F"]; };

private _ids = [];
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
