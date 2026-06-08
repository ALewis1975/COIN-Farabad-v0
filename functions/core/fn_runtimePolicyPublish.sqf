/*
    ARC_fnc_runtimePolicyPublish

    Publishes the server-owned Runtime Boundary snapshot.

    Public keys:
      ARC_pub_runtimePolicy
      ARC_pub_runtimePolicyUpdatedAt
      ARC_pub_runtimePolicyMeta

    Returns: BOOL
*/

if (!isServer) exitWith { false };

if (isNil "ARC_fnc_runtimePolicyBuild") then
{
    ARC_fnc_runtimePolicyBuild = compile preprocessFileLineNumbers "functions\\core\\fn_runtimePolicyBuild.sqf";
};

private _snapshot = [] call ARC_fnc_runtimePolicyBuild;
if (!(_snapshot isEqualType [])) exitWith { false };

private _now = serverTime;
private _meta = [
    ["source", "ARC_fnc_runtimePolicyPublish"],
    ["publishedAt", _now],
    ["schema", "ARC_runtimePolicy_v1"]
];

missionNamespace setVariable ["ARC_pub_runtimePolicy", _snapshot, true];
missionNamespace setVariable ["ARC_pub_runtimePolicyUpdatedAt", _now, true];
missionNamespace setVariable ["ARC_pub_runtimePolicyMeta", _meta, true];
missionNamespace setVariable ["ARC_runtimePolicyLastPublishAt", _now];

true
