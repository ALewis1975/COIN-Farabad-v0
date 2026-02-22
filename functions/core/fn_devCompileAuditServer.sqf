/*
    ARC_fnc_devCompileAuditServer

    Server-side compile audit to surface SQF syntax errors early.

    What it does:
      - Iterates ARC entries in mission CfgFunctions
      - Resolves each function file path robustly (handles category-level and function-level 'file' overrides)
      - Preprocesses with line numbers and compiles it
      - Logs a summary to RPT
      - Returns a human-readable report to the requesting client

    Notes:
      - SQF compile errors are reported to the RPT by the engine (with file/line).
      - This audit ensures we attempt compilation for every file and highlights missing paths.

    Params:
      0: requester (OBJECT) - used to route the report back to the correct client
*/

if (!isServer) exitWith { false };

params [
    ["_requester", objNull, [objNull]]
];

private _owner = 0;
if (!isNull _requester) then { _owner = owner _requester; };
if (_owner <= 0 && { !isNil "remoteExecutedOwner" }) then { _owner = remoteExecutedOwner; };

private _lines = [];
private _push = {
    params ["_ok", "_name", ["_detail", ""], ["_isWarn", false]];
    private _tag = if (_isWarn) then {"WARN"} else { if (_ok) then {"PASS"} else {"FAIL"} };
    private _c = if (_isWarn) then {"#FBBF24"} else { if (_ok) then {"#6EE7B7"} else {"#FF6B6B"} };
    _lines pushBack format ["<t color='%1'>%2</t> <t font='PuristaMedium'>%3</t>", _c, _tag, _name];
    if (_detail isEqualType "" && { _detail isNotEqualTo "" }) then {
        _lines pushBack format ["<t color='#BDBDBD' size='0.9'>%1</t>", _detail];
    };
    _lines pushBack "";
};

// Normalize a mission-relative path so fileExists() works reliably.
private _normPath = {
    params ["_p"];
    if !(_p isEqualType "") exitWith { "" };

    // Robust path normalization without relying on String 'replace' (keeps compatibility).
    // - Convert "/" (47) to "\" (92)
    // - Collapse duplicate "\" runs
    // - Trim trailing "\"
    private _arr = toArray _p;
    private _out = [];
    private _last = -1;

    {
        private _c = _x;
        if (_c == 47) then { _c = 92; }; // "/" -> "\"

        // collapse duplicate backslashes
        if !(_c == 92 && { _last == 92 }) then {
            _out pushBack _c;
            _last = _c;
        };
    } forEach _arr;

    // Trim trailing backslashes
    while { (count _out) > 0 && { (_out select ((count _out) - 1)) == 92 } } do {
        _out deleteAt ((count _out) - 1);
    };

    toString _out
};

// Resolve the SQF path for a given function class.
private _resolveFnPath = {
    params ["_catBase", "_fnCfg", "_fnName"];

    private _base = _catBase;
    private _override = getText (_fnCfg >> "file");
    if (_override isNotEqualTo "") then { _base = _override; };

    _base = [_base] call _normPath;

    if (_base isEqualTo "") exitWith { "" };

    // If 'file' already points to a .sqf, use it directly.
    private _lower = toLower _base;
    if (_lower find ".sqf" == ((count _lower) - 4)) exitWith { _base };

    // Otherwise treat as directory containing fn_<name>.sqf
    format ["%1\fn_%2.sqf", _base, _fnName]
};

_lines pushBack "<t size='1.2' font='PuristaMedium'>SQF Compile Audit</t>";
_lines pushBack format ["<t size='0.9' color='#BDBDBD'>Server time:</t> <t size='0.9'>%1</t>", serverTime];
_lines pushBack "";

private _root = missionConfigFile >> "CfgFunctions" >> "ARC";
private _cats = "true" configClasses _root;

private _total = 0;
private _missing = 0;
private _compiled = 0;

diag_log "[ARC][COMPILE] ===== Compile Audit START =====";
diag_log format ["[ARC][COMPILE] buildStamp=%1", missionNamespace getVariable ["ARC_buildStamp","UNKNOWN"]];

{
    private _cat = _x;
    private _catName = configName _cat;

    private _catBase = getText (_cat >> "file");
    _catBase = [_catBase] call _normPath;

    if (_catBase isEqualTo "") then {
        // Category without a base dir. Skip loudly so it doesn't silently hide coverage gaps.
        [false, _catName, "Category has no 'file' path in CfgFunctions", false] call _push;
        diag_log format ["[ARC][COMPILE][SKIP] category=%1 reason=no file path", _catName];
        continue;
    };

    _lines pushBack format ["<t size='1.05' font='PuristaMedium'>%1</t>", toUpper _catName];

    private _fnClasses = "true" configClasses _cat;
    {
        private _fnCfg = _x;
        private _fnName = configName _fnCfg;

        private _path = [_catBase, _fnCfg, _fnName] call _resolveFnPath;
        _total = _total + 1;

        if (_path isEqualTo "") then {
            _missing = _missing + 1;
            [false, _fnName, "MISSING: could not resolve file path (check CfgFunctions)", false] call _push;
            diag_log format ["[ARC][COMPILE][MISSING] fn=%1 reason=unresolved", _fnName];
        } else {
            private _ok = fileExists _path;
            if (!_ok) then {
                _missing = _missing + 1;
                [false, _fnName, format ["MISSING: %1", _path], false] call _push;
                diag_log format ["[ARC][COMPILE][MISSING] %1", _path];
            } else {
                // Attempt compile. Any syntax errors will show in RPT with line numbers.
                // Pass empty array as _this so params blocks use defaults
                // without "Type Object, expected String" errors.
                [] call compile preprocessFileLineNumbers _path;
                _compiled = _compiled + 1;

                // WARN tag: compiled attempt made; check RPT for syntax errors.
                [true, _fnName, _path, true] call _push;
                diag_log format ["[ARC][COMPILE][OK] %1", _path];
            };
        };
    } forEach _fnClasses;

    _lines pushBack "";
} forEach _cats;

_lines pushBack "<t size='1.05' font='PuristaMedium'>Summary</t>";
_lines pushBack format ["<t size='0.95'>Total functions:</t> <t size='0.95'>%1</t>", _total];
_lines pushBack format ["<t size='0.95'>Compiled attempts:</t> <t size='0.95'>%1</t>", _compiled];
_lines pushBack format ["<t size='0.95'>Missing files:</t> <t size='0.95' color='#FF6B6B'>%1</t>", _missing];
_lines pushBack "";
_lines pushBack "<t size='0.9' color='#BDBDBD'>If a function shows WARN, the mission attempted compilation. Any syntax error details will be in the server RPT with file/line numbers.</t>";

diag_log format ["[ARC][COMPILE] total=%1 compiled=%2 missing=%3", _total, _compiled, _missing];
diag_log "[ARC][COMPILE] ===== Compile Audit END =====";

private _report = _lines joinString "<br/>";
if (_owner > 0) then {
    [_report] remoteExecCall ["ARC_fnc_uiConsoleCompileAuditClientReceive", _owner];
};

true