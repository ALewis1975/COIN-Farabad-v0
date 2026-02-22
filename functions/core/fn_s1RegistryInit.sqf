/*
    Server-owned bootstrap for S1 unit/group registry.
    Seeds canonical rows from live authoritative group/unit references and
    applies ORBAT-style decomposition from groupId naming.
*/

if (!isServer) exitWith { false };

private _arcState = missionNamespace getVariable ["ARC_state", []];
if !(_arcState isEqualType []) then { _arcState = []; };
missionNamespace setVariable ["ARC_STATE", _arcState];

missionNamespace setVariable ["ARC_s1_registrySchema", ["ARC_s1_registry_v1", 1], true];
missionNamespace setVariable ["ARC_s1_registry", [["version", 1], ["updatedAt", serverTime], ["groups", []], ["units", []]]];

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
