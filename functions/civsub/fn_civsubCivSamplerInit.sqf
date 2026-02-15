/*
    ARC_fnc_civsubCivSamplerInit

    Phase 4: physical civilian sampling inside the player relevance bubble.

    Posture:
      - Server-owned, feature-flagged via civsub_v1_civs_enabled (default OFF).
      - Hard caps and cleanup discipline from day one.
      - No dependency on GRAD Passport.

    State:
      civsub_v1_activeDistrictIds (array of strings)
      civsub_v1_civ_registry (HashMap: key -> HashMap record)
      civsub_v1_civ_despawnQueue (array of keys)
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_civs_enabled", false]) exitWith {false};

if (missionNamespace getVariable ["civsub_v1_civSamplerRunning", false]) exitWith {true};
missionNamespace setVariable ["civsub_v1_civSamplerRunning", true, true];

// Ensure state containers exist
if !((missionNamespace getVariable ["civsub_v1_activeDistrictIds", []]) isEqualType []) then {
    missionNamespace setVariable ["civsub_v1_activeDistrictIds", [], true];
};

private _reg = missionNamespace getVariable ["civsub_v1_civ_registry", createHashMap];
if !(_reg isEqualType createHashMap) then { _reg = createHashMap; };
missionNamespace setVariable ["civsub_v1_civ_registry", _reg, true];

private _q = missionNamespace getVariable ["civsub_v1_civ_despawnQueue", []];
if !(_q isEqualType []) then { _q = []; };
missionNamespace setVariable ["civsub_v1_civ_despawnQueue", _q, true];

missionNamespace setVariable ["civsub_v1_civ_cleanup_last_ts", serverTime, true];

// Tick loop
[] spawn
{
    while { isServer && { missionNamespace getVariable ["civsub_v1_enabled", false] } && { missionNamespace getVariable ["civsub_v1_civs_enabled", false] } } do
    {
        uiSleep (missionNamespace getVariable ["civsub_v1_civ_tick_s", 20]);
        [] call ARC_fnc_civsubCivSamplerTick;
        [] call ARC_fnc_civsubCivCleanupTick;
    };

    missionNamespace setVariable ["civsub_v1_civSamplerRunning", false, true];
};

if (missionNamespace getVariable ["civsub_v1_debug", false]) then {
    diag_log "[CIVSUB][CIVS] Sampler init";
};

true
