/*
    Generate follow-on leads from an incident close.

    Params:
        0: STRING - result ("SUCCEEDED", "FAILED", "CANCELED")
        1: STRING - incidentType
        2: STRING - markerName (may be "")
        3: ARRAY  - position (may be [])
        4: STRING - zoneId (may be "")
        5: STRING - taskId
        6: STRING - displayName

    Returns:
        NUMBER - leads created
*/

if (!isServer) exitWith {0};

params ["_result", "_incidentType", "_marker", "_pos", "_zone", "_taskId", "_displayName"];

private _resU  = toUpper _result;
private _typeU = toUpper _incidentType;

// Only act on real outcomes
if !(_resU in ["SUCCEEDED", "FAILED"]) exitWith {0};

// Center position
private _center = [];
if (_pos isEqualType [] && { (count _pos) >= 2 }) then
{
    _center = +_pos;
    _center resize 3;
}
else
{
    if (!(_marker isEqualTo "")) then
    {
        private _m = [_marker] call ARC_fnc_worldResolveMarker;
        if (_m in allMapMarkers) then
        {
            _center = markerPos _m;
        };
    };
};

if (_center isEqualTo []) exitWith {0};

// World-state levers
private _p    = ["insurgentPressure", 0.60] call ARC_fnc_stateGet;  // 0..1
private _corr = ["corruption", 0.55] call ARC_fnc_stateGet;         // 0..1
private _inf  = ["infiltration", 0.35] call ARC_fnc_stateGet;       // 0..1

_p    = (_p max 0) min 1;
_corr = (_corr max 0) min 1;
_inf  = (_inf max 0) min 1;

// Default: no lead
private _leadType = "";
private _leadDisp = "";
private _chance   = 0;
private _strength = 0.5;
private _ttl      = 3600; // seconds
private _radius   = 700;  // search radius for "inside a building" style leads
private _avoidZones = []; // zone ids to avoid when picking a lead position

private _tag = "";

