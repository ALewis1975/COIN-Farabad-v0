/*
    Client-side: refresh diary record text from server-published snapshots.

    Data sources (missionNamespace):
      - ARC_pub_state (pairs array)
      - ARC_pub_intelLog (intel entries)
      - ARC_activeTaskId / ARC_activeIncident* (active incident info)
*/

if (!hasInterface) exitWith {false};

// Keep ARC diary tabs alive even if another script/mod rebuilds the briefing UI.
// If subjects or record handles are missing, recreate them without starting extra loops.

private _ensureSubject = {
    params ["_id", "_title", "_recVar"];
    if !(player diarySubjectExists _id) then
    {
        player createDiarySubject [_id, _title, ""];
        // Force record recreation on next ensure
        player setVariable [_recVar, diaryRecordNull];
    };
};

["ARC_OPS", "OPS", "ARC_diary_rec_ops"] call _ensureSubject;
["ARC_INTEL", "INTEL", "ARC_diary_rec_intel"] call _ensureSubject;
["ARC_SITREP", "SITREP", "ARC_diary_rec_sitrep"] call _ensureSubject;
["ARC_S1", "S-1", "ARC_diary_rec_s1"] call _ensureSubject;

// Debug inspector is controlled by a server-published flag.
private _dbgEnabled = missionNamespace getVariable ["ARC_debugInspectorEnabled", false];
if (!(_dbgEnabled isEqualType true)) then { _dbgEnabled = false; };
if (_dbgEnabled) then
{
    ["ARC_DEBUG", "DEBUG", "ARC_diary_rec_debug"] call _ensureSubject;
};

private _ensureRecord = {
    params ["_recVar", "_subject", "_title"];
    private _r = player getVariable [_recVar, diaryRecordNull];
    if (_r isEqualTo diaryRecordNull) then
    {
        _r = player createDiaryRecord [_subject, [_title, "Initializing..."]];
        player setVariable [_recVar, _r];
    };
    _r
};



private _recOps = ['ARC_diary_rec_ops', 'ARC_OPS', 'OPS Dashboard'] call _ensureRecord;
private _recIntel = ['ARC_diary_rec_intel', 'ARC_INTEL', 'Intel Feed'] call _ensureRecord;
private _recSitrep = ['ARC_diary_rec_sitrep', 'ARC_SITREP', 'SITREP'] call _ensureRecord;
private _recS1 = ['ARC_diary_rec_s1', 'ARC_S1', 'Personnel Snapshot'] call _ensureRecord;

private _recDebug = diaryRecordNull;
if (_dbgEnabled) then
{
    _recDebug = ['ARC_diary_rec_debug', 'ARC_DEBUG', 'Debug Inspector'] call _ensureRecord;
};
private _recOpord = ["ARC_diary_rec_opord", "Diary", "OPORD"] call _ensureRecord;
private _recRoles = ["ARC_diary_rec_roles", "Diary", "ROLES & CAPABILITIES"] call _ensureRecord;
private _recOrbat = ["ARC_diary_rec_orbat", "Diary", "ORBAT"] call _ensureRecord;
private _recSoI = ["ARC_diary_rec_soi", "Diary", "SOI"] call _ensureRecord;


private _pub = missionNamespace getVariable ["ARC_pub_state", []];
if (!(_pub isEqualType [])) then { _pub = []; };

private _get = {
    params ["_k", "_def"];
    private _idx = -1;
    { if ((_x select 0) isEqualTo _k) exitWith { _idx = _forEachIndex; }; } forEach _pub;
    if (_idx < 0) exitWith {_def};
    (_pub select _idx) select 1
};

private _p = ["insurgentPressure", 0.60] call _get;
private _c = ["corruption", 0.55] call _get;
private _i = ["infiltration", 0.35] call _get;

private _sent = ["civSentiment", 0.55] call _get;
private _leg  = ["govLegitimacy", 0.45] call _get;
private _cas  = ["civCasualties", 0] call _get;

private _fuel = ["baseFuel", 0.75] call _get;
private _ammo = ["baseAmmo", 0.60] call _get;
private _med  = ["baseMed",  0.80] call _get;

private _intelCount = ["intelCount", 0] call _get;
private _incidentCount = ["incidentCount", 0] call _get;

private _histTail = ["incidentHistoryTail", []] call _get;
if (!(_histTail isEqualType [])) then { _histTail = []; };

private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""];
private _disp  = missionNamespace getVariable ["ARC_activeIncidentDisplayName", ""];
private _type  = missionNamespace getVariable ["ARC_activeIncidentType", ""];
private _mkr   = missionNamespace getVariable ["ARC_activeIncidentMarker", ""];
private _posATL = missionNamespace getVariable ["ARC_activeIncidentPos", []];

private _grid = "";
if (_posATL isEqualType [] && { (count _posATL) >= 2 }) then
{
    _grid = mapGridPosition _posATL;
};

private _locLine = "";
if (!(_taskId isEqualTo "")) then
{
    if (_mkr isEqualTo "") then
    {
        _locLine = if (_grid isEqualTo "") then { "Location: (lead/pos)" } else { format ["Location (lead): %1", _grid] };
    }
    else
    {
        _locLine = format ["Marker: %1", _mkr];
    };
};

private _opsText = "";

// ACTIVE TASK (quick-glance section for field leaders)
private _zoneA = "Unzoned";
if (_taskId isEqualTo "") then
{
    // No active task.
}
else
{
    if (!(_mkr isEqualTo "")) then
    {
        _zoneA = [_mkr] call ARC_fnc_worldGetZoneForMarker;
    }
    else
    {
        if (_posATL isEqualType [] && { (count _posATL) >= 2 }) then
        {
            _zoneA = [_posATL] call ARC_fnc_worldGetZoneForPos;
        };
    };
};
if (!(_zoneA isEqualType "")) then { _zoneA = "Unzoned"; };
if (_zoneA isEqualTo "") then { _zoneA = "Unzoned"; };

private _taskingFrom = "";
private _supporting = "";
private _constraints = "";
if (!(_taskId isEqualTo "") && { !(_type isEqualTo "") }) then
{
    private _t = [_type, _zoneA] call ARC_fnc_orbatPickTasking;
    if (_t isEqualType [] && { (count _t) >= 3 }) then
    {
        _t params ["_tf", "_sup", "_con"];
        if (_tf isEqualType "") then { _taskingFrom = _tf; };
        if (_sup isEqualType "") then { _supporting = _sup; };
        if (_con isEqualType "") then { _constraints = _con; };
    };
};

