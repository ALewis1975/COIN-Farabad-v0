/*
    ARC_fnc_civsubSchedulerTick

    CIVSUB Phase 5 scheduler run (every civsub_v1_scheduler_s seconds).
    Implements:
      - ambient lead generation (<=1 per district per hour)
      - reactive contact cue (<=1 per district per 30 minutes)
      - optional rumor (stubbed)

    Exact formulas and cooldown logic are taken from the CIVSUB v1 Development Baseline (Section 8.3, 8.4, 9, 12).

    Returns: true
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_scheduler_enabled", false]) exitWith {false};

private _requiredFnNames = [
    "ARC_fnc_civsubIsDistrictActive",
    "ARC_fnc_civsubScoresCompute",
    "ARC_fnc_civsubProbLeadHour",
    "ARC_fnc_civsubProbAttackHour",
    "ARC_fnc_civsubProbHourToTick",
    "ARC_fnc_civsubIntelConfidence",
    "ARC_fnc_civsubSchedulerEmitAmbientLead",
    "ARC_fnc_civsubSchedulerEmitReactiveContact",
    "ARC_fnc_civsubBundleToPairs"
];
private _missingFns = _requiredFnNames select {
    private _fn = missionNamespace getVariable [_x, objNull];
    !(_fn isEqualType {})
};

private _hasDistrictsState = !(isNil { missionNamespace getVariable "civsub_v1_districts" });
private _hasSchedulerState = !(isNil { missionNamespace getVariable "civsub_v1_scheduler_s" });

if ((count _missingFns) > 0 || {!_hasDistrictsState} || {!_hasSchedulerState}) exitWith {
    if (
        missionNamespace getVariable ["civsub_v1_debug", false]
        && {((floor serverTime) mod 300) isEqualTo 0}
    ) then {
        diag_log format [
            "[CIVSUB][SCHED][GUARD] missing prerequisites fn=%1 districts=%2 scheduler=%3",
            _missingFns,
            _hasDistrictsState,
            _hasSchedulerState
        ];
    };
    false
};

// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
private _hg      = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _mapGet  = compile "params ['_h','_k']; _h get _k";
private _hmFrom  = compile "private _pairs = _this; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";
private _keysFn  = compile "params ['_h']; keys _h";

// Test/diagnostics (server only)
// - civsub_v1_scheduler_force_emit: "" | "LEAD" | "ATTACK" | "BOTH"
// - civsub_v1_scheduler_force_district: "" (all) or "Dxx"
// - civsub_v1_scheduler_diag_enabled: bool (store last computed values per district)

private _forceMode = missionNamespace getVariable ["civsub_v1_scheduler_force_emit", ""]; // "" | "LEAD" | "ATTACK" | "BOTH"
private _forceDidRaw = missionNamespace getVariable ["civsub_v1_scheduler_force_district", ""]; // "" (all) or "Dxx"
private _forceDid = _forceDidRaw;
if (_forceDid isEqualType "") then {
    _forceDid = toUpper ([_forceDid] call _trimFn);
} else {
    _forceDid = "";
};
private _diagEnabled = missionNamespace getVariable ["civsub_v1_scheduler_diag_enabled", false];
private _diagMap = missionNamespace getVariable ["civsub_v1_scheduler_diag", createHashMap];
if !(_diagMap isEqualType createHashMap) then { _diagMap = createHashMap; };

private _todPolicy = [] call ARC_fnc_dynamicTodRefresh;
private _phase = _todPolicy getOrDefault ["phase", "DAY"];
if (!(_phase isEqualType "")) then { _phase = "DAY"; };
private _tod = _todPolicy getOrDefault ["tod", dayTime];
if (!(_tod isEqualType 0)) then { _tod = dayTime; };

private _mLead = missionNamespace getVariable ["civsub_v1_activity_mul_sched_lead_day", 1.0];
private _mAttack = missionNamespace getVariable ["civsub_v1_activity_mul_sched_attack_day", 1.0];
if (_phase isEqualTo "NIGHT") then {
    _mLead = missionNamespace getVariable ["civsub_v1_activity_mul_sched_lead_night", 0.85];
    _mAttack = missionNamespace getVariable ["civsub_v1_activity_mul_sched_attack_night", 1.10];
};
if (_phase isEqualTo "PEAK") then {
    _mLead = missionNamespace getVariable ["civsub_v1_activity_mul_sched_lead_peak", 1.10];
    _mAttack = missionNamespace getVariable ["civsub_v1_activity_mul_sched_attack_peak", 0.95];
};
if !(_mLead isEqualType 0) then { _mLead = 1.0; };
if !(_mAttack isEqualType 0) then { _mAttack = 1.0; };
_mLead = (_mLead max 0.1) min 2.0;
_mAttack = (_mAttack max 0.1) min 2.0;
missionNamespace setVariable ["civsub_v1_activity_mul_sched_lead_active", _mLead, false];
missionNamespace setVariable ["civsub_v1_activity_mul_sched_attack_active", _mAttack, false];

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if !(_districts isEqualType createHashMap) exitWith {false};

private _schedRaw = missionNamespace getVariable ["civsub_v1_scheduler_s", 300];
private _schedCheck = [_schedRaw, "SCALAR_BOUNDS", "civsub_v1_scheduler_s", [300, 30, 86400]] call ARC_fnc_paramAssert;
private _schedS = _schedCheck param [1, 300];
if !(_schedCheck param [0, false]) then {
    ["CIVSUB", format ["scheduler tick guard: code=%1 msg=%2", _schedCheck param [2, "ARC_ASSERT_UNKNOWN"], _schedCheck param [3, "scheduler interval invalid"]], [["code", _schedCheck param [2, "ARC_ASSERT_UNKNOWN"]], ["guard", "civsubSchedulerTick"], ["key", "civsub_v1_scheduler_s"]]] call ARC_fnc_farabadWarn;
};

missionNamespace setVariable ["civsub_v1_scheduler_lastTick_ts", serverTime, true];

// Scheduler over all districts (stable ids D01..D20)
{
    private _did = _x;
    private _d = [_districts, _did] call _mapGet;
    if !(_d isEqualType createHashMap) then { continue; };

    // Activity
    private _active = [_d] call ARC_fnc_civsubIsDistrictActive;
    if (_active) then { _d set ["last_player_touch_ts", serverTime]; };

    // Scores
    private _scores = [_d] call ARC_fnc_civsubScoresCompute;
    private _Scoop = [_scores, "S_COOP", 0] call _hg;
    private _Sthreat = [_scores, "S_THREAT", 0] call _hg;

    // Hourly probabilities
    private _pLeadHour = [_Scoop] call ARC_fnc_civsubProbLeadHour;
    private _pAttackHour = [_Sthreat] call ARC_fnc_civsubProbAttackHour;

    // Tick probabilities
    private _pLeadTick = [_pLeadHour, _schedS] call ARC_fnc_civsubProbHourToTick;
    private _pAttackTick = [_pAttackHour, _schedS] call ARC_fnc_civsubProbHourToTick;
    _pLeadTick = (_pLeadTick * _mLead) min 1;
    _pAttackTick = (_pAttackTick * _mAttack) min 1;

    // Active multiplier applies only to reactive contact probability
    private _pAttackTickEff = _pAttackTick;
    if (_active) then { _pAttackTickEff = _pAttackTickEff * 1.5; };
    if (_pAttackTickEff > 1) then { _pAttackTickEff = 1; };

    // Intel confidence
    private _intelConf = [_Scoop, _Sthreat] call ARC_fnc_civsubIntelConfidence;

    // Cooldowns
    private _nextLead = [_d, "cooldown_nextLead_ts", 0] call _hg;
    private _nextAttack = [_d, "cooldown_nextAttack_ts", 0] call _hg;

    // Diagnostics snapshot (per district)
    if (_diagEnabled) then {
        private _row = [
            ["ts", serverTime],
            ["active", _active],
            ["S_COOP", _Scoop],
            ["S_THREAT", _Sthreat],
            ["pLeadHour", _pLeadHour],
            ["pAttackHour", _pAttackHour],
            ["pLeadTick", _pLeadTick],
            ["pAttackTick", _pAttackTick],
            ["pAttackTickEff", _pAttackTickEff],
            ["intel_conf", _intelConf],
            ["nextLead_ts", _nextLead],
            ["nextAttack_ts", _nextAttack]
        ] call _hmFrom;
        _diagMap set [_did, _row];
    };

    // Force emit logic (test only)
    private _forceThisDistrict = (_forceDid isEqualTo "") || {_forceDid isEqualTo _did};
    private _forceLead = _forceThisDistrict && ((_forceMode isEqualTo "LEAD") || {_forceMode isEqualTo "BOTH"});
    private _forceAttack = _forceThisDistrict && ((_forceMode isEqualTo "ATTACK") || {_forceMode isEqualTo "BOTH"});

    // Emit ambient lead (<= 1/hr)
    if (serverTime >= _nextLead) then {
        if (_forceLead || {(random 1) < _pLeadTick}) then {
            private _b = [_did, _d, _intelConf] call ARC_fnc_civsubSchedulerEmitAmbientLead;

            if (!isNil "ARC_fnc_civsubLeadEmitBridge") then
            {
                private _bridgedLeadId = [_b] call ARC_fnc_civsubLeadEmitBridge;
                if (_bridgedLeadId isEqualType "" && { !(_bridgedLeadId isEqualTo "") }) then
                {
                    missionNamespace setVariable ["civsub_v1_lastScheduler_leadId", _bridgedLeadId, true];
                };
            };

            missionNamespace setVariable ["civsub_v1_lastScheduler_bundle", _b, true];
            missionNamespace setVariable ["civsub_v1_lastScheduler_bundle_pairs", [_b] call ARC_fnc_civsubBundleToPairs, true];

            // Phase 6: per-district last bundle map (for SITREP annex + UI)
            private _lb = missionNamespace getVariable ["civsub_v1_lastBundleByDistrict", createHashMap];
            if !(_lb isEqualType createHashMap) then { _lb = createHashMap; };
            _lb set [_did, _b];
            missionNamespace setVariable ["civsub_v1_lastBundleByDistrict", _lb, true];
            if (_diagEnabled) then {
                private _row2 = [_diagMap, _did] call _mapGet;
                if (_row2 isEqualType createHashMap) then {
                    _row2 set ["nextLead_ts", [_d, "cooldown_nextLead_ts", _nextLead] call _hg];
                };
            };
        };
    };

    // Emit reactive contact (<= 1/30m)
    if (serverTime >= _nextAttack) then {
        if (_forceAttack || {(random 1) < _pAttackTickEff}) then {
            private _b2 = [_did, _d, _pAttackTickEff, _active] call ARC_fnc_civsubSchedulerEmitReactiveContact;
            missionNamespace setVariable ["civsub_v1_lastScheduler_bundle", _b2, true];
            missionNamespace setVariable ["civsub_v1_lastScheduler_bundle_pairs", [_b2] call ARC_fnc_civsubBundleToPairs, true];

            // Phase 6: per-district last bundle map (for SITREP annex + UI)
            private _lb2 = missionNamespace getVariable ["civsub_v1_lastBundleByDistrict", createHashMap];
            if !(_lb2 isEqualType createHashMap) then { _lb2 = createHashMap; };
            _lb2 set [_did, _b2];
            missionNamespace setVariable ["civsub_v1_lastBundleByDistrict", _lb2, true];
            if (_diagEnabled) then {
                private _row3 = [_diagMap, _did] call _mapGet;
                if (_row3 isEqualType createHashMap) then {
                    _row3 set ["nextAttack_ts", [_d, "cooldown_nextAttack_ts", _nextAttack] call _hg];
                };
            };
        };
    };

} forEach ([_districts] call _keysFn);

// Publish diagnostics map (bounded by 20 districts)
if (_diagEnabled) then {
    missionNamespace setVariable ["civsub_v1_scheduler_diag", _diagMap, true];
};

// Auto-clear force mode after one tick (prevents accidental spam)
if !(_forceMode isEqualTo "") then {
    missionNamespace setVariable ["civsub_v1_scheduler_force_emit", "", true];
    missionNamespace setVariable ["civsub_v1_scheduler_force_district", "", true];
};

if (missionNamespace getVariable ["civsub_v1_debug", false]) then {
    diag_log format ["[CIVSUB][SCHED] tick=%1 districts=%2", serverTime, count ([_districts] call _keysFn)];
};

true
