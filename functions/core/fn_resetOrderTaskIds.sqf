/* Pure explicit-ID collection shared by reset and terminal-history eviction. */
params [["_orders", [], [[]]]];
private _ids = [];
{
    if (_x isEqualType [] && {count _x >= 6}) then
    {
        private _data = _x select 5;
        if (_data isEqualType []) then
        {
            {
                if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualTo "taskId"}) then
                {
                    private _id = _x select 1;
                    if (_id isEqualType "" && {!(_id isEqualTo "")}) then {_ids pushBackUnique _id;};
                };
            } forEach _data;
        };
    };
} forEach _orders;
_ids
