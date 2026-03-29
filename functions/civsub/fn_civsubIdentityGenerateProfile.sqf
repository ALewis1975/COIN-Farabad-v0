/*
    ARC_fnc_civsubIdentityGenerateProfile

    Generates a lightweight identity profile record for a touched civilian.
    Determinism is not required once persisted, but we use civsub_v1_seed and
    civsub_v1_identity_seq to make generation reasonably stable within a campaign.

    PH4B: Optional enrichment (district-weighted occupations + richer background)
          behind civsub_v1_enrich_enabled. Defaults to true.

    Params:
      0: civ_uid (string)
      1: districtId (string)
      2: homePos (array [x,y,z], optional)

    Returns: HashMap civ_identity_record
*/

if (!isServer) exitWith {createHashMap};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {createHashMap};

params [
    ["_civUid", "", [""]],
    ["_districtId", "", [""]],
    ["_homePos", [0,0,0], [[]]]
];

if (_civUid isEqualTo "" || { _districtId isEqualTo "" }) exitWith {createHashMap};

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
private _hg      = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _seed = missionNamespace getVariable ["civsub_v1_seed", 1337];
if !(_seed isEqualType 0) then { _seed = 1337; };
private _seq = missionNamespace getVariable ["civsub_v1_identity_seq", 1];
if !(_seq isEqualType 0) then { _seq = 1; };

private _roll = {
    params ["_m"]; // returns 0..(_m-1)
    _seed = (_seed * 1103515245 + 12345 + _seq) mod 2147483647;
    (_seed mod _m)
};

private _pad2 = {
    params ["_n"]; 
    private _s = str _n;
    if ((count _s) < 2) then { "0" + _s } else { _s };
};

private _pickWeighted = {
    params ["_arr", "_rollFn"]; // _arr: [[val,weight],...]
    private _tw = 0;
    { _tw = _tw + (_x select 1); } forEach _arr;
    if (_tw <= 0) exitWith { (_arr select 0) select 0 };
    private _r = [_tw] call _rollFn;
    private _acc = 0;
    private _out = (_arr select 0) select 0;
    {
        _acc = _acc + (_x select 1);
        if (_r < _acc) exitWith { _out = _x select 0; };
    } forEach _arr;
    _out
};

private _maleFirst = ["Ahmad","Ali","Farid","Hamid","Jamal","Karim","Latif","Omid","Rahim","Sadiq","Tariq","Yusuf"];
private _femaleFirst = ["Amina","Farah","Hala","Layla","Mariam","Nadia","Roya","Samira","Zahra","Zainab"];
private _lastNames = ["Azizi","Barakzai","Farhadi","Haqmal","Jalali","Karimi","Noori","Rahmani","Safi","Shinwari","Wardak","Yousufi"];

private _sex = if (([2] call _roll) == 0) then {"M"} else {"F"};
private _first = if (_sex isEqualTo "M") then { _maleFirst select ([count _maleFirst] call _roll) } else { _femaleFirst select ([count _femaleFirst] call _roll) };
private _last = _lastNames select ([count _lastNames] call _roll);

// Optional enrichment toggle
private _enrich = missionNamespace getVariable ["civsub_v1_enrich_enabled", true];
if !(_enrich isEqualType true) then { _enrich = true; };

// Infer a simple district archetype from pop_total (district has no name yet)
private _arch = "";
private _pop = -1;
if (_enrich) then {
    // Tolerant inline lookup (avoid external getter to prevent hard-fail chains)
    private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
    if (_districts isEqualType []) then { _districts = [_districts] call _hmCreate; };

    if (_districts isEqualType createHashMap) then {
        private _d = [_districts, _districtId, createHashMap] call _hg;
        if (!(_d isEqualType createHashMap) || {(count _d) == 0}) then { _d = [_districts, toLower _districtId, createHashMap] call _hg; };
        if (!(_d isEqualType createHashMap) || {(count _d) == 0}) then { _d = [_districts, toUpper _districtId, createHashMap] call _hg; };

        if (_d isEqualType []) then { _d = [_d] call _hmCreate; };
        if (_d isEqualType createHashMap) then {
            _pop = [_d, "pop_total", -1] call _hg;
            if !(_pop isEqualType 0) then { _pop = -1; };
        };
    };

    if (_pop >= 900) then { _arch = "URBAN"; } else {
        if (_pop >= 150) then { _arch = "TOWN"; } else { _arch = "RURAL"; };
    };
};
if (_arch isEqualTo "") then { _arch = "TOWN"; };

// Occupation pools (district-weighted) and a richer background line
private _job = "";
private _bg = "";
private _edu = "";
private _marital = "";
private _house = 1;

