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

private _levelOrder = createHashMapFromArray [
    ["DEBUG", 10],
    ["INFO", 20],
    ["WARN", 30],
    ["ERROR", 40]
];

private _normalizedLevel = toUpperANSI _level;
if !(_normalizedLevel in _levelOrder) then {
    _normalizedLevel = "INFO";
};

private _minLevelCfg = toUpperANSI (missionNamespace getVariable ["FARABAD_log_minLevel", "INFO"]);
if !(_minLevelCfg in _levelOrder) then {
    _minLevelCfg = "INFO";
};

private _currentPriority = _levelOrder get _normalizedLevel;
private _minimumPriority = _levelOrder get _minLevelCfg;
if (_currentPriority < _minimumPriority) exitWith { false };

private _channelNorm = toUpperANSI _channel;
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
        private _extensionResult = nil;
        _extensionFailed = isNil {
            _extensionResult = _extensionName callExtension _line;
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
