/*
    Build a human-friendly task description that can also surface "known intel".

    Notes on formatting:
    - The task description field uses Structured Text.
    - Use <br/> tags for line breaks (not "\n").

    Params:
        0: STRING - taskId
        1: STRING - markerName (raw or canonical, may be "" for lead-driven incidents)
        2: STRING - displayName
        3: STRING - incidentType
        4: ARRAY  - (optional) posATL override [x,y,z]

    Returns:
        STRING
*/

params ["_taskId", "_markerName", "_displayName", "_incidentType", ["_posATL", []]];

private _BR = "<br/>";
private _PARA = "<br/><br/>";

private _m = "";
private _pos = [];

if (!(_markerName isEqualTo "")) then
{
    _m = [_markerName] call ARC_fnc_worldResolveMarker;
    if (_m in allMapMarkers) then
    {
        _pos = getMarkerPos _m;
    };
};

if (_pos isEqualTo [] && { _posATL isEqualType [] && { (count _posATL) >= 2 } }) then
{
    _pos = +_posATL;
    _pos resize 3;
};

if (_pos isEqualTo []) then
{
    _pos = [0,0,0];
};
private _grid = mapGridPosition _pos;

private _zone = if (_m isEqualTo "") then { [_pos] call ARC_fnc_worldGetZoneForPos } else { [_m] call ARC_fnc_worldGetZoneForMarker };
private _typeU = toUpper _incidentType;


// Task UI hints (tunable via initServer.sqf / missionNamespace vars)
private _iedSearchRad = missionNamespace getVariable ["ARC_taskObjSearchRadiusM_IED", 125];
if (!(_iedSearchRad isEqualType 0) || { _iedSearchRad <= 0 }) then { _iedSearchRad = 125; };
_iedSearchRad = (_iedSearchRad max 50) min 400;

// Assignment/acceptance workflow context (only meaningful for the active incident).
private _activeTaskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _isActive = (_taskId isEqualTo _activeTaskId);
private _accepted = false;
private _closeReady = false;
if (_isActive) then
{
    _accepted = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
    if (!(_accepted isEqualType true)) then { _accepted = false; };

    _closeReady = ["activeIncidentCloseReady", false] call ARC_fnc_stateGet;
    if (!(_closeReady isEqualType true)) then { _closeReady = false; };
};

private _workflowText = "Flow: Assignment → Acceptance → Movement → Maneuver/Completion → SITREP (wait for higher) → RTB / Next lead.";
private _phaseText = "";
if (_isActive) then
{
    // Pull key workflow state (server state) so the task text reflects reality.
    private _sitrepSent = ["activeIncidentSitrepSent", false] call ARC_fnc_stateGet;
    if (!(_sitrepSent isEqualType true)) then { _sitrepSent = false; };

    private _execKind = ["activeExecKind", ""] call ARC_fnc_stateGet;
    if (!(_execKind isEqualType "")) then { _execKind = ""; };

    private _activated = ["activeExecActivated", false] call ARC_fnc_stateGet;
    if (!(_activated isEqualType true) && !(_activated isEqualType false)) then { _activated = false; };

    private _holdReq = ["activeExecHoldReq", 0] call ARC_fnc_stateGet;
    if (!(_holdReq isEqualType 0)) then { _holdReq = 0; };

    private _holdAccum = ["activeExecHoldAccum", 0] call ARC_fnc_stateGet;
    if (!(_holdAccum isEqualType 0)) then { _holdAccum = 0; };

    _phaseText = if (!_accepted) then
    {
        "Current phase: AWAITING ACCEPTANCE (TOC must accept to start clocks and spawn assets)."
    }
    else
    {
        if (_closeReady) then
        {
            if (_sitrepSent) then
            {
                "Current phase: SITREP SENT (awaiting TOC closure)."
            }
            else
            {
                "Current phase: SITREP PENDING (objective complete; submit SITREP)."
            };
        }
        else
        {
            if ((toUpper _execKind) isEqualTo "CONVOY") then
            {
                "Current phase: EXECUTION (convoy movement / link-up / escort)."
            }
            else
            {
                if (!_activated) then
                {
                    "Current phase: EN ROUTE (move to objective area)."
                }
                else
                {
                    if (_holdReq > 0) then
                    {
                        private _rem = (_holdReq - _holdAccum) max 0;
                        private _remMin = ceil (_rem / 60);
                        format ["Current phase: ON-OBJECTIVE (hold remaining: ~%1 min).", (_remMin max 0)]
                    }
                    else
                    {
                        "Current phase: ON-OBJECTIVE (execute objective actions)."
                    };
                };
            };
        };
    };
};

