/*
    ARC_preflightMapClickCompile.sqf

    Dev-only preflight for map-click lifecycle scripts.
    Run from debug console before MP playtest:
      [] execVM "dev\\ARC_preflightMapClickCompile.sqf";
*/

private _files = [
    "functions\\command\\fn_mapClick_arm.sqf",
    "functions\\command\\fn_mapClick_onClick.sqf",
    "functions\\command\\fn_mapClick_submit.sqf",
    "functions\\command\\fn_mapClick_disarm.sqf"
];

{
    private _path = _x;
    try
    {
        compileFinal preprocessFileLineNumbers _path;
        diag_log format ["[FARABAD][DEV][PREFLIGHT] file=%1 result=OK", _path];
    }
    catch
    {
        diag_log format ["[FARABAD][DEV][PREFLIGHT] file=%1 result=FAIL error=%2", _path, _exception];
    };
} forEach _files;
