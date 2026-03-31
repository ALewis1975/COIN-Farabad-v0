/*
    ARC_fnc_intelTocIssueLead

    Server: helper for TOC/S2 staff to issue a specific lead from the lead pool
    as a LEAD order without going through the queue wizard.

    Params:
      0: OBJECT issuer
      1: STRING leadId  (specific lead to consume; "" = consume next available)
      2: STRING note    (optional note)

    Target group resolution (priority):
      1) activeIncidentAcceptedByGroup
      2) lastTaskingGroup
      3) issuer's own group

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

// Resolve target group
private _targetGroup = ["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateGet;
if (!(_targetGroup isEqualType "") || { _targetGroup isEqualTo "" }) then
{
    _targetGroup = ["lastTaskingGroup", ""] call ARC_fnc_stateGet;
};
if (!(_targetGroup isEqualType "") || { _targetGroup isEqualTo "" }) then
{
    _targetGroup = groupId (group _issuer);
};

// Build data seed: include specific lead ID if provided so fn_intelOrderIssue
// consumes that exact lead rather than the next available one.
private _seed = [];
if (!(_leadId isEqualTo "")) then
{
    _seed = [["leadId", _leadId]];
};

["LEAD", _targetGroup, _seed, _issuer, _note, ""] call ARC_fnc_intelOrderIssue;
