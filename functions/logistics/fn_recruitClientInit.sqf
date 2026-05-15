/*
    ARC_fnc_recruitClientInit

    Client: discover configured Huron cargo recruitment containers and attach
    local addActions. Containers must be class-whitelisted and opt-in via
    server-published netId or replicated object variable:
      this setVariable ["ARC_isRecruitContainer", true, true]

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

if (!(missionNamespace getVariable ["ARC_recruitContainerEnabled", true])) exitWith {false};

private _classes = missionNamespace getVariable ["ARC_recruitContainerClasses", ["B_Slingload_01_Cargo_F"]];
if (!(_classes isEqualType [])) then { _classes = ["B_Slingload_01_Cargo_F"]; };

private _containers = [];

private _publishedNetIds = missionNamespace getVariable ["ARC_recruitContainerNetIds", []];
if (_publishedNetIds isEqualType []) then
{
    {
        if (!(_x isEqualType "")) then { continue; };
        private _container = objectFromNetId _x;
        if (isNull _container) then { continue; };
        _containers pushBackUnique _container;
    } forEach _publishedNetIds;
};

{
    private _class = _x;
    if (!(_class isEqualType "")) then { continue; };
    {
        private _container = _x;
        if (isNull _container) then { continue; };
        if (!(_container getVariable ["ARC_isRecruitContainer", false])) then { continue; };
        _containers pushBackUnique _container;
    } forEach (allMissionObjects _class);
} forEach _classes;

{
    [_x] call ARC_fnc_recruitClientAddActions;
} forEach _containers;

true
