/* Pure admission: preserve all live/unknown/pending records; evict terminal history only. */
params [["_orders", [], [[]]], ["_cap", 30, [0]], ["_pendingId", "", [""]]];
_cap = (floor _cap) max 1;
private _retained = +_orders;
private _evicted = [];
private _possible = true;
while {count _retained >= _cap && {_possible}} do
{
    private _idx = -1;
    {
        if (_x isEqualType [] && {count _x >= 7}) then
        {
            private _id = _x select 0;
            private _status = _x select 2;
            if (_id isEqualType "" && {_status isEqualType ""} && {!(_id isEqualTo _pendingId)} &&
                {(toUpper _status) in ["COMPLETED","CANCELED","FAILED"]}) exitWith {_idx = _forEachIndex;};
        };
    } forEach _retained;
    if (_idx < 0) then {_possible = false;}
    else {_evicted pushBack (_retained deleteAt _idx);};
};
if (!_possible) exitWith {[false,+_orders,[]]};
[true,_retained,_evicted]
