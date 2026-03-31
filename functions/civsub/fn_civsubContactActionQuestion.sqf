/*
    ARC_fnc_civsubContactActionQuestion

    Server-side: answers a player question in the CIVSUB Interact dialog.

    Params:
      0: actor (object)
      1: civ (object)
      2: payload (HashMap/array-of-pairs/array) - expects key "qid" (string)

    Returns:
      [ok(bool), html(string), payload(HashMap)]

    v1 (Phase 5):
      - Rule-driven answer model keyed to district scores + civ outlook
      - No intel logging yet (kept lightweight)
*/

if (!isServer) exitWith { [false, "", createHashMap] };
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith { [false, "", createHashMap] };

params [
    ["_actor", objNull, [objNull]],
    ["_civ", objNull, [objNull]],
    ["_payload", createHashMap, [createHashMap, []]]
];

if (isNull _actor || {isNull _civ}) exitWith { [false, "", createHashMap] };

// sqflint-compatible helpers for HashMap operations and trim
private _hg     = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _hmFrom = compile "private _pairs = _this; private _r = createHashMap; if !(_pairs isEqualType []) exitWith {_r}; { if !(_x isEqualType []) then { diag_log format ['[CIVSUB][WARN] _hmFrom skipped non-array entry type=%1', typeName _x]; } else { if ((count _x) < 2) then { diag_log format ['[CIVSUB][WARN] _hmFrom skipped short entry=%1', _x]; } else { private _k = _x select 0; if !(_k isEqualType '') then { _k = str _k; }; _r set [_k, _x select 1]; }; }; } forEach _pairs; _r";
private _trimFn = compile "params ['_s']; trim _s";

private _pl = _payload;
if !(_pl isEqualType createHashMap) then {
    if (_pl isEqualType []) then {
        if ((count _pl) > 0 && {(_pl select 0) isEqualType []}) then {
            _pl = _pl call _hmFrom;
        } else {
            if ((count _pl) >= 2) then {
                _pl = [_pl] call _hmFrom;
            } else {
                _pl = createHashMap;
            };
        };
    } else {
        _pl = createHashMap;
    };
};
if !(_pl isEqualType createHashMap) then { _pl = createHashMap; };

private _qidRaw = [_pl, "qid", ""] call _hg;
private _qid = _qidRaw;
if !(_qid isEqualType "") then { _qid = str _qid; };
_qid = [_qid] call _trimFn;

// Optional label (UI text) for tolerant routing
private _lblRaw = [_pl, "label", ""] call _hg;
private _qlabel = _lblRaw;
if !(_qlabel isEqualType "") then { _qlabel = str _qlabel; };
_qlabel = [_qlabel] call _trimFn;

if (_qid isEqualTo "") exitWith { [false, "<t size='0.9'>No question selected.</t>", createHashMap] };

/*
    Tolerant QID normalization
    - Accept canonical QIDs (Q_LIVE, Q_WORK, Q_SEEN_IED, Q_SEEN_INS, Q_OPINION_US, Q_OPINION_AREA)
    - Accept common aliases (Q_IED, Q_INSURGENT, etc.)
    - Accept label text ("Where do you live?", etc.)
*/
private _qidNorm = toUpper _qid;
private _canon = "";

switch (_qidNorm) do {
    // Canonical
    case "Q_LIVE": { _canon = "Q_LIVE"; };
    case "Q_WORK": { _canon = "Q_WORK"; };
    case "Q_SEEN_IED": { _canon = "Q_SEEN_IED"; };
    case "Q_SEEN_INS": { _canon = "Q_SEEN_INS"; };
    case "Q_OPINION_US": { _canon = "Q_OPINION_US"; };
    case "Q_OPINION_AREA": { _canon = "Q_OPINION_AREA"; };
    // UI-short QIDs (from right-pane list)
    case "Q_OP_US": { _canon = "Q_OPINION_US"; };
    case "Q_OP_AREA": { _canon = "Q_OPINION_AREA"; };

    // Aliases / historical
    case "Q_IED": { _canon = "Q_SEEN_IED"; };
    case "Q_SEEN_IEDS": { _canon = "Q_SEEN_IED"; };
    case "Q_HAVE_SEEN_IED": { _canon = "Q_SEEN_IED"; };
    case "Q_INS": { _canon = "Q_SEEN_INS"; };
    case "Q_INSURGENT": { _canon = "Q_SEEN_INS"; };
    case "Q_SEEN_INSURGENT": { _canon = "Q_SEEN_INS"; };
    case "Q_SEEN_INSURGENTS": { _canon = "Q_SEEN_INS"; };
    case "Q_OPINION": { _canon = "Q_OPINION_US"; };
    case "Q_OPINION_BLUFOR": { _canon = "Q_OPINION_US"; };
    case "Q_AREA": { _canon = "Q_OPINION_AREA"; };
    case "Q_OVERALL": { _canon = "Q_OPINION_AREA"; };

    default {
        // Try to interpret as a label string
        private _q = toLower (if (_qlabel isEqualTo "") then {_qid} else {_qlabel});
        if ((_q find "where do you live") > -1) exitWith { _canon = "Q_LIVE"; };
        if ((_q find "where do you work") > -1) exitWith { _canon = "Q_WORK"; };
        if ((_q find "ied") > -1) exitWith { _canon = "Q_SEEN_IED"; };
        if (((_q find "insurgent") > -1) || ((_q find "armed") > -1)) exitWith { _canon = "Q_SEEN_INS"; };
        if ((_q find "opinion of us") > -1) exitWith { _canon = "Q_OPINION_US"; };
        if (((_q find "overall opinion") > -1) || ((_q find "in the area") > -1)) exitWith { _canon = "Q_OPINION_AREA"; };
        _canon = "";
    };
};

