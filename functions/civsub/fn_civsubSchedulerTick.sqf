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

// Test/diagnostics (server only)
// - civsub_v1_scheduler_force_emit: "" | "LEAD" | "ATTACK" | "BOTH"
// - civsub_v1_scheduler_force_district: "" (all) or "Dxx"
// - civsub_v1_scheduler_diag_enabled: bool (store last computed values per district)

private _forceMode = missionNamespace getVariable ["civsub_v1_scheduler_force_emit", ""]; // "" | "LEAD" | "ATTACK" | "BOTH"
private _forceDid = missionNamespace getVariable ["civsub_v1_scheduler_force_district", ""]; // "" (all) or "Dxx"
private _diagEnabled = missionNamespace getVariable ["civsub_v1_scheduler_diag_enabled", false];
private _diagMap = missionNamespace getVariable ["civsub_v1_scheduler_diag", createHashMap];
if !(_diagMap isEqualType createHashMap) then { _diagMap = createHashMap; };

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if !(_districts isEqualType createHashMap) exitWith {false};

private _schedS = missionNamespace getVariable ["civsub_v1_scheduler_s", 300];
if (!(_schedS isEqualType 0)) then { _schedS = 300; };
if (_schedS < 30) then { _schedS = 30; };

missionNamespace setVariable ["civsub_v1_scheduler_lastTick_ts", serverTime, true];

// Scheduler over all districts (stable ids D01..D20)
{
    private _did = _x;
    private _d = _districts get _did;
    if !(_d isEqualType createHashMap) then { continue; };

    // Activity
    private _active = [_d] call ARC_fnc_civsubIsDistrictActive;
    if (_active) then { _d set ["last_player_touch_ts", serverTime]; };

    // Scores
    private _scores = [_d] call ARC_fnc_civsubScoresCompute;
    private _Scoop = _scores getOrDefault ["S_COOP", 0];
    private _Sthreat = _scores getOrDefault ["S_THREAT", 0];

    // Hourly probabilities
    private _pLeadHour = [_Scoop] call ARC_fnc_civsubProbLeadHour;
    private _pAttackHour = [_Sthreat] call ARC_fnc_civsubProbAttackHour;

    // Tick probabilities
    private _pLeadTick = [_pLeadHour, _schedS] call ARC_fnc_civsubProbHourToTick;
    private _pAttackTick = [_pAttackHour, _schedS] call ARC_fnc_civsubProbHourToTick;

    // Active multiplier applies only to reactive contact probability
    private _pAttackTickEff = _pAttackTick;
    if (_active) then { _pAttackTickEff = _pAttackTickEff * 1.5; };
    if (_pAttackTickEff > 1) then { _pAttackTickEff = 1; };

    // Intel confidence
    private _intelConf = [_Scoop, _Sthreat] call ARC_fnc_civsubIntelConfidence;

    // Cooldowns
    private _nextLead = _d getOrDefault ["cooldown_nextLead_ts", 0];
    private _nextAttack = _d getOrDefault ["cooldown_nextAttack_ts", 0];

    // Diagnostics snapshot (per district)
    if (_diagEnabled) then {
        private _row = createHashMapFromArray [
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
        ];
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
            missionNamespace setVariable ["civsub_v1_lastScheduler_bundle", _b, true];
            missionNamespace setVariable ["civsub_v1_lastScheduler_bundle_pairs", [_b] call ARC_fnc_civsubBundleToPairs, true];

            // Phase 6: per-district last bundle map (for SITREP annex + UI)
            private _lb = missionNamespace getVariable ["civsub_v1_lastBundleByDistrict", createHashMap];
            if !(_lb isEqualType createHashMap) then { _lb = createHashMap; };
            _lb set [_did, _b];
            missionNamespace setVariable ["civsub_v1_lastBundleByDistrict", _lb, true];
            if (_diagEnabled) then {
                private _row2 = _diagMap get _did;
                if (_row2 isEqualType createHashMap) then {
                    _row2 set ["nextLead_ts", _d getOrDefault ["cooldown_nextLead_ts", _nextLead]];
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
                private _row3 = _diagMap get _did;
                if (_row3 isEqualType createHashMap) then {
                    _row3 set ["nextAttack_ts", _d getOrDefault ["cooldown_nextAttack_ts", _nextAttack]];
                };
            };
        };
    };

} forEach (keys _districts);

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
    diag_log format ["[CIVSUB][SCHED] tick=%1 districts=%2", serverTime, count (keys _districts)];
};

true
