/*
    ARC_fnc_threatGovernorCheck

    Threat Economy v0: gate evaluation for a new threat event in a district.

    Params:
      0: STRING districtId (e.g. "D01")
      1: STRING threatType  ("IED", "VBIED", "SUICIDE")
      2: NUMBER escalationTier (0=normal, 1=elevated, 2=high, 3=critical)

    Returns:
      ARRAY [allowed(BOOL), denyReason(STRING)]
      denyReason: "" on allow; one of:
        "THREAT_DISABLED", "GLOBAL_COOLDOWN", "DISTRICT_COOLDOWN",
        "BUDGET_EXHAUSTED", "ESCALATION_TIER"
*/

if (!isServer) exitWith {[false, "NOT_SERVER"]};

params [
    ["_districtId", "", [""]],
    ["_threatType",  "IED", [""]],
    ["_tier", 0, [0]]
];

if (_districtId isEqualTo "") exitWith {[false, "BAD_DISTRICT"]};

// ── 1. Global enable flag ──────────────────────────────────────────────────
private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {[false, "THREAT_DISABLED"]};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _now = serverTime;

// ── 2. Global cooldown ─────────────────────────────────────────────────────
private _gc = ["threat_v0_global_cooldown_until", -1] call ARC_fnc_stateGet;
if (!(_gc isEqualType 0)) then { _gc = -1; };
if (_gc > 0 && { _now < _gc }) exitWith
{
    diag_log format ["[ARC][WARN] ARC_fnc_threatGovernorCheck: GLOBAL_COOLDOWN district=%1 type=%2 remaining=%3s", _districtId, _threatType, _gc - _now];
    [false, "GLOBAL_COOLDOWN"]
};

// ── 3. District risk + cooldown ────────────────────────────────────────────
private _riskMap = ["threat_v0_district_risk", createHashMap] call ARC_fnc_stateGet;
if (!(_riskMap isEqualType createHashMap)) then { _riskMap = createHashMap; };
private _rEntry = [_riskMap, _districtId, createHashMap] call _hg;
private _coolUntil = [_rEntry, "cooldown_until", -1] call _hg;
if (_coolUntil > 0 && { _now < _coolUntil }) exitWith
{
    diag_log format ["[ARC][WARN] ARC_fnc_threatGovernorCheck: DISTRICT_COOLDOWN district=%1 type=%2 remaining=%3s", _districtId, _threatType, _coolUntil - _now];
    [false, "DISTRICT_COOLDOWN"]
};

// ── 4. Attack budget ───────────────────────────────────────────────────────
private _budgetMap = ["threat_v0_attack_budget", createHashMap] call ARC_fnc_stateGet;
if (!(_budgetMap isEqualType createHashMap)) then { _budgetMap = createHashMap; };
private _bEntry = [_budgetMap, _districtId, createHashMap] call _hg;
private _bPoints = [_bEntry, "budget_points", 3] call _hg;
private _spent   = [_bEntry, "spent_today", 0] call _hg;
if (_spent >= _bPoints) exitWith
{
    diag_log format ["[ARC][WARN] ARC_fnc_threatGovernorCheck: BUDGET_EXHAUSTED district=%1 type=%2 spent=%3 budget=%4", _districtId, _threatType, _spent, _bPoints];
    [false, "BUDGET_EXHAUSTED"]
};

// ── 5. Escalation tier requirement ────────────────────────────────────────
private _typeU = toUpper _threatType;
private _tierMin = 0;
if (_typeU isEqualTo "VBIED")   then { _tierMin = 2; };
if (_typeU isEqualTo "SUICIDE") then { _tierMin = 3; };
if (_tier < _tierMin) exitWith
{
    diag_log format ["[ARC][WARN] ARC_fnc_threatGovernorCheck: ESCALATION_TIER district=%1 type=%2 tier=%3 tierMin=%4", _districtId, _threatType, _tier, _tierMin];
    [false, "ESCALATION_TIER"]
};

// ── 6. CIVSUB GREEN score gate (budget modifier) ───────────────────────────
if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
{
    private _civDistricts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
    if (_civDistricts isEqualType createHashMap) then
    {
        private _d = [_civDistricts, _districtId, createHashMap] call _hg;
        private _greenScore = [_d, "G", 35] call _hg;
        if (!(_greenScore isEqualType 0)) then { _greenScore = 35; };

        if (_greenScore >= 80 && { _tier < 2 }) then
        {
            // High legitimacy: refresh budget bonus (non-persisted, tick-level effect)
            private _budgetMap = ["threat_v0_attack_budget", createHashMap] call ARC_fnc_stateGet;
            if (_budgetMap isEqualType createHashMap) then
            {
                private _bEntry = [_budgetMap, _districtId, createHashMap] call _hg;
                if (_bEntry isEqualType createHashMap) then
                {
                    private _bp = [_bEntry, "budget_points", 3] call _hg;
                    _bEntry set ["budget_points", (_bp + 5) min 10];
                    _budgetMap set [_districtId, _bEntry];
                    ["threat_v0_attack_budget", _budgetMap] call ARC_fnc_stateSet;
                };
            };
        };

        if (_greenScore < 20) then
        {
            // Very low legitimacy: burn budget penalty
            private _budgetMap = ["threat_v0_attack_budget", createHashMap] call ARC_fnc_stateGet;
            if (_budgetMap isEqualType createHashMap) then
            {
                private _bEntry = [_budgetMap, _districtId, createHashMap] call _hg;
                if (_bEntry isEqualType createHashMap) then
                {
                    private _spent = [_bEntry, "spent_today", 0] call _hg;
                    _bEntry set ["spent_today", _spent + 5];
                    _budgetMap set [_districtId, _bEntry];
                    ["threat_v0_attack_budget", _budgetMap] call ARC_fnc_stateSet;
                };
            };
        };
    };
};

[true, ""]
