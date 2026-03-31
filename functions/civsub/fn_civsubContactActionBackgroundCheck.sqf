/*
    ARC_fnc_civsubContactActionBackgroundCheck

    HF6: harden against runtime script errors by guarding all external calls.
    - Never throws (returns INCONCLUSIVE on internal failures).
    - Emits CHECK_PAPERS (best-effort).
    - Emits CRIME_DB_HIT only on valid HIT resolution.

    Returns: [ok(bool), html(string)]
*/
if (!isServer) exitWith {[false, "<t size='0.9'>Server-only action.</t>"]};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {[false, "<t size='0.9'>CIVSUB not enabled.</t>"]};

params [
    ["_actor", objNull, [objNull]],
    ["_civ", objNull, [objNull]]
];

if (isNull _actor || {isNull _civ}) exitWith {[false, "<t size='0.9'>Invalid target.</t>"]};
if !(isPlayer _actor) exitWith {[false, "<t size='0.9'>Invalid actor.</t>"]};
if !(_civ getVariable ["civsub_v1_isCiv", false]) exitWith {[false, "<t size='0.9'>Not a CIVSUB civilian.</t>"]};

private _ensureFn = {
    params ["_name"];
    private _resolved = missionNamespace getVariable [_name, objNull];
    private _resolvedType = typeName _resolved;
    if !(_resolved isEqualType {}) then {
        diag_log format ["[CIVSUB][BG] ensureFn unresolved fn=%1 resolvedType=%2", _name, _resolvedType];
        _resolved = {};
    };
    _resolved
};

if (isNil "ARC_fnc_civsubIdentityTouch") then { ARC_fnc_civsubIdentityTouch = compile preprocessFileLineNumbers "functions\civsub\fn_civsubIdentityTouch.sqf"; };
if (isNil "ARC_fnc_civsubIdentityGenerateUid") then { ARC_fnc_civsubIdentityGenerateUid = compile preprocessFileLineNumbers "functions\civsub\fn_civsubIdentityGenerateUid.sqf"; };
if (isNil "ARC_fnc_civsubIdentityGenerateProfile") then { ARC_fnc_civsubIdentityGenerateProfile = compile preprocessFileLineNumbers "functions\civsub\fn_civsubIdentityGenerateProfile.sqf"; };
if (isNil "ARC_fnc_civsubIdentitySet") then { ARC_fnc_civsubIdentitySet = compile preprocessFileLineNumbers "functions\civsub\fn_civsubIdentitySet.sqf"; };
if (isNil "ARC_fnc_civsubIdentityEvictIfNeeded") then { ARC_fnc_civsubIdentityEvictIfNeeded = compile preprocessFileLineNumbers "functions\civsub\fn_civsubIdentityEvictIfNeeded.sqf"; };
if (isNil "ARC_fnc_civsubCrimeDbPickPoiForDistrict") then { ARC_fnc_civsubCrimeDbPickPoiForDistrict = compile preprocessFileLineNumbers "functions\civsub\fn_civsubCrimeDbPickPoiForDistrict.sqf"; };
if (isNil "ARC_fnc_civsubCrimeDbGetById") then { ARC_fnc_civsubCrimeDbGetById = compile preprocessFileLineNumbers "functions\civsub\fn_civsubCrimeDbGetById.sqf"; };
if (isNil "ARC_fnc_civsubEmitDelta") then { ARC_fnc_civsubEmitDelta = compile preprocessFileLineNumbers "functions\civsub\fn_civsubEmitDelta.sqf"; };
if (isNil "ARC_fnc_civsubScoresCompute") then { ARC_fnc_civsubScoresCompute = compile preprocessFileLineNumbers "functions\civsub\fn_civsubScoresCompute.sqf"; };
if (isNil "ARC_fnc_civsubIntelConfidence") then { ARC_fnc_civsubIntelConfidence = compile preprocessFileLineNumbers "functions\civsub\fn_civsubIntelConfidence.sqf"; };

private _setStep = {
    params ["_step"];
    _civ setVariable ["civsub_bg_lastStep", _step, false];
};

private _inconclusive = {
    params ["_serial", "_note"];
    private _s = _serial; if (_s isEqualTo "") then { _s = "UNKNOWN"; };
    private _html = format [
        "<t size='0.95' color='#CFE8FF'>BACKGROUND CHECK</t><br/>" +
        "<t size='0.9'>Result: <t color='#FFD27A'>INCONCLUSIVE</t></t><br/>" +
        "<t size='0.85'>Serial: %1</t><br/>" +
        "<t size='0.85'>Note: %2</t>",
        _s, _note
    ];
    [true, _html]
};

