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

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
private _hg      = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _trimFn  = compile "params ['_s']; trim _s";

_districtId = toUpper ([_districtId] call _trimFn);
if (_districtId isEqualTo "") exitWith {""};

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if !(_districts isEqualType createHashMap) exitWith {""};

private _d = [_districts, _districtId, createHashMap] call _hg;
if (_d isEqualType []) then { _d = [_d] call _hmCreate; };
if !(_d isEqualType createHashMap) exitWith {""};

private _active = [_d] call ARC_fnc_civsubIsDistrictActive;
private _scores = [_d] call ARC_fnc_civsubScoresCompute;

private _Scoop = 0;
private _Sthreat = 0;
if (_scores isEqualType createHashMap) then
{
    _Scoop = [_scores, "S_COOP", 0] call _hg;
    _Sthreat = [_scores, "S_THREAT", 0] call _hg;
};

private _intelConf = [_Scoop, _Sthreat] call ARC_fnc_civsubIntelConfidence;

private _W = [_d, "W_EFF_U", 0] call _hg;
private _R = [_d, "R_EFF_U", 0] call _hg;
private _G = [_d, "G_EFF_U", 0] call _hg;

// Baseline A.6 counters (persisted per district)
private _kia = [_d, "civ_cas_kia", 0] call _hg;
private _wia = [_d, "civ_cas_wia", 0] call _hg;
private _crimeHits = [_d, "crime_db_hits", 0] call _hg;
private _detInit = [_d, "detentions_initiated", 0] call _hg;
private _detHand = [_d, "detentions_handed_off", 0] call _hg;
private _aid = [_d, "aid_events", 0] call _hg;

private _cent = [_d, "centroid", [0,0]] call _hg;
private _grid = "";
if (_cent isEqualType [] && { (count _cent) >= 2 }) then
{
    _grid = mapGridPosition [_cent select 0, _cent select 1, 0];
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
    _startHm = [_start] call _hmCreate;
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
    _Ws = [_startHm, "W", _W] call _hg;
    _Rs = [_startHm, "R", _R] call _hg;
    _Gs = [_startHm, "G", _G] call _hg;

    _kiaS = [_startHm, "civ_cas_kia", _kia] call _hg;
    _wiaS = [_startHm, "civ_cas_wia", _wia] call _hg;
    _crimeS = [_startHm, "crime_db_hits", _crimeHits] call _hg;
    _detInitS = [_startHm, "detentions_initiated", _detInit] call _hg;
    _detHandS = [_startHm, "detentions_handed_off", _detHand] call _hg;
    _aidS = [_startHm, "aid_events", _aid] call _hg;
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
if (_last isEqualType []) then { _last = [_last] call _hmCreate; };
private _lastEvent = "";
if (_last isEqualType createHashMap) then
{
    private _did = [_last, "district_id", ""] call _hg; // contract
    if (_did isEqualTo "") then { _did = [_last, "districtId", ""] call _hg; }; // legacy
    if ((toUpper _did) isEqualTo _districtId) then
    {
        private _src = [_last, "source", createHashMap] call _hg;
        if (_src isEqualType []) then { _src = [_src] call _hmCreate; };
        private _ev = "";
        if (_src isEqualType createHashMap) then { _ev = [_src, "event", ""] call _hg; };
        if (_ev isEqualTo "") then { _ev = "CIVSUB_EVENT"; };

        private _ts = [_last, "ts", -1] call _hg;
        private _lead = [_last, "lead_emit", createHashMap] call _hg;
        if (_lead isEqualType []) then { _lead = [_lead] call _hmCreate; };
        private _lt = "";
        private _conf = -1;
        if (_lead isEqualType createHashMap) then
        {
            _lt = [_lead, "lead_type", ""] call _hg; 
            _conf = [_lead, "confidence", -1] call _hg;
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
if (!(_lastEvent isEqualTo "")) then { _lines pushBack _lastEvent; };

_lines joinString "\n"
