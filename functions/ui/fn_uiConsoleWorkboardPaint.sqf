/*
    ARC_fnc_uiConsoleWorkboardPaint

    Client: paints the Workboard tab using the list+details pane.
    This is the first step toward a unified "incidents + leads" board.

    Params:
      0: DISPLAY
      1: BOOL rebuild list (default true)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]],
    ["_rebuild", true, [true]]
];

if (isNull _display) exitWith {false};

private _ctrlMain    = _display displayCtrl 78010;
private _ctrlMainGrp = _display displayCtrl 78015;
private _ctrlList    = _display displayCtrl 78011;
private _ctrlDetails = _display displayCtrl 78012;
private _ctrlDetailsGrp = _display displayCtrl 78016;

private _b1 = _display displayCtrl 78021;
private _b2 = _display displayCtrl 78022;

// Flip pane visibility: list/details on, main off
if (!isNull _ctrlMainGrp) then { _ctrlMainGrp ctrlShow false; };
if (!isNull _ctrlMain) then { _ctrlMain ctrlShow false; };
if (!isNull _ctrlList) then { _ctrlList ctrlShow true; };
if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow true; };
if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow true; };

if (isNull _ctrlList || { isNull _ctrlDetails }) exitWith {false};

// Preserve prior selection by data string when rebuilding
private _prevData = "";
private _prevSel = lbCurSel _ctrlList;
if (_prevSel >= 0) then { _prevData = _ctrlList lbData _prevSel; };

if (_rebuild) then
{
    lbClear _ctrlList;

    // 1) Active incident (if any)
    private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""];
    if ((_taskId isEqualType "") && { _taskId isNotEqualTo "" }) then
    {
        private _disp = missionNamespace getVariable ["ARC_activeIncidentDisplayName", "Active Incident"];
        if (!(_disp isEqualType "")) then { _disp = "Active Incident"; };

        private _accepted = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
        if (!(_accepted isEqualType true) && !(_accepted isEqualType false)) then { _accepted = false; };

        private _st = if (_accepted) then {"ACCEPTED"} else {"PENDING"};
        private _i = _ctrlList lbAdd format ["INCIDENT: %1 [%2]", _disp, _st];
        _ctrlList lbSetData [_i, format ["INCIDENT|%1", _taskId]];
    };

    // 2) Lead pool (public snapshot)
    private _pool = missionNamespace getVariable ["ARC_leadPoolPublic", []];
    if (!(_pool isEqualType [])) then { _pool = []; };

    {
        if (!(_x isEqualType []) || { (count _x) < 4 }) then { continue; };
        _x params ["_id", "_leadType", "_displayName", "_pos", "_strength", "_createdAt", "_expiresAt", "_sourceTaskId", "_sourceIncidentType", "_threadId", "_tag"];

        private _grid = "";
        if (_pos isEqualType [] && { (count _pos) >= 2 }) then { _grid = mapGridPosition _pos; };

        private _lbl = format ["LEAD: %1 (%2)%3", _displayName, _leadType, if (_grid isEqualTo "") then {""} else {format [" @%1", _grid]}];
        private _j = _ctrlList lbAdd _lbl;
        _ctrlList lbSetData [_j, format ["LEAD|%1", _id]];
    } forEach _pool;

    if ((lbSize _ctrlList) isEqualTo 0) then
    {
        private _k = _ctrlList lbAdd "No active incident or leads.";
        _ctrlList lbSetData [_k, "NONE|"];
    };

    // Restore selection if possible
    private _set = -1;
    if (_prevData isNotEqualTo "") then
    {
        for "_n" from 0 to ((lbSize _ctrlList) - 1) do
        {
            if ((_ctrlList lbData _n) isEqualTo _prevData) exitWith { _set = _n; };
        };
    };

    if (_set < 0) then { _set = 0; };
    _ctrlList lbSetCurSel _set;
};

// ---------------------------------------------------------------------------
// Details + button states (based on current selection)
// ---------------------------------------------------------------------------
private _sel = lbCurSel _ctrlList;
private _data = if (_sel >= 0) then { _ctrlList lbData _sel } else { "NONE|" };

if (!(_data isEqualType "")) then { _data = "NONE|"; };
private _parts = _data splitString "|";
private _kind = if ((count _parts) > 0) then { toUpper (_parts # 0) } else { "NONE" };
private _id   = if ((count _parts) > 1) then { _parts # 1 } else { "" };

// Default buttons
{ if (!isNull _x) then { _x ctrlShow true; _x ctrlEnable false; }; } forEach [_b1, _b2];
if (!isNull _b1) then { _b1 ctrlSetText "N/A"; };
if (!isNull _b2) then { _b2 ctrlSetText "N/A"; };

private _txt = "<t size='1.15' font='PuristaMedium'>Workboard</t><br/><t size='0.9' color='#DDDDDD'>Incidents + Leads</t><br/><br/>";

switch (_kind) do
{
    case "INCIDENT":
    {
        private _disp = missionNamespace getVariable ["ARC_activeIncidentDisplayName", "Active Incident"];
        if (!(_disp isEqualType "")) then { _disp = "Active Incident"; };

        private _itype = missionNamespace getVariable ["ARC_activeIncidentType", ""];
        if (!(_itype isEqualType "")) then { _itype = ""; };

        private _pos = missionNamespace getVariable ["ARC_activeIncidentPos", []];
        if (!(_pos isEqualType [])) then { _pos = []; };

        private _grid = if ((count _pos) >= 2) then { mapGridPosition _pos } else { "UNKNOWN" };

        private _accepted = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
        if (!(_accepted isEqualType true) && !(_accepted isEqualType false)) then { _accepted = false; };

        private _acceptedBy = missionNamespace getVariable ["ARC_activeIncidentAcceptedByGroup", ""];
        if (!(_acceptedBy isEqualType "")) then { _acceptedBy = ""; };
        if (_acceptedBy isEqualTo "") then { _acceptedBy = "(unassigned)"; };

        private _closeReady = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false];
        if (!(_closeReady isEqualType true) && !(_closeReady isEqualType false)) then { _closeReady = false; };

        private _sitrepSent = missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false];
        if (!(_sitrepSent isEqualType true) && !(_sitrepSent isEqualType false)) then { _sitrepSent = false; };

        _txt = _txt + format [
            "<t size='1.05' font='PuristaMedium'>%1</t><br/><t size='0.9' color='#DDDDDD'>Type: %2 | Grid: %3</t><br/><br/>",
            _disp, if (_itype isEqualTo "") then {"(n/a)"} else {_itype}, _grid
        ];

        _txt = _txt + format [
            "<t size='0.95'>Status</t><br/>- Accepted: %1<br/>- Accepted By: %2<br/>- Close-ready: %3<br/>- SITREP Sent: %4<br/><br/>",
            if (_accepted) then {"YES"} else {"NO"},
            _acceptedBy,
            if (_closeReady) then {"YES"} else {"NO"},
            if (_sitrepSent) then {"YES"} else {"NO"}
        ];

        // Primary: Accept if pending; otherwise Send SITREP if available
        if (!isNull _b1) then
        {
            if (!_accepted) then
            {
                _b1 ctrlSetText "ACCEPT INCIDENT";
                _b1 ctrlEnable (([player] call ARC_fnc_rolesIsAuthorized) || { (missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]]) findIf { [player, _x] call ARC_fnc_rolesHasGroupIdToken } >= 0 });
            }
            else
            {
                _b1 ctrlSetText "SEND SITREP";
                _b1 ctrlEnable ([player] call ARC_fnc_clientCanSendSitrep);
            };
        };

        // Secondary: Request Follow-on (requires SITREP + no pending orders)
        if (!isNull _b2) then
        {
            _b2 ctrlSetText "FOLLOW-ON REQUEST";
            _b2 ctrlEnable (call ARC_fnc_intelClientCanRequestFollowOn);
        };

        _txt = _txt + "<t size='0.9' color='#DDDDDD'>Tip: Use SITREP to close out on-scene work, then request the next TOC follow-on.</t>";
    };

    case "LEAD":
    {
        private _pool = missionNamespace getVariable ["ARC_leadPoolPublic", []];
        if (!(_pool isEqualType [])) then { _pool = []; };

        private _lead = [];
        {
            if (_x isEqualType [] && { (count _x) >= 4 } && { (_x # 0) isEqualTo _id }) exitWith { _lead = _x; };
        } forEach _pool;

        if (_lead isEqualTo []) then
        {
            _txt = _txt + "<t size='0.95' color='#FFB0B0'>Lead not found (pool refreshed or expired).</t>";
        }
        else
        {
            _lead params ["_lid", "_ltype", "_lname", "_pos", "_strength", "_createdAt", "_expiresAt", "_sourceTaskId", "_sourceIncidentType", "_threadId", "_tag"];
            private _grid = if (_pos isEqualType [] && { (count _pos) >= 2 }) then { mapGridPosition _pos } else { "UNKNOWN" };

            _txt = _txt + format [
                "<t size='1.05' font='PuristaMedium'>%1</t><br/><t size='0.9' color='#DDDDDD'>Lead Type: %2 | Grid: %3</t><br/><br/>",
                _lname, _ltype, _grid
            ];

            private _age = if (_createdAt isEqualType 0) then { round (serverTime - _createdAt) } else { -1 };
            private _ageTxt = if (_age < 0) then {"(unknown)"} else { format ["%1s", _age] };

            _txt = _txt + format [
                "<t size='0.95'>Details</t><br/>- Strength: %1<br/>- Age: %2<br/>- Tag: %3<br/>- Thread: %4<br/><br/>",
                _strength, _ageTxt,
                if (_tag isEqualType "" && { _tag isNotEqualTo "" }) then {_tag} else {"(none)"},
                if (_threadId isEqualType "" && { _threadId isNotEqualTo "" }) then {_threadId} else {"(none)"}
            ];

            _txt = _txt + "<t size='0.9' color='#DDDDDD'>Leads feed TOC tasking. S2 creates leads; TOC converts them into orders/incidents.</t>";
        };

        // Buttons: no direct lead actions yet (UI09+)
        if (!isNull _b1) then { _b1 ctrlSetText "N/A"; _b1 ctrlEnable false; };
        if (!isNull _b2) then { _b2 ctrlSetText "N/A"; _b2 ctrlEnable false; };
    };

    default
    {
        _txt = _txt + "<t size='0.95' color='#DDDDDD'>Select an item to view details.</t>";
    };
};

_ctrlDetails ctrlSetStructuredText parseText _txt;

// Auto-fit + clamp to viewport so the controls group can scroll when needed.
[_ctrlDetails] call BIS_fnc_ctrlFitToTextHeight;
private _grp = _display displayCtrl 78016;
private _minH = if (!isNull _grp) then { (ctrlPosition _grp) # 3 } else { 0.74 };
private _p = ctrlPosition _ctrlDetails;
_p set [3, (_p # 3) max _minH];
_ctrlDetails ctrlSetPosition _p;
_ctrlDetails ctrlCommit 0;

true