private _acceptedByGrp = missionNamespace getVariable ["ARC_activeIncidentAcceptedByGroup", ""];
if (!(_acceptedByGrp isEqualType "")) then { _acceptedByGrp = ""; };
if (_acceptedByGrp isEqualTo "") then { _acceptedByGrp = "UNASSIGNED"; };

// Derive a simple execution status label for the OPS dashboard.
private _statusA = "";
private _linkupWith = "None";

if (!(_taskId isEqualTo "")) then
{
    private _accepted = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
    if (!(_accepted isEqualType true) && !(_accepted isEqualType false)) then { _accepted = false; };

    private _closeReady = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false];
    if (!(_closeReady isEqualType true) && !(_closeReady isEqualType false)) then { _closeReady = false; };

    private _sitrepSent = missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false];
    if (!(_sitrepSent isEqualType true) && !(_sitrepSent isEqualType false)) then { _sitrepSent = false; };

    private _kind = missionNamespace getVariable ["ARC_activeExecKind", ""];
    if (!(_kind isEqualType "")) then { _kind = ""; };

    private _activated = missionNamespace getVariable ["ARC_activeExecActivated", false];
    if (!(_activated isEqualType true) && !(_activated isEqualType false)) then { _activated = false; };

    private _holdReq = missionNamespace getVariable ["ARC_activeExecHoldReq", 0];
    if (!(_holdReq isEqualType 0)) then { _holdReq = 0; };

    private _holdAccum = missionNamespace getVariable ["ARC_activeExecHoldAccum", 0];
    if (!(_holdAccum isEqualType 0)) then { _holdAccum = 0; };

    _statusA = "ASSIGNED";
    if (!_accepted) then { _statusA = "ASSIGNED (NOT ACCEPTED)"; };

    if (_accepted) then
    {
        if (_closeReady) then
        {
            _statusA = if (_sitrepSent) then { "SITREP SENT" } else { "SITREP PENDING" };
        }
        else
        {
            if ((toUpper _kind) isEqualTo "CONVOY") then
            {
                _statusA = "EXECUTION (CONVOY)";
            }
            else
            {
                if (!_activated) then
                {
                    _statusA = "EN ROUTE";
                }
                else
                {
                    _statusA = "ON-OBJECTIVE";
                    if (_holdReq > 0) then
                    {
                        private _rem = (_holdReq - _holdAccum) max 0;
                        private _remMin = ceil (_rem / 60);
                        _statusA = format ["ON-OBJECTIVE (~%1 min remaining)", (_remMin max 0)];
                    };
                };
            };
        };
    };

    // Link-up unit (convoys / escorted elements)
    if ((toUpper _type) in ["LOGISTICS","ESCORT"]) then
    {
        private _got = false;

        private _nids = missionNamespace getVariable ["ARC_activeConvoyNetIds", []];
        if (_nids isEqualType [] && { (count _nids) > 0 }) then
        {
            private _leadVeh = objectFromNetId (_nids select 0);
            if (!isNull _leadVeh) then
            {
                private _drv = driver _leadVeh;
                if (isNull _drv) then { _drv = effectiveCommander _leadVeh; };

                if (!isNull _drv) then
                {
                    private _gid = groupId (group _drv);
                    if (_gid isEqualType "" && { !(_gid isEqualTo "") }) then
                    {
                        _linkupWith = _gid;
                        _got = true;
                    };
                };
            };
        };

        if (!_got) then
        {
            _linkupWith = if ((toUpper _type) isEqualTo "ESCORT" && { !(_taskingFrom isEqualTo "") }) then { _taskingFrom } else { "Friendly convoy element" };
        };
    };
};


_opsText = _opsText + "<t size='1.2'>ACTIVE TASK</t><br/>";
if (_taskId isEqualTo "") then
{
    _opsText = _opsText + "<t size='0.95' color='#A0A0A0'>No active task at this time.</t><br/><br/>";
}
else
{
    _opsText = _opsText + format [
        "<t size='1.05'>%1</t><br/>Type: %2<br/>Status: %3<br/>%4<br/>Zone: %5<br/>Task ID: %6<br/>Tasking From: %7<br/>Linking up with: %8<br/>Supported by: %9<br/>Assigned Unit: %10<br/><br/>",
        _disp, _type, _statusA, _locLine, _zoneA, _taskId, _taskingFrom, _linkupWith, _supporting, _acceptedByGrp
    ];
    if (!(_constraints isEqualTo "")) then
    {
        _opsText = _opsText + format ["<t size='0.9' color='#C0C0C0'>Constraints: %1</t><br/><br/>", _constraints];
    };
};

_opsText = _opsText + format [
"<t size='1.1'>Active Incident</t><br/>%1<br/><br/>",
if (_taskId isEqualTo "") then
{
    "None"
}
else
{
    format ["<t color='#FFD700'>%1</t><br/>Type: %2<br/>%3<br/>TaskID: %4", _disp, _type, _locLine, _taskId]
}
];

_opsText = _opsText + "<t size='1.1'>Recent Outcomes</t><br/>";
if ((count _histTail) isEqualTo 0) then
{
    _opsText = _opsText + "No completed incidents yet.<br/>";
}
else
{
    {
        _x params ["_tId", "_marker", "_tType", "_tDisp", "_res", "_created", "_closed"];
        _opsText = _opsText + format ["%1: %2 (%3) - <t color='#A0A0A0'>%4</t><br/>", _tId, _tDisp, _tType, _res];
    } forEach _histTail;
};

// -------------------------------------------------------------------
// TOC Queue (pending requests + recent decisions)
// -------------------------------------------------------------------
private _qPending = missionNamespace getVariable ["ARC_pub_queuePending", (missionNamespace getVariable ["ARC_pub_queue", []])];
private _qTail = missionNamespace getVariable ["ARC_pub_queueTail", []];
if (!(_qPending isEqualType [])) then { _qPending = []; };
if (!(_qTail isEqualType [])) then { _qTail = []; };

// Helper: pull from meta pairs
private _qMetaGet = {
    params ["_meta", "_k", "_d"];
    if (!(_meta isEqualType [])) exitWith { _d };
    private _out = _d;
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _k }) exitWith
        {
            _out = _x select 1;
        };
    } forEach _meta;
    _out
};

private _qUpdatedAt = missionNamespace getVariable ["ARC_pub_queueUpdatedAt", -1];
private _qAgeMin = -1;
if (_qUpdatedAt isEqualType 0 && { _qUpdatedAt > 0 }) then
{
    _qAgeMin = floor ((serverTime - _qUpdatedAt) / 60);
};

_opsText = _opsText + "<br/><t size='1.1'>TOC Queue</t><br/>";
if (_qAgeMin >= 0) then
{
    _opsText = _opsText + format ["Snapshot: ~%1m old<br/>", _qAgeMin];
};

