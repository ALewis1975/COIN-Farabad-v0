/*
    ARC_fnc_startdispCaptureGroup
    Server-side group disposition capture for STARTDISP v1.
*/

if (!isServer) exitWith { [] };
params [["_caller", objNull]];
if (isNull _caller) exitWith { [] };

private _grp = group _caller;
if (isNull _grp) exitWith { [] };
private _units = units _grp;
private _aliveUnits = _units select { alive _x };

private _incClass = {
    params ["_rows", "_cls", ["_maxRows", 80]];
    if (!(_cls isEqualType "") || { _cls isEqualTo "" }) exitWith { _rows };
    private _idx = -1;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _cls }) exitWith { _idx = _forEachIndex; }; } forEach _rows;
    if (_idx < 0) then
    {
        if ((count _rows) < _maxRows) then { _rows pushBack [_cls, 1]; };
    }
    else
    {
        private _r = _rows select _idx;
        _r set [1, (_r select 1) + 1];
        _rows set [_idx, _r];
    };
    _rows
};

private _weapons = [];
private _launchers = [];
private _medical = [];
private _tools = [];
private _radios = [];
private _special = [];
private _smallArms = [];
private _mg = [];
private _launcherRounds = [];
private _grenades = [];
private _smoke = [];
private _explosives = [];

{
    private _u = _x;
    {
        private _cls = _x;
        if (_cls isEqualTo "") then { continue; };
        private _isLauncher = false;
        if (isClass (configFile >> "CfgWeapons" >> _cls)) then
        {
            private _type = getNumber (configFile >> "CfgWeapons" >> _cls >> "type");
            _isLauncher = (_type == 4) || { _type == 16 };
        };
        if (_isLauncher) then { _launchers = [_launchers, _cls, 40] call _incClass; } else { _weapons = [_weapons, _cls, 60] call _incClass; };
    } forEach (weapons _u);

    {
        private _cls = _x;
        private _uCls = toUpper _cls;
        if ((_uCls find "ACE_" >= 0) || { (_uCls find "BANDAGE" >= 0) } || { (_uCls find "MORPHINE" >= 0) || { (_uCls find "EPI" >= 0) } }) then
        {
            _medical = [_medical, _cls, 60] call _incClass;
        }
        else
        {
            if ((_uCls find "TOOL" >= 0) || { (_uCls find "KIT" >= 0) || { (_uCls find "DETECTOR" >= 0) } }) then
            {
                _tools = [_tools, _cls, 50] call _incClass;
            }
            else
            {
                if ((_uCls find "RADIO" >= 0) || { (_uCls find "ACRE" >= 0) || { (_uCls find "TFAR" >= 0) } }) then
                {
                    _radios = [_radios, _cls, 40] call _incClass;
                }
                else
                {
                    _special = [_special, _cls, 80] call _incClass;
                };
            };
        };
    } forEach (items _u);

    {
        private _cls = _x;
        private _uCls = toUpper _cls;
        if ((_uCls find "SMOKE" >= 0) || { (_uCls find "SMK" >= 0) }) then
        {
            _smoke = [_smoke, _cls, 50] call _incClass;
        }
        else
        {
            if ((_uCls find "GRENADE" >= 0) || { (_uCls find "HANDGRENADE" >= 0) }) then
            {
                _grenades = [_grenades, _cls, 50] call _incClass;
            }
            else
            {
                if ((_uCls find "ROCKET" >= 0) || { (_uCls find "MISSILE" >= 0) || { (_uCls find "RPG" >= 0) || { (_uCls find "MAAWS" >= 0) } } }) then
                {
                    _launcherRounds = [_launcherRounds, _cls, 50] call _incClass;
                }
                else
                {
                    if ((_uCls find "SATCHEL" >= 0) || { (_uCls find "MINE" >= 0) || { (_uCls find "DEMO" >= 0) || { (_uCls find "CHARGE" >= 0) } } }) then
                    {
                        _explosives = [_explosives, _cls, 50] call _incClass;
                    }
                    else
                    {
                        if ((_uCls find "200" >= 0) || { (_uCls find "100" >= 0) || { (_uCls find "MG" >= 0) } }) then
                        {
                            _mg = [_mg, _cls, 60] call _incClass;
                        }
                        else
                        {
                            _smallArms = [_smallArms, _cls, 80] call _incClass;
                        };
                    };
                };
            };
        };
    } forEach (magazines _u);
} forEach _aliveUnits;

private _vehicles = [];
{
    private _veh = objectParent _x;
    if (!isNull _veh) then { _vehicles pushBackUnique _veh; };
} forEach _aliveUnits;

{
    private _veh = _x;
    private _crew = crew _veh;
    private _owned = false;
    { if ((group _x) isEqualTo _grp) exitWith { _owned = true; }; } forEach _crew;
    if (_owned) then { _vehicles pushBackUnique _veh; };
} forEach ((getPosATL _caller) nearEntities [["LandVehicle", "Air", "Ship"], 40]);

private _vehRows = [];
private _vehicleAmmo = [];
{
    private _veh = _x;
    private _cls = typeOf _veh;
    private _display = _cls;
    if (isClass (configFile >> "CfgVehicles" >> _cls)) then { _display = getText (configFile >> "CfgVehicles" >> _cls >> "displayName"); };
    _vehRows pushBack [
        ["class", _cls],
        ["display", _display],
        ["fuel", fuel _veh],
        ["damage", damage _veh],
        ["can_move", canMove _veh],
        ["crew_count", count (crew _veh)],
        ["pos", getPosATL _veh]
    ];
    {
        if (_x isEqualType [] && { (count _x) >= 2 }) then
        {
            _vehicleAmmo = [_vehicleAmmo, _x select 0, 60] call _incClass;
        };
    } forEach (magazinesAllTurrets _veh);
} forEach _vehicles;

private _wounded = count (_aliveUnits select { damage _x > 0.2 });
private _uncon = count (_aliveUnits select { (lifeState _x) in ["INCAPACITATED", "UNCONSCIOUS"] });

[
    ["capture_pos", getPosATL _caller],
    ["capture_grid", mapGridPosition _caller],
    ["personnel", [["present", count _units], ["effective", (count _aliveUnits) - _uncon], ["alive", count _aliveUnits], ["wounded", _wounded], ["unconscious", _uncon]]],
    ["vehicles", [["count", count _vehicles], ["records", _vehRows]]],
    ["equipment", [["weapons", _weapons], ["launchers", _launchers], ["medical", _medical], ["tools", _tools], ["radios", _radios], ["special", _special]]],
    ["ammo", [["small_arms", _smallArms], ["mg", _mg], ["launcher", _launcherRounds], ["grenades", _grenades], ["smoke", _smoke], ["explosives", _explosives], ["vehicle_ammo", _vehicleAmmo]]]
]
