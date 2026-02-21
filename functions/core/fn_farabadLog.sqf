/*
    FARABAD_fnc_farabadLog

    Structured logger with level gating and optional extension forwarding.

    Params:
      0: STRING  - channel
      1: STRING  - level: DEBUG | INFO | WARN | ERROR
      2: STRING  - message
      3: ANY     - meta payload (default [])

    Config keys (missionNamespace):
      FARABAD_log_enabled         (BOOL, default true)
      FARABAD_log_minLevel        (STRING, default "INFO")
      FARABAD_log_toRPT           (BOOL, default true)
      FARABAD_log_toExtension     (BOOL, default false)
      FARABAD_log_extensionName   (STRING, default "")
      FARABAD_log_includeMeta     (BOOL, default true)
*/

params [
    ["_channel", "CORE", [""]],
    ["_level", "INFO", [""]],
    ["_message", "", [""]],
    ["_meta", []]
];

private _enabled = missionNamespace getVariable ["FARABAD_log_enabled", true];
if !(_enabled) exitWith { false };

// sqflint-compat helpers
private _hmFrom = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";
private _mapGet = compile "params ['_h','_k']; _h get _k";

private _levelOrder = [
    [["DEBUG", 10], ["INFO", 20], ["WARN", 30], ["ERROR", 40]]
] call _hmFrom;

private _normalizedLevel = toUpper _level;
if !(_normalizedLevel in _levelOrder) then {
    _normalizedLevel = "INFO";
};

private _minLevelCfg = toUpper (missionNamespace getVariable ["FARABAD_log_minLevel", "INFO"]);
if !(_minLevelCfg in _levelOrder) then {
    _minLevelCfg = "INFO";
};

private _currentPriority = [_levelOrder, _normalizedLevel] call _mapGet;
private _minimumPriority = [_levelOrder, _minLevelCfg] call _mapGet;
if (!(_currentPriority isEqualType 0)) then { _currentPriority = 20; };
if (!(_minimumPriority isEqualType 0)) then { _minimumPriority = 20; };
if (_currentPriority < _minimumPriority) exitWith { false };

private _channelNorm = toUpper _channel;
private _text = if (_message isEqualType "") then { _message } else { str _message };
private _includeMeta = missionNamespace getVariable ["FARABAD_log_includeMeta", true];
private _metaText = if (_includeMeta) then { str _meta } else { "<omitted>" };

private _line = format [
    "[FARABAD][%1][%2] t=%3 msg=%4 meta=%5",
    _channelNorm,
    _normalizedLevel,
    serverTime,
    _text,
    _metaText
];

if (missionNamespace getVariable ["FARABAD_log_toRPT", true]) then {
    diag_log _line;
};

if (missionNamespace getVariable ["FARABAD_log_toExtension", false]) then {
    private _extensionName = missionNamespace getVariable ["FARABAD_log_extensionName", ""];

    if (_extensionName isEqualType "" && { _extensionName != "" }) then {
        private _extensionFailed = false;

        // callExtension may fail depending on extension availability/load state.
        // Keep gameplay flow safe by swallowing failures and warning once.
        _extensionFailed = isNil {
            _extensionName callExtension _line;
            false
        };

        if (_extensionFailed) then {
            if !(missionNamespace getVariable ["FARABAD_log_extensionWarned", false]) then {
                missionNamespace setVariable ["FARABAD_log_extensionWarned", true];
                diag_log "[FARABAD][LOG][WARN] callExtension failed; disabling extension logging for this session.";
            };
            missionNamespace setVariable ["FARABAD_log_toExtension", false];
        };
    };
};

true