// Pending
if ((count _qPending) isEqualTo 0) then
{
    _opsText = _opsText + "Pending: none<br/>";
}
else
{
    private _showN = 8;
    private _shown = 0;
    {
        if !(_x isEqualType [] && { (count _x) >= 12 }) then { continue; };
        _x params [
            "_qid",
            "_qt",
            "_qst",
            "_qkind",
            "_qfrom",
            "_qfromGroup",
            "_qfromUID",
            "_qpos",
            "_qsum",
            "_qdet",
            "_qpayload",
            "_qmeta",
            ["_qdec", []]
        ];

        private _age = 0;
        if (_qt isEqualType 0) then { _age = floor ((serverTime - _qt) / 60); };

        private _gridQ = "";
        if (_qpos isEqualType [] && { (count _qpos) >= 2 }) then { _gridQ = mapGridPosition _qpos; };

        private _zoneQ = [_qmeta, "zone", ""] call _qMetaGet;
        private _whoQ = if (_qfromGroup isEqualTo "") then { _qfrom } else { _qfromGroup };

        private _sumQ = _qsum;
        if (!(_sumQ isEqualType "")) then { _sumQ = ""; };
        if ((count _sumQ) > 64) then { _sumQ = (_sumQ select [0, 64]) + "..."; };

        _opsText = _opsText + format ["<t color='#FFD700'>%1</t> | %2 | %3m | %4 | %5 | %6<br/>", _qid, _qkind, _age, _whoQ, _zoneQ, _gridQ];
        if (!(_sumQ isEqualTo "")) then { _opsText = _opsText + format ["<t color='#A0A0A0'>%1</t><br/>", _sumQ]; };

        _shown = _shown + 1;
        if (_shown >= _showN) exitWith {};
    } forEach _qPending;

    if ((count _qPending) > _shown) then
    {
        _opsText = _opsText + format ["<t color='#A0A0A0'>(%1 more pending...)</t><br/>", (count _qPending) - _shown];
    };
};

// Recent decisions (tail)
private _decisions = [];
{
    if !(_x isEqualType [] && { (count _x) >= 13 }) then { continue; };
    private _st = _x select 2;
    if (_st isEqualType "") then
    {
        private _u = toUpper _st;
        if (_u in ["APPROVED", "REJECTED"]) then { _decisions pushBack _x; };
    };
} forEach _qTail;

if ((count _decisions) > 0) then
{
    _opsText = _opsText + "<t color='#A0A0A0'>Recent decisions:</t><br/>";
    private _n = 6;
    private _start = ((count _decisions) - _n) max 0;
    for "_i" from _start to ((count _decisions) - 1) do
    {
        private _it = _decisions select _i;
        _it params [
            "_qid",
            "_qt",
            "_qst",
            "_qkind",
            "_qfrom",
            "_qfromGroup",
            "_qfromUID",
            "_qpos",
            "_qsum",
            "_qdet",
            "_qpayload",
            "_qmeta",
            ["_qdec", []]
        ];

        private _who = if (_qfromGroup isEqualTo "") then { _qfrom } else { _qfromGroup };
        private _stU = toUpper _qst;
        private _col = if (_stU isEqualTo "APPROVED") then { "#00FF00" } else { "#FF6666" };
        _opsText = _opsText + format ["%1 | <t color='%2'>%3</t> | %4 | %5<br/>", _qid, _col, _stU, _qkind, _who];
    };
}
else
{
    _opsText = _opsText + "<t color='#A0A0A0'>Recent decisions: none</t><br/>";
};



// OPS LOG (server-side events, including player SITREPs)
private _opsLog = missionNamespace getVariable ["ARC_pub_opsLog", []];
if (!(_opsLog isEqualType [])) then { _opsLog = []; };

_opsText = _opsText + "<br/><t size='1.1'>OPS Log</t><br/>";
if ((count _opsLog) isEqualTo 0) then
{
    _opsText = _opsText + "No OPS events logged yet.<br/>";
}
else
{
    private _startOps = ((count _opsLog) - 20) max 0;
    private _sliceOps = _opsLog select [_startOps, (count _opsLog) - _startOps];

    private _metaGetOps = {
        params ["_meta", "_k", "_def"];
        if (!(_meta isEqualType [])) exitWith {_def};
        private _idx = -1;
        { if ((_x select 0) isEqualTo _k) exitWith { _idx = _forEachIndex; }; } forEach _meta;
        if (_idx < 0) exitWith {_def};
        (_meta select _idx) select 1
    };

    {
        _x params ["_iid", "_t", "_cat", "_sum", "_posATL", "_meta"];
        private _mins = round (_t / 60);

        private _grid = [_meta, "grid", ""] call _metaGetOps;
        if (_grid isEqualTo "" && {_posATL isEqualType []}) then { _grid = mapGridPosition _posATL; };

        private _event = [_meta, "event", ""] call _metaGetOps;
        if (!(_event isEqualType "")) then { _event = ""; };

        private _from = [_meta, "from", ""] call _metaGetOps;
        if (!(_from isEqualType "")) then { _from = ""; };

        private _details = [_meta, "details", ""] call _metaGetOps;
        if (!(_details isEqualType "")) then { _details = ""; };
        _details = [_details] call _trimFn;
        if (!(_details isEqualTo "")) then
        {
            _details = (_details splitString (toString [10])) joinString "<br/>";
            _details = format ["<br/><t color='#A0A0A0'>%1</t>", _details];
        };

        private _tag = if (_event isEqualTo "") then { "" } else { format [" <t color='#A0A0A0'>(%1)</t>", _event] };
        private _who = if (_from isEqualTo "") then { "" } else { format ["<br/><t color='#A0A0A0'>From: %1</t>", _from] };

        _opsText = _opsText + format [
            "%1 <t color='#A0A0A0'>(T+%2m)</t>%3<br/><t color='#A0A0A0'>Grid: %4</t>%5<br/>%6%7<br/><br/>",
            _iid,
            _mins,
            _tag,
            _grid,
            _who,
            _sum,
            _details
        ];
    } forEach _sliceOps;
};

_opsText = _opsText + "<br/><t size='1.1'>Key Metrics</t><br/>";
_opsText = _opsText + format [
"Incidents completed: %1<br/>Intel reports logged: %2<br/><br/>Insurgent pressure: %3%4<br/>Corruption: %5%6<br/>Infiltration: %7%8<br/><br/>Civ sentiment: %9%10<br/>Gov legitimacy: %11%12<br/>Civ casualties: %13<br/><br/>Base fuel: %14%15<br/>Base ammo: %16%17<br/>Base med: %18%19<br/>",
_incidentCount,
_intelCount,
round (_p * 100), "%",
round (_c * 100), "%",
round (_i * 100), "%",
round (_sent * 100), "%",
round (_leg * 100), "%",
_cas,
round (_fuel * 100), "%",
round (_ammo * 100), "%",
round (_med * 100), "%"
];