// --- Successful incident -> intel lead (slower burn) --------------------------
if (_resU isEqualTo "SUCCEEDED") then
{
    switch (_typeU) do
    {
        case "IED":
        {
            _leadType = "RAID";
            _leadDisp = "Lead: Bombmaker Safehouse";
            _chance   = 0.55 + (0.25 * _inf);
            _strength = 0.55 + (0.30 * _inf);
            _ttl      = 70 * 60;
            _radius   = 900;

            // Bombmaker safehouses inside the Green Zone / Airbase are pretty "Hollywood".
            // Keep these leads outside secure zones by default.
            _avoidZones = ["Airbase", "GreenZone"];
        };

        case "RECON":
        {
            // RECON outcomes should start mundane and only occasionally jump to a raid-safehouse.
            // Use campaign stage + local levers to diversify follow-ons.
            private _histNow = ["incidentHistory", []] call ARC_fnc_stateGet;
            private _nHist = if (_histNow isEqualType []) then { count _histNow } else { 0 };
            private _stage = (_nHist / 12) min 1;
            _stage = (_stage max 0) min 1;

            // Each option: [weight, leadType, display, chance, strength, ttlSec, radiusM, avoidZones]
            private _opts = [];
            _opts pushBack [ (1.8 * (1 - _stage)) + 0.20, "RECON", "Lead: Pattern of Life Follow-Up", 0.40 + (0.10 * _inf) + (0.05 * (1 - _p)), 0.40 + (0.15 * _inf), 60 * 60, 900, [] ];
            _opts pushBack [ (1.2 * (1 - _stage)) + (0.30 * _corr) + 0.15, "CHECKPOINT", "Lead: Vehicle of Interest", 0.35 + (0.15 * _corr), 0.45 + (0.10 * _corr), 55 * 60, 1000, [] ];
            _opts pushBack [ (1.0 * (1 - _stage)) + 0.15, "CIVIL", "Lead: Witness / Liaison Follow-Up", 0.30 + (0.10 * (1 - _corr)), 0.40 + (0.10 * (1 - _corr)), 50 * 60, 800, [] ];
            _opts pushBack [ (0.50 * _stage) + (0.40 * _p) + 0.10, "IED", "Lead: Suspected IED Team Movement", 0.25 + (0.20 * _p), 0.45 + (0.20 * _p), 55 * 60, 900, ["Airbase", "GreenZone"] ];
            _opts pushBack [ (1.20 * _stage) + (0.90 * _inf) + 0.05, "RAID", "Lead: Likely Insurgent Hideout", 0.20 + (0.35 * _inf) + (0.15 * _stage), 0.50 + (0.35 * _inf), 80 * 60, 1100, ["Airbase", "GreenZone"] ];

            private _totalW = 0;
            { _totalW = _totalW + (_x select 0); } forEach _opts;

            if (_totalW > 0) then
            {
                private _r = random _totalW;
                private _pick = _opts select 0;

                {
                    _r = _r - (_x select 0);
                    if (_r <= 0) exitWith { _pick = _x; };
                } forEach _opts;

                _leadType = _pick select 1;
                _leadDisp = _pick select 2;
                _chance   = (_pick select 3) min 0.95;
                _strength = _pick select 4;
                _ttl      = _pick select 5;
                _radius   = _pick select 6;
                _avoidZones = _pick select 7;
            };
        };

        case "PATROL":
        {
            _leadType = "RECON";
            _leadDisp = "Lead: Pattern of Life Follow-Up";
            _chance   = 0.30 + (0.15 * _inf);
            _strength = 0.40 + (0.20 * _inf);
            _ttl      = 60 * 60;
            _radius   = 900;
        };

        case "CIVIL":
        {
            // Corruption-heavy regions tend to surface checkpoint/raid-type leads.
            if (_inf > 0.55) then
            {
                _leadType = "RAID";
                _leadDisp = "Lead: Informant Tip on Insurgent Cell";
            }
            else
            {
                _leadType = "CHECKPOINT";
                _leadDisp = "Lead: Vehicle of Interest";
            };

            _chance   = 0.40 + (0.25 * _corr) + (0.10 * _inf);
            _strength = 0.45 + (0.25 * _corr);
            _ttl      = 60 * 60;
            _radius   = 800;
        };

        case "CHECKPOINT":
        {
            // Checkpoints mean very different things depending on where they are.
            // - Airbase ECPs: insider/contraband/infiltration attempts (not an IED team strolling through USAF gates).
            // - Green Zone gates: political/security screening, corruption, watchlists.
            // - Elsewhere: movement control and insurgent interdiction.

            switch (_zone) do
            {
                case "Airbase":
                {
                    if (_inf > 0.55) then
                    {
                        _leadType = "RAID";
                        _leadDisp = "Lead: Contraband / Insider Network Safehouse";
                        _chance   = 0.30 + (0.25 * _inf) + (0.10 * _corr);
                        _strength = 0.55 + (0.25 * _inf);
                        _ttl      = 60 * 60;
                        _radius   = 1400;
                    }
                    else
                    {
                        _leadType = "RECON";
                        _leadDisp = "Lead: Vehicle of Interest (Off-Base)";
                        _chance   = 0.25 + (0.20 * _corr);
                        _strength = 0.45 + (0.15 * _corr);
                        _ttl      = 45 * 60;
                        _radius   = 1600;
                    };

                    // Whatever we do next, it should not be *inside* the airbase.
                    _avoidZones = ["Airbase"];
                };

                case "GreenZone":
                {
                    if (_corr > 0.60) then
                    {
                        _leadType = "RAID";
                        _leadDisp = "Lead: Corrupt Gate Network / Courier Route";
                        _chance   = 0.30 + (0.30 * _corr) + (0.10 * _inf);
                        _strength = 0.50 + (0.25 * _corr);
                        _ttl      = 55 * 60;
                        _radius   = 1000;

                        // The racket is usually outside the cordon, not in the middle of the Green Zone.
                        _avoidZones = ["GreenZone"];
                    }
                    else
                    {
                        _leadType = "CIVIL";
                        _leadDisp = "Lead: Witness Interview / Liaison Follow-Up";
                        _chance   = 0.25 + (0.20 * (1 - _p)) + (0.10 * _inf);
                        _strength = 0.45;
                        _ttl      = 55 * 60;
                        _radius   = 700;
                    };
                };

                default
                {
                    _leadType = "IED";
                    _leadDisp = "Lead: Suspected IED Team Movement";
                    _chance   = 0.35 + (0.20 * _p);
                    _strength = 0.45 + (0.20 * _p);
                    _ttl      = 55 * 60;
                    _radius   = 900;

                    // Avoid secure zones for IED movement leads.
                    _avoidZones = ["Airbase", "GreenZone"];
                };
            };
        };

        case "RAID":
        {
            // Raids often spark retaliation; keep TTL short so it feels urgent.
            _leadType = "DEFEND";
            _leadDisp = "Lead: Retaliation Threat";
            _chance   = 0.25 + (0.35 * _p);
            _strength = 0.55 + (0.25 * _p);
            _ttl      = 35 * 60;
            _radius   = 400;
        };

        case "LOGISTICS":
        {
            _leadType = "ESCORT";
            _leadDisp = "Lead: Follow-on Resupply Convoy";

            // Only generate follow-on convoy leads when sustainment is actually hurting.
            private _f = ["baseFuel", 0.50] call ARC_fnc_stateGet;
            private _a = ["baseAmmo", 0.50] call ARC_fnc_stateGet;
            private _m = ["baseMed",  0.50] call ARC_fnc_stateGet;
            if (!(_f isEqualType 0)) then { _f = 0.50; };
            if (!(_a isEqualType 0)) then { _a = 0.50; };
            if (!(_m isEqualType 0)) then { _m = 0.50; };

            _f = (_f max 0) min 1;
            _a = (_a max 0) min 1;
            _m = (_m max 0) min 1;

            private _avg = (_f + _a + _m) / 3;
            private _need = (1 - _avg) max 0;
            _need = _need min 1;

            // If need is below this threshold, do not create a follow-on convoy lead.
            private _needMin = missionNamespace getVariable ["ARC_logisticsFollowonNeedMin", 0.55];
            if (!(_needMin isEqualType 0)) then { _needMin = 0.55; };
            _needMin = (_needMin max 0) min 1;

            if (_need < _needMin) then
            {
                _chance = 0;
            }
            else
            {
                private _t = (_need - _needMin) / ((1 - _needMin) max 0.001);
                _t = (_t max 0) min 1;

                // Range: 0.08 .. 0.40 as need increases.
                _chance = 0.08 + (0.32 * _t);
            };

            _strength = 0.45;
            _ttl      = 75 * 60;
            _radius   = 500;
        };


case "ESCORT":
        {
            _leadType = "QRF";
            _leadDisp = "Lead: Ambush Report Along MSR";
            _chance   = 0.20 + (0.35 * _p);
            _strength = 0.55 + (0.20 * _p);
            _ttl      = 40 * 60;
            _radius   = 600;
        };

        default {};
    };
};

