/*
    ARC_fnc_civsubSitrepAnnexBuild

    Phase 6: Build a CIVSUB annex string to append to incident SITREPs.

    Phase 6 closeout:
      - Includes baseline A.6 start/end windowing for influence and counters.
      - Applies readability thresholds: influence delta line only when |d*| >= 2.
      - Uses toFixed for decimal formatting (SQF format does not support %.1f etc.).

    Server authoritative. Produces compact, readable text.

    Params:
      0: STRING - districtId
      1: ARRAY  - reference position [x,y,z] (optional)

    Returns:
      STRING ("" if CIVSUB disabled or district not found)
*/

if (!isServer) exitWith {""};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {""};

params [
    ["_districtId", "", [""]],
    ["_pos", [0,0,0], [[]]]
];

_districtId = toUpper (trim _districtId);
if (_districtId isEqualTo "") exitWith {""};

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if !(_districts isEqualType createHashMap) exitWith {""};

private _d = _districts getOrDefault [_districtId, createHashMap];
if (_d isEqualType []) then { _d = createHashMapFromArray _d; };
if !(_d isEqualType createHashMap) exitWith {""};

private _active = [_d] call ARC_fnc_civsubIsDistrictActive;
private _scores = [_d] call ARC_fnc_civsubScoresCompute;

private _Scoop = 0;
private _Sthreat = 0;
if (_scores isEqualType createHashMap) then
{
    _Scoop = _scores getOrDefault ["S_COOP", 0];
    _Sthreat = _scores getOrDefault ["S_THREAT", 0];
};

private _intelConf = [_Scoop, _Sthreat] call ARC_fnc_civsubIntelConfidence;

private _W = _d getOrDefault ["W_EFF_U", 0];
private _R = _d getOrDefault ["R_EFF_U", 0];
private _G = _d getOrDefault ["G_EFF_U", 0];

// Baseline A.6 counters (persisted per district)
private _kia = _d getOrDefault ["civ_cas_kia", 0];
private _wia = _d getOrDefault ["civ_cas_wia", 0];
private _crimeHits = _d getOrDefault ["crime_db_hits", 0];
private _detInit = _d getOrDefault ["detentions_initiated", 0];
private _detHand = _d getOrDefault ["detentions_handed_off", 0];
private _aid = _d getOrDefault ["aid_events", 0];

