/*
    ARC_fnc_civsubInitServer

    CIVSUB v1 Phase 0-2: server-authoritative district influence state + decay tick + delta emitter.

    Posture:
      - Feature-flagged via civsub_v1_enabled (default OFF).
      - Single-writer: server updates civsub_v1_* state.
      - Persistence is bounded and uses profileNamespace keys locked in CIVSUB baseline.
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

// Phase 2: shared off-road placement helpers (server-owned).
// We store these as missionNamespace function values to avoid touching CfgFunctions.hpp
// (reduces regression risk when multiple hotfixes touch config files).
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

if (isNil { missionNamespace getVariable "ARC_civsub_fnc_posIsRoadish" }) then
{
    missionNamespace setVariable ["ARC_civsub_fnc_posIsRoadish",
    {
        params [
            ["_pos", [0,0,0], [[]]],
            ["_probeStep", 1.2, [0]],
            ["_nearR", 0.75, [0]]
        ];

        if (!(_pos isEqualType []) || { (count _pos) < 2 }) exitWith { true };

        private _p = _pos;
        if ((count _p) == 2) then { _p = [_p select 0, _p select 1, 0]; };

        _probeStep = (_probeStep max 0.6) min 2.0;
        _nearR = (_nearR max 0.15) min 1.5;

        if (isOnRoad _p) exitWith { true };
        if ((count (_p nearRoads _nearR)) > 0) exitWith { true };

        {
            private _q = _p getPos [_probeStep, _x];
            _q set [2, 0];
            if (isOnRoad _q) exitWith { true };
            if ((count (_q nearRoads _nearR)) > 0) exitWith { true };
        } forEach [0, 90, 180, 270];

        false
    },
    false];
};

if (isNil { missionNamespace getVariable "ARC_civsub_fnc_findPosOffRoad" }) then
{
    missionNamespace setVariable ["ARC_civsub_fnc_findPosOffRoad",
    {
        params [
            ["_seed", [0,0,0], [[]]],
            ["_minOff", 2, [0]],
            ["_maxOff", 18, [0]],
            ["_tries", 12, [0]]
        ];

        if (!(_seed isEqualType []) || { (count _seed) < 2 }) exitWith { [0,0,0] };

        private _p0 = _seed;
        if ((count _p0) == 2) then { _p0 = [_p0#0,_p0#1,0]; };

        _minOff = (_minOff max 0.5) min 6;
        _maxOff = (_maxOff max (_minOff + 0.5)) min 30;
        _tries = (_tries max 3) min 30;

        private _posIsRoadish = missionNamespace getVariable ["ARC_civsub_fnc_posIsRoadish", { params ["_p"]; isOnRoad _p }];

        if !([_p0] call _posIsRoadish) exitWith { _p0 };

        for "_i" from 1 to _tries do
        {
            private _r = _minOff + random (_maxOff - _minOff);
            private _a = random 360;
            private _p = _p0 getPos [_r, _a];
            _p set [2, 0];

            if (surfaceIsWater _p) then { continue; };

            // Avoid steep slopes (keep consistent with CIVTRAF shoulder logic)
            private _n = surfaceNormal _p;
            private _slope = acos ((_n vectorDotProduct [0,0,1]) max -1 min 1);
            if (_slope > 0.35) then { continue; };

            if ([_p] call _posIsRoadish) then { continue; };

            _p
        };

        [0,0,0]
    },
    false];
};

// Ensure persistence keys exist / campaign id seeded.
private _persist = missionNamespace getVariable ["civsub_v1_persist", true];
if (!(_persist isEqualType true)) then { _persist = true; };

if (_persist) then {
    [] call ARC_fnc_civsubPersistMigrateIfNeeded;
} else {
    diag_log "[CIVSUB][PERSIST] Disabled (skipping migrate/load/autosave)";
};

private _ok = false;
if (_persist) then { _ok = [] call ARC_fnc_civsubPersistLoad; };
if (!_ok) then
{
    private _districts = [] call ARC_fnc_civsubDistrictsCreateDefaults;

    missionNamespace setVariable ["civsub_v1_districts", _districts, true];
    missionNamespace setVariable ["civsub_v1_identities", createHashMap, true];
    missionNamespace setVariable ["civsub_v1_crimedb", createHashMap, true];
    missionNamespace setVariable ["civsub_v1_version", missionNamespace getVariable ["civsub_v1_version", 1], true];

    diag_log format ["[CIVSUB][INIT] Fresh state created (districts=%1)", count (keys _districts)];
}
else
{
    private _d = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
    diag_log format ["[CIVSUB][INIT] State loaded (districts=%1)", count (keys _d)];
};

// Phase 3: identity + crime DB init (self-contained, no gameplay integration yet)
[] call ARC_fnc_civsubIdentityInit;
[] call ARC_fnc_civsubCrimeDbInit;

// Phase 4 defaults + sampler init (off by default)
if (isNil { missionNamespace getVariable "civsub_v1_civs_enabled" }) then { missionNamespace setVariable ["civsub_v1_civs_enabled", false, true]; };
// Phase 7 defaults (interaction and harm hooks are safe even if civs are disabled)
if (isNil { missionNamespace getVariable "civsub_v1_interactions_enabled" }) then { missionNamespace setVariable ["civsub_v1_interactions_enabled", true, true]; };
if (isNil { missionNamespace getVariable "civsub_v1_harm_enabled" }) then { missionNamespace setVariable ["civsub_v1_harm_enabled", true, true]; };
// Milestone 2: WIA attribution (enabled by default when harm is enabled)
if (isNil { missionNamespace getVariable "civsub_v1_wia_enabled" }) then { missionNamespace setVariable ["civsub_v1_wia_enabled", true, true]; };

// Phase 7.3: install a single server-side kill listener (robust across locality/HC).
if (missionNamespace getVariable ["civsub_v1_harm_enabled", true]) then
{
    if (isNil { missionNamespace getVariable "civsub_v1_eh_entityKilled" }) then
    {
        private _ehId = addMissionEventHandler ["EntityKilled", {
            params ["_killed", "_killer", "_instigator"];
            if (!isServer) exitWith {};
            if (isNull _killed) exitWith {};
            if !(side _killed isEqualTo civilian) exitWith {};
            if !(_killed getVariable ["civsub_v1_isCiv", false]) exitWith {};

            [_killed, _killer, _instigator] call ARC_fnc_civsubOnCivKilled;
        }];

        missionNamespace setVariable ["civsub_v1_eh_entityKilled", _ehId, true];
        diag_log format ["[CIVSUB][HARM] EntityKilled EH installed (%1)", _ehId];
    };
};

// Milestone 2: install a lightweight server-side WIA monitor.
// Reason: counting "went unconscious" (ACE) once per unit-life is more robust than raw damage EH spam.
if ((missionNamespace getVariable ["civsub_v1_harm_enabled", true]) && { missionNamespace getVariable ["civsub_v1_wia_enabled", true] }) then
{
    if (!(missionNamespace getVariable ["civsub_v1_wiaThreadRunning", false])) then
    {
        missionNamespace setVariable ["civsub_v1_wiaThreadRunning", true, true];
        [] spawn
        {
            while { isServer && { missionNamespace getVariable ["civsub_v1_enabled", false] } && { missionNamespace getVariable ["civsub_v1_harm_enabled", true] } && { missionNamespace getVariable ["civsub_v1_wia_enabled", true] } } do
            {
                uiSleep 2;

                private _reg = missionNamespace getVariable ["civsub_v1_civ_registry", createHashMap];
                if !(_reg isEqualType createHashMap) then { continue; };

                {
                    private _row = [_reg, _x, createHashMap] call _hg;
                    if !(_row isEqualType createHashMap) then { continue; };

                    private _u = [_row, "unit", objNull] call _hg;
                    if (isNull _u) then { continue; };
                    if !(alive _u) then { continue; };
                    if !(_u getVariable ["civsub_v1_isCiv", false]) then { continue; };

                    private _uncon = _u getVariable ["ACE_isUnconscious", false];
                    if (_uncon && {!(_u getVariable ["civsub_v1_wia_counted", false])}) then
                    {
                        _u setVariable ["civsub_v1_wia_counted", true, true];
                        [_u] call ARC_fnc_civsubOnCivWia;
                    };
                } forEach (keys _reg);
            };

            missionNamespace setVariable ["civsub_v1_wiaThreadRunning", false, true];
        };

        diag_log "[CIVSUB][HARM] WIA monitor thread installed";
    };
};

if (isNil { missionNamespace getVariable "civsub_v1_civ_classPool" }) then {
    missionNamespace setVariable ["civsub_v1_civ_classPool", ["C_man_1","C_man_polo_1_F","C_man_polo_2_F","C_man_polo_3_F","C_man_polo_4_F","C_man_polo_5_F","C_man_polo_6_F","C_Man_casual_1_F","C_Man_casual_2_F","C_Man_casual_3_F"], true];
};
if (isNil { missionNamespace getVariable "civsub_v1_civ_tick_s" }) then { missionNamespace setVariable ["civsub_v1_civ_tick_s", 20, true]; };
if (isNil { missionNamespace getVariable "civsub_v1_civ_cap_global" }) then { missionNamespace setVariable ["civsub_v1_civ_cap_global", 24, true]; };
if (isNil { missionNamespace getVariable "civsub_v1_civ_cap_perDistrict" }) then { missionNamespace setVariable ["civsub_v1_civ_cap_perDistrict", 8, true]; };
if (isNil { missionNamespace getVariable "civsub_v1_civ_cap_activeDistrictsMax" }) then { missionNamespace setVariable ["civsub_v1_civ_cap_activeDistrictsMax", 3, true]; };

// Register optional editor-placed CIVSUB test civilians (after identity init and before runtime ticks rely on registry).
[] call ARC_fnc_civsubRegisterEditorCivs;

if (missionNamespace getVariable ["civsub_v1_civs_enabled", false]) then {
    [] call ARC_fnc_civsubCivSamplerInit;
};

// Phase 3: Ambient CIVTRAF (mostly parked, minimal moving)
if (missionNamespace getVariable ["civsub_v1_traffic_enabled", false]) then {
    [] call ARC_fnc_civsubTrafficInit;
};

// Phase 5 defaults + scheduler init (enabled by default for Phase 5 testing)
if (isNil { missionNamespace getVariable "civsub_v1_scheduler_enabled" }) then {
    missionNamespace setVariable ["civsub_v1_scheduler_enabled", true, true];
};
if (isNil { missionNamespace getVariable "civsub_v1_scheduler_s" }) then {
    missionNamespace setVariable ["civsub_v1_scheduler_s", 300, true];
};

if (missionNamespace getVariable ["civsub_v1_scheduler_enabled", false]) then {
    [] call ARC_fnc_civsubSchedulerInit;
};


// Milestone 0: one-time init dump (keeps debugging deterministic without RPT spam)
if (missionNamespace getVariable ["civsub_v1_debug", false]) then
{
    private _persist = missionNamespace getVariable ["civsub_v1_persist", true];
    private _capsG = missionNamespace getVariable ["civsub_v1_civ_cap_global", -1];
    private _capsD = missionNamespace getVariable ["civsub_v1_civ_cap_perDistrict", -1];
    private _capsMaxAD = missionNamespace getVariable ["civsub_v1_civ_cap_activeDistrictsMax", -1];
    private _ov = missionNamespace getVariable ["civsub_v1_civ_cap_overrides", []];
    private _locR = missionNamespace getVariable ["civsub_v1_spawn_cache_locRadius_m", -1];
    [format ["[INIT] persist=%1 civsEnabled=%2 caps(G=%3 D=%4 maxAD=%5) overrides=%6 locRadius=%7", _persist, (missionNamespace getVariable ["civsub_v1_civs_enabled", false]), _capsG, _capsD, _capsMaxAD, _ov, _locR]] call ARC_fnc_civsubDebugLog;
};
// Tick thread (decay + autosave cadence)
if (missionNamespace getVariable ["civsub_v1_tickThreadRunning", false]) exitWith {true};
missionNamespace setVariable ["civsub_v1_tickThreadRunning", true, true];

private _tickS = missionNamespace getVariable ["civsub_v1_tick_s", 60];
if (!(_tickS isEqualType 0)) then { _tickS = 60; };
if (_tickS < 5) then { _tickS = 5; };

missionNamespace setVariable ["civsub_v1_lastTick_ts", serverTime, true];
missionNamespace setVariable ["civsub_v1_nextSave_ts", serverTime + 300, true];

[] spawn
{
    while { isServer && { missionNamespace getVariable ["civsub_v1_enabled", false] } } do
    {
        uiSleep (missionNamespace getVariable ["civsub_v1_tick_s", 60]);
        [] call ARC_fnc_civsubTick;

        // Autosave every 300s (locked baseline).
        private _next = missionNamespace getVariable ["civsub_v1_nextSave_ts", serverTime + 300];
        if (serverTime >= _next) then
        {
            if (missionNamespace getVariable ["civsub_v1_persist", true]) then { [] call ARC_fnc_civsubPersistSave; };
            missionNamespace setVariable ["civsub_v1_nextSave_ts", serverTime + 300, true];
        };
    };

    missionNamespace setVariable ["civsub_v1_tickThreadRunning", false, true];
};

true