if (_canon isEqualTo "") exitWith {
    [true,
        "<t size='0.95' color='#CFE8FF'>QUESTION</t><br/><t size='0.9'>I don't understand the question.</t>",
        [["qid_raw", _qid]] call _hmFrom
    ]
};

_qid = _canon;

// Identity record (if present)
private _civUid = _civ getVariable ["civ_uid", ""]; 
private _rec = createHashMap;
if (_civUid isEqualType "" && {!(_civUid isEqualTo "")}) then {
    _rec = [_civUid] call ARC_fnc_civsubIdentityGet;
    if !(_rec isEqualType createHashMap) then { _rec = createHashMap; };
};

// District state + scores
private _did = _civ getVariable ["civsub_districtId", ""]; 
if (_did isEqualTo "") then { _did = [_rec, "home_district_id", ""] call _hg; };

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if !(_districts isEqualType createHashMap) then { _districts = createHashMap; };

private _d = [_districts, _did, createHashMap] call _hg;
if !(_d isEqualType createHashMap) then { _d = createHashMap; };

private _scores = [_d] call ARC_fnc_civsubScoresCompute;
if !(_scores isEqualType createHashMap) then {
    _scores = createHashMap;
    _scores set ["S_COOP", 0];
    _scores set ["S_THREAT", 0];
};
private _Scoop   = [_scores, "S_COOP", 0] call _hg;
private _Sthreat = [_scores, "S_THREAT", 0] call _hg;

private _fear = [_d, "fear_idx", 50] call _hg;

// Civ needs/outlook (tracked by aid actions)
private _sat = _civ getVariable ["civsub_need_satiation", 50];
private _hyd = _civ getVariable ["civsub_need_hydration", 50];
private _outlook = _civ getVariable ["civsub_outlook_blufor", 50];

// Helper: nearest named location
private _locName = "around here";
private _loc = nearestLocation [getPosATL _civ, "NameVillage"];
if (isNull _loc) then { _loc = nearestLocation [getPosATL _civ, "NameCity"]; };
if (isNull _loc) then { _loc = nearestLocation [getPosATL _civ, "NameCityCapital"]; };
if (!isNull _loc) then {
    private _t = text _loc;
    private _dist = _civ distance2D (locationPosition _loc);
    if (_t isEqualType "" && {!(_t isEqualTo "")} && {_dist <= 750}) then { _locName = _t; };
};
if (_locName isEqualTo "around here" && {!(_did isEqualTo "")}) then {
    _locName = "this settlement";
};

// Tone gates
private _cooperative = (_outlook >= 60) && (_Sthreat <= 70) && (_fear <= 70);
private _guarded = (_outlook < 40) || (_Sthreat > 70) || (_fear > 75);

private _title = "QUESTION";
private _answer = "";