// Metric change monitor (server-sampled snapshots)
    private _snapTail = ["metricsSnapshotsTail", []] call _get;
if (!(_snapTail isEqualType [])) then { _snapTail = []; };

_opsText = _opsText + "<br/><t size='1.1'>Metric Change Monitor</t><br/>";
if ((count _snapTail) < 2) then
{
    _opsText = _opsText + "No metric deltas yet. First sample seeds baseline; next sample shows change.<br/>";
}
else
{
    private _pairGet = {
        params ["_pairs", "_k", "_def"];
        if (!(_pairs isEqualType [])) exitWith { _def };
        private _idx = -1;
        { if ((_x select 0) isEqualTo _k) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
        if (_idx < 0) exitWith { _def };
        (_pairs select _idx) select 1
    };

    private _fmtPctDelta = {
        params ["_d"];
        if (!(_d isEqualType 0)) exitWith { "0%" };
        private _p = round (_d * 100);
        private _s = if (_p > 0) then { "+" } else { "" };
        format ["%1%2%3", _s, _p, "%"]
    };

    private _fmtIntDelta = {
        params ["_d"];
        if (!(_d isEqualType 0)) exitWith { "0" };
        private _v = round _d;
        private _s = if (_v > 0) then { "+" } else { "" };
        format ["%1%2", _s, _v]
    };

    private _n = count _snapTail;
    private _maxLines = 4;
    private _startIdx = ((_n - _maxLines) max 1);
    for "_i" from _startIdx to (_n - 1) do
    {
        private _a = _snapTail select (_i - 1);
        private _b = _snapTail select _i;
        if (!(_a isEqualType []) || { !(_b isEqualType []) } || { (count _a) < 2 } || { (count _b) < 2 }) then { continue; };
        private _tB = _b select 0;
        private _minsB = round (_tB / 60);
        private _pA = _a select 1;
        private _pB = _b select 1;

        private _dPress = ([_pB, "insurgentPressure", 0] call _pairGet) - ([_pA, "insurgentPressure", 0] call _pairGet);
        private _dSent  = ([_pB, "civSentiment", 0] call _pairGet) - ([_pA, "civSentiment", 0] call _pairGet);
        private _dLeg   = ([_pB, "govLegitimacy", 0] call _pairGet) - ([_pA, "govLegitimacy", 0] call _pairGet);
        private _dCorr  = ([_pB, "corruption", 0] call _pairGet) - ([_pA, "corruption", 0] call _pairGet);
        private _dInf   = ([_pB, "infiltration", 0] call _pairGet) - ([_pA, "infiltration", 0] call _pairGet);
        private _dFuel  = ([_pB, "baseFuel", 0] call _pairGet) - ([_pA, "baseFuel", 0] call _pairGet);
        private _dAmmo  = ([_pB, "baseAmmo", 0] call _pairGet) - ([_pA, "baseAmmo", 0] call _pairGet);
        private _dMed   = ([_pB, "baseMed", 0] call _pairGet) - ([_pA, "baseMed", 0] call _pairGet);
        private _dCas   = ([_pB, "civCasualties", 0] call _pairGet) - ([_pA, "civCasualties", 0] call _pairGet);

        _opsText = _opsText + format [
            "T+%1m: Pressure %2 | Sentiment %3 | Legitimacy %4 | Corruption %5 | Infil %6<br/>Fuel %7 | Ammo %8 | Med %9 | CivCas %10<br/>",
            _minsB,
            [_dPress] call _fmtPctDelta,
            [_dSent] call _fmtPctDelta,
            [_dLeg] call _fmtPctDelta,
            [_dCorr] call _fmtPctDelta,
            [_dInf] call _fmtPctDelta,
            [_dFuel] call _fmtPctDelta,
            [_dAmmo] call _fmtPctDelta,
            [_dMed] call _fmtPctDelta,
            [_dCas] call _fmtIntDelta
        ];
    };
};

// INTEL
private _intelLog = missionNamespace getVariable ["ARC_pub_intelLog", []];
if (!(_intelLog isEqualType [])) then { _intelLog = []; };

private _leadPoolPub = missionNamespace getVariable ["ARC_leadPoolPublic", []];
if (!(_leadPoolPub isEqualType [])) then { _leadPoolPub = []; };
private _intelText = "<t size='1.1'>Intel Feed</t><br/>";

// Lead pool visibility (what the TOC can turn into tasks/orders)
_intelText = _intelText + "<t size='1.1'>Lead Pool</t><br/>";
if ((count _leadPoolPub) isEqualTo 0) then
{
    _intelText = _intelText + "None<br/>";
}
else
{
    _intelText = _intelText + format ["Available: %1<br/>", count _leadPoolPub];
    private _showN = 10;
    private _shown = 0;
    {
        if !(_x isEqualType [] && { (count _x) >= 11 }) then { continue; };
        _x params [
            "_lid",
            "_lType",
            "_lDisp",
            "_lPos",
            ["_lStrength", 0.5],
            ["_lCreated", -1],
            ["_lExpires", -1],
            ["_lSourceTask", ""],
            ["_lSourceType", ""],
            ["_lThread", ""],
            ["_lTag", ""]
        ];

        private _gridL = "";
        if (_lPos isEqualType [] && { (count _lPos) >= 2 }) then { _gridL = mapGridPosition _lPos; };

        private _zoneL = "";
        if (!isNil "ARC_fnc_worldGetZoneForPos" && { _lPos isEqualType [] && { (count _lPos) >= 2 } }) then
        {
            _zoneL = [_lPos] call ARC_fnc_worldGetZoneForPos;
        };
        if (_zoneL isEqualTo "") then { _zoneL = "Unzoned"; };

        private _ttlMin = -1;
        if (_lExpires isEqualType 0 && { _lExpires > 0 }) then
        {
            _ttlMin = floor ((_lExpires - serverTime) / 60);
        };

        private _tagTxt = "";
        if (_lTag isEqualType "" && { !(_lTag isEqualTo "") }) then
        {
            _tagTxt = format [" <t color='#A0A0A0'>[%1]</t>", _lTag];
        };

        private _ttlTxt = "";
        if (_ttlMin >= 0) then
        {
            _ttlTxt = format [" <t color='#A0A0A0'>(~%1m)</t>", _ttlMin max 0];
        };

        _intelText = _intelText + format ["<t color='#FFD700'>%1</t> | %2%3%4 | %5 | %6<br/>", _lid, _lType, _tagTxt, _ttlTxt, _zoneL, _gridL];

        _shown = _shown + 1;
        if (_shown >= _showN) exitWith {};
    } forEach _leadPoolPub;

    if ((count _leadPoolPub) > _shown) then
    {
        _intelText = _intelText + format ["<t color='#A0A0A0'>(%1 more leads...)</t><br/>", (count _leadPoolPub) - _shown];
    };
};

_intelText = _intelText + "<br/><t size='1.1'>Latest Intel</t><br/>";
if ((count _intelLog) isEqualTo 0) then
{
    _intelText = _intelText + "No intel logged yet.<br/>";
}
else
{
    private _start = ((count _intelLog) - 20) max 0;
    private _slice = _intelLog select [_start, (count _intelLog) - _start];

    private _metaGet = {
        params ["_meta", "_k", "_def"];
        if (!(_meta isEqualType [])) exitWith {_def};
        private _idx = -1;
        { if ((_x select 0) isEqualTo _k) exitWith { _idx = _forEachIndex; }; } forEach _meta;
        if (_idx < 0) exitWith {_def};
        (_meta select _idx) select 1
    };

    {
        _x params ["_iid", "_t", "_cat", "_sum", "_posATL", "_meta"];
        private _mins = round (_t / 60);

        private _grid = [_meta, "grid", ""] call _metaGet;
        if (_grid isEqualTo "" && {_posATL isEqualType []}) then { _grid = mapGridPosition _posATL; };

        private _zone = [_meta, "zone", ""] call _metaGet;
        if (_zone isEqualTo "") then { _zone = "Unzoned"; };

        private _conf = [_meta, "confidence", ""] call _metaGet;
        private _confTxt = if (_conf isEqualTo "") then { "" } else { format [" <t color='#A0A0A0'>(%1)</t>", _conf] };

        private _details = [_meta, "details", ""] call _metaGet;
        if (!(_details isEqualType "")) then { _details = ""; };
        _details = [_details] call _trimFn;
        if (!(_details isEqualTo "")) then
        {
            // Convert any newline characters to <br/> for structured text output
            _details = (_details splitString (toString [10])) joinString "<br/>";
            _details = format ["<br/><t color='#A0A0A0'>%1</t>", _details];
        };

        _intelText = _intelText + format [
            "%1 <t color='#A0A0A0'>(%2, T+%3m)</t>%4<br/><t color='#A0A0A0'>Grid: %5 | Zone: %6</t><br/>%7%8<br/><br/>",
            _iid,
            _cat,
            _mins,
            _confTxt,
            _grid,
            _zone,
            _sum,
            _details
        ];
    } forEach _slice;
};

// SITREP
private _sitrepText = "";
_sitrepText = _sitrepText + "<t size='1.2'>JOINT BASE FARABAD SITREP</t><br/><br/>";
_sitrepText = _sitrepText + format ["Active incident: %1<br/><br/>", if (_taskId isEqualTo "") then {"None"} else {_disp}];
_sitrepText = _sitrepText + format [
"Pressure: %1%2 | Sentiment: %3%4 | Legitimacy: %5%6<br/>Base: Fuel %7%8, Ammo %9%10, Med %11%12<br/>Incidents: %13 | Intel: %14<br/><br/>",
round (_p * 100), "%",
round (_sent * 100), "%",
round (_leg * 100), "%",
round (_fuel * 100), "%",
round (_ammo * 100), "%",
round (_med * 100), "%",
_incidentCount,
_intelCount
];
_sitrepText = _sitrepText + "See ARC OPS and ARC Intel for details.<br/>";


/*
    BRIEFING (Diary): OPORD + ORBAT records

    These are briefing entries under the default "Diary" subject.
    They are maintained here so they survive other scripts/mods rebuilding diary subjects.
*/

private _sitrepRad = missionNamespace getVariable ["ARC_sitrepProximityM", 350];
if !(_sitrepRad isEqualType 0) then { _sitrepRad = 350; };

private _convoySpawnInt = missionNamespace getVariable ["ARC_convoySpawnIntervalSec", 5];
if !(_convoySpawnInt isEqualType 0) then { _convoySpawnInt = 5; };

private _opordText = "";
_opordText = _opordText + "<t size='1.2'>OPORD</t><br/>";
_opordText = _opordText + "<t color='#A0A0A0'>Farabad AO (2011) — COIN</t><br/><br/>";

_opordText = _opordText + "<t size='1.05'>1. Situation</t><br/>";
_opordText = _opordText + "Insurgent activity varies by zone. Host-nation security forces exist but effectiveness varies. Civilian dynamics drive the information environment.<br/><br/>";

_opordText = _opordText + "<t size='1.05'>2. Mission</t><br/>";
_opordText = _opordText + "TF REDFALCON conducts persistent COIN operations in the Farabad AO to reduce insurgent pressure, improve host-nation legitimacy, and protect the population.<br/><br/>";

_opordText = _opordText + "<t size='1.05'>3. Execution</t><br/>";
_opordText = _opordText + "a. Tasking: Accept incidents through the TOC workflow.<br/>";
_opordText = _opordText + format ["b. SITREPs: Authorized roles may send SITREPs only when within %1m of the active task/lead (or convoy/lead anchors).<br/>", _sitrepRad];
_opordText = _opordText + "c. Logging: The unit accepting the incident and the unit sending the SITREP are logged separately; they can differ if the SITREP sender is near the action.<br/><br/>";

_opordText = _opordText + "<t size='1.05'>4. Sustainment</t><br/>";
_opordText = _opordText + "Base supply levels and COIN metrics update continuously. Convoys may be tasked to restore sustainment or move assets.<br/><br/>";

_opordText = _opordText + "<t size='1.05'>5. Command &amp; Signal</t><br/>";
_opordText = _opordText + "Use ORBAT for callsigns and relationships. Use OPS / INTEL / SITREP tabs for live operational data.<br/>";
_opordText = _opordText + format ["Convoy spawn interval (server target): %1 seconds between vehicles.<br/>", _convoySpawnInt];

private _soiText = "";
_soiText = _soiText + "<t size='1.2'>Signal Operating Instructions</t><br/>";
_soiText = _soiText + "<t color='#A0A0A0'>ACRE2 preset plan. Use this as a quick reference; see docs/Signal Operating Instructions.md for full PRC-343 block mapping.</t><br/><br/>";

_soiText = _soiText + "<t size='1.05'>PRC-117F channels</t><br/>";
_soiText = _soiText + "001 BCT CMD FALCON<br/>";
_soiText = _soiText + "002 TF CMD REDFALCON<br/>";
_soiText = _soiText + "003 BN CMD 2-325 AIR<br/>";
_soiText = _soiText + "004 A CO CMD REDFALCON 1<br/>";
_soiText = _soiText + "005 B CO CMD REDFALCON 2<br/>";
_soiText = _soiText + "006 C CO CMD REDFALCON 3<br/>";
_soiText = _soiText + "007 WPN CO CMD REDFALCON 4<br/>";
_soiText = _soiText + "008 CAV SQDN CMD THUNDER<br/><br/>";

_soiText = _soiText + "041 FIRES CMD BLACKFALCON<br/>";
_soiText = _soiText + "042 FIRES FDC BLACKFALCON FDC<br/>";
_soiText = _soiText + "043 ISR UAS OPS SHADOW<br/><br/>";

_soiText = _soiText + "050 AVIATION CMD PEGASUS<br/>";
_soiText = _soiText + "051 AIR-GROUND JTAC RAVEN<br/>";
_soiText = _soiText + "052 MEDEVAC AIR DUSTOFF<br/>";
_soiText = _soiText + "090 EMERGENCY GUARD<br/><br/>";

_soiText = _soiText + "060 MP CMD SHERIFF<br/>";
_soiText = _soiText + "070 BSB CMD GRIFFIN<br/><br/>";

_soiText = _soiText + "080 USAF BASE CMD REDTAIL<br/>";
_soiText = _soiText + "081 USAF SECFO CMD SENTRY<br/>";
_soiText = _soiText + "084 FARABAD TOWER<br/>";
_soiText = _soiText + "085 FARABAD GROUND<br/>";
_soiText = _soiText + "086 FARABAD APPROACH<br/><br/>";

_soiText = _soiText + "<t size='1.05'>PRC-152 channels</t><br/>";
_soiText = _soiText + "Charlie: 010 1PLT | 011 2PLT | 012 3PLT<br/>";
_soiText = _soiText + "Bravo: 020 1PLT | 021 2PLT | 022 3PLT<br/>";
_soiText = _soiText + "Alpha: 030 1PLT | 031 2PLT | 032 3PLT<br/>";
_soiText = _soiText + "WPN: 040 2-325 TAC<br/>";
_soiText = _soiText + "THUNDER: 050/051/052 A/B/C TAC<br/>";
_soiText = _soiText + "SHERIFF: 060 TAC<br/>";
_soiText = _soiText + "GRIFFIN: 070 CONVOY TAC<br/>";
_soiText = _soiText + "SENTRY: 080 TAC<br/><br/>";

_soiText = _soiText + "<t size='1.05'>PRC-343 channel buckets (1-16)</t><br/>";
_soiText = _soiText + "1 C 1PLT | 2 C 2PLT | 3 C 3PLT<br/>";
_soiText = _soiText + "4 B 1PLT | 5 B 2PLT | 6 B 3PLT<br/>";
_soiText = _soiText + "7 A 1PLT | 8 A 2PLT | 9 A 3PLT<br/>";
_soiText = _soiText + "10 WPN sections | 11 THUNDER A | 12 THUNDER B | 13 THUNDER C<br/>";
_soiText = _soiText + "14 SHERIFF MP | 15 GRIFFIN convoys | 16 SENTRY SECFO<br/><br/>";

_soiText = _soiText + "<t color='#A0A0A0'>PRC-343 default blocks: BLK1 squad net, BLK2/3 Team A/B, BLK4+ additional squads/weapons. Full block callsign mapping is in the SOI doc.</t><br/>";


private _rolesText = "";
_rolesText = _rolesText + "<t size='1.2'>ROLES &amp; MISSION CAPABILITIES</t><br/>";
_rolesText = _rolesText + "<t color='#A0A0A0'>Quick reference for who does what, and who can drive the mission tasking loop.</t><br/><br/>";

_rolesText = _rolesText + "<t size='1.05'>1) Ops Control / TOC (FALCON/REDFALCON TOC)</t><br/>";
_rolesText = _rolesText + "Primary function: maintain tempo and intent — validate requests, assign tasks, and control follow-ons.<br/>";
_rolesText = _rolesText + "Mission capabilities:<br/>";
_rolesText = _rolesText + "- Monitor <t color='#FFD700'>ARC OPS</t> (active task, TOC queue, decisions, OPS log).<br/>";
_rolesText = _rolesText + "- Monitor <t color='#FFD700'>ARC INTEL</t> (lead pool + intel feed) and convert leads into tasking.<br/>";
_rolesText = _rolesText + "- Issue follow-ons after completion / SITREP: RTB / HOLD / PROCEED.<br/><br/>";

_rolesText = _rolesText + "<t size='1.05'>2) Maneuver Leadership (CO/XO/1SG/PL/PSG/SL)</t><br/>";
_rolesText = _rolesText + "Primary function: execute assigned tasks, manage risk, and close the loop with accurate reporting.<br/>";
_rolesText = _rolesText + "Mission capabilities:<br/>";
_rolesText = _rolesText + "- Accept incidents/tasks through the TOC workflow.<br/>";
_rolesText = _rolesText + format ["- Submit SITREPs when authorized and within %1m of the active task/lead (or convoy/lead anchors).<br/>", _sitrepRad];
_rolesText = _rolesText + "- Provide the TOC: outcome, ACE/LACE, enemy situation (SALUTE if relevant), and requests (MEDEVAC/QRF/resupply).<br/><br/>";

_rolesText = _rolesText + "<t size='1.05'>3) Specialists (RTO / Medic / FO-JTAC / MP / ISR / Aviation / Sustainment)</t><br/>";
_rolesText = _rolesText + "Primary function: enable maneuver and increase reporting quality.<br/>";
_rolesText = _rolesText + "Typical contributions:<br/>";
_rolesText = _rolesText + "- RTO: comms discipline, grids/markers, message formatting; keeps the leader synced with TOC intent.<br/>";
_rolesText = _rolesText + "- Medic: casualty triage, evacuation decisions; feeds status into SITREP (ACE/LACE + CASEVAC).<br/>";
_rolesText = _rolesText + "- FO/JTAC: fires/CAS integration, deconfliction, BDA; supports precision and reduced collateral.<br/>";
_rolesText = _rolesText + "- MPs: detainee handling and security tasks; supports SSE/evidence narrative as needed.<br/>";
_rolesText = _rolesText + "- ISR (SHADOW) / Aviation (PEGASUS/DUSTOFF) / Sustainment (GRIFFIN): improve reach, tempo, and survivability.<br/><br/>";

_rolesText = _rolesText + "<t size='1.05'>4) Everyone</t><br/>";
_rolesText = _rolesText + "Primary function: generate useful information, protect the population, and support the leader’s decision cycle.<br/>";
_rolesText = _rolesText + "Use the live tabs for situational awareness:<br/>";
_rolesText = _rolesText + "- <t color='#FFD700'>ARC OPS</t>: what is happening right now (active task + TOC queue).<br/>";
_rolesText = _rolesText + "- <t color='#FFD700'>ARC INTEL</t>: what we know (lead pool + latest reports).<br/>";
_rolesText = _rolesText + "- <t color='#FFD700'>ARC SITREP</t>: quick status snapshot for the AO/base.<br/><br/>";

_rolesText = _rolesText + "<t color='#A0A0A0'>Note: if you are not in an authorized leadership slot, you may not see task-accept or SITREP actions.</t><br/>";


private _orbatText = "";
_orbatText = _orbatText + "<t size='1.2'>ORBAT</t><br/>";
_orbatText = _orbatText + "<t size='1.05'>BLUFOR</t><br/>";
_orbatText = _orbatText + "FALCON (2BCT HQ) | REDFALCON (2-325 AIR) | THUNDER (1-73 CAV) | SHADOW (UAS) | SHERIFF (MP) | BLACKFALCON (Fires) | GRIFFIN (BSB / CONVOY) | PEGASUS (CAB) | REDTAIL (USAF host wing)<br/><br/>";
_orbatText = _orbatText + "<t size='1.05'>Host Nation / Civil</t><br/>";
_orbatText = _orbatText + "TNP (Takistan National Police) | TNA (Takistan National Army) | SHURA (local councils)<br/><br/>";
_orbatText = _orbatText + "<t size='1.05'>OPFOR</t><br/>";
_orbatText = _orbatText + "TIM insurgent network (cells: IED, guerrilla attack, urban support).<br/><br/>";

_orbatText = _orbatText + "<t size='1.05'>Active Incident</t><br/>";
_orbatText = _orbatText + format ["%1<br/>", if (_taskId isEqualTo "") then {"None"} else {format ["%1 (%2)", _disp, _type]}];

// --- Debug inspector ---------------------------------------------------------
private _dbgText = "";
if (_dbgEnabled) then
{
    private _dbgPub = missionNamespace getVariable ["ARC_pub_debug", []];
    if (!(_dbgPub isEqualType [])) then { _dbgPub = []; };

    private _getDbg = {
        params ["_k", "_def"];
        private _idx = -1;
        { if ((_x select 0) isEqualTo _k) exitWith { _idx = _forEachIndex; }; } forEach _dbgPub;
        if (_idx < 0) exitWith { _def };
        (_dbgPub select _idx) select 1
    };

    // Server publishes this using serverTime; treat as display/change token, not wall-clock age.
    private _dbgAt = missionNamespace getVariable ["ARC_pub_debugUpdatedAt", -1];
    if (!(_dbgAt isEqualType 0)) then { _dbgAt = -1; };

    private _cap = ["netIdCap", 25] call _getDbg;
    if (!(_cap isEqualType 0)) then { _cap = 25; };

    private _cleanupCount = ["cleanupCount", 0] call _getDbg;
    if (!(_cleanupCount isEqualType 0)) then { _cleanupCount = 0; };

    private _cleanupByLabel = ["cleanupByLabel", []] call _getDbg;
    if (!(_cleanupByLabel isEqualType [])) then { _cleanupByLabel = []; };

    private _convoyCount = ["activeConvoyCount", 0] call _getDbg;
    if (!(_convoyCount isEqualType 0)) then { _convoyCount = 0; };
    private _convoyNids = ["activeConvoyNetIds", []] call _getDbg;
    if (!(_convoyNids isEqualType [])) then { _convoyNids = []; };

    private _localCount = ["activeLocalSupportCount", 0] call _getDbg;
    if (!(_localCount isEqualType 0)) then { _localCount = 0; };
    private _localNids = ["activeLocalSupportNetIds", []] call _getDbg;
    if (!(_localNids isEqualType [])) then { _localNids = []; };

    private _routeCount = ["activeRouteSupportCount", 0] call _getDbg;
    if (!(_routeCount isEqualType 0)) then { _routeCount = 0; };
    private _routeNids = ["activeRouteSupportNetIds", []] call _getDbg;
    if (!(_routeNids isEqualType [])) then { _routeNids = []; };

    private _cpCount = ["persistentCheckpointCount", 0] call _getDbg;
    if (!(_cpCount isEqualType 0)) then { _cpCount = 0; };
    private _cpNids = ["persistentCheckpointNetIds", []] call _getDbg;
    if (!(_cpNids isEqualType [])) then { _cpNids = []; };

    private _spawnContacts = missionNamespace getVariable ["ARC_patrolSpawnContactsEnabled", false];
    if (!(_spawnContacts isEqualType true)) then { _spawnContacts = false; };

    private _cleanupRadius = missionNamespace getVariable ["ARC_cleanupRadiusM", 1000];
    if (!(_cleanupRadius isEqualType 0)) then { _cleanupRadius = 1000; };

    // Active incident state (client-side mirror vars)
    private _accepted = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
    if (!(_accepted isEqualType true)) then { _accepted = false; };

    private _closeReady = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false];
    if (!(_closeReady isEqualType true)) then { _closeReady = false; };

    private _sitrepSent = missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false];
    if (!(_sitrepSent isEqualType true)) then { _sitrepSent = false; };

    // Active exec state
    private _kind = missionNamespace getVariable ["ARC_activeExecKind", ""];
    if (!(_kind isEqualType "")) then { _kind = ""; };

    private _activated = missionNamespace getVariable ["ARC_activeExecActivated", false];
    if (!(_activated isEqualType true)) then { _activated = false; };

    private _holdReq = missionNamespace getVariable ["ARC_activeExecHoldReq", 0];
    if (!(_holdReq isEqualType 0)) then { _holdReq = 0; };

    private _holdAccum = missionNamespace getVariable ["ARC_activeExecHoldAccum", 0];
    if (!(_holdAccum isEqualType 0)) then { _holdAccum = 0; };

    _dbgText = _dbgText + "<t size='1.2'>Debug Inspector</t><br/>";
    _dbgText = _dbgText + format ["Updated: %1<br/><br/>", if (_dbgAt < 0) then {"(no data)"} else {format ["%1s", floor _dbgAt]}];

    _dbgText = _dbgText + "<t size='1.05'>Active incident</t><br/>";
    _dbgText = _dbgText + format ["TaskId: %1<br/>", if (_taskId isEqualTo "") then {"(none)"} else {_taskId}];
    _dbgText = _dbgText + format ["Type: %1<br/>", if (_type isEqualTo "") then {"(unknown)"} else {_type}];
    _dbgText = _dbgText + format ["Accepted: %1 (by %2)<br/>", _accepted, _acceptedByGrp];
    _dbgText = _dbgText + format ["Close-ready: %1<br/>", _closeReady];
    _dbgText = _dbgText + format ["SITREP sent: %1<br/><br/>", _sitrepSent];

    _dbgText = _dbgText + "<t size='1.05'>Exec</t><br/>";
    _dbgText = _dbgText + format ["Kind: %1<br/>", if (_kind isEqualTo "") then {"(none)"} else {_kind}];
    _dbgText = _dbgText + format ["Activated: %1<br/>", _activated];
    _dbgText = _dbgText + format ["Hold: %1/%2<br/><br/>", _holdAccum, _holdReq];

    _dbgText = _dbgText + "<t size='1.05'>Toggles</t><br/>";
    _dbgText = _dbgText + format ["Patrol contacts enabled: %1<br/>", _spawnContacts];
    _dbgText = _dbgText + format ["Cleanup radius (m): %1<br/><br/>", _cleanupRadius];

    _dbgText = _dbgText + "<t size='1.05'>Persistent netId arrays</t><br/>";
    private _fmtArr = {
        params ["_label", "_countTotal", "_arr"];
        private _shown = count _arr;
        private _suffix = "";
        if (_countTotal > _shown) then { _suffix = format [" (showing %1 of %2)", _shown, _countTotal]; };
        format ["%1: %2%3<br/>%4<br/><br/>", _label, _countTotal, _suffix, str _arr]
    };

    _dbgText = _dbgText + (["Convoy", _convoyCount, _convoyNids] call _fmtArr);
    _dbgText = _dbgText + (["Local support", _localCount, _localNids] call _fmtArr);
    _dbgText = _dbgText + (["Route support", _routeCount, _routeNids] call _fmtArr);
    _dbgText = _dbgText + (["Checkpoint props", _cpCount, _cpNids] call _fmtArr);

    _dbgText = _dbgText + "<t size='1.05'>Cleanup queue</t><br/>";
    _dbgText = _dbgText + format ["Queued entities: %1<br/>", _cleanupCount];

    if ((count _cleanupByLabel) > 0) then
    {
        _dbgText = _dbgText + "<br/><t size='1.0'>By label (grouped)</t><br/>";
        {
            if (_x isEqualType [] && { (count _x) >= 2 }) then
            {
                _x params ["_lbl", "_cnt"];
                if (!(_lbl isEqualType "")) then { _lbl = ""; };
                if (!(_cnt isEqualType 0)) then { _cnt = 0; };
                _dbgText = _dbgText + format ["%1: %2<br/>", _lbl, _cnt];
            };
        } forEach _cleanupByLabel;
    };
};


