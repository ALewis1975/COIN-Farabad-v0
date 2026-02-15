/*
    ARC_fnc_intelClientBeginLeadRequestMapClick

    Client: S2 helper. Prompts for a lead request, then places it via map click.

    This does NOT directly create a lead; it submits a LEAD_REQUEST into the
    TOC queue so S3/Command can approve.

    Params:
      0: STRING leadType (incident type)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [["_leadType", "RECON"]];
_leadType = toUpper (trim _leadType);
if (_leadType isEqualTo "") then { _leadType = "RECON"; };

private _defSum = format ["Lead: %1 (S2 Request)", _leadType];
private _defDet = "Confidence: MED\nTTL(min): 60\nNotes:";

private _res = ["S2 LEAD REQUEST", _defSum, _defDet] call ARC_fnc_clientIntelPrompt;
_res params ["_ok", "_sum", "_det"];
if (!_ok) exitWith {false};

_sum = trim _sum;
if (_sum isEqualTo "") then { _sum = _defSum; };
if ((toUpper _sum) find "LEAD:" < 0) then { _sum = format ["Lead: %1", _sum]; };

// Parse confidence/TTL from details (best-effort)
private _conf = "MED";
private _ttl = 3600;
{
    private _u = toUpper _x;

    if (_u find "CONF" >= 0) then
    {
        if (_u find "LOW" >= 0) then { _conf = "LOW"; };
        if (_u find "HIGH" >= 0) then { _conf = "HIGH"; };
        if (_u find "MED" >= 0) then { _conf = "MED"; };
    };

    if (_u find "TTL" >= 0) then
    {
        // extract any number on the line (digits-only)
        private _chars = toArray _x;
        private _onlyDigits = [];
        {
            if (_x >= 48 && _x <= 57) then { _onlyDigits pushBack _x; };
        } forEach _chars;

        if ((count _onlyDigits) > 0) then
        {
            private _n = parseNumber (toString _onlyDigits);
            if (_n > 0) then
            {
                // assume minutes for small values
                if (_n <= 240) then { _ttl = _n * 60; } else { _ttl = _n; };
            };
        };
    };
} forEach (_det splitString "\n");

private _strength = switch (_conf) do
{
    case "LOW":  {0.35};
    case "HIGH": {0.75};
    default       {0.55};
};

_ttl = (_ttl max 600) min 21600;

missionNamespace setVariable ["ARC_lastLeadReqType", _leadType];
missionNamespace setVariable ["ARC_lastLeadReqSummary", _sum];
missionNamespace setVariable ["ARC_lastLeadReqDetails", _det];
missionNamespace setVariable ["ARC_lastLeadReqConfidence", _conf];
missionNamespace setVariable ["ARC_lastLeadReqStrength", _strength];
missionNamespace setVariable ["ARC_lastLeadReqTTL", _ttl];

// If the Farabad Console is open, close it so map clicks can register, then re-open once the map closes.
private _reopenConsole = false;
private _reopenTab = "INTEL";
private _consoleDisp = uiNamespace getVariable ["ARC_console_display", displayNull];
if (isNull _consoleDisp) then { _consoleDisp = findDisplay 78000; };
if (!isNull _consoleDisp) then
{
    _reopenConsole = true;
    _reopenTab = uiNamespace getVariable ["ARC_console_activeTab", "INTEL"];
    closeDialog 0;
};

if (_reopenConsole) then
{
    uiNamespace setVariable ["ARC_console_reopenAfterMap", true];
    uiNamespace setVariable ["ARC_console_reopenTab", _reopenTab];
    [] spawn {
        waitUntil { uiSleep 0.05; visibleMap };
        waitUntil { uiSleep 0.05; !visibleMap };
        uiSleep 0.05;
        if (uiNamespace getVariable ["ARC_console_reopenAfterMap", false]) then
        {
            uiNamespace setVariable ["ARC_console_reopenAfterMap", false];
            private _tab = uiNamespace getVariable ["ARC_console_reopenTab", "INTEL"];
            // Re-open on the same tab without calling the listbox handler directly.
            uiNamespace setVariable ["ARC_console_forceTab", _tab];
            [] call ARC_fnc_uiConsoleOpen;
        };
    };
};

hint "Map click to place the LEAD REQUEST (Esc to cancel).";
openMap [true, false];

private _mapClickCode = [
    "params ['_units','_pos','_alt','_shift'];",
    "",
    "private _leadType = missionNamespace getVariable ['ARC_lastLeadReqType','RECON'];",
    "private _sum = missionNamespace getVariable ['ARC_lastLeadReqSummary','Lead: Unknown'];",
    "private _det = missionNamespace getVariable ['ARC_lastLeadReqDetails',''];",
    "private _conf = missionNamespace getVariable ['ARC_lastLeadReqConfidence','MED'];",
    "private _strength = missionNamespace getVariable ['ARC_lastLeadReqStrength',0.55];",
    "private _ttl = missionNamespace getVariable ['ARC_lastLeadReqTTL',3600];",
    "",
    "private _payload = [",
    "    ['leadType', _leadType],",
    "    ['displayName', _sum],",
    "    ['strength', _strength],",
    "    ['ttl', _ttl],",
    "    ['confidence', _conf],",
    "    ['tag', 'S2_REQUEST']",
    "];",
    "",
    "[",
    "    player,",
    "    'LEAD_REQUEST',",
    "    _payload,",
    "    _sum,",
    "    _det,",
    "    _pos,",
    "    [ ['source','S2_MAPCLICK'] ]",
    "] remoteExec ['ARC_fnc_intelQueueSubmit', 2];",
    "",
    "hint 'Lead request submitted to TOC queue.';",
    "openMap [false, false];",
    "onMapSingleClick '';",
    "true;"
] joinString "\n";

onMapSingleClick _mapClickCode;

true