switch (_qid) do {
    case "Q_LIVE": {
        _title = "WHERE DO YOU LIVE";
        if (_guarded) then {
            _answer = "I live nearby. I don't want trouble.";
        } else {
            private _homeDid = [_rec, "home_district_id", _did] call _hg;
            if (_homeDid isEqualTo "") then { _homeDid = "this district"; };
            _answer = format ["I live in %1, near %2.", _homeDid, _locName];
        };
    };

    case "Q_WORK": {
        _title = "WHERE DO YOU WORK";
        private _job = [_rec, "occupation", ""] call _hg;
        if (_job isEqualTo "") then { _job = "odd jobs"; };
        if (_guarded) then {
            _answer = "I work where I can. It's hard here.";
        } else {
            _answer = format ["I work as %1, mostly around %2.", _job, _locName];
        };
    };

    case "Q_SEEN_IED": {
        _title = "IED ACTIVITY";
        if (_Sthreat < 35) then {
            _answer = "No. I haven't seen anything like that.";
        } else {
            if (_cooperative) then {
                _answer = "People talk about bombs on the roads. Avoid the main routes at night and watch for disturbed ground.";
            } else {
                _answer = "I heard rumors, but I didn't see anything myself.";
            };
        };
    };

    case "Q_SEEN_INS": {
        _title = "INSURGENT ACTIVITY";
        if (_Sthreat < 35) then {
            _answer = "No. Not recently.";
        } else {
            if (_cooperative) then {
                _answer = "I've seen armed men moving in small groups. They avoid the markets and move through the fields.";
            } else {
                _answer = "I don't know. I keep my head down.";
            };
        };
    };

    case "Q_OPINION_US": {
        _title = "OPINION OF BLUFOR";
        if (_outlook < 25) then { _answer = "Honestly? I'm angry and I'm scared. I don't trust you."; } else {
            if (_outlook < 45) then { _answer = "I'm cautious. I watch what you do before I decide anything."; } else {
                if (_outlook < 65) then { _answer = "I feel a little safer lately, but I'm still not sure about you."; } else {
                    _answer = "Personally, I appreciate the security. And the help has made a difference.";
                };
            };
        };
    };

    case "Q_OPINION_AREA": {
        _title = "AREA SENTIMENT";
        if (_Scoop < 35 || {_fear > 70}) then {
            _answer = "Most people keep quiet. They worry about retaliation.";
        } else {
            if (_Scoop < 60) then {
                _answer = "It's mixed. If you stay respectful, people cooperate.";
            } else {
                _answer = "People are more willing to talk lately. They want stability.";
            };
        };
    };

    default {
        _title = "QUESTION";
        _answer = "I don't understand the question.";
    };
};

// Needs tag (lightweight contextual tail)
private _needsTail = "";
if (_sat < 35) then { _needsTail = " My family needs food."; };
if (_hyd < 35) then { _needsTail = _needsTail + " We also need clean water."; };

// District conditions tail
private _condTail = "";
if (_Sthreat >= 70) then { _condTail = " It's dangerous right now."; };

// Intel generation: log an intel entry and optionally create a lead when the civ gives
// a cooperative, informative answer about IEDs or insurgent activity.
private _intelHtml = "";
if (_cooperative && { _Sthreat >= 35 } && { _canon in ["Q_SEEN_IED", "Q_SEEN_INS"] }) then
{
    private _civPos = getPosATL _civ;
    // Offset the lead position from the civ by 150-350 m (enough for a squad-size search area
    // without pointing exactly at the civ, which would compromise the source).
    private _jitter = 150 + floor (random 200);
    private _leadPos = _civPos getPos [_jitter, random 360];
    _leadPos resize 3;

    private _cat = if (_canon isEqualTo "Q_SEEN_IED") then { "IED" } else { "HUMINT" };
    private _leadType = if (_canon isEqualTo "Q_SEEN_IED") then { "IED" } else { "RECON" };
    private _intelSummary = format [
        "HUMINT (civilian tip): %1 in %2 (%3)",
        if (_canon isEqualTo "Q_SEEN_IED") then { "possible IED activity" } else { "armed elements sighted" },
        if (_did isEqualTo "") then { "unknown district" } else { _did },
        _locName
    ];

    [_cat, _intelSummary, _civPos,
        [
            ["qid", _canon],
            ["districtId", _did],
            ["S_COOP", _Scoop toFixed 1],
            ["S_THREAT", _Sthreat toFixed 1],
            ["source", "HUMINT_QUESTION"]
        ]
    ] call ARC_fnc_intelLog;

    // Create an actionable lead offset from the civ so field units have a grid to investigate.
    private _leadId = [
        _leadType,
        format ["HUMINT: %1 near %2", if (_canon isEqualTo "Q_SEEN_IED") then {"IED activity"} else {"insurgents"}, _locName],
        _leadPos,
        (_Sthreat / 100) min 0.85,
        1800,
        "",
        "CIVSUB",
        "",
        "CIVSUB_HUMINT"
    ] call ARC_fnc_leadCreate;

    if (_leadId isEqualType "" && { !(_leadId isEqualTo "") }) then
    {
        _intelHtml = format ["<br/><t size='0.78' color='#FFD080'>Intel logged. Lead created: %1</t>", _leadId];
    } else {
        _intelHtml = "<br/><t size='0.78' color='#FFD080'>Intel logged.</t>";
    };
};

private _html = format [
    "<t size='0.95' color='#CFE8FF'>%1</t><br/><t size='0.9'>%2%3%4</t><br/><t size='0.78' color='#A0A0A0'>D:%5  Coop:%6  Threat:%7</t>%8",
    _title,
    _answer,
    _needsTail,
    _condTail,
    if (_did isEqualTo "") then {"N/A"} else {_did},
    _Scoop toFixed 0,
    _Sthreat toFixed 0,
    _intelHtml
];

private _outPayload = [
    ["qid", _qid],
    ["qid_raw", _qidRaw],
    ["districtId", _did],
    ["S_COOP", _Scoop],
    ["S_THREAT", _Sthreat],
    ["need_satiation", _sat],
    ["need_hydration", _hyd],
    ["outlook_blufor", _outlook]
] call _hmFrom;

[true, _html, _outPayload]
