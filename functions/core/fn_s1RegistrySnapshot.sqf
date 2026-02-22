/*
    Build/publish a read-only S1 registry snapshot for clients.

    Params:
      0: BOOL - publish snapshot into ARC_pub_s1_registry (default true)

    Returns:
      ARRAY - snapshot pairs array
*/

params [["_publish", true, [true]]];

private _registry = missionNamespace getVariable ["ARC_s1_registry", []];
if !(_registry isEqualType []) then { _registry = []; };

private _snapshot = +_registry;
private _now = serverTime;

if (_publish && {isServer}) then
{
    missionNamespace setVariable ["ARC_pub_s1_registry", _snapshot, true];
    missionNamespace setVariable ["ARC_pub_s1_registryUpdatedAt", _now, true];
    missionNamespace setVariable ["ARC_pub_s1_registryMeta", ["s1RegistrySnapshot", _now]];
};

_snapshot