// sqflint-compatible helpers for HashMap operations (getOrDefault and createHashMapFromArray
// are valid SQF 3.x operators but are not recognised by the sqflint 0.3.x static analyser).
private _hg     = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k,_d]";
private _hmFrom = compile "private _pairs = _this; private _r = createHashMap; if !(_pairs isEqualType []) exitWith {_r}; { if !(_x isEqualType []) then { diag_log format ['[CIVSUB][WARN][fn_civsubContactActionBackgroundCheck] _hmFrom skipped non-array entry type=%1', typeName _x]; } else { if ((count _x) < 2) then { diag_log format ['[CIVSUB][WARN][fn_civsubContactActionBackgroundCheck] _hmFrom skipped short entry=%1', _x]; } else { private _k = _x select 0; if !(_k isEqualType '') then { _k = str _k; }; _r set [_k, _x select 1]; }; }; } forEach _pairs; _r";

["START"] call _setStep;

private _did = _civ getVariable ["civsub_districtId", ""];
if (_did isEqualTo "") exitWith {[false, "<t size='0.9'>No district ID for this civilian.</t>"]};

private _actorUid = getPlayerUID _actor;

// District lookup (hardened)
["DISTRICT_LOOKUP"] call _setStep;
private _d = createHashMap;

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];

// Tolerate legacy array-of-pairs without risking a hard script error.
if (_districts isEqualType []) then {
    private _hm = createHashMap;
    {
        if (_x isEqualType [] && {(count _x) >= 2}) then {
            _hm set [_x select 0, _x select 1];
        };
    } forEach _districts;
    _districts = _hm;
};

if !(_districts isEqualType createHashMap) exitWith { ["", "District store unavailable."] call _inconclusive };

_d = [_districts, _did, createHashMap] call _hg;

// Tolerate casing drift (D02 vs d02).
if !(_d isEqualType createHashMap) then {
    private _didL = toLower _did;
    private _didU = toUpper _did;
    _d = [_districts, _didL, createHashMap] call _hg;
    if !(_d isEqualType createHashMap) then { _d = [_districts, _didU, createHashMap] call _hg; };
};

if !(_d isEqualType createHashMap) exitWith {
    diag_log format ["[CIVSUB][BG] DISTRICT_LOOKUP miss civ=%1 did=%2 storeType=%3",
        name _civ,
        _did,
        typeName _districts
    ];
    ["", "District record unavailable."] call _inconclusive
};

// Scores (guarded)
["SCORES"] call _setStep;
private _scores = createHashMap;
_scores set ["S_COOP", 0];
_scores set ["S_THREAT", 0];
if (isNil "ARC_fnc_civsubScoresCompute") then {
    diag_log format ["[CIVSUB][ERR] BACKGROUND_CHECK: ARC_fnc_civsubScoresCompute still nil after guard. did=%1", _did];
} else {
    isNil { private _tmp = [_d] call ARC_fnc_civsubScoresCompute; if (_tmp isEqualType createHashMap) then { _scores = _tmp; }; };
};
private _Sthreat = [_scores, "S_THREAT", 0] call _hg;
if !(_Sthreat isEqualType 0) then { _Sthreat = 0; };
private _Scoop   = [_scores, "S_COOP", 0] call _hg;
if !(_Scoop isEqualType 0) then { _Scoop = 0; };

// Ensure civ UID
["IDENTITY_UID"] call _setStep;
private _civUid = _civ getVariable ["civ_uid", ""];
private _civUidGenerated = (_civUid isEqualTo "");
if (_civUidGenerated) then {
    isNil { _civUid = [_did] call ARC_fnc_civsubIdentityGenerateUid; };
};
if (_civUid isEqualTo "") exitWith { ["", "Identity UID generation failed."] call _inconclusive };
if (_civUidGenerated) then { _civ setVariable ["civ_uid", _civUid, true]; };

// Touch identity (guarded)
["IDENTITY_TOUCH"] call _setStep;
private _identityDepsOk = true;
{
    private _depName = _x select 0;
    private _fn = {};
    private _nilDep = isNil { _fn = [_depName] call _ensureFn; _fn };
    if (_nilDep || {!(_fn isEqualType {})}) then {
        _identityDepsOk = false;
        private _resolved = missionNamespace getVariable [_depName, objNull];
        diag_log format ["[CIVSUB][BG] IDENTITY_TOUCH dependency unresolved fn=%1 resolvedType=%2", _depName, typeName _resolved];
    };
} forEach [
    ["ARC_fnc_civsubIdentityTouch"],
    ["ARC_fnc_civsubIdentityGenerateProfile"],
    ["ARC_fnc_civsubIdentitySet"],
    ["ARC_fnc_civsubIdentityEvictIfNeeded"]
];

