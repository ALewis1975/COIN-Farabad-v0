/*
    ARC_fnc_civsubIdentityInit

    Phase 3: Initialize identity layer containers.
    - No gameplay integration yet.
    - Ensures civsub_v1_identities exists and respects the hard cap (500).
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

// sqflint-compat helpers
private _keysFn   = compile "params ['_m']; keys _m";

private _ids = missionNamespace getVariable ["civsub_v1_identities", createHashMap];
if !(_ids isEqualType createHashMap) then { _ids = createHashMap; };

missionNamespace setVariable ["civsub_v1_identities", _ids, true];
missionNamespace setVariable ["civsub_v1_identity_evictions", missionNamespace getVariable ["civsub_v1_identity_evictions", 0], true];

private _cap = 500;
if ((count ([_ids] call _keysFn)) > _cap) then {
    [_cap] call ARC_fnc_civsubIdentityEvictIfNeeded;
};

true
