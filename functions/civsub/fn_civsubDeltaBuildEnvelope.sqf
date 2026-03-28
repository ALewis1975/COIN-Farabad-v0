/*
    ARC_fnc_civsubDeltaBuildEnvelope

    Builds a CIVSUB delta bundle envelope and computes influence_delta from locked effect IDs.

    Params:
      0: districtId (string)
      1: event (string)
      2: sourceModule (string)
      3: payload (hashmap)
      4: actorUid (string)

    Returns:
      hashmap bundle
*/

params [
    ["_districtId", "", [""]],
    ["_event", "", [""]],
    ["_sourceModule", "", [""]],
    ["_payload", createHashMap, [createHashMap]],
    ["_actorUid", "", [""]]
];

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _effects = [];

switch (_event) do
{
    case "SHOW_PAPERS": { _effects = ["WHITE_TRUST_MICRO_GAIN"]; };
    case "CHECK_PAPERS":
    {
        private _hit = [_payload, "hit", false] call _hg;
        private _method = toUpper ([_payload, "method", "SEARCH"] call _hg);
        private _coop = [_payload, "cooperative", false] call _hg;

        if (_hit) then
        {
            _effects = ["GOV_LEGIT_SMALL_GAIN", "RED_DISRUPTION_SMALL"];
        }
        else
        {
            // Baseline: forced searches that come up empty cost trust.
            // MDT/cooperative checks should not penalize trust.
            if ((_method isEqualTo "MDT") || { _coop }) then
            {
                _effects = [];
            }
            else
            {
                _effects = ["WHITE_TRUST_HARD_LOSS"];
            };
        };
    };

    case "DETENTION_INIT":
    {
        // Detaining wanted suspects improves trust; detaining innocents reduces trust.
        private _wl = [_payload, "wanted_level", 0] call _hg;
        if !(_wl isEqualType 0) then { _wl = 0; };
        if (_wl > 0) then { _effects = ["WHITE_TRUST_MICRO_GAIN"]; } else { _effects = ["WHITE_TRUST_HARD_LOSS"]; };
    };
    case "DETENTION_HANDOFF":
    {
        // Handoff reinforces legitimacy when the detainee was actually wanted.
        if !(_wl isEqualType 0) then { _wl = 0; };
        if (_wl > 0) then { _effects = ["WHITE_TRUST_SMALL_GAIN"]; } else { _effects = []; };
    };
    case "CRIME_DB_HIT": { _effects = ["GOV_LEGIT_SMALL_GAIN", "RED_DISRUPTION_MED"]; };
    case "AID_WATER": { _effects = ["WHITE_TRUST_MED_GAIN"]; };
    case "AID_RATIONS": { _effects = ["WHITE_TRUST_MED_GAIN"]; };
    case "MED_AID_CIV": { _effects = ["WHITE_TRUST_SMALL_GAIN"]; };
    case "CIV_KILLED":
    {
        // Baseline distinguishes blame attribution. Payload may include attrib_side.
        private _as = toUpper ([_payload, "attrib_side", "UNKNOWN"] call _hg);
        switch (_as) do
        {
            case "BLUFOR": { _effects = ["CIV_CASUALTY_BLAME_BLUFOR"]; };
            case "OPFOR": { _effects = ["CIV_CASUALTY_BLAME_OPFOR"]; };
            default { _effects = ["CIV_CASUALTY_BLAME_UNKNOWN"]; };
        };
    };
    case "INTIMIDATION_EVENT": { _effects = ["FEAR_SPIKE"]; };
    default { _effects = []; };
};

// Effect table (locked v1)
private _effectTable = [[
    ["WHITE_TRUST_MICRO_GAIN", [0.25, -0.05, 0.10]],
    ["WHITE_TRUST_SMALL_GAIN", [1.00, -0.25, 0.25]],
    ["WHITE_TRUST_MED_GAIN", [2.00, -0.50, 0.50]],
    ["WHITE_TRUST_HARD_LOSS", [-2.50, 1.25, -0.75]],
    // Legacy key
    ["CIV_CASUALTY_LOSS", [-5.00, 2.50, -2.50]],
    // v1 attribution keys (BLUFOR matches legacy; OPFOR/UNKNOWN are intentionally lighter)
    ["CIV_CASUALTY_BLAME_BLUFOR", [-5.00, 2.50, -2.50]],
    ["CIV_CASUALTY_BLAME_OPFOR", [-1.50, 1.00, -0.50]],
    ["CIV_CASUALTY_BLAME_UNKNOWN", [-1.00, 0.75, -0.25]],
    ["GOV_LEGIT_SMALL_GAIN", [0.25, -0.25, 1.00]],
    ["RED_DISRUPTION_SMALL", [0.10, -1.00, 0.25]],
    ["RED_DISRUPTION_MED", [0.25, -2.50, 0.75]],
    ["FEAR_SPIKE", [-0.50, 0.50, -0.25]]
]] call _hmCreate;

private _dW = 0;
private _dR = 0;
private _dG = 0;

{
    private _row = [_effectTable, _x, [0,0,0]] call _hg;
    _dW = _dW + (_row select 0);
    _dR = _dR + (_row select 1);
    _dG = _dG + (_row select 2);
} forEach _effects;

private _influenceDelta = [[
    ["dW", _dW],
    ["dR", _dR],
    ["dG", _dG]
]] call _hmCreate;

private _leadEmit = [[
    ["emit", false],
    ["lead_type", ""],
    ["lead_id", ""],
    ["confidence", 0.0],
    ["seed", createHashMap]
]] call _hmCreate;

private _actorType = "AI";
if !(_actorUid isEqualTo "") then { _actorType = "PLAYER"; };

private _centroid = [0,0];
private _d = (missionNamespace getVariable ["civsub_v1_districts", createHashMap]) getOrDefault [_districtId, createHashMap];
if (_d isEqualType createHashMap) then { _centroid = [_d, "centroid", [0,0]] call _hg; };

private _bundle = [
    _districtId,
    _centroid,
    _sourceModule,
    _event,
    _payload,
    _effects,
    _influenceDelta,
    _leadEmit,
    [],
    _actorUid,
    _actorType,
    "",
    "",
    "",
    ""
] call ARC_fnc_civsubBundleMake;

_bundle
