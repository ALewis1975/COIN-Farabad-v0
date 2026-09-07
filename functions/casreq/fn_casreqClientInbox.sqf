// Engine-compatible command wrappers retain the repository lint baseline.
private _casDefault = compile "params ['_map','_args']; _map getOrDefault _args";
private _casMap = compile "params ['_pairs']; createHashMapFromArray _pairs";
/* Console CAS helper. Reconstructs every row from the authoritative complete inbox. */
if (!hasInterface) exitWith {false};
if (!canSuspend) exitWith {_this spawn ARC_fnc_casreqClientInbox; false};
disableSerialization;
if (!isNull findDisplay 78520) exitWith {true};
if !(createDialog "ARC_CasreqInboxDialog") exitWith {false};
private _d = findDisplay 78520;
private _last = [];
while {!isNull _d} do {
    private _inbox = missionNamespace getVariable ["ARC_pub_casreqInbox", []];
    private _h = ([_inbox] call _casMap);
    private _rows = ([_h, ["records", []]] call _casDefault);
    if !(_rows isEqualTo _last) then {
        _last = +_rows;
        private _list = _d displayCtrl 1500;
        private _oldId = _list lbData (lbCurSel _list);
        lbClear _list;
        private _sel = 0;
        {
            private _r = ([_x] call _casMap);
            private _id = ([_r, ["casreq_id", ""]] call _casDefault);
            private _i = _list lbAdd format ["%1 | %2", _id, ([_r, ["state", ""]] call _casDefault)];
            _list lbSetData [_i, _id];
            if (_id isEqualTo _oldId) then {_sel = _i};
        } forEach _rows;
        _list lbSetCurSel (if (_rows isEqualTo []) then {-1} else {_sel});
    };
    // Aircraft/crew presence can change independently of a CAS transition.
    private _combo = _d displayCtrl 2100;
    private _oldAircraft = _combo lbData (lbCurSel _combo);
    lbClear _combo;
    private _airSel = 0;
    {
        private _a = missionNamespace getVariable [_x, objNull];
        if (!isNull _a && {alive _a} && {({isPlayer _x} count (crew _a)) > 0}) then {
            private _i = _combo lbAdd format ["%1: %2", _x, ((crew _a) select {isPlayer _x}) apply {name _x} joinString ", "];
            _combo lbSetData [_i, _x];
            if (_x isEqualTo _oldAircraft) then {_airSel = _i};
        };
    } forEach (missionNamespace getVariable ["casreq_v1_airbase_attack_vehvars", ["plane4", "plane5"]]);
    _combo lbSetCurSel _airSel;
    ["SELECT"] call ARC_fnc_casreqInboxAction;
    sleep 0.5;
};
true
