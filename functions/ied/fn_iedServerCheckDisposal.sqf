/*
    ARC_fnc_iedServerCheckDisposal

    Server: Phase 5 disposal-site checks.

    Handles:
      - Enabling evidence logistics after TOC approval (RTB_IED)
      - Marking evidence "delivered" when evidence (or player, for VIRTUAL_ITEM) reaches the disposal site

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";

private _incType = toUpper (['activeIncidentType',''] call ARC_fnc_stateGet);
if (!(_incType isEqualTo 'IED')) exitWith {false};

private _taskId = ['activeTaskId',''] call ARC_fnc_stateGet;
if !(_taskId isEqualType '' && { !(_taskId isEqualTo '') }) exitWith {false};

private _gid = ['activeIncidentAcceptedByGroup',''] call ARC_fnc_stateGet;
if !(_gid isEqualType '' && { !(_gid isEqualTo '') }) exitWith {false};

private _mkr = missionNamespace getVariable ['ARC_eodDisposalMarkerName','mkr_eod_disposal'];
if !(_mkr isEqualType '') then { _mkr = 'mkr_eod_disposal'; };

private _rad = missionNamespace getVariable ['ARC_eodDisposalRadiusM',12];
if !(_rad isEqualType 0) then { _rad = 12; };
_rad = (_rad max 3) min 80;

private _sitePos = getMarkerPos _mkr;
if !(_sitePos isEqualType [] && { (count _sitePos) >= 2 }) exitWith {false};
_sitePos = +_sitePos; _sitePos resize 3;

// Approval lookup helper (reads published approvals; should already be filtered for expiry)
private _hasApproval = {
    params ['_reqType'];
    private _appr = missionNamespace getVariable ['ARC_pub_eodDispoApprovals', []];
    if !(_appr isEqualType []) exitWith {false};
    private _ok = false;
    {
        if !(_x isEqualType [] && { (count _x) >= 6 }) then { continue; };
        if (!((_x select 0) isEqualTo _taskId)) then { continue; };
        if (!((_x select 1) isEqualTo _gid)) then { continue; };
        if (!((toUpper ([(_x select 2)] call _trimFn)) isEqualTo _reqType)) then { continue; };
        private _exp = _x select 5;
        if (!(_exp isEqualType 0)) then { _exp = -1; };
        if (_exp >= 0 && { serverTime > _exp }) then { continue; };
        _ok = true;
        break;
    } forEach _appr;
    _ok
};

// Evidence transport enablement + delivery
private _evNid = ['activeIedEvidenceNetId',''] call ARC_fnc_stateGet;
if !(_evNid isEqualType '') then { _evNid = ''; };

private _collected = ['activeIedEvidenceCollected', false] call ARC_fnc_stateGet;
if (!(_collected isEqualType true) && !(_collected isEqualType false)) then { _collected = false; };

private _delivered = ['activeIedEvidenceDelivered', false] call ARC_fnc_stateGet;
if (!(_delivered isEqualType true) && !(_delivered isEqualType false)) then { _delivered = false; };

private _mode = missionNamespace getVariable ['ARC_eodRtbEvidenceMode','ACE_CARGO'];
if !(_mode isEqualType '') then { _mode = 'ACE_CARGO'; };
_mode = toUpper ([_mode] call _trimFn);
if !(_mode in ['ACE_CARGO','VIRTUAL_ITEM']) then { _mode = 'ACE_CARGO'; };

private _rtbApproved = ['RTB_IED'] call _hasApproval;

// If evidence is collected and RTB approved, enable logistics once (ACE mode)
if (_collected && _rtbApproved && !_delivered) then
{
    private _transportEnabled = ['activeIedEvidenceTransportEnabled', false] call ARC_fnc_stateGet;
    if (!(_transportEnabled isEqualType true) && !(_transportEnabled isEqualType false)) then { _transportEnabled = false; };

    if (!_transportEnabled) then
    {
        ['activeIedEvidenceTransportEnabled', true] call ARC_fnc_stateSet;
        missionNamespace setVariable ['ARC_activeIedEvidenceTransportEnabled', true, true];

        if (_mode isEqualTo 'ACE_CARGO' && { !(_evNid isEqualTo '') }) then
        {
            private _cargoSize = missionNamespace getVariable ['ARC_iedEvidenceCargoSize', 1];
            if !(_cargoSize isEqualType 0) then { _cargoSize = 1; };
            private _enCarry = missionNamespace getVariable ['ARC_iedEvidenceCarryEnabled', true];
            if (!(_enCarry isEqualType true) && !(_enCarry isEqualType false)) then { _enCarry = true; };
            private _enDrag = missionNamespace getVariable ['ARC_iedEvidenceDragEnabled', true];
            if (!(_enDrag isEqualType true) && !(_enDrag isEqualType false)) then { _enDrag = true; };

            // Enable ACE interactions on all clients; safe no-op if ACE missing
            [_evNid, _cargoSize, _enCarry, _enDrag] remoteExec ['ARC_fnc_iedClientEnableEvidenceLogistics', 0, true];
        };
    };
};

// Delivery completion
if (_collected && _rtbApproved && !_delivered) then
{
    private _atSite = false;

    if (_mode isEqualTo 'ACE_CARGO') then
    {
        if (!(_evNid isEqualTo '')) then
        {
            private _evObj = objectFromNetId _evNid;
            if (!isNull _evObj) then
            {
                private _p = getPosATL _evObj;
                _atSite = ((_p distance2D _sitePos) <= _rad);
            };
        };
    }
    else
    {
        // Virtual fallback: any WEST player from the accepted group within radius counts as delivery.
        private _near = false;
        {
            if (!isPlayer _x) then { continue; };
            if (!((groupId (group _x)) isEqualTo _gid)) then { continue; };
            if ((getPosATL _x) distance2D _sitePos <= _rad) exitWith { _near = true; };
        } forEach allPlayers;
        _atSite = _near;
    };

    if (_atSite) then
    {
        // Best-effort "who" for audit
        private _by = 'UNKNOWN';
        private _byUid = '';
        private _best = objNull;
        private _bestD = 1e9;
        {
            if (!isPlayer _x) then { continue; };
            if (!((groupId (group _x)) isEqualTo _gid)) then { continue; };
            private _d = (getPosATL _x) distance2D _sitePos;
            if (_d < _bestD) then { _bestD = _d; _best = _x; };
        } forEach allPlayers;
        if (!isNull _best) then
        {
            _by = name _best;
            _byUid = getPlayerUID _best;
        };

        ['activeIedEvidenceDelivered', true] call ARC_fnc_stateSet;
        ['activeIedEvidenceDeliveredAt', serverTime] call ARC_fnc_stateSet;
        ['activeIedEvidenceDeliveredBy', _by] call ARC_fnc_stateSet;
        ['activeIedEvidenceDeliveredByUID', _byUid] call ARC_fnc_stateSet;

        missionNamespace setVariable ['ARC_activeIedEvidenceDelivered', true, true];
        missionNamespace setVariable ['ARC_activeIedEvidenceDeliveredAt', serverTime, true];
        missionNamespace setVariable ['ARC_activeIedEvidenceDeliveredBy', _by, true];

        private _pos = _sitePos;
        private _grid = mapGridPosition _pos;
        private _zone = [_pos] call ARC_fnc_worldGetZoneForPos;

        ['TECHINT', format ['Evidence delivered to EOD site (%1).', _grid], _pos,
            [
                ['event','IED_EVIDENCE_DELIVERED'],
                ['taskId',_taskId],
                ['grid',_grid],
                ['zone',_zone],
                ['deliveredBy',_by],
                ['deliveredByUID',_byUid]
            ]
        ] call ARC_fnc_intelLog;

	    	    // Optional follow-on lead (deferred until evidence delivery)
	    	    private _pending = ['activeIedEvidenceLeadPending', false] call ARC_fnc_stateGet;
	    	    if (!(_pending isEqualType true) && !(_pending isEqualType false)) then { _pending = false; };
	    	    private _leadId = ['activeIedEvidenceLeadId', ''] call ARC_fnc_stateGet;
	    	    if (!(_leadId isEqualType '')) then { _leadId = ''; };

	    	    if (_pending && { _leadId isEqualTo '' }) then
	    	    {
	    	        private _lpos = ['activeIedEvidenceLeadPendingPos', []] call ARC_fnc_stateGet;
	    	        if (!(_lpos isEqualType []) || { (count _lpos) < 2 }) then { _lpos = _pos; };
	    	        _lpos = +_lpos; _lpos resize 3;
	    	        private _incType2 = ['activeIncidentType', ''] call ARC_fnc_stateGet;
	    	        if (!(_incType2 isEqualType '')) then { _incType2 = ''; };
	    	        private _lid = ['RECON', 'Lead: IED facilitation follow-up', _lpos, 0.55, 60*60, _taskId, _incType2, '', 'IED_FACILITATION'] call ARC_fnc_leadCreate;
	    	        if (!(_lid isEqualTo '')) then
	    	        {
	    	            ['activeIedEvidenceLeadId', _lid] call ARC_fnc_stateSet;
	    	            ['activeIedEvidenceLeadPending', false] call ARC_fnc_stateSet;
	    	            ['activeIedEvidenceLeadPendingPos', []] call ARC_fnc_stateSet;
	    	        };
	    	    };
    };
};

true
