/*
    ARC_fnc_civsubInteractCheckPapers

    Server-side handler for Crime DB checks.

    Notes:
      - Method "SEARCH" models a non-cooperative search (requires compliance)
      - Method "MDT" models a background ID run (does NOT require compliance)

    Params:
      0: actor (object) - player who initiated
      1: civ (object)   - target civilian

    Emits:
      CHECK_PAPERS delta bundle (always when executed)
      CRIME_DB_HIT delta bundle + lead_emit (only when hit=true)
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

params [
    ["_actor", objNull, [objNull]],
    ["_civ", objNull, [objNull]],
    ["_method", "SEARCH", [""]],
    ["_requireCompliance", true, [true]]
];
if (isNull _actor || {isNull _civ}) exitWith {false};
if !(isPlayer _actor) exitWith {false};

private _methodUp = toUpper (trim _method);
if (_methodUp isEqualTo "") then { _methodUp = "SEARCH"; };
private _coop = (_methodUp isEqualTo "MDT");

private _did = _civ getVariable ["civsub_districtId", ""];
if (_did isEqualTo "") exitWith {
    ["CIVSUB: This civilian has no district id.", "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
    false
};

// Compliant state precondition (baseline): unconscious, handcuffed, or surrendering.
private _isUncon = _civ getVariable ["ACE_isUnconscious", false];
private _isCuffed = _civ getVariable ["ACE_captives_isHandcuffed", false];
private _isSurrender = captive _civ;
private _isCompliant = (_isUncon || _isCuffed || _isSurrender);
if (_requireCompliance && { !_isCompliant }) exitWith {
    ["CIVSUB: Target is not compliant (must be unconscious, handcuffed, or surrendering).", "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
    false
};


private _d = [_did] call ARC_fnc_civsubDistrictsGetById;
if (_d isEqualType []) then { _d = createHashMapFromArray _d; };
if !(_d isEqualType createHashMap) exitWith {false};

private _scores = [_d] call ARC_fnc_civsubScoresCompute;
private _Scoop = _scores getOrDefault ["S_COOP", 0];
private _Sthreat = _scores getOrDefault ["S_THREAT", 0];

private _actorUid = getPlayerUID _actor;
private _civUid = _civ getVariable ["civ_uid", ""];
if (_civUid isEqualTo "") then {
    _civUid = [_did] call ARC_fnc_civsubIdentityGenerateUid;
    _civ setVariable ["civ_uid", _civUid, true];
};

// Touch identity now (touched-only persistence)
private _rec = [_did, _actorUid, _civUid, getPosATL _civ] call ARC_fnc_civsubIdentityTouch;
if !(_rec isEqualType createHashMap) exitWith {false};

private _serial = _rec getOrDefault ["passport_serial", ""];

// Hit probability is not locked; we tie it to S_THREAT conservatively.
private _pHit = 0.02 + (0.002 * _Sthreat);
if (_pHit < 0.02) then { _pHit = 0.02; };
if (_pHit > 0.18) then { _pHit = 0.18; };

private _hit = (random 1) < _pHit;

// If we got a hit, bind this identity to a real POI record for payload fidelity.
private _poiId = "";
private _wanted = 0;
private _charges = [];

if (_hit) then
{
    _poiId = [_did, false, true] call ARC_fnc_civsubCrimeDbPickPoiForDistrict;
    if (_poiId isEqualTo "") then { _hit = false; };
    if (_hit) then {
        private _poi = [_poiId] call ARC_fnc_civsubCrimeDbGetById;
        if !(_poi isEqualType createHashMap) then { _hit = false; } else {
            // Ensure serial aligns to a DB record
            _serial = _poi getOrDefault ["passport_serial", _serial];

            private _cat = _poi getOrDefault ["category", ""]; 
            private _isHvt = _poi getOrDefault ["is_hvt", false];

            _wanted = if (_isHvt) then { 3 } else {
                if (_cat in ["IED_FACILITATOR","OPS_PLANNER"]) then { 2 } else { 1 };
            };

            _charges = [
                format ["Suspected %1", _cat],
                "Material support to insurgents"
            ];
            if (_isHvt) then { _charges pushBack "High-value target"; };

            // Update identity record (persisted) to reflect a confirmed hit.
            _rec set ["passport_serial", _serial];
            _rec set ["wanted_level", _wanted];
            _rec set ["poi_id", _poiId];
            _rec set ["charges", _charges];

            private _flags = _rec getOrDefault ["flags", []];
            if !(_flags isEqualType []) then { _flags = []; };
            if ((_flags find "CRIMEDB_HIT") < 0) then { _flags pushBack "CRIMEDB_HIT"; };
            _rec set ["flags", _flags];

            [_civUid, _rec] call ARC_fnc_civsubIdentitySet;
        };
    };
};

// Always emit CHECK_PAPERS (hit flag controls effect mapping).
private _payloadCheck = createHashMapFromArray [
    ["cooperative", _coop],
    ["method", _methodUp],
    ["passport_serial", _serial],
    ["hit", _hit]
];
[_did, "CHECK_PAPERS", "IDENTITY", _payloadCheck, _actorUid] call ARC_fnc_civsubEmitDelta;

if !(_hit) exitWith {
    [format ["CIVSUB: %1 check (%2). No hit.", _methodUp, _serial], "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
    true
};

// Emit separate CRIME_DB_HIT bundle with lead_emit contract fields.
private _payloadHit = createHashMapFromArray [
    ["passport_serial", _serial],
    ["hit", true],
    ["wanted_level", _wanted],
    ["charges", _charges]
];

if !(["CRIME_DB_HIT", _payloadHit] call ARC_fnc_civsubDeltaValidate) exitWith {false};

private _bundle = [_did, "CRIME_DB_HIT", "IDENTITY", _payloadHit, _actorUid] call ARC_fnc_civsubDeltaBuildEnvelope;
if !(_bundle isEqualType createHashMap) exitWith {false};

private _intelConf = [_Scoop, _Sthreat] call ARC_fnc_civsubIntelConfidence;
private _seed = createHashMapFromArray [
    ["subject_civ_uid", _civUid],
    ["home_pos", _rec getOrDefault ["home_pos", getPosATL _civ]],
    ["linked_network", "RED"]
];

_bundle set ["lead_emit", createHashMapFromArray [
    ["emit", true],
    ["lead_type", "LEAD_DETAIN_SUSPECT"],
    ["lead_id", ""],
    ["confidence", _intelConf],
    ["seed", _seed]
]];

// Apply to district + update lastDelta probes (mirrors ARC_fnc_civsubEmitDelta).
[_bundle] call ARC_fnc_civsubDeltaApplyToDistrict;
missionNamespace setVariable ["civsub_v1_lastDelta_id", _bundle getOrDefault ["bundle_id", ""], true];
missionNamespace setVariable ["civsub_v1_lastDelta_ts", serverTime, true];

[format ["CIVSUB: %1 HIT (%2). Wanted level %3.", _methodUp, _serial, _wanted], "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];

true