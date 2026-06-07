/*
    ARC_fnc_uiConsoleActionOpsPrimary

    UI09: Primary action for Operations (S3) tab.

    Context-driven based on the Ops focus list:
      INCIDENT:
        - Accept Incident (if not accepted)
        - Send SITREP (if accepted and available)
      ORDER:
        - Accept next issued order (for your group)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

private _focus = ["ARC_console_opsFocus", "INCIDENT"] call ARC_fnc_uiNsGetString;
_focus = toUpper _focus;

switch (_focus) do
{
    case "ORDER":
    {
        // Accept next issued order for the group
        [] spawn ARC_fnc_uiConsoleActionAcceptOrder;
    };

    case "LEAD":
    {
        // Submit the selected lead to the TOC queue as a LEAD_ISSUE_REQUEST.
        // Leads are never assigned as field tasks; on approval the lead is added to
        // the TOC Queue (backlog) for TOC-driven incident creation.
        private _disp = findDisplay 78000;
        private _cLead = if (!isNull _disp) then { _disp displayCtrl 78038 } else { controlNull };
        private _sel = if (!isNull _cLead) then { lbCurSel _cLead } else { -1 };
        private _lbData = if (_sel >= 0) then { _cLead lbData _sel } else { "NONE" };
        private _parts = _lbData splitString "|";
        private _leadId = if ((count _parts) > 1) then { _parts select 1 } else { "" };
        private _ok = (!isNull _disp) && { !isNull _cLead } && { _sel >= 0 } && { !(_lbData isEqualTo "") } && { !(_lbData isEqualTo "NONE") } && { !(_leadId isEqualTo "") };

        if (_ok) then
        {
            // Resolve lead record from the public pool so we can build a rich queue payload.
            private _leads = missionNamespace getVariable ["ARC_leadPoolPublic", []];
            if (!(_leads isEqualType [])) then { _leads = []; };

            private _trimFn = compile "params ['_s']; trim _s";
            private _leadRec = [];
            { if (_x isEqualType [] && { (count _x) >= 1 } && { (_x select 0) isEqualTo _leadId }) exitWith { _leadRec = _x; }; } forEach _leads;

            private _leadType = if ((count _leadRec) >= 2 && { (_leadRec select 1) isEqualType "" }) then { toUpper ([_leadRec select 1] call _trimFn) } else { "LEAD" };
            private _leadName = if ((count _leadRec) >= 3) then { _leadRec select 2 } else { "Lead" };
            if (!(_leadName isEqualType "")) then { _leadName = "Lead"; };
            private _leadPos  = if ((count _leadRec) >= 4) then { _leadRec select 3 } else { [] };
            if (!(_leadPos isEqualType []) || { (count _leadPos) < 2 }) then { _leadPos = getPosATL player; };
            private _missionMeta = if ((count _leadRec) >= 12 && { (_leadRec select 11) isEqualType [] }) then { _leadRec select 11 } else { [] };
            private _getPair = {
                params ["_pairs", "_k", "_d"];
                if (!(_pairs isEqualType [])) exitWith { _d };
                private _out = _d;
                { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _k }) exitWith { _out = _x select 1; }; } forEach _pairs;
                _out
            };
            private _source = [_missionMeta, "source", ""] call _getPair;
            private _confidence = [_missionMeta, "confidence", ""] call _getPair;
            if (!(_source isEqualType "")) then { _source = ""; };
            if (!(_confidence isEqualType "")) then { _confidence = ""; };

            private _summary = format ["LEAD ISSUE: %1 - %2", _leadType, _leadName];
            private _details = format ["S3 requests TOC approval to issue a PROCEED order for lead %1 (%2) at grid %3.", _leadId, _leadType, mapGridPosition _leadPos];
            if (!(_source isEqualTo "") || { !(_confidence isEqualTo "") }) then {
                private _srcTxt = if (_source isEqualTo "") then { "N/A" } else { _source };
                private _confTxt = if (_confidence isEqualTo "") then { "N/A" } else { _confidence };
                _details = _details + format [" ISR source=%1 confidence=%2.", _srcTxt, _confTxt];
            };

            private _payload = [
                ["leadId",      _leadId],
                ["leadType",    _leadType],
                ["displayName", _leadName]
            ];
            if (!(_source isEqualTo "")) then { _payload pushBack ["source", _source]; };
            if (!(_confidence isEqualTo "")) then { _payload pushBack ["confidence", _confidence]; };

            [player, "LEAD_ISSUE_REQUEST", _payload, _summary, _details, _leadPos] remoteExec ["ARC_fnc_intelQueueSubmit", 2];
            ["Operations", format ["Lead %1 submitted to TOC queue for approval.", _leadId]] call ARC_fnc_clientToast;
        }
        else
        {
            private _msg = "Could not submit lead.";
            if (isNull _disp) then { _msg = "Console not found."; } else {
            if (isNull _cLead) then { _msg = "Lead list not found."; } else {
            if (_sel < 0) then { _msg = "Select a lead from the list first."; } else {
            if (_lbData isEqualTo "NONE") then { _msg = "No leads available."; };
            };};};
            ["Operations", _msg] call ARC_fnc_clientToast;
        };
    };

    default
    {
        // Incident focused
        private _accepted = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
        if (!_accepted) exitWith
        {
            [] spawn ARC_fnc_uiConsoleActionAcceptIncident;
        };

        private _canSitrep = [] call ARC_fnc_clientCanSendSitrep;
        if (_canSitrep) exitWith
        {
            [] spawn ARC_fnc_uiConsoleActionSendSitrep;
        };

        ["Operations", "No primary action available (SITREP not available yet)."] call ARC_fnc_clientToast;
    };
};

true