private _cent = _d getOrDefault ["centroid", [0,0]];
private _grid = "";
if (_cent isEqualType [] && { (count _cent) >= 2 }) then
{
    _grid = mapGridPosition [_cent # 0, _cent # 1, 0];
};

// Incident window snapshot (captured at acceptance)
private _incDid = ["activeIncidentCivsubDistrictId", ""] call ARC_fnc_stateGet;
if !(_incDid isEqualType "") then { _incDid = ""; };
_incDid = toUpper _incDid;

private _start = ["activeIncidentCivsubStart", []] call ARC_fnc_stateGet;
private _startHm = createHashMap;
if (_start isEqualType createHashMap) then { _startHm = _start; };
if (_start isEqualType []) then
{
    // array-of-pairs -> hashmap
    _startHm = createHashMapFromArray _start;
};

private _hasWindow = (_incDid isEqualTo _districtId) && { _startHm isEqualType createHashMap } && { (count (keys _startHm)) > 0 };

private _Ws = _W;
private _Rs = _R;
private _Gs = _G;
private _kiaS = _kia;
private _wiaS = _wia;
private _crimeS = _crimeHits;
private _detInitS = _detInit;
private _detHandS = _detHand;
private _aidS = _aid;

if (_hasWindow) then
{
    _Ws = _startHm getOrDefault ["W", _W];
    _Rs = _startHm getOrDefault ["R", _R];
    _Gs = _startHm getOrDefault ["G", _G];

    _kiaS = _startHm getOrDefault ["civ_cas_kia", _kia];
    _wiaS = _startHm getOrDefault ["civ_cas_wia", _wia];
    _crimeS = _startHm getOrDefault ["crime_db_hits", _crimeHits];
    _detInitS = _startHm getOrDefault ["detentions_initiated", _detInit];
    _detHandS = _startHm getOrDefault ["detentions_handed_off", _detHand];
    _aidS = _startHm getOrDefault ["aid_events", _aid];
};

private _dW = _W - _Ws;
private _dR = _R - _Rs;
private _dG = _G - _Gs;

private _dkia = _kia - _kiaS;
private _dwia = _wia - _wiaS;
private _dcrime = _crimeHits - _crimeS;
private _ddetInit = _detInit - _detInitS;
private _ddetHand = _detHand - _detHandS;
private _daid = _aid - _aidS;

// Pull latest district event bundle if available (Phase 5.5 contract).
private _last = missionNamespace getVariable ["civsub_v1_lastScheduler_bundle", createHashMap];
if (_last isEqualType []) then { _last = createHashMapFromArray _last; };
private _lastEvent = "";
if (_last isEqualType createHashMap) then
{
    private _did = _last getOrDefault ["district_id", ""]; // contract
    if (_did isEqualTo "") then { _did = _last getOrDefault ["districtId", ""]; }; // legacy
    if ((toUpper _did) isEqualTo _districtId) then
    {
        private _src = _last getOrDefault ["source", createHashMap];
        if (_src isEqualType []) then { _src = createHashMapFromArray _src; };
        private _ev = "";
        if (_src isEqualType createHashMap) then { _ev = _src getOrDefault ["event", ""]; };
        if (_ev isEqualTo "") then { _ev = "CIVSUB_EVENT"; };

        private _ts = _last getOrDefault ["ts", -1];
        private _lead = _last getOrDefault ["lead_emit", createHashMap];
        if (_lead isEqualType []) then { _lead = createHashMapFromArray _lead; };
        private _lt = "";
        private _conf = -1;
        if (_lead isEqualType createHashMap) then
        {
            _lt = _lead getOrDefault ["lead_type", ""]; 
            _conf = _lead getOrDefault ["confidence", -1];
        };

        private _tsTxt = if (_ts < 0) then {""} else { str (round _ts) };
        private _confTxt = if (_conf < 0) then {""} else { (_conf toFixed 2) };

        _lastEvent = "Last: " + _ev +
            (if (_tsTxt isEqualTo "") then {""} else { " (ts=" + _tsTxt + ")" }) +
            (if (_lt isEqualTo "") then {""} else { " | type=" + _lt }) +
            (if (_confTxt isEqualTo "") then {""} else { " | conf=" + _confTxt });
    };
};

private _lines = [];
_lines pushBack "CIVSUB ANNEX";
_lines pushBack ("District: " + _districtId + (if (_grid isEqualTo "") then {""} else { " (" + _grid + ")" }));
_lines pushBack ("Active: " + (if (_active) then {"YES"} else {"NO"}));

if (_hasWindow) then
{
    _lines pushBack ("Influence start W/R/G: " + (_Ws toFixed 1) + " / " + (_Rs toFixed 1) + " / " + (_Gs toFixed 1));
    _lines pushBack ("Influence end W/R/G: " + (_W toFixed 1) + " / " + (_R toFixed 1) + " / " + (_G toFixed 1));

    // Baseline threshold: show deltas only when magnitude meaningful
    if ((abs _dW) >= 2 || (abs _dR) >= 2 || (abs _dG) >= 2) then
    {
        _lines pushBack ("Influence delta dW/dR/dG: " + (_dW toFixed 1) + " / " + (_dR toFixed 1) + " / " + (_dG toFixed 1));
    };

    // Window counters: show non-zero only
    if (_dkia > 0 || _dwia > 0) then { _lines pushBack ("Civilian casualties (window) KIA/WIA: " + str _dkia + " / " + str _dwia); };
    if (_dcrime > 0) then { _lines pushBack ("Crime DB hits (window): " + str _dcrime); };
    if (_ddetInit > 0 || _ddetHand > 0) then { _lines pushBack ("Detentions (window) initiated/handedOff: " + str _ddetInit + " / " + str _ddetHand); };
    if (_daid > 0) then { _lines pushBack ("Aid events (window): " + str _daid); };
}
else
{
    // Fallback (no acceptance snapshot) - still show current end-state for operator awareness
    _lines pushBack ("Influence end W/R/G: " + (_W toFixed 1) + " / " + (_R toFixed 1) + " / " + (_G toFixed 1));
    if ((_kia + _wia) > 0) then { _lines pushBack ("Civilian casualties (total) KIA/WIA: " + str _kia + " / " + str _wia); };
    if (_crimeHits > 0) then { _lines pushBack ("Crime DB hits (total): " + str _crimeHits); };
    if (_detInit > 0 || _detHand > 0) then { _lines pushBack ("Detentions (total) initiated/handedOff: " + str _detInit + " / " + str _detHand); };
    if (_aid > 0) then { _lines pushBack ("Aid events (total): " + str _aid); };
};

_lines pushBack ("S_COOP: " + (_Scoop toFixed 1) + "  S_THREAT: " + (_Sthreat toFixed 1) + "  IntelConf: " + (_intelConf toFixed 2));
if (_lastEvent isNotEqualTo "") then { _lines pushBack _lastEvent; };

_lines joinString "\n"
