/*
    ARC_fnc_uiConsoleHandoffPaint

    UI09: paint the Handoff tab (Intel Debrief + EPW processing).

    IMPORTANT:
      - "Arrived" is based on the server arrival state for the RTB order (meta: arrivedAt / awaiting*),
        not the local player's distance to the destination.
      - This avoids confusing UX when the console is used from the TOC building while the handoff
        point is elsewhere on base.

    Params:
      0: DISPLAY

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]]
];

if (isNull _display) exitWith {false};

private _ctrlMain = _display displayCtrl 78010;
private _b1 = _display displayCtrl 78021;
private _b2 = _display displayCtrl 78022;

if (isNull _ctrlMain) exitWith {false};

private _fmt = {
    params ["_label", "_state", ["_ok", false]];
    private _c = if (_ok) then {"#A0FFA0"} else {"#FFB0B0"};
    format ["<t color='%1'>%2</t>: %3", _c, _label, _state]
};

private _gidSelf = groupId (group player);
private _roleTag = [player] call ARC_fnc_rolesGetTag;
if (_roleTag isEqualTo "") then { _roleTag = "RFL"; };

private _isToc = [player] call ARC_fnc_rolesCanApproveQueue;
if (!(_isToc isEqualType true)) then { _isToc = false; };

// When the console is used by TOC staff (BN CO / S2 / S3), focus the handoff view on
// the group executing the active incident (SITREP sender preferred).
private _focusGid = _gidSelf;
if (_isToc) then
{
    _focusGid = missionNamespace getVariable ["ARC_activeIncidentSitrepFromGroup", ""];
    if (!(_focusGid isEqualType "")) then { _focusGid = ""; };
    _focusGid = [_focusGid] call _trimFn;

    if (_focusGid isEqualTo "") then
    {
        _focusGid = missionNamespace getVariable ["ARC_activeIncidentAcceptedByGroup", ""];
        if (!(_focusGid isEqualType "")) then { _focusGid = ""; };
        _focusGid = [_focusGid] call _trimFn;
    };

    if (_focusGid isEqualTo "") then { _focusGid = _gidSelf; };
};

private _orders = missionNamespace getVariable ["ARC_pub_orders", []];
if (!(_orders isEqualType [])) then { _orders = []; };

private _getPair = {
    params ["_pairs", "_k", "_d"];
    if (!(_pairs isEqualType [])) exitWith { _d };
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _k }) exitWith { _x select 1 };
    } forEach _pairs;
    _d
};

private _findAcceptedRtb = {
    params ["_purposeU"];
    private _out = [];
    {
        if (!(_x isEqualType [] && { (count _x) >= 7 })) then { continue; };
        _x params ["_orderId", "_issuedAt", "_status", "_orderType", "_targetGroup", "_data", "_meta"]; 
        if (!((toUpper _status) isEqualTo "ACCEPTED")) then { continue; };
        if (!((toUpper _orderType) isEqualTo "RTB")) then { continue; };
        if (!(_targetGroup isEqualTo _focusGid)) then { continue; };
        private _p = toUpper ([_data, "purpose", "REFIT"] call _getPair);
        if (_p isEqualTo _purposeU) exitWith { _out = _x; };
    } forEach _orders;
    _out
};

private _findIssuedAny = {
    private _has = false;
    {
        if (_x isEqualType [] && { (count _x) >= 5 }) then
        {
            private _st = toUpper (_x select 2);
            private _tg = _x select 4;
            if (_st isEqualTo "ISSUED" && { _tg isEqualTo _focusGid }) exitWith { _has = true; };
        };
    } forEach _orders;
    _has
};

private _isArrived = {
    params ["_ord", "_purposeU"];
    if (_ord isEqualTo []) exitWith {false};


// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
    _ord params ["_oid", "_iat", "_st", "_ot", "_tg", "_data", "_meta"]; 

    // Primary: server arrival state
    private _arrivedAt = [_meta, "arrivedAt", -1] call _getPair;
    if (!(_arrivedAt isEqualType 0)) then { _arrivedAt = -1; };
    if (_arrivedAt >= 0) exitWith {true};

    private _k = if (_purposeU isEqualTo "INTEL") then {"awaitingDebrief"} else {"awaitingEpwProcessing"};
    private _aw = [_meta, _k, false] call _getPair;
    if (!(_aw isEqualType true)) then { _aw = false; };
    if (_aw) exitWith {true};

    // UX: if the player is physically at the destination, treat as arrived even before the
    // 60s order tick marks arrivedAt.
    private _destPos = [_data, "destPos", []] call _getPair;
    private _destRad = [_data, "destRadius", 30] call _getPair;
    if (!(_destRad isEqualType 0)) then { _destRad = 30; };

    // Intel debrief destination radius is intentionally generous (players use different consoles/boards).
    if (_purposeU isEqualTo "INTEL") then { _destRad = _destRad max 30; };

    if (_destPos isEqualType [] && { (count _destPos) >= 2 }) then
    {
        private _p = +_destPos; _p resize 3;
        if ((player distance2D _p) <= (_destRad + 10)) exitWith {true};
    };

    // UX: for EPW, also treat as arrived if a detained AI is within the processing zone,
    // even when the console is used away from the handoff point (avoids waiting on server tick).
    if (_purposeU isEqualTo "EPW") then
    {
        if (_destPos isEqualType [] && { (count _destPos) >= 2 }) then
        {
            private _searchRad = missionNamespace getVariable ["ARC_epwProcessSearchRadius", 45];
            if (!(_searchRad isEqualType 0)) then { _searchRad = 45; };
            _searchRad = (_searchRad max 10) min 200;

            private _found = false;
            {
                private _u = _x;
                if (isPlayer _u) then { continue; };
                if (!alive _u) then { continue; };
                if ((_u distance2D _destPos) > _searchRad) then { continue; };
                private _hc = _u getVariable ["ace_captives_isHandcuffed", false];
                if (!(_hc isEqualType true)) then { _hc = false; };
                private _hc2 = _u getVariable ["ACE_captives_isHandcuffed", false];
                if (!(_hc2 isEqualType true)) then { _hc2 = false; };
                private _isDetained = (captive _u) || { _hc } || { _hc2 };
                if (!_isDetained) then { continue; };
                _found = true;
            } forEach allUnits;

            if (_found) exitWith {true};
        };
    };

    false
};

private _focusLabel = if (_focusGid isEqualTo "") then {"(no callsign)"} else {_focusGid};
private _hdr = format [
    "<t size='1.15' font='PuristaMedium'>HANDOFF</t><br/><t size='0.9' color='#DDDDDD'>Group: %1 | Tag: %2</t>",
    _focusLabel,
    _roleTag
];

if (_isToc && { !(_focusGid isEqualTo _gidSelf) }) then
{
    private _selfLbl = if (_gidSelf isEqualTo "") then {"(no callsign)"} else {_gidSelf};
    _hdr = _hdr + format ["<br/><t size='0.85' color='#CCCCCC'>Focus: Active incident group (you are %1)</t>", _selfLbl];
};

_hdr = _hdr + "<br/><br/>";

private _intelOrd = ["INTEL"] call _findAcceptedRtb;
private _epwOrd   = ["EPW"] call _findAcceptedRtb;
// Cache selected orders for the ACTION / ALT handlers (deterministic console buttons)
private _intelId = "";
private _intelTg = "";
if (!(_intelOrd isEqualTo [])) then {
    _intelId = _intelOrd select 0;
    _intelTg = _intelOrd select 4;
};

private _epwId = "";
private _epwTg = "";
if (!(_epwOrd isEqualTo [])) then {
    _epwId = _epwOrd select 0;
    _epwTg = _epwOrd select 4;
};

uiNamespace setVariable ["ARC_console_handoff_intelOrderId", _intelId];
uiNamespace setVariable ["ARC_console_handoff_intelTargetGroup", _intelTg];
uiNamespace setVariable ["ARC_console_handoff_epwOrderId", _epwId];
uiNamespace setVariable ["ARC_console_handoff_epwTargetGroup", _epwTg];

private _intelAccepted = (!(_intelOrd isEqualTo []));
private _epwAccepted = (!(_epwOrd isEqualTo []));

private _intelArr = [_intelOrd, "INTEL"] call _isArrived;
private _epwArr   = [_epwOrd, "EPW"] call _isArrived;

private _intelLine = ["RTB (INTEL)", if (_intelAccepted) then {"ACCEPTED"} else {"NONE"}, _intelAccepted] call _fmt;
private _epwLine   = ["RTB (EPW)",   if (_epwAccepted) then {"ACCEPTED"} else {"NONE"}, _epwAccepted] call _fmt;

private _intelDest = "";
if (_intelAccepted) then
{
    _intelOrd params ["_oid", "_iat", "_st", "_ot", "_tg", "_data", "_meta"]; 
    private _lbl = [_data, "destLabel", "Destination"] call _getPair;
    private _pos = [_data, "destPos", []] call _getPair;
    private _grid = if (_pos isEqualType [] && { (count _pos) >= 2 }) then { mapGridPosition _pos } else { "" };
    _intelDest = format ["<t size='0.9' color='#CCCCCC'>%1 %2</t>", _lbl, if (_grid isEqualTo "") then {""} else {format ["(@ %1)", _grid]}];
};

private _epwDest = "";
if (_epwAccepted) then
{
    _epwOrd params ["_oid", "_iat", "_st", "_ot", "_tg", "_data", "_meta"]; 
    private _lbl = [_data, "destLabel", "Destination"] call _getPair;
    private _pos = [_data, "destPos", []] call _getPair;
    private _grid = if (_pos isEqualType [] && { (count _pos) >= 2 }) then { mapGridPosition _pos } else { "" };
    _epwDest = format ["<t size='0.9' color='#CCCCCC'>%1 %2</t>", _lbl, if (_grid isEqualTo "") then {""} else {format ["(@ %1)", _grid]}];
};

private _help = "";
private _hasIssued = call _findIssuedAny;
if (_hasIssued) then
{
    _help = "<br/><t size='0.9' color='#FFFFA0'>A TOC order is ISSUED for your group and awaits acceptance by an authorized leader (or OMNI).</t>";
};

private _txt = _hdr
    + _intelLine + "<br/>" + _intelDest + "<br/>" + format ["<t size='0.9'>Arrived: %1</t>", if (_intelArr) then {"YES"} else {"NO"}]
    + "<br/><br/>"
    + _epwLine + "<br/>" + _epwDest + "<br/>" + format ["<t size='0.9'>Arrived: %1</t>", if (_epwArr) then {"YES"} else {"NO"}]
    + _help;

_ctrlMain ctrlSetStructuredText parseText _txt;

// Auto-fit + clamp to viewport so the controls group can scroll when needed.
[_ctrlMain] call BIS_fnc_ctrlFitToTextHeight;
private _mainGrp = _display displayCtrl 78015;
private _minH = if (!isNull _mainGrp) then { (ctrlPosition _mainGrp) select 3 } else { 0.74 };
private _p = ctrlPosition _ctrlMain;
_p set [3, (_p select 3) max _minH];
_ctrlMain ctrlSetPosition _p;
_ctrlMain ctrlCommit 0;

// Enable when the RTB order exists and has ARRIVED.
if (!isNull _b1) then { _b1 ctrlEnable (_intelAccepted); };
if (!isNull _b2) then { _b2 ctrlEnable (_epwAccepted && _epwArr); };

true
