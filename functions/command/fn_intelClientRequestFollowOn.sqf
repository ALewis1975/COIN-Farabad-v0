/*
    ARC_fnc_intelClientRequestFollowOn

    Client: submit a structured follow-on request to the TOC queue.

    Params:
      0: STRING request (RTB|HOLD|PROCEED)
      1: STRING purpose (REFIT|INTEL|EPW) - RTB only
      2: STRING rationale (optional)
      3: STRING constraints (optional)
      4: STRING support request (optional)
      5: STRING notes (optional)
      6: STRING holdIntent (optional) - HOLD only
      7: NUMBER holdMinutes (optional) - HOLD only
      8: STRING proceedIntent (optional) - PROCEED only

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// This function can open BIS_fnc_guiMessage (lead warning) and should run scheduled.
if (!canSuspend) exitWith { _this spawn ARC_fnc_intelClientRequestFollowOn; false };

params [
    ["_request", "RTB"],
    ["_purpose", "REFIT"],
    ["_rationale", ""],
    ["_constraints", ""],
    ["_support", ""],
    ["_notes", ""],
    ["_holdIntent", ""],
    ["_holdMinutes", 0],
    ["_proceedIntent", ""]
];

// Normalize
if (!(_request isEqualType "")) then { _request = "RTB"; };
_request = toUpper (trim _request);
if !(_request in ["RTB","HOLD","PROCEED"]) then { _request = "RTB"; };

if (!(_purpose isEqualType "")) then { _purpose = "REFIT"; };
_purpose = toUpper (trim _purpose);
if !(_purpose in ["REFIT","INTEL","EPW"]) then { _purpose = "REFIT"; };

if (!(_rationale isEqualType "")) then { _rationale = ""; };
if (!(_constraints isEqualType "")) then { _constraints = ""; };
if (!(_support isEqualType "")) then { _support = ""; };
if (!(_notes isEqualType "")) then { _notes = ""; };
if (!(_holdIntent isEqualType "")) then { _holdIntent = ""; };
if (!(_proceedIntent isEqualType "")) then { _proceedIntent = ""; };
if (!(_holdMinutes isEqualType 0)) then { _holdMinutes = 0; };
_holdMinutes = (_holdMinutes max 0) min 240;

if (!(call ARC_fnc_intelClientCanRequestFollowOn)) exitWith
{
    ["SITREP", "Follow-on request unavailable. Send SITREP and ensure no TOC order is waiting for acceptance."] call ARC_fnc_clientToast;
    false
};

private _gid = groupId (group player);

// Warn if RTB will fail an accepted lead assignment
private _orders = missionNamespace getVariable ["ARC_pub_orders", []];
private _hasAcceptedLead = false;
private _leadSummary = "";
{
    if (!(_x isEqualType []) || { (count _x) < 7 }) then { continue; };
    _x params ["_oid", "_iat", "_st", "_ot", "_tg", "_data", "_meta"]; 
    if (!(_tg isEqualTo _gid)) then { continue; };
    if (!((toUpper _ot) isEqualTo "LEAD")) then { continue; };
    if (!((toUpper _st) isEqualTo "ACCEPTED")) then { continue; };

    private _leadDisp = "";
    if (_data isEqualType []) then
    {
        {
            // NOTE: order payload uses key "leadName" (not "leadDisplayName")
            if (_x isEqualType [] && { (count _x) >= 2 } && { (_x # 0) isEqualTo "leadName" }) exitWith { _leadDisp = _x # 1; };
        } forEach _data;
    };

    _hasAcceptedLead = true;
    _leadSummary = if (_leadDisp isEqualTo "") then {"(Unnamed lead)"} else { _leadDisp };
} forEach _orders;

if (_request isEqualTo "RTB" && { _hasAcceptedLead }) then
{
    private _txt = format [
        "You have an accepted lead assignment that will FAIL if you RTB and TOC approves it.\n\nAccepted lead: %1\n\nRecommendation: complete accepted leads before requesting RTB.\n\nProceed with RTB request?",
        _leadSummary
    ];

    private _ok = [_txt, "RTB Warning", true, true] call BIS_fnc_guiMessage;
    if (!_ok) exitWith {false};
};

// Ensure purpose is meaningful for non-RTB for display
private _purposeDisp = _purpose;
if (_request isEqualTo "HOLD") then { _purposeDisp = "HOLD"; };
if (_request isEqualTo "PROCEED") then { _purposeDisp = "PROCEED"; };

private _sum = "";
switch (_request) do
{
    case "RTB": { _sum = format ["Follow-on Request: RTB (%1)", _purpose]; };
    case "HOLD": { _sum = "Follow-on Request: HOLD"; };
    case "PROCEED": { _sum = "Follow-on Request: PROCEED"; };
    default { _sum = format ["Follow-on Request: %1", _request]; };
};

// Build detail string (readable in TOC queue)
private _grid = mapGridPosition (getPosATL player);
private _from = format ["%1 (%2)", name player, _gid];

private _lines = [];
_lines pushBack format ["FROM: %1", _from];
_lines pushBack format ["LOCATION: %1", _grid];
_lines pushBack format ["REQUEST: %1 (%2)", _request, _purposeDisp];

if (_request isEqualTo "HOLD") then
{
    if (trim _holdIntent isNotEqualTo "") then { _lines pushBack format ["HOLD INTENT: %1", trim _holdIntent]; };
    if (_holdMinutes > 0) then { _lines pushBack format ["HOLD DURATION: %1 min", _holdMinutes]; };
};

if (_request isEqualTo "PROCEED") then
{
    if (trim _proceedIntent isNotEqualTo "") then { _lines pushBack format ["PROCEED INTENT: %1", trim _proceedIntent]; };
};

if (trim _rationale isNotEqualTo "") then { _lines pushBack format ["RATIONALE: %1", trim _rationale]; };
if (trim _constraints isNotEqualTo "") then { _lines pushBack format ["CONSTRAINTS: %1", trim _constraints]; };
if (trim _support isNotEqualTo "") then { _lines pushBack format ["SUPPORT: %1", trim _support]; };
if (trim _notes isNotEqualTo "") then { _lines pushBack format ["NOTES: %1", trim _notes]; };

private _details = _lines joinString "\n";

// Short note to carry into issued order meta
private _noteLines = [];
if (trim _rationale isNotEqualTo "") then { _noteLines pushBack format ["Rationale: %1", trim _rationale]; };
if (trim _constraints isNotEqualTo "") then { _noteLines pushBack format ["Constraints: %1", trim _constraints]; };
if (trim _support isNotEqualTo "") then { _noteLines pushBack format ["Support: %1", trim _support]; };
if (trim _notes isNotEqualTo "") then { _noteLines pushBack format ["Notes: %1", trim _notes]; };
private _noteForOrder = _noteLines joinString " | ";

private _payload =
[
    ["request", _request],
    ["purpose", _purpose],
    ["purposeDisp", _purposeDisp],
    ["requestorGroup", _gid],
    ["requestorRole", ([player] call ARC_fnc_rolesGetTag)],
    ["rationale", trim _rationale],
    ["constraints", trim _constraints],
    ["support", trim _support],
    ["holdIntent", trim _holdIntent],
    ["holdMinutes", _holdMinutes],
    ["proceedIntent", trim _proceedIntent],
    ["note", _noteForOrder]
];

[player, "FOLLOWON_REQUEST", _payload, _sum, _details, getPosATL player, []] remoteExec ["ARC_fnc_intelQueueSubmit", 2];

["TOC", "Follow-on request submitted to TOC queue."] call ARC_fnc_clientToast;

true
