/*
    ARC_fnc_casreqBuildId

    Build CASREQ id using policy CAS:Dxx:nnnnnn.

    Params:
      0: districtId (STRING, expected D01..D99)

    Returns:
      STRING casreq_id
*/

if (!isServer) exitWith {""};

params [
    ["_districtId", "D00", [""]]
];

private _trimFn = compile "params ['_s']; trim _s";
private _district = toUpper ([_districtId] call _trimFn);
if (_district isEqualTo "") then { _district = "D00"; };
if ((count _district) < 3) then { _district = "D00"; };
_district = format ["D%1", (_district select [1, 2])];

private _seq = ["casreq_v1_seq", 0] call ARC_fnc_stateGet;
if (!(_seq isEqualType 0) || { _seq < 0 }) then { _seq = 0; };
_seq = _seq + 1;
["casreq_v1_seq", _seq] call ARC_fnc_stateSet;

private _seqStr = str _seq;
if ((count _seqStr) > 6) then {
    diag_log format ["[ARC][WARN] ARC_fnc_casreqBuildId: seq exceeds 6 digits, truncating to last 6 (collision risk) seq=%1", _seq];
    _seqStr = _seqStr select [(count _seqStr) - 6, 6];
};
while { (count _seqStr) < 6 } do { _seqStr = "0" + _seqStr; };

format ["CAS:%1:%2", _district, _seqStr]
