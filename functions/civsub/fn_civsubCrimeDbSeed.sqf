/*
    ARC_fnc_civsubCrimeDbSeed

    Seeds the Crime DB with 30 POIs:
      - 6 HVT
      - 24 associates

    Baseline locks:
      - All start AT_LARGE
      - District assignment is population-weighted and deterministic per campaign
      - Categories include (minimum):
          IED_FACILITATOR, OPS_PLANNER, FINANCE_LOGISTICS, URBAN_SUPPORT, WEAPONS_SMUGGLER, CELL_MEMBER

    PH4B: Optional enrichment behind civsub_v1_enrich_enabled:
          Adds wanted_level + narrative reason fields (issuer/confidence) to POI records.

    Returns: HashMap poi_id -> crime_record
*/

if (!isServer) exitWith {createHashMap};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {createHashMap};

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if !(_districts isEqualType createHashMap) exitWith {createHashMap};

private _enrich = missionNamespace getVariable ["civsub_v1_enrich_enabled", true];
if !(_enrich isEqualType true) then { _enrich = true; };

private _campaignId = profileNamespace getVariable ["FARABAD_CIVSUB_V1_CAMPAIGN_ID", ""]; 
private _seed = missionNamespace getVariable ["civsub_v1_seed", 1337];
if !(_seed isEqualType 0) then { _seed = 1337; };

// Derive a deterministic integer seed from campaign id + civsub_v1_seed
private _hash = 0;
{ _hash = (_hash + (_x * 33)) mod 2147483647; } forEach (toArray _campaignId);
_seed = (_seed + _hash) mod 2147483647;
if (_seed <= 0) then { _seed = 1337; };

private _rand01 = {
    // LCG, returns float [0,1)
    _seed = (_seed * 1103515245 + 12345) mod 2147483647;
    (_seed / 2147483647)
};

private _pad3 = {
    params ["_n"]; 
    private _s = str _n;
    while { (count _s) < 3 } do { _s = "0" + _s; };
    _s
};

// Build weighted district list by population
private _weights = [];
private _totalPop = 0;
{
    private _d = _districts get _x;
    if !(_d isEqualType createHashMap) then { continue; };
    private _p = [_d, "pop_total", 0] call _hg;
    if !(_p isEqualType 0) then { _p = 0; };
    if (_p < 0) then { _p = 0; };
    _weights pushBack [_x, _p];
    _totalPop = _totalPop + _p;
} forEach (keys _districts);
if (_totalPop <= 0) then { _totalPop = 1; };

private _pickDistrict = {
    private _r = (call _rand01) * _totalPop;
    private _acc = 0;
    {
        _acc = _acc + (_x select 1);
        if (_r <= _acc) exitWith { _x select 0 };
    } forEach _weights;
    (_weights select 0) select 0
};

private _cats = ["IED_FACILITATOR","OPS_PLANNER","FINANCE_LOGISTICS","URBAN_SUPPORT","WEAPONS_SMUGGLER","CELL_MEMBER"];
private _catsHvt = ["OPS_PLANNER","FINANCE_LOGISTICS","IED_FACILITATOR"]; // biased subset for HVT

private _db = createHashMap;
private _status0 = "AT_LARGE";

private _mkNarrative = {
    // Returns: [wantedLvl, reasonCode, reasonText, issuerOrg, conf]
    params ["_poiId","_cat","_isHvt","_randFn"];

    private _wl = if (_isHvt) then { 4 + floor ((call _randFn) * 2) } else { 2 + floor ((call _randFn) * 2) };
    if (_wl < 1) then { _wl = 1; };
    if (_wl > 5) then { _wl = 5; };

    private _code = "SUSPICIOUS";
    private _text = format ["Suspicious activity (%1)", _cat];

    switch (_cat) do {
        case "IED_FACILITATOR": { _code = "EXPLOSIVES_FAC"; _text = "Linked to IED procurement or facilitation."; };
        case "OPS_PLANNER": { _code = "OPS_PLANNING"; _text = "Suspected involvement in planning insurgent operations."; };
        case "FINANCE_LOGISTICS": { _code = "FIN_LOG"; _text = "Suspected finance or logistics support to insurgents."; };
        case "URBAN_SUPPORT": { _code = "URBAN_SUPPORT"; _text = "Provides courier or safe-house support in town."; };
        case "WEAPONS_SMUGGLER": { _code = "WEAPONS_SMUG"; _text = "Suspected weapons smuggling or trafficking."; };
        case "CELL_MEMBER": { _code = "CELL_MEMBER"; _text = "Identified member or associate of a local cell."; };
        default { };
    };

    private _issuerPool = if (_isHvt) then {
        ["COALITION WATCHLIST","PROVINCIAL INTEL CELL","NDS CT UNIT"]
    } else {
        ["LOCAL POLICE","PROVINCIAL INTEL","NDS TIPLINE","COALITION REPORT"]
    };

    private _issuer = _issuerPool select (floor ((call _randFn) * (count _issuerPool)));

    private _conf = 0.55 + ((call _randFn) * 0.35);
    if (_isHvt) then { _conf = _conf + 0.10; };
    if (_conf > 0.95) then { _conf = 0.95; };
    if (_conf < 0.35) then { _conf = 0.35; };

    [_wl, _code, _text, _issuer, _conf]
};

for "_i" from 1 to 30 do
{
    private _isHvt = (_i <= 6);
    private _districtId = call _pickDistrict;

    private _poiId = format ["POI:%1:%2", _districtId, ([_i] call _pad3)];

    private _cat = if (_isHvt) then {
        _catsHvt select (floor ((call _rand01) * (count _catsHvt)))
    } else {
        _cats select (floor ((call _rand01) * (count _cats)))
    };

    // Serial-like handle for cross reference
    private _serialNum = str (100000 + floor ((call _rand01) * 900000));
    private _serial = format ["FRB-11-%1", _serialNum];

    private _hist = [[_status0, serverTime]];

    private _rec = [[
        ["poi_id", _poiId],
        ["is_hvt", _isHvt],
        ["category", _cat],
        ["homeDistrictId", _districtId],
        ["passport_serial", _serial],
        ["status", _status0],
        ["status_ts", serverTime],
        ["status_history", _hist]
    ]] call _hmCreate;

    if (_enrich) then {
        private _n = [_poiId, _cat, _isHvt, _rand01] call _mkNarrative;
        _rec set ["wanted_level", _n select 0];
        _rec set ["wanted_reason_code", _n select 1];
        _rec set ["wanted_reason_text", _n select 2];
        _rec set ["wanted_issuing_org", _n select 3];
        _rec set ["wanted_confidence", _n select 4];
    };

    _db set [_poiId, _rec];
};

_db
