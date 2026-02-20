/*
    Logs curated operator-facing startup controls in a consistent format.
    Catalog source: missionNamespace variable ARC_operatorToggleAuditCatalog.
*/

if (!isServer) exitWith {};

private _catalog = missionNamespace getVariable ["ARC_operatorToggleAuditCatalog", []];
if !(_catalog isEqualType []) exitWith
{
    diag_log format ["[ARC][CONFIG][AUDIT][ERROR] ARC_operatorToggleAuditCatalog has invalid type (%1).", typeName _catalog];
};

diag_log "[ARC][CONFIG][AUDIT] Startup operator toggle audit begin.";

{
    private _subsystem = _x param [0, "UNKNOWN_SUBSYSTEM", [""]];
    private _entries = _x param [1, [], [[]]];

    if !(_entries isEqualType []) then
    {
        diag_log format ["[ARC][CONFIG][AUDIT][WARN][%1] Entry list has invalid type (%2).", _subsystem, typeName _entries];
        continue;
    };

    {
        private _varName = _x param [0, "", [""]];
        private _kind = toLower (_x param [1, "", [""]]);
        if (_varName isEqualTo "") then { continue; };

        private _value = missionNamespace getVariable [_varName, nil];
        if (isNil "_value") then
        {
            diag_log format ["[ARC][CONFIG][AUDIT][%1] %2 | expected=%3 | effective=MISSING", _subsystem, _varName, toUpper _kind];
            continue;
        };

        switch (_kind) do
        {
            case "bool":
            {
                if !(_value isEqualType true) then
                {
                    diag_log format ["[ARC][CONFIG][AUDIT][%1] %2 | expected=BOOL | effective=%3 (type=%4)", _subsystem, _varName, _value, typeName _value];
                }
                else
                {
                    diag_log format ["[ARC][CONFIG][AUDIT][%1] %2 | expected=BOOL | effective=%3", _subsystem, _varName, _value];
                };
            };

            case "number":
            {
                if ((_value isEqualType 0) || (_value isEqualType 0.0)) then
                {
                    diag_log format ["[ARC][CONFIG][AUDIT][%1] %2 | expected=NUMBER | effective=%3", _subsystem, _varName, _value];
                }
                else
                {
                    diag_log format ["[ARC][CONFIG][AUDIT][%1] %2 | expected=NUMBER | effective=%3 (type=%4)", _subsystem, _varName, _value, typeName _value];
                };
            };

            default
            {
                diag_log format ["[ARC][CONFIG][AUDIT][%1] %2 | expected=%3 | effective=%4 (type=%5)", _subsystem, _varName, toUpper _kind, _value, typeName _value];
            };
        };
    } forEach _entries;
} forEach _catalog;

diag_log "[ARC][CONFIG][AUDIT] Startup operator toggle audit end.";
