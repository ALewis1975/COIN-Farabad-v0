/*
    Server-owned bootstrap for S1 unit/group registry.
    Rehydrates persisted registry records when present, then updates from
    live authoritative group/unit references.
*/

if (!isServer) exitWith { false };

private _arcState = missionNamespace getVariable ["ARC_state", []];
if !(_arcState isEqualType []) then { _arcState = []; };
missionNamespace setVariable ["ARC_STATE", _arcState];

missionNamespace setVariable ["ARC_s1_registrySchema", ["ARC_s1_registry_v1", 1], true];

private _persisted = ["s1Registry", []] call ARC_fnc_stateGet;
if !(_persisted isEqualType []) then { _persisted = []; };

private _groups = [];
private _units = [];
if ((count _persisted) >= 4) then
{
    {
        if !(_x isEqualType []) then { continue; };
        private _k = _x param [0, ""];
        private _v = _x param [1, []];
        switch (_k) do
        {
            case "groups": { if (_v isEqualType []) then { _groups = +_v; }; };
            case "units": { if (_v isEqualType []) then { _units = +_v; }; };
        };
    } forEach _persisted;
};

private _now = serverTime;
private _seed = [
    ["version", 1],
    ["updatedAt", _now],
    ["groups", _groups],
    ["units", _units]
];

missionNamespace setVariable ["ARC_s1_registry", _seed];
["s1Registry", _seed] call ARC_fnc_stateSet;
["s1RegistryUpdatedAt", _now] call ARC_fnc_stateSet;

if (isNil { missionNamespace getVariable "ARC_pub_s1_registry" }) then {
    missionNamespace setVariable ["ARC_pub_s1_registry", [], true];
};
if (isNil { missionNamespace getVariable "ARC_pub_s1_registryUpdatedAt" }) then {
    missionNamespace setVariable ["ARC_pub_s1_registryUpdatedAt", -1, true];
};

{
    private _grp = _x;
    private _members = units _grp;
    if ((count _members) == 0) then {
        [objNull, _grp, [["virtualStatus", "VIRTUAL"]], false] call ARC_fnc_s1RegistryUpsertUnit;
    } else {
        { [_x, _grp, [], false] call ARC_fnc_s1RegistryUpsertUnit; } forEach _members;
    };
} forEach allGroups;

[] call ARC_fnc_s1RegistrySnapshot;

true