// Convoy link-up (edge-start convoys) nuance for the active task.
private _hasConvoyLinkup = false;
private _convoyLinkupGrid = "";
if ( ["activeExecTaskId", ""] call ARC_fnc_stateGet isEqualTo _taskId ) then
{
    private _lpos = ["activeConvoyLinkupPos", []] call ARC_fnc_stateGet;
    if (_lpos isEqualType [] && { (count _lpos) >= 2 }) then
    {
        _hasConvoyLinkup = true;
        _convoyLinkupGrid = mapGridPosition _lpos;
    };
};

// Pick tasking flavor from ORBAT logic
private _flavor = [_incidentType, _zone] call ARC_fnc_orbatPickTasking;
_flavor params ["_taskingFrom", "_supporting", "_constraints"];
// Optional: expose who we're linking up with (convoys / escorted elements).
private _linkupWith = "(none)";
if (_isActive && { _typeU in ["LOGISTICS","ESCORT"] }) then
{
    private _got = false;

    // Best-effort: resolve the spawned convoy group ID (once vehicles exist).
    private _nids = ["activeConvoyNetIds", []] call ARC_fnc_stateGet;
    if (_nids isEqualType [] && { (count _nids) > 0 }) then
    {
        private _leadVeh = objectFromNetId (_nids # 0);
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

    // Fallbacks when the convoy has not spawned yet (or netIds not propagated).
    if (!_got) then
    {
        if (_typeU isEqualTo "ESCORT" && { !(_taskingFrom isEqualTo "") }) then
        {
            _linkupWith = _taskingFrom;
            _got = true;
        };

        if (!_got && { _typeU isEqualTo "LOGISTICS" }) then
        {
            private _supply = ["activeConvoySupplyKind", ""] call ARC_fnc_stateGet;
            if (!(_supply isEqualType "")) then { _supply = ""; };
            _supply = toUpper _supply;

            private _callsign = switch (_supply) do
            {
                case "FUEL": {"PROVIDER"};
                case "AMMO": {"LONGHAUL"};
                case "MED":  {"ANGEL"};
                default {"LIFELINE"};
            };

            _linkupWith = format ["%1 convoy element", _callsign];
            _got = true;
        };

        if (!_got) then { _linkupWith = "Friendly convoy element"; };
    };
};



// Situation + task steps
private _situation = switch (_typeU) do
{
    case "RAID": { format ["Insurgent presence suspected near %1 (%2). Exact intel location is not marked; search the objective area.", _displayName, _grid] };
    case "IED":  { format ["Possible IED activity reported near %1 (%2). Initial report places the device within ~%3m of the area marker; exact location unknown.", _displayName, _grid, _iedSearchRad] };
    case "CIVIL": { format ["Civil engagement required at %1 (%2). Liaison location will be marked on the map once the task is accepted.", _displayName, _grid] };
    case "LOGISTICS": { format ["Sustainment activity required near %1 (%2).", _displayName, _grid] };
    case "ESCORT": { format ["Escort mission staged near %1 (%2).", _displayName, _grid] };
    case "CHECKPOINT": { format ["Checkpoint operations requested near %1 (%2).", _displayName, _grid] };
    case "DEFEND": { format ["Defensive posture required near %1 (%2).", _displayName, _grid] };
    case "QRF": { format ["Rapid response required near %1 (%2).", _displayName, _grid] };
    case "RECON": { format ["Reconnaissance requested near %1 (%2).", _displayName, _grid] };
    default { format ["Activity reported near %1 (%2).", _displayName, _grid] };
};

private _taskLines = switch (_typeU) do
{
    case "IED": {
        [
            "Move to the area and establish a cordon.",
            "Search for devices, triggermen, and secondary hazards.",
            "Preserve the site for exploitation; report any components or indicators."
        ]
    };
    case "CHECKPOINT": {
        [
            "Establish a checkpoint and control traffic flow.",
            "Inspect vehicles and personnel; detain suspicious individuals for processing.",
            "Record key details (vehicle description, direction of travel, identifiers)."
        ]
    };
    case "CIVIL": {
        [
            "Engage local leaders or affected civilians.",
            "Assess the grievance and de-escalate where possible.",
            "Report actionable details and follow-on recommendations."
        ]
    };
    case "RECON": {
        private _dn = toLower _displayName;
        if ((_dn find "route") >= 0) then
        {
            [
                "Proceed to the route START point.",
                "Move along the route to the END point while observing and reporting.",
                "Avoid decisive engagement; break contact and report if compromised."
            ]
        }
        else
        {
            [
                "Observe the area and report patterns of life.",
                "Avoid decisive engagement; prioritize identification and reporting.",
                "If compromised, break contact and report."
            ]
        }
    };

    case "LOGISTICS": {
        if (_hasConvoyLinkup) then
        {
            [
                format ["Proceed to the convoy link-up point (%1) and establish local security.", _convoyLinkupGrid],
                "Link up with the convoy; it will stage briefly before departing.",
                "Escort the logistics convoy to the destination area; maintain spacing and report contact/losses."
            ]
        }
        else
        {
            [
                "Rally at the convoy staging point and verify vehicles/crew are ready.",
                "Escort the logistics convoy to the destination area.",
                "Maintain convoy spacing and a steady speed; report contact and any losses."
            ]
        }
    };

    case "ESCORT": {
        if (_hasConvoyLinkup) then
        {
            [
                format ["Proceed to the convoy link-up point (%1) and establish local security.", _convoyLinkupGrid],
                "Link up with the convoy; it will stage briefly before departing.",
                "Escort the convoy to the destination area; keep the lead vehicle alive and break contact when able."
            ]
        }
        else
        {
            [
                "Rally at the convoy staging point and coordinate security posture.",
                "Escort the convoy to the destination area.",
                "Keep the lead vehicle alive; break contact and continue movement when able."
            ]
        }
    };
    default {
        [
            "Move to the area and assess.",
            "Resolve the incident (or confirm it as false / stale).",
            "Report outcomes and any follow-on requirements."
        ]
    };
};

private _taskText = (_taskLines apply { format ["- %1", _x] }) joinString _BR;

// --- End-state / completion criteria (kept simple & readable) -----------------
private _endState = "";

// If the execution package exists for this task, surface the actual timing.
private _execTaskId = ["activeExecTaskId", ""] call ARC_fnc_stateGet;
private _hasExec = (_execTaskId isEqualTo _taskId);

private _timingLine = "";
if (_hasExec) then
{
    private _startAt = ["activeExecStartedAt", -1] call ARC_fnc_stateGet;
    private _deadlineAt = ["activeExecDeadlineAt", -1] call ARC_fnc_stateGet;
    private _travelSec = ["activeExecTravelSec", -1] call ARC_fnc_stateGet;
    private _distM = ["activeExecTravelDistM", -1] call ARC_fnc_stateGet;
    private _speedKph = ["activeExecSpeedKph", -1] call ARC_fnc_stateGet;
    private _stage = ["activeExecStagingLabel", ""] call ARC_fnc_stateGet;

    private _windowMin = -1;
    if (_startAt isEqualType 0 && { _deadlineAt isEqualType 0 } && { _deadlineAt > _startAt }) then
    {
        _windowMin = ceil ((_deadlineAt - _startAt) / 60);
    };

    private _travelMin = -1;
    if (_travelSec isEqualType 0 && { _travelSec >= 0 }) then
    {
        _travelMin = ceil (_travelSec / 60);
    };

    private _km = -1;
    if (_distM isEqualType 0 && { _distM >= 0 }) then
    {
        _km = (_distM / 1000);
    };

    if (_windowMin > 0) then
    {
        private _travelTxt = "";
        if (_travelMin >= 0 && { _speedKph isEqualType 0 } && { _speedKph > 0 } && { _km >= 0 }) then
        {
            private _kmTxt = (round (_km * 10)) / 10;
            _travelTxt = format ["Estimated travel: ~%1 min (%2 km @ %3 kph, staging: %4).", _travelMin, _kmTxt, (round _speedKph), _stage];
        }
        else
        {
            _travelTxt = "Estimated travel: (not available).";
        };

        _timingLine = format ["Timing window (from acceptance): ~%1 minutes (scaled by distance).%2%3", _windowMin, _BR, _travelTxt];
    };
};

private _holdReq = if (_hasExec) then { ["activeExecHoldReq", 0] call ARC_fnc_stateGet } else { 0 };
private _arrivalReq = if (_hasExec) then { ["activeExecArrivalReq", 0] call ARC_fnc_stateGet } else { 0 };
private _holdMin = if (_holdReq isEqualType 0 && { _holdReq > 0 }) then { ceil (_holdReq / 60) } else { -1 };
private _arrMin = if (_arrivalReq isEqualType 0 && { _arrivalReq > 0 }) then { ceil (_arrivalReq / 60) } else { -1 };

switch (_typeU) do
{
    case "CHECKPOINT": { _endState = format ["Success: Hold the checkpoint position for %1 minutes. Failure: task expires or checkpoint team is driven off.", (_holdMin max 10)]; };
    case "PATROL":     { _endState = format ["Success: Conduct presence patrol in the area for %1 minutes. Failure: task expires.", (_holdMin max 5)]; };
    case "RECON":      { _endState = format ["Success: Observe the area for %1 minutes and report. Failure: task expires.", (_holdMin max 4)]; };
    case "DEFEND":     { _endState = format ["Success: Maintain security posture for %1 minutes. Failure: task expires.", (_holdMin max 10)]; };
    case "QRF":        { _endState = format ["Success: Respond quickly and stabilize the situation (arrive within %1 minutes, hold %2 minutes). Failure: late response or task expires.", (_arrMin max 5), (_holdMin max 3)]; };
    case "CMDNODE_INTERCEPT": { _endState = format ["Success: Intercept quickly (arrive within %1 minutes, hold %2 minutes). Failure: late response or task expires.", (_arrMin max 4), (_holdMin max 3)]; };
    case "LOGISTICS":  { _endState = "Success: Escort the friendly logistics convoy to the destination AO. Failure: convoy destroyed or task expires."; };
    case "ESCORT":     { _endState = "Success: Escort the friendly convoy to the destination AO. Failure: convoy destroyed or task expires."; };
    case "RAID":       { _endState = "Success: Locate the objective and exploit/capture key materials (on-site action). Failure: objective lost or task expires."; };
    case "CMDNODE_RAID": { _endState = "Success: Exploit the command node (on-site action). Failure: objective lost or task expires."; };
    case "IED":        { _endState = "Success: Locate and clear the device (on-site action). Failure: device detonates/destroyed or task expires."; };
    case "CIVIL":      { _endState = "Success: Conduct the engagement (on-site action). Failure: liaison killed or task expires."; };
    case "CMDNODE_MEET": { _endState = "Success: Conduct the engagement (on-site action). Failure: liaison killed or task expires."; };
    default             { _endState = "Success: Resolve the situation and report. Failure: task expires."; };
};

if (!(_timingLine isEqualTo "")) then
{
    _endState = format ["%1%2%2%3", _endState, _BR, _timingLine];
};

// Known intel (most recent, nearby).
// Filter out pure OPS/tasking noise so players see actual reporting.
private _intelLog = ["intelLog", []] call ARC_fnc_stateGet;
if (!(_intelLog isEqualType [])) then { _intelLog = []; };

private _near = [];
{
    if (!(_x isEqualType []) || { (count _x) < 6 }) then { continue; };
    private _iid = _x param [0, ""];
    private _t = _x param [1, 0];
    private _cat = _x param [2, ""];
    private _sum = _x param [3, ""];
    private _pATL = _x param [4, []];
    private _meta = _x param [5, []];
    if (!(_cat isEqualType "")) then { _cat = str _cat; };
    if (toUpper _cat isEqualTo "OPS") then { continue; };
    if (!(_pATL isEqualType [])) then { continue; };
    if ((_pATL distance2D _pos) < 2500) then
    {
        _near pushBack _x;
    };
} forEach _intelLog;

// Keep last 3 entries
private _intelText = "No additional reporting beyond the initial report.";
if ((count _near) > 0) then
{
    private _start = ((count _near) - 3) max 0;
    private _slice = _near select [_start, (count _near) - _start];

    _intelText = (_slice apply {
        _x params ["_iid", "_t", "_cat", "_sum", "_pATL", "_meta"];
        private _mins = round (_t / 60);
        format ["- %1 (%2, T+%3m): %4", _iid, _cat, _mins, _sum]
    }) joinString _BR;
};

private _markerLine = if (_m isEqualTo "") then { "- Marker: (Lead-derived / no named marker)" } else { format ["- Marker: %1", _m] };

// TOC-controlled closure prompt
private _tocPrompt = "";
if (_hasExec) then
{
    private _ready = ["activeIncidentCloseReady", false] call ARC_fnc_stateGet;
    if (_ready isEqualType true && { _ready }) then
    {
        private _sug = ["activeIncidentSuggestedResult", ""] call ARC_fnc_stateGet;
        private _why = ["activeIncidentCloseReason", ""] call ARC_fnc_stateGet;
        if (!(_sug isEqualType "")) then { _sug = ""; };
        if (!(_why isEqualType "")) then { _why = ""; };

        _sug = toUpper _sug;
        _why = toUpper _why;

        _tocPrompt = format [
            "TOC ACTION REQUIRED:%1- Incident is ready to close.%1- Recommended result: %2.%1- Reason: %3.%1- Close this incident via TOC (Success or Fail).",
            _BR,
            (if (_sug isEqualTo "") then {"(none)"} else {_sug}),
            (if (_why isEqualTo "") then {"(none)"} else {_why})
        ];
    };
};

private _workflowBlock = _workflowText;
if (!(_phaseText isEqualTo "")) then
{
    _workflowBlock = format ["%1%2%3", _workflowText, _BR, _phaseText];
};

private _body = format [
    "SITUATION:%1%2%1%1TASK:%1%3%1%1WORKFLOW:%1%4%1%1END STATE:%1%5%1%1%6%1%1KNOWN INTEL:%1%7%1%1TASKING:%1- From: %8%1- Linking up with: %9%1- Supported by: %10%1%1COORDINATING INSTRUCTIONS:%1%11%1%1LOCATION:%1%12%1- Grid: %13%1- Zone: %14",
    _BR,
    _situation,
    _taskText,
    _workflowBlock,
    _endState,
    _tocPrompt,
    _intelText,
    _taskingFrom,
    _linkupWith,
    _supporting,
    _constraints,
    _markerLine,
    _grid,
    _zone
];

// Task window text size control (default smaller so the Assigned Task view is readable).
private _scale = missionNamespace getVariable ["ARC_taskDescTextScale", 0.88];
if (!(_scale isEqualType 0)) then { _scale = 0.88; };
_scale = (_scale max 0.65) min 1;

format ["<t size='%1'>%2</t>", _scale, _body]