if (_enrich) then {
    private _jobsW = [];
    private _bgT = [];

    switch (_arch) do {
        case "URBAN": {
            _jobsW = [
                ["Clerk",18],["Shopkeeper",15],["Driver",10],["Mechanic",8],["Teacher",8],
                ["Medic",6],["Laborer",8],["Student",10],["Tailor",6],["Unemployed",11]
            ];
            _bgT = [
                "Lives in %1 and works near the market.",
                "Rents a small room in %1; picks up day labor when available.",
                "Commutes within %1 for work; keeps a low profile.",
                "Known around %1 for reliable work and routine travel."
            ];
        };
        case "RURAL": {
            _jobsW = [
                ["Farmer",28],["Laborer",16],["Driver",10],["Shopkeeper",10],["Mechanic",6],
                ["Teacher",5],["Student",10],["Carpenter",5],["Medic",2],["Unemployed",8]
            ];
            _bgT = [
                "Lives outside %1 and supports a family household.",
                "Works seasonal labor around %1.",
                "Maintains a small property near %1 and travels occasionally.",
                "Primarily stays local to %1 for work and supplies."
            ];
        };
        default {
            _jobsW = [
                ["Shopkeeper",20],["Driver",12],["Laborer",12],["Clerk",10],["Mechanic",8],
                ["Teacher",8],["Medic",4],["Tailor",6],["Student",10],["Unemployed",10]
            ];
            _bgT = [
                "Lives in %1 and works in the local bazaar.",
                "Known in %1 for steady work and routine travel.",
                "Supports a household in %1 and avoids trouble.",
                "Works local jobs in %1 and keeps to family networks."
            ];
        };
    };

    _job = [_jobsW, _roll] call _pickWeighted;

    private _bgLine = _bgT select ([count _bgT] call _roll);
    _bg = format [_bgLine, _districtId];

    // Light demographic flavor (does not drive gameplay yet)
    private _eduW = [["None",12],["Primary",40],["Secondary",30],["Higher",18]];
    _edu = [_eduW, _roll] call _pickWeighted;

    private _mW = [["Single",40],["Married",55],["Widowed",5]];
    _marital = [_mW, _roll] call _pickWeighted;

    _house = 1 + ([8] call _roll);
} else {
    private _jobs = ["Farmer","Shopkeeper","Driver","Laborer","Teacher","Clerk","Mechanic","Medic","Tailor","Carpenter","Student","Unemployed"];
    _job = _jobs select ([count _jobs] call _roll);
    _bg = format ["%1 %2 from %3.", _first, _last, _districtId];
    _edu = "";
    _marital = "";
    _house = 1;
};

// DOB 1965-2005
private _year = 1965 + ([41] call _roll);
private _month = 1 + ([12] call _roll);
private _day = 1 + ([28] call _roll);
private _dob = format ["%1-%2-%3", _year, ([_month] call _pad2), ([_day] call _pad2)];

// Passport serial format FRB-11-XXXXXX
private _serialNum = str (100000 + ([900000] call _roll));
private _serial = format ["FRB-11-%1", _serialNum];

// Expiry 2026-2031
private _expYear = 2026 + ([6] call _roll);
private _expMonth = 1 + ([12] call _roll);
private _expDay = 1 + ([28] call _roll);
private _expires = format ["%1-%2-%3", _expYear, ([_expMonth] call _pad2), ([_expDay] call _pad2)];

private _nat = "Takistan";
private _isPassport = true;

[[
    ["civ_uid", _civUid],
    ["first_name", _first],
    ["last_name", _last],
    ["sex", _sex],
    ["dob_iso", _dob],
    ["nationality", _nat],
    ["home_district_id", _districtId],
    ["home_pos", _homePos],
    ["occupation", _job],
    ["background", _bg],

    // enrichment fields (safe, optional)
    ["district_archetype", _arch],
    ["education_level", _edu],
    ["marital_status", _marital],
    ["household_size", _house],

    ["passport_serial", _serial],
    ["passport_expires_iso", _expires],
    ["passport_isPassport", _isPassport],
    ["flags", []],
    ["wanted_level", 0],

    // v1 detention pipeline fields (persisted)
    ["status_detained", false],
    ["status_detainedAt", 0],
    ["status_detainedDistrictId", ""],
    ["status_handedOff", false],
    ["status_handedOffAt", 0],
    ["status_handedOffTo", ""],
    ["status_releasedAt", 0],

    // Optional linkages for crime DB hits
    ["poi_id", ""],
    ["charges", []],

    // Optional crime narrative fields (set on hits)
    ["wanted_reason_code", ""],
    ["wanted_reason_text", ""],
    ["wanted_issuing_org", ""],
    ["wanted_confidence", 0],

    ["seen_by", createHashMap],
    ["last_interaction_ts", serverTime]
]] call _hmCreate
