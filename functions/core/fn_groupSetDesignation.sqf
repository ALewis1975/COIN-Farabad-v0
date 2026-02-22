/*
    Server: assign an editor-style unit designation to a spawned group.

    Example:
        "C/2-325 AIR | REDFALCON 3-1-1"

    Format:
        CompanyLetter / Battalion-Regiment Type | Callsign Company-Platoon-Squad

    Notes:
      - Uses persistent counters so each spawned group gets a unique designation.
      - Defaults can be overridden via missionNamespace variables:
          ARC_unitBnReg, ARC_unitType, ARC_unitCallsign,
          ARC_unitCompanyLetters, ARC_unitMaxPlatoons, ARC_unitMaxSquads
*/

if (!isServer) exitWith {""};

params [
    ["_grp", grpNull],
    ["_role", ""]
];

if (isNull _grp) exitWith {""};

// Prevent double-assignment (convoy watchdogs can reconstruct groups)
if (_grp getVariable ["ARC_hasDesignation", false]) exitWith { groupId _grp };

// Prefer a per-group profile (set by spawners for realism) over global defaults.
// Profile format:
//   [bnReg, unitType, callsign, companyDesignators, maxPlatoons, maxSquads]
private _profile = _grp getVariable ["ARC_designationProfile", []];

private _bnReg = missionNamespace getVariable ["ARC_unitBnReg", "2-325"];
private _uType = missionNamespace getVariable ["ARC_unitType", "AIR"];
private _callsign = missionNamespace getVariable ["ARC_unitCallsign", "REDFALCON"];

private _letters = missionNamespace getVariable ["ARC_unitCompanyLetters", ["A","B","C","D"]];
private _maxPlt = missionNamespace getVariable ["ARC_unitMaxPlatoons", 4];
private _maxSq  = missionNamespace getVariable ["ARC_unitMaxSquads", 4];

if (_profile isEqualType [] && { (count _profile) >= 3 }) then
{
    _profile params [
        ["_pBnReg", ""],
        ["_pType", ""],
        ["_pCall", ""],
        ["_pCompanies", []],
        ["_pMaxPlt", -1],
        ["_pMaxSq", -1]
    ];

    if (_pBnReg isEqualType "" && { _pBnReg isNotEqualTo "" }) then { _bnReg = _pBnReg; };
    if (_pType isEqualType "" && { _pType isNotEqualTo "" }) then { _uType = _pType; };
    if (_pCall isEqualType "" && { _pCall isNotEqualTo "" }) then { _callsign = _pCall; };
    if (_pCompanies isEqualType [] && { (count _pCompanies) > 0 }) then { _letters = _pCompanies; };
    if (_pMaxPlt isEqualType 0 && { _pMaxPlt > 0 }) then { _maxPlt = _pMaxPlt; };
    if (_pMaxSq isEqualType 0 && { _pMaxSq > 0 }) then { _maxSq = _pMaxSq; };
};

if (!(_letters isEqualType []) || { (count _letters) <= 0 }) then { _letters = ["A","B","C","D"]; };

if (!(_maxPlt isEqualType 0)) then { _maxPlt = 4; };
_maxPlt = (_maxPlt max 1) min 9;

if (!(_maxSq isEqualType 0)) then { _maxSq = 4; };
_maxSq = (_maxSq max 1) min 9;

// Persistent counters (stored in ARC_state)
private _cIdx = ["unitDesignation_companyIdx", 0] call ARC_fnc_stateGet;
private _plt = ["unitDesignation_platoonNum", 1] call ARC_fnc_stateGet;
private _sq  = ["unitDesignation_squadNum", 1] call ARC_fnc_stateGet;

if (!(_cIdx isEqualType 0)) then { _cIdx = 0; };
if (!(_plt isEqualType 0)) then { _plt = 1; };
if (!(_sq isEqualType 0)) then { _sq = 1; };

_cIdx = _cIdx max 0;
_plt  = (_plt max 1) min _maxPlt;
_sq   = (_sq max 1) min _maxSq;

private _cSlot = _cIdx % (count _letters);
private _companyLetter = _letters # _cSlot;
private _companyNum = _cSlot + 1;

// Build group name
private _name = format ["%1/%2 %3 | %4 %5-%6-%7", _companyLetter, _bnReg, _uType, _callsign, _companyNum, _plt, _sq];

_grp setGroupIdGlobal [_name];
_grp setVariable ["ARC_hasDesignation", true, true];

// Advance counters (squad -> platoon -> company)
_sq = _sq + 1;
if (_sq > _maxSq) then
{
    _sq = 1;
    _plt = _plt + 1;
};

if (_plt > _maxPlt) then
{
    _plt = 1;
    _cIdx = _cIdx + 1;
};

["unitDesignation_companyIdx", _cIdx] call ARC_fnc_stateSet;
["unitDesignation_platoonNum", _plt] call ARC_fnc_stateSet;
["unitDesignation_squadNum", _sq] call ARC_fnc_stateSet;

_name
