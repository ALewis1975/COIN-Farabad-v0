/*
    ARC_fnc_uiIncidentGetNextActions

    UI helper: returns a short list of "what is blocked / what is next" lines
    for the Dashboard tab.

    Params:
      0: STRING roleCat (FIELD|TOC-S2|TOC-S3|TOC-CMD|GUEST)

    Returns:
      ARRAY of STRING (each is a line of structuredText)
*/

if (!hasInterface) exitWith {[]};

params [
    ['_roleCat','FIELD',['']]
];

private _lines = [];

private _taskId = missionNamespace getVariable ['ARC_activeTaskId',''];
if (!(_taskId isEqualType '')) then { _taskId = ''; };
_taskId = trim _taskId;

private _hasIncident = (_taskId isNotEqualTo '');
private _accepted = missionNamespace getVariable ['ARC_activeIncidentAccepted', false];
if (!(_accepted isEqualType true) && !(_accepted isEqualType false)) then { _accepted = false; };

private _closeReady = missionNamespace getVariable ['ARC_activeIncidentCloseReady', false];
if (!(_closeReady isEqualType true) && !(_closeReady isEqualType false)) then { _closeReady = false; };

private _sitrepSent = missionNamespace getVariable ['ARC_activeIncidentSitrepSent', false];
if (!(_sitrepSent isEqualType true) && !(_sitrepSent isEqualType false)) then { _sitrepSent = false; };

// Orders summary (issued orders require acceptance)
private _gid = groupId (group player);
private _orders = missionNamespace getVariable ['ARC_pub_orders', []];
if (!(_orders isEqualType [])) then { _orders = []; };
private _issuedCount = 0;
{
    if (!(_x isEqualType [] && { (count _x) >= 6 })) then { continue; };
    private _st = toUpper (_x # 2);
    private _tg = _x # 4;
    if (_tg isNotEqualTo _gid) then { continue; };
    if (_st isEqualTo 'ISSUED') then { _issuedCount = _issuedCount + 1; };
} forEach _orders;

// EOD disposition approvals / gates
private _eodApproved = false;
private _appr = missionNamespace getVariable ['ARC_pub_eodDispoApprovals', []];
if (!(_appr isEqualType [])) then { _appr = []; };

private _accG = missionNamespace getVariable ['ARC_activeIncidentAcceptedByGroup',''];
if (!(_accG isEqualType '')) then { _accG = ''; };

private _hasRtbEvidenceApproval = false;
private _hasTowVbiedApproval = false;
{
    if (!(_x isEqualType [] && { (count _x) >= 6 })) then { continue; };
    if ((_x # 0) isNotEqualTo _taskId) then { continue; };
    if ((_x # 1) isNotEqualTo _accG) then { continue; };
    private _rt = toUpper (trim (_x # 2));
    if (_rt isEqualTo 'RTB_IED') then { _hasRtbEvidenceApproval = true; };
    if (_rt isEqualTo 'TOW_VBIED') then { _hasTowVbiedApproval = true; };
} forEach _appr;

// Evidence / VBIED Phase 5 state mirrors (set by server)
private _evCollected = missionNamespace getVariable ['ARC_activeIedEvidenceCollected', false];
if (!(_evCollected isEqualType true) && !(_evCollected isEqualType false)) then { _evCollected = false; };
private _evTransport = missionNamespace getVariable ['ARC_activeIedEvidenceTransportEnabled', false];
if (!(_evTransport isEqualType true) && !(_evTransport isEqualType false)) then { _evTransport = false; };
private _evDelivered = missionNamespace getVariable ['ARC_activeIedEvidenceDelivered', false];
if (!(_evDelivered isEqualType true) && !(_evDelivered isEqualType false)) then { _evDelivered = false; };

private _vbSafe = missionNamespace getVariable ['ARC_activeVbiedSafe', false];
if (!(_vbSafe isEqualType true) && !(_vbSafe isEqualType false)) then { _vbSafe = false; };
private _vbDisposed = missionNamespace getVariable ['ARC_activeVbiedDisposed', false];
if (!(_vbDisposed isEqualType true) && !(_vbDisposed isEqualType false)) then { _vbDisposed = false; };
private _vbCause = missionNamespace getVariable ['ARC_activeVbiedDestroyedCause', ''];
if (!(_vbCause isEqualType '')) then { _vbCause = ''; };
_vbCause = trim _vbCause;

// Priority 1: active incident acceptance + SITREP gate
if (_hasIncident) then
{
    if (!_accepted) then
    {
        _lines pushBack "<t color='#FFFFA0'>Blocked:</t> Incident not accepted. <t color='#DDDDDD'>Next:</t> S3 / OPS tab <t color='#B89B6B'>→ ACCEPT ORDER</t>";
    }
    else
    {
        if (_closeReady && {!_sitrepSent}) then
        {
            _lines pushBack "<t color='#FFFFA0'>Blocked:</t> SITREP not sent. <t color='#DDDDDD'>Next:</t> OPS send SITREP (OPS tab).";
        };
    };
};

// Priority 2: outstanding orders for the group
if (_issuedCount > 0) then
{
    _lines pushBack format ["<t color='#FFFFA0'>Pending:</t> %1 TOC order(s) issued. <t color='#DDDDDD'>Next:</t> Accept on Handoff/OPS tab.", _issuedCount];
};

// Priority 3: Phase 5 logistics gates
if (_hasIncident && {_accepted}) then
{
    if (_hasRtbEvidenceApproval) then
    {
        if (_evCollected && {!_evDelivered}) then
        {
            _lines pushBack "<t color='#A0FFA0'>Approved:</t> RTB evidence. <t color='#DDDDDD'>Next:</t> Transport evidence to EOD site (mkr_eod_disposal).";
        };
        if (_evDelivered) then
        {
            _lines pushBack "<t color='#A0FFA0'>Complete:</t> Evidence delivered to EOD site. <t color='#DDDDDD'>Next:</t> OPS SITREP / closeout as directed.";
        };
    };

    if (_hasTowVbiedApproval) then
    {
        if (_vbSafe && {!_vbDisposed} && {_vbCause isEqualTo ''}) then
        {
            _lines pushBack "<t color='#A0FFA0'>Approved:</t> Tow VBIED. <t color='#DDDDDD'>Next:</t> Move VBIED to EOD site, then dispose.";
        };
    };

    if (_vbCause isNotEqualTo '') then
    {
        _lines pushBack "<t color='#FF8080'>Warning:</t> VBIED destroyed without valid disposal. <t color='#DDDDDD'>Next:</t> OPS SITREP; TOC review.";
    };
};

// Clamp
if ((count _lines) > 6) then { _lines = _lines select [0, 6]; };

_lines
