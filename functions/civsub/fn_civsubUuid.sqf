/*
    ARC_fnc_civsubUuid

    Generates a best-effort GUID-like string (not cryptographic).
    Format: XXXXXXXX-XXXX-4XXX-YXXX-XXXXXXXXXXXX
*/

private _hex = {
    params [["_n", 0, [0]]];
    private _s = "";
    for "_i" from 1 to _n do
    {
        _s = _s + (toString [48 + floor random 10]);
    };
    _s
};

private _randHex4 = {
    private _chars = "0123456789abcdef";
    private _out = "";
    for "_i" from 1 to 4 do
    {
        _out = _out + (_chars select [floor random 16, 1]);
    };
    _out
};

private _chars = "0123456789abcdef";
private _hexN = {
    params [["_len", 0, [0]]];
    private _out = "";
    for "_i" from 1 to _len do
    {
        _out = _out + (_chars select [floor random 16, 1]);
    };
    _out
};

private _a = [8] call _hexN;
private _b = [4] call _hexN;
private _c = "4" + ([3] call _hexN);
private _yChars = "89ab";
private _d = (_yChars select [floor random 4, 1]) + ([3] call _hexN);
private _e = [12] call _hexN;

format ["%1-%2-%3-%4-%5", _a, _b, _c, _d, _e]
