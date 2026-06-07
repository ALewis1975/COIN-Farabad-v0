/*
    ARC_fnc_intelTocIssueLead

    Server: helper for TOC/S2 staff to triage a specific lead from the lead pool
    into the TOC Queue (backlog) for later TOC-driven incident creation.

    Leads (e.g. HUMINT follow-up) have no on-scene completion gates such as a
    Civ/liaison interaction, so they must NOT be issued as a PROCEED order that
    becomes an assigned field task. Instead, an approved lead is added to the TOC
    Queue (backlog) and only becomes actionable through the normal incident
    workflow, which carries proper completion gates.

    Params:
      0: OBJECT issuer
      1: STRING leadId  (specific lead to triage)
      2: STRING note    (optional note)

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_issuer", objNull, [objNull]],
    ["_leadId", "", [""]],
    ["_note", "", [""]]
];

if (isNull _issuer) exitWith {false};

// Dedicated MP hardening: validate sender identity.
if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        if ((owner _issuer) != _reo) exitWith
        {
            diag_log format ["[ARC][SEC] ARC_fnc_intelTocIssueLead: sender-owner mismatch reo=%1 issuerOwner=%2 issuer=%3",
                _reo, owner _issuer, name _issuer];
            false
        };
    };
};

if (!(_leadId isEqualType "")) then { _leadId = ""; };
private _trimFn = compile "params ['_s']; trim _s";
_leadId = [_leadId] call _trimFn;
if (!(_note isEqualType "")) then { _note = ""; };
_note = [_note] call _trimFn;

if (_leadId isEqualTo "") exitWith {false};

// Leads must never be assigned as field tasks; route the approved lead into the
// TOC Queue (backlog) for TOC-driven incident creation instead of issuing a LEAD order.
if (isNil "ARC_fnc_tocBacklogEnqueue") exitWith {false};

private _by = "SYSTEM";
if (!isNil "ARC_fnc_rolesFormatUnit") then { _by = [_issuer] call ARC_fnc_rolesFormatUnit; };

private _priority = 3;
private _pool = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_pool isEqualType [])) then { _pool = []; };
{
    if (_x isEqualType [] && { (count _x) >= 12 } && { (_x select 0) isEqualTo _leadId }) exitWith
    {
        private _meta = _x select 11;
        if (_meta isEqualType []) then
        {
            {
                if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "priority" }) exitWith
                {
                    private _p = _x select 1;
                    if (_p isEqualType 0) then { _priority = round _p; };
                };
            } forEach _meta;
        };
    };
} forEach _pool;
_priority = (_priority max 1) min 5;

[_leadId, _priority, "", _by, _note] call ARC_fnc_tocBacklogEnqueue