// --- Failed incident -> urgent lead (hot) ------------------------------------
if (_resU isEqualTo "FAILED") then
{
    // If an unattended IED detonation response has already been queued for TOC review,
    // do not auto-generate a duplicate urgent follow-on lead.
    if (_typeU isEqualTo "IED") then
    {
        private _qid = ["activeIedDetonationQueueId", ""] call ARC_fnc_stateGet;
        if (_qid isEqualType "" && { !(_qid isEqualTo "") }) exitWith {0};
    };

    // Default urgent response
    _leadType = "QRF";
    _leadDisp = "Lead: Escalation / Emergency Response";
    _chance   = 0.35 + (0.35 * _p);
    _strength = 0.60 + (0.25 * _p);
    _ttl      = 25 * 60;
    _radius   = 500;

    // Airbase failures feel like base defense events.
    if (_zone isEqualTo "Airbase") then
    {
        _leadType = "DEFEND";
        _leadDisp = "Lead: Base Security Alert";
        _chance   = 0.45 + (0.35 * _p);
        _strength = 0.70 + (0.20 * _p);
        _ttl      = 20 * 60;
        _radius   = 350;
    };

    // Green Zone failures tend to generate political crises / QRF.
    if (_zone isEqualTo "GreenZone") then
    {
        _leadType = "QRF";
        _leadDisp = "Lead: Green Zone Distress Call";
        _chance   = 0.45 + (0.30 * _p) + (0.20 * _inf);
        _strength = 0.65 + (0.20 * _inf);
        _ttl      = 25 * 60;
        _radius   = 450;
    };
};

if (_leadType isEqualTo "" || { _chance <= 0 }) exitWith {0};
if ((random 1) > _chance) exitWith {0};

// Pick a lead position. For "building-style" leads, bias to enterable buildings near the action.
private _leadPos = _center;
if (_leadType in ["RAID", "IED", "CIVIL"] || { !(_avoidZones isEqualTo []) }) then
{
    _leadPos = [_center, _radius, _avoidZones] call ARC_fnc_worldPickEnterablePosNear;
};

// Clamp strength
_strength = (_strength max 0) min 1;

// Create lead
// Assign a thread/case so follow-ups evolve into something meaningful.
private _threadType = "GENERIC";

switch (toUpper _leadType) do
{
    case "IED": { _threadType = "IED_CELL"; };

    case "RAID":
    {
        if (_typeU in ["IED", "RECON"]) then { _threadType = "IED_CELL"; };
        if (_zone in ["Airbase", "GreenZone"] && { _inf > 0.50 || _corr > 0.55 }) then { _threadType = "INSIDER_NETWORK"; };
    };

    case "CHECKPOINT":
    {
        if (_zone isEqualTo "Airbase") then { _threadType = "INSIDER_NETWORK"; } else { _threadType = "SMUGGLING_RING"; };
    };

    case "CIVIL":
    {
        if (_zone isEqualTo "GreenZone" || { _corr > 0.60 } || { _inf > 0.60 }) then { _threadType = "INSIDER_NETWORK"; };
    };

    case "RECON":
    {
        if (_typeU in ["IED", "RAID"] || { _p > 0.65 }) then { _threadType = "IED_CELL"; };
    };

    default {};
};



// Tag certain leads as "suspicious" so the map representation stays approximate (circle only).
private _ld = toLower _leadDisp;
if ((_ld find "vehicle of interest") >= 0) then { _tag = "SUS_VEHICLE"; };
if ((_ld find "suspect vehicle") >= 0) then { _tag = "SUS_VEHICLE"; };
if ((_ld find "suspected") >= 0 && { _leadType isEqualTo "IED" }) then { _tag = "SUS_ACTIVITY"; };
private _threadId = [_threadType, _leadPos, _zone] call ARC_fnc_threadFindOrCreate;

private _id = [_leadType, _leadDisp, _leadPos, _strength, _ttl, _taskId, _incidentType, _threadId, _tag] call ARC_fnc_leadCreate;

if (_id isEqualTo "") exitWith {0};
1
