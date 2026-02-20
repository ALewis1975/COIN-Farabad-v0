/*
    ARC_fnc_clientNotifyGate

    Client-side notification dedupe/cooldown gate.

    Params:
      0: STRING key - namespace-safe cooldown key (caller-owned)
      1: NUMBER cooldownSeconds - suppression window in seconds
      2: ANY messageHashOrText - message fingerprint input (text/hash/value)

    Returns:
      BOOL - true when caller should send notification, false when suppressed
*/

if (!hasInterface) exitWith {false};

params [
    ["_key", ""],
    ["_cooldownS", 0],
    ["_msg", ""]
];

if (!(_key isEqualType "")) then { _key = str _key; };
_key = trim _key;
if (_key isEqualTo "") exitWith {true};

if (!(_cooldownS isEqualType 0)) then { _cooldownS = 0; };
_cooldownS = _cooldownS max 0;

private _msgSig = if (_msg isEqualType "") then { _msg } else { str _msg };

private _store = uiNamespace getVariable ["ARC_clientNotifyGateStore", createHashMap];
if !(_store isEqualType createHashMap) then { _store = createHashMap; };

private _now = diag_tickTime;
private _entry = _store getOrDefault [_key, []];

private _lastAt = -1;
private _lastSig = "";
if (_entry isEqualType [] && { (count _entry) >= 2 }) then
{
    _lastAt = _entry # 0;
    _lastSig = _entry # 1;
};

private _allow = true;
if (_lastAt isEqualType 0 && { _lastAt >= 0 } && { _lastSig isEqualTo _msgSig }) then
{
    _allow = ((_now - _lastAt) >= _cooldownS);
};

if (_allow) then
{
    _store set [_key, [_now, _msgSig]];
    uiNamespace setVariable ["ARC_clientNotifyGateStore", _store];
};

_allow