private _s1Registry = missionNamespace getVariable ["ARC_pub_s1_registry", []];
if (!(_s1Registry isEqualType [])) then { _s1Registry = []; };
private _s1UpdatedAt = missionNamespace getVariable ["ARC_pub_s1_registryUpdatedAt", -1];
if (!(_s1UpdatedAt isEqualType 0)) then { _s1UpdatedAt = -1; };
private _s1Get = {
    params ["_pairs", "_key", "_default"];

// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
    if (!(_pairs isEqualType [])) exitWith { _default };
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x select 0) isEqualTo _key) }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
    if (_idx < 0) exitWith { _default };
    (_pairs select _idx) select 1
};
private _s1Groups = [_s1Registry, "groups", []] call _s1Get;
private _s1Units = [_s1Registry, "units", []] call _s1Get;
if (!(_s1Groups isEqualType [])) then { _s1Groups = []; };
if (!(_s1Units isEqualType [])) then { _s1Units = []; };
private _s1Text = "<font size='16' color='#B89B6B'>S-1 Personnel Snapshot</font><br/><br/>";
if (_s1UpdatedAt < 0 || { (count _s1Groups) isEqualTo 0 }) then
{
    _s1Text = _s1Text + "Snapshot unavailable (cold join / JIP sync pending).\n";
    _s1Text = _s1Text + "Wait for server publication.\n";
}
else
{
    _s1Text = _s1Text + format ["Updated at: T+%1s\nGroups: %2\nUnits: %3\n\n", round _s1UpdatedAt, count _s1Groups, count _s1Units];
    {
        if (!(_x isEqualType [])) then { continue; };
        private _gid = [_x, "groupId", ""] call _s1Get;
        if (!(_gid isEqualType "")) then { _gid = ""; };
        private _co = [_x, "company", "UNK"] call _s1Get;
        if (!(_co isEqualType "")) then { _co = "UNK"; };
        private _call = [_x, "callsign", ""] call _s1Get;
        if (!(_call isEqualType "")) then { _call = ""; };
        _s1Text = _s1Text + format ["[%1] %2 (%3)\n", _co, _gid, if (_call isEqualTo "") then {"No callsign"} else {_call}];
    } forEach (_s1Groups select [0, ((count _s1Groups) min 8)]);
};