if (!_identityDepsOk) exitWith { ["", "One or more identity functions could not be resolved (IDENTITY_TOUCH)."] call _inconclusive };

private _rec = createHashMap;
private _nil = isNil { _rec = [_did, _actorUid, _civUid, getPosATL _civ] call ARC_fnc_civsubIdentityTouch; _rec };
if (_nil || {!(_rec isEqualType createHashMap)} || {(count _rec) == 0}) exitWith {
    diag_log format ["[CIVSUB][ERR] BACKGROUND_CHECK step=IDENTITY_TOUCH failed did=%1 civUid=%2 actorUid=%3 nilResult=%4 recType=%5 recCount=%6",
        _did, _civUid, _actorUid, _nil, typeName _rec, count _rec];
    ["", "Identity record unavailable."] call _inconclusive
};

private _serial = [_rec, "passport_serial", ""] call _hg;
if (_serial isEqualTo "") then { _serial = "UNKNOWN"; };

// Best-effort delta: CHECK_PAPERS
["DELTA_CHECK_PAPERS"] call _setStep;
private _payloadCheck = [
    ["passport_serial", _serial],
    ["method", "MDT"],
    ["hit", false],
    ["inconclusive", false]
] call _hmFrom;
// Guard: _hmFrom may return nil if the compiled helper is broken; ensure _payloadCheck
// is always a valid HashMap so downstream set-calls don't throw.
if (!(_payloadCheck isEqualType createHashMap)) then { _payloadCheck = createHashMap; };
isNil { [_did, "CHECK_PAPERS", "IDENTITY", _payloadCheck, _actorUid] call ARC_fnc_civsubEmitDelta; };

// HIT roll (bounded)
private _pHit = 0.02 + (0.002 * _Sthreat);
if (_pHit < 0.02) then { _pHit = 0.02; };
if (_pHit > 0.18) then { _pHit = 0.18; };

if (!((random 1) < _pHit)) exitWith {
    private _html = format [
        "<t size='0.95' color='#CFE8FF'>BACKGROUND CHECK</t><br/>" +
        "<t size='0.9'>Result: <t color='#77FF77'>NO HIT</t></t><br/>" +
        "<t size='0.85'>Serial: %1</t>",
        _serial
    ];
    [true, _html]
};

// Resolve POI (guarded)
["CRIMEDB_PICK"] call _setStep;
private _poiId = [_rec, "poi_id", ""] call _hg;
if (_poiId isEqualTo "") then {
    isNil { _poiId = [_did, false, true] call ARC_fnc_civsubCrimeDbPickPoiForDistrict; };
};
if (_poiId isEqualTo "") exitWith {
    _payloadCheck set ["inconclusive", true];
    isNil { [_did, "CHECK_PAPERS", "IDENTITY", _payloadCheck, _actorUid] call ARC_fnc_civsubEmitDelta; };
    [_serial, "Database record unavailable for this district."] call _inconclusive
};

["CRIMEDB_GET"] call _setStep;
private _poi = createHashMap;
private _nil = isNil { _poi = [_poiId] call ARC_fnc_civsubCrimeDbGetById; _poi };
if (_nil || {!(_poi isEqualType createHashMap)} || {(count _poi) == 0}) exitWith {
    _payloadCheck set ["inconclusive", true];
    isNil { [_did, "CHECK_PAPERS", "IDENTITY", _payloadCheck, _actorUid] call ARC_fnc_civsubEmitDelta; };
    [_serial, "Database record unavailable for this district."] call _inconclusive
};

// Derive hit fields (never allow wanted<=0)
["CRIMEDB_BIND"] call _setStep;
private _cat    = [_poi, "category", "Unknown"] call _hg;
private _isHvt  = [_poi, "is_hvt", false] call _hg;
private _wanted = [_poi, "wanted_level", if (_isHvt) then {3} else {2}] call _hg;
if (_wanted <= 0) then { _wanted = if (_isHvt) then {3} else {2}; };

private _issuer = [_poi, "wanted_issuing_org", ""] call _hg;
if (_issuer isEqualTo "") then {
    _issuer = if (_wanted >= 3 || {_isHvt}) then {"Coalition Watchlist"} else {"Provincial Police"};
};

