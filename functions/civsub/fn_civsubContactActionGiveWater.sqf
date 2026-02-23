/*
    ARC_fnc_civsubContactActionGiveWater

    Dialog-safe server-side aid action: give water.
    - Validates actor has an allowed water item.
    - Consumes 1 item on success.
    - Emits CIVSUB delta: AID_WATER.
    - Returns HTML for CIV Interact dialog.

    Params:
      0: actor (object)
      1: civ (object)

    Returns:
      [ok(bool), html(string)]

    Config overrides:
      missionNamespace getVariable ["ARC_civsubAidWaterItems", <array>]
*/

if (!isServer) exitWith {[false, "<t size='0.9'>Server-only action.</t>"]};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {[false, "<t size='0.9'>CIVSUB not enabled.</t>"]};

params [
    ["_actor", objNull, [objNull]],
    ["_civ", objNull, [objNull]]
];

if (isNull _actor || {isNull _civ}) exitWith {[false, "<t size='0.9'>Invalid target.</t>"]};
if !(isPlayer _actor) exitWith {[false, "<t size='0.9'>Invalid actor.</t>"]};
if !(_civ getVariable ["civsub_v1_isCiv", false]) exitWith {[false, "<t size='0.9'>Not a CIVSUB civilian.</t>"]};

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

private _did = _civ getVariable ["civsub_districtId", ""];
if (_did isEqualTo "") exitWith {[false, "<t size='0.9'>No district ID for this civilian.</t>"]};

private _defaults = [
    "ACE_WaterBottle",
    "ACE_WaterBottle_Empty",
    "ACE_Canteen",
    "ACE_Canteen_Empty",
    "ACE_Canteen_Half",
    "ACE_Can_RedGull"
];

private _allowed = missionNamespace getVariable ["ARC_civsubAidWaterItems", _defaults];
if !(_allowed isEqualType []) then { _allowed = _defaults; };

private _kwDefaults = ["water","canteen","bottle"];
private _kw = missionNamespace getVariable ["ARC_civsubAidWaterKeywords", _kwDefaults];
if !(_kw isEqualType []) then { _kw = _kwDefaults; };


private _inv = (items _actor) + (magazines _actor);
private _found = "";

// 1) direct allow-list match
{
    if (_x in _inv) exitWith { _found = _x; };
} forEach _allowed;

// 2) keyword match (displayName) to catch mod items like "Humanitarian Ration" and "Sunflower Seeds"
if (_found isEqualTo "") then {
    {
        private _cls = _x;
        private _dn = getText (configFile >> "CfgWeapons" >> _cls >> "displayName");
        if (_dn isEqualTo "") then { _dn = getText (configFile >> "CfgMagazines" >> _cls >> "displayName"); };

        if !(_dn isEqualTo "") then {
            private _dnL = toLower _dn;
            {
                private _k = toLower _x;
                if ((_dnL find _k) >= 0) exitWith { _found = _cls; };
            } forEach _kw;
        };

        if !(_found isEqualTo "") exitWith {};
    } forEach _inv;
};

if (_found isEqualTo "") exitWith {
    private _list = "";
    {
        _list = _list + format ["<br/><t size='0.85'>• %1</t>", _x];
    } forEach _allowed;

    [false, format [
        "<t size='0.95' color='#CFE8FF'>GIVE WATER</t><br/>" +
        "<t size='0.9'>You don't have any approved water items.</t><br/>" +
        "<t size='0.85'>Allowed (configurable via ARC_civsubAidWaterItems):</t>%1",
        _list
    ]]
};

// Consume one unit
if (_found in (items _actor)) then {
    _actor removeItem _found;
} else {
    if (_found in (magazines _actor)) then {
        _actor removeMagazine _found;
    } else {
        _actor removeItem _found;
    };
};

private _actorUid = getPlayerUID _actor;

// Ensure the civilian has a stable identity UID (used elsewhere in CIVSUB)
private _civUid = _civ getVariable ["civ_uid", ""]; 
if (_civUid isEqualTo "") then {
    _civUid = [_did] call ARC_fnc_civsubIdentityGenerateUid;
    _civ setVariable ["civ_uid", _civUid, true];
};


// Apply needs + BLUFOR outlook (server-authoritative on civ object)
private _sat0 = _civ getVariable ["civsub_need_satiation", -1];
if !(_sat0 isEqualType 0) then { _sat0 = -1; };
if (_sat0 < 0) then { _sat0 = 30 + floor (random 41); };

private _hyd0 = _civ getVariable ["civsub_need_hydration", -1];
if !(_hyd0 isEqualType 0) then { _hyd0 = -1; };
if (_hyd0 < 0) then { _hyd0 = 30 + floor (random 41); };

private _out0 = _civ getVariable ["civsub_outlook_blufor", -1];
if !(_out0 isEqualType 0) then { _out0 = -1; };
if (_out0 < 0) then { _out0 = 45 + floor (random 21); };

private _gain = missionNamespace getVariable ["ARC_civsubAidWaterGain", 20];
if !(_gain isEqualType 0) then { _gain = 20; };

private _hyd1 = (_hyd0 + _gain) min 100;
private _hydDelta = _hyd1 - _hyd0;

private _opDelta = round (_hydDelta * 0.25);
if (_hyd0 < 30) then { _opDelta = _opDelta + 2; };

private _out1 = (_out0 + _opDelta) min 100;

_civ setVariable ["civsub_need_satiation", _sat0, true];
_civ setVariable ["civsub_need_hydration", _hyd1, true];
_civ setVariable ["civsub_outlook_blufor", _out1, true];

private _payload = [[
    ["civ_uid", _civUid],
    ["item", _found],
    ["amount", 1],
    ["method", "INTERACT"],
    ["need_satiation_before", _sat0],
    ["need_satiation_after", _sat0],
    ["need_hydration_before", _hyd0],
    ["need_hydration_after", _hyd1],
    ["outlook_before", _out0],
    ["outlook_after", _out1],
    ["outlook_delta", _opDelta]
]] call _hmCreate;

// Emit CIVSUB delta (validated and applied inside EmitDelta)
[_did, "AID_WATER", "AID", _payload, _actorUid] call ARC_fnc_civsubEmitDelta;

private _html = format [
    "<t size='0.95' color='#CFE8FF'>GIVE WATER</t><br/>" +
    "<t size='0.9'>Water provided.</t><br/>" +
    "<t size='0.85'>Item: %1</t><br/>" +
    "<t size='0.85'>Needs: Water +%2 (now %3/100)</t><br/>" +
    "<t size='0.85'>Outlook(BLU): +%4 (now %5/100)</t>",
    _found,
    _hydDelta,
    _hyd1,
    _opDelta,
    _out1
];

[true, _html]