// Apply updates (setDiaryRecordText)
if (!(_recOps isEqualTo diaryRecordNull)) then
{
    player setDiaryRecordText [["ARC_OPS", _recOps], ["OPS Dashboard", _opsText, ""]];
};

if (!(_recIntel isEqualTo diaryRecordNull)) then
{
    player setDiaryRecordText [["ARC_INTEL", _recIntel], ["Intel Feed", _intelText, ""]];
};

if (!(_recSitrep isEqualTo diaryRecordNull)) then
{
    player setDiaryRecordText [["ARC_SITREP", _recSitrep], ["SITREP", _sitrepText, ""]];
};

if (!(_recS1 isEqualTo diaryRecordNull)) then
{
    player setDiaryRecordText [["ARC_S1", _recS1], ["Personnel Snapshot", _s1Text, ""]];
};

if (!(_recDebug isEqualTo diaryRecordNull)) then
{
    player setDiaryRecordText [["ARC_DEBUG", _recDebug], ["Debug Inspector", _dbgText, ""]];
};

if (!(_recOpord isEqualTo diaryRecordNull)) then
{
    player setDiaryRecordText [["Diary", _recOpord], ["OPORD", _opordText, ""]];
};


if (!(_recRoles isEqualTo diaryRecordNull)) then
{
    player setDiaryRecordText [["Diary", _recRoles], ["ROLES & CAPABILITIES", _rolesText, ""]];
};

if (!(_recOrbat isEqualTo diaryRecordNull)) then
{
    player setDiaryRecordText [["Diary", _recOrbat], ["ORBAT", _orbatText, ""]];
};

if (!(_recSoI isEqualTo diaryRecordNull)) then
{
    player setDiaryRecordText [["Diary", _recSoI], ["SOI", _soiText, ""]];
};

true