private _reasonCode = [_poi, "wanted_reason_code", ""] call _hg;
private _reasonText = [_poi, "wanted_reason_text", ""] call _hg;
if (_reasonCode isEqualTo "" || {_reasonText isEqualTo ""}) then {
    private _catU = toUpper _cat;
    if (_catU find "IED" >= 0) then { _reasonCode = "IED_FACILITATION"; _reasonText = "Suspected facilitation of IED activity"; }
    else {
        if (_catU find "WEAPON" >= 0 || {_catU find "SMUGGL" >= 0}) then { _reasonCode = "WEAPONS_SMUGGLING"; _reasonText = "Suspected weapons smuggling / illegal arms possession"; }
        else {
            if (_catU find "FINANCE" >= 0 || {_catU find "LOGISTIC" >= 0}) then { _reasonCode = "FINANCE_LOGISTICS"; _reasonText = "Suspected financial/logistics support to insurgents"; }
            else {
                if (_catU find "OPS" >= 0 || {_catU find "PLANNER" >= 0}) then { _reasonCode = "OPS_PLANNING"; _reasonText = "Suspected operational planning / coordination"; }
                else { _reasonCode = "SUSPICIOUS_ACTIVITY"; _reasonText = format ["Suspicious activity (%1)", _cat]; };
            };
        };
    };
};

// Intel confidence (guarded)
["INTEL_CONF"] call _setStep;
private _intelConf = 0.5;
if (!isNil "ARC_fnc_civsubIntelConfidence") then {
    isNil { _intelConf = [_Scoop, _Sthreat] call ARC_fnc_civsubIntelConfidence; };
};
if !(_intelConf isEqualType 0) then { _intelConf = 0.5; };
private _confLabel = "MED";
if (_intelConf < 0.34) then { _confLabel = "LOW"; };
if (_intelConf > 0.66) then { _confLabel = "HIGH"; };

// Charges list
private _charges = [_rec, "charges", []] call _hg;
if !(_charges isEqualType []) then { _charges = []; };
if ((count _charges) == 0) then {
    _charges = [_reasonText, "Material support to insurgents"];
    if (_isHvt) then { _charges pushBack "High-value target"; };
};

// Persist identity (guarded)
["IDENTITY_PERSIST"] call _setStep;
_rec set ["passport_serial", _serial];
_rec set ["poi_id", _poiId];
_rec set ["wanted_level", _wanted];
_rec set ["charges", _charges];
_rec set ["wanted_issuing_org", _issuer];
_rec set ["wanted_reason_code", _reasonCode];
_rec set ["wanted_reason_text", _reasonText];
_rec set ["wanted_confidence", _intelConf];

private _flags = [_rec, "flags", []] call _hg;
if !(_flags isEqualType []) then { _flags = []; };
if ((_flags find "CRIMEDB_HIT") < 0) then { _flags pushBack "CRIMEDB_HIT"; };
_rec set ["flags", _flags];

isNil { [_civUid, _rec] call ARC_fnc_civsubIdentitySet; };

// Emit HIT delta (best-effort)
["DELTA_HIT"] call _setStep;
private _payloadHit = [
    ["passport_serial", _serial],
    ["poi_id", _poiId],
    ["wanted_level", _wanted],
    ["charges", _charges],
    ["issued_by", _issuer],
    ["reason_code", _reasonCode],
    ["reason_text", _reasonText],
    ["intel_conf", _intelConf],
    ["method", "MDT"]
] call _hmFrom;
isNil { [_did, "CRIME_DB_HIT", "IDENTITY", _payloadHit, _actorUid] call ARC_fnc_civsubEmitDelta; };

// HTML
private _chargesHtml = "";
{ _chargesHtml = _chargesHtml + format ["<br/><t size='0.85'>• %1</t>", _x]; } forEach _charges;

private _html = format [
    "<t size='0.95' color='#CFE8FF'>BACKGROUND CHECK</t><br/>" +
    "<t size='0.9'>Result: <t color='#FF7777'>HIT</t></t><br/>" +
    "<t size='0.85'>Serial: %1</t><br/>" +
    "<t size='0.85'>Wanted Level: %2</t><br/>" +
    "<t size='0.85'>Issued By: %3</t><br/>" +
    "<t size='0.85'>Reason: %4</t><br/>" +
    "<t size='0.85'>Confidence: %5</t><br/>" +
    "<t size='0.9'>Charges:</t>%6",
    _serial, _wanted, _issuer, _reasonText, _confLabel, _chargesHtml
];

[true, _html]
