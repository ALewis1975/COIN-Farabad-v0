/*
    ARC_fnc_medicalOnCasualty

    Server-only: handle a BLUFOR or civilian KIA event.

    Decrements baseMed by a configurable step and increments the appropriate
    casualty counter. Called from the EntityKilled handler registered in
    ARC_fnc_medicalInit.

    Params:
      0: OBJECT - killed entity
      1: SIDE   - side of the entity (west = baseCasualties; civilian = civCasualties)

    Returns: BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_entity", objNull, [objNull]],
    ["_side",   sideEmpty]
];

if (isNull _entity) exitWith {false};

// Configurable shock drop per casualty (tuneable via missionNamespace)
private _step = missionNamespace getVariable ["ARC_medCasualtyDrop", 0.04];
if (!(_step isEqualType 0)) then { _step = 0.04; };
_step = (_step max 0) min 0.20;

// Update casualty counter
if (_side isEqualTo west) then
{
    private _bCas = ["baseCasualties", 0] call ARC_fnc_stateGet;
    if (!(_bCas isEqualType 0)) then { _bCas = 0; };
    _bCas = _bCas + 1;
    ["baseCasualties", _bCas] call ARC_fnc_stateSet;
    diag_log format ["[ARC][MEDICAL] medicalOnCasualty: BLUFOR KIA — baseCasualties=%1", _bCas];
}
else
{
    private _cCas = ["civCasualties", 0] call ARC_fnc_stateGet;
    if (!(_cCas isEqualType 0)) then { _cCas = 0; };
    _cCas = _cCas + 1;
    ["civCasualties", _cCas] call ARC_fnc_stateSet;
    diag_log format ["[ARC][MEDICAL] medicalOnCasualty: Civilian KIA — civCasualties=%1", _cCas];
};

// Apply shock drop to baseMed
private _med = ["baseMed", 0.57] call ARC_fnc_stateGet;
if (!(_med isEqualType 0)) then { _med = 0.57; };
_med = (_med - _step) max 0;
["baseMed", _med] call ARC_fnc_stateSet;

// Replicate immediately so clients see updated value (not waiting for next tick)
missionNamespace setVariable ["ARC_pub_baseMed", _med, true];

diag_log format ["[ARC][MEDICAL] medicalOnCasualty: baseMed drop by %1 → %2", _step, _med];

// When baseMed drops below critical threshold, log a warning so TOC can act
private _critical = missionNamespace getVariable ["ARC_medCriticalThreshold", 0.18];
if (!(_critical isEqualType 0)) then { _critical = 0.18; };
if (_med < _critical) then
{
    diag_log format ["[ARC][WARN] medicalOnCasualty: baseMed=%1 below critical threshold %2 — LOGI_MEDICAL incident may be generated.", _med, _critical];
};

true
