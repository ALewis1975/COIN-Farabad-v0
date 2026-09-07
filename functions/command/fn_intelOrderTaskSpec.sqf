/* Pure persisted RTB/HOLD view descriptor; no acceptance/closeout side effects. */
params [["_record", [], [[]]]];
if (count _record < 7) exitWith {[]};
_record params ["","","_status","_type","_groupId","_data","_meta"];
if (!(_status isEqualType "") || {!(_type isEqualType "")} || {!(_groupId isEqualType "")}) exitWith {[]};
if (!((toUpper _status) isEqualTo "ACCEPTED") || {_groupId isEqualTo ""}) exitWith {[]};
_type = toUpper _type;
if (!(_type in ["RTB","HOLD"])) exitWith {[]};
private _get = {
    params ["_pairs","_key","_default"];
    if (!(_pairs isEqualType [])) exitWith {_default};
    private _value = _default;
    {if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualTo _key}) exitWith {_value = _x select 1;};} forEach _pairs;
    _value
};
private _taskId = [_data,"taskId",""] call _get;
private _pos = [_data,if (_type isEqualTo "RTB") then {"destPos"} else {"holdPos"},[]] call _get;
if (!(_taskId isEqualType "") || {_taskId isEqualTo ""} || {!(_pos isEqualType [])} || {count _pos < 2}) exitWith {[]};
if (!((_pos select 0) isEqualType 0) || {!((_pos select 1) isEqualType 0)}) exitWith {[]};
_pos = +_pos;
if (count _pos < 3) then {_pos pushBack 0;};
if (!((_pos select 2) isEqualType 0)) then {_pos set [2,0];};
private _note = [_meta,"note",""] call _get;
if (!(_note isEqualType "")) then {_note = "";};
private _noteText = if (_note isEqualTo "") then {""} else {format ["\n\nTOC Note: %1",_note]};
private _title = "HOLD: Maintain Position";
private _desc = "Hold at current position until further notice." + _noteText;
private _icon = "HOLD";
if (_type isEqualTo "RTB") then
{
    private _purpose = [_data,"purpose","REFIT"] call _get;
    private _label = [_data,"destLabel","Base"] call _get;
    if (!(_purpose isEqualType "")) then {_purpose = "REFIT";};
    if (!(_label isEqualType "")) then {_label = "Base";};
    _title = format ["RTB: %1 (%2)",_label,_purpose];
    _desc = format ["Return to %1 to %2.%3\n\nTip: If you only need ammo/fuel/medical, consider requesting resupply in-place via support modules/vehicles instead of RTB.",_label,_purpose,_noteText];
    if ((toUpper _purpose) isEqualTo "INTEL") then {_desc = _desc + "\n\nOn arrival, use the Intel Debrief station to submit your debrief and complete the order.";};
    _icon = "MOVE";
};
[_taskId,_groupId,_title,_desc,_pos,_icon]
