/*
    ARC_fnc_threatEconomyReasonMeta

    Stable Threat Economy reason-code metadata.

    Params:
      0: STRING reason code, or "__ALL__" to return the full taxonomy.

    Returns:
      ARRAY pairs for one code, or ARRAY of pair-arrays for "__ALL__".
*/

params [
    ["_code", "UNKNOWN_REASON", [""]]
];

private _mk = {
    params ["_code", "_decision", "_category", "_label", "_hint", "_blocksEvent"];
    [
        ["code", _code],
        ["decision", _decision],
        ["category", _category],
        ["label", _label],
        ["operator_hint", _hint],
        ["blocks_event", _blocksEvent]
    ]
};

private _all = [
    ["ALLOW_GOVERNOR", "ALLOW", "GOVERNOR", "Governor allowed event", "Threat governor cleared budget, cooldown, and escalation gates.", false] call _mk,
    ["ALLOW_SCHEDULED", "ALLOW", "SCHEDULER", "Event scheduled", "Threat event record was scheduled after governor approval.", false] call _mk,
    ["THREAT_DISABLED", "DENY", "ENABLE", "Threat system disabled", "Threat v0 is disabled; no scheduled threat event may proceed.", true] call _mk,
    ["GLOBAL_COOLDOWN", "DENY", "COOLDOWN", "Global cooldown active", "Global threat cooldown still blocks new scheduled threat events.", true] call _mk,
    ["DISTRICT_COOLDOWN", "DENY", "COOLDOWN", "District cooldown active", "District-specific cooldown still blocks a new scheduled threat event.", true] call _mk,
    ["BUDGET_EXHAUSTED", "DENY", "BUDGET", "District budget exhausted", "Requested threat cost would exceed the district's available attack budget.", true] call _mk,
    ["ESCALATION_TIER", "DENY", "ESCALATION", "Escalation tier too low", "Requested threat type requires a higher district posture tier.", true] call _mk,
    ["BAD_DISTRICT", "DENY", "INPUT", "Bad district", "Threat governor received an empty or invalid district id.", true] call _mk,
    ["NOT_SERVER", "DENY", "AUTHORITY", "Not server", "Threat governor was invoked outside server authority.", true] call _mk,
    ["SCHEDULE_FAILED", "WARN", "SCHEDULER", "Schedule failed after approval", "Governor approved the event, but record scheduling failed.", true] call _mk,
    ["UNKNOWN_REASON", "WARN", "UNKNOWN", "Unknown reason", "Reason code was missing or not part of the current taxonomy.", true] call _mk
];

if (_code isEqualTo "__ALL__") exitWith { _all };

private _codeU = toUpper _code;
private _out = [];
{
    private _row = _x;
    private _rowCode = "";
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo "code" }) exitWith { _rowCode = _x select 1; };
    } forEach _row;
    if (_rowCode isEqualTo _codeU) exitWith { _out = _row; };
} forEach _all;

if (_out isEqualTo []) exitWith { ["UNKNOWN_REASON"] call ARC_fnc_threatEconomyReasonMeta };
_out
