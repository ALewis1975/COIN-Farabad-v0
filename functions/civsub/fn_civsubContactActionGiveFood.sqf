/*
    ARC_fnc_civsubContactActionGiveFood

    Dialog-safe server-side aid action: give food/rations.
    - Validates actor has an allowed food item.
    - Consumes 1 item on success.
    - Emits CIVSUB delta: AID_RATIONS.
    - Returns HTML for CIV Interact dialog.

    Params:
      0: actor (object)
      1: civ (object)

    Returns:
      [ok(bool), html(string)]

    Config overrides:
      missionNamespace getVariable ["ARC_civsubAidFoodItems", <array>]
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

private _did = _civ getVariable ["civsub_districtId", ""]; 
if (_did isEqualTo "") exitWith {[false, "<t size='0.9'>No district ID for this civilian.</t>"]};

// Default item list is intentionally broad; override via missionNamespace to match your modset.
private _defaults = [
    
    "ACE_Humanitarian_Ration_Item",
    "ACE_Sunflower_Seeds_Item",
    "ACE_MRE_BeefStew",
    "ACE_MRE_ChickenTikkaMasala",
    "ACE_MRE_SteakVegetables",
    "ACE_MRE_CreamChickenSoup",
    "ACE_MRE_MeatballsPasta",
    "ACE_MRE_LambCurry",
    "ACE_MRE_ChickenHerb",
    "ACE_Banana",
    "ACE_Can_Franta",
    "ACE_Can_RedGull"
];

private _allowed = missionNamespace getVariable ["ARC_civsubAidFoodItems", _defaults];
if !(_allowed isEqualType []) then { _allowed = _defaults; };

private _kwDefaults = ["humanitarian","sunflower"];
private _kw = missionNamespace getVariable ["ARC_civsubAidFoodKeywords", _kwDefaults];
if !(_kw isEqualType []) then { _kw = _kwDefaults; };


// Inventory check across items + magazines (some mod consumables are magazines)
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
        _list = _list + format ["<br/><t size='0.82'>• %1</t>", _x];
    } forEach _allowed;

    private _html = "<t size='0.95' color='#CFE8FF'>GIVE FOOD</t><br/>" +
        "<t size='0.9'>No approved food item found in your inventory.</t><br/>" +
        "<t size='0.85'>Allowed items (override with missionNamespace ARC_civsubAidFoodItems). Also accepted by keyword match (ARC_civsubAidFoodKeywords):</t>" + _list;

    [false, _html]
};

// Consume one unit
if (_found in (items _actor)) then {
    _actor removeItem _found;
} else {
    if (_found in (magazines _actor)) then {
        _actor removeMagazine _found;
    } else {
        // fallback: try removeItem anyway
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

private _gain = missionNamespace getVariable ["ARC_civsubAidFoodGain", 20];
if !(_gain isEqualType 0) then { _gain = 20; };

private _sat1 = (_sat0 + _gain) min 100;
private _satDelta = _sat1 - _sat0;

private _opDelta = round (_satDelta * 0.25);
if (_sat0 < 30) then { _opDelta = _opDelta + 2; };

private _out1 = (_out0 + _opDelta) min 100;

_civ setVariable ["civsub_need_satiation", _sat1, true];
_civ setVariable ["civsub_need_hydration", _hyd0, true];
_civ setVariable ["civsub_outlook_blufor", _out1, true];

private _payload = createHashMapFromArray [
    ["civ_uid", _civUid],
    ["item", _found],
    ["amount", 1],
    ["method", "INTERACT"],
    ["need_satiation_before", _sat0],
    ["need_satiation_after", _sat1],
    ["need_hydration_before", _hyd0],
    ["need_hydration_after", _hyd0],
    ["outlook_before", _out0],
    ["outlook_after", _out1],
    ["outlook_delta", _opDelta]
];

// Emit CIVSUB delta (validated and applied inside EmitDelta)
[_did, "AID_RATIONS", "AID", _payload, _actorUid] call ARC_fnc_civsubEmitDelta;

private _html = format [
    "<t size='0.95' color='#CFE8FF'>GIVE FOOD</t><br/>" +
    "<t size='0.9'>Food provided.</t><br/>" +
    "<t size='0.85'>Item: %1</t><br/>" +
    "<t size='0.85'>Needs: Food +%2 (now %3/100)</t><br/>" +
    "<t size='0.85'>Outlook(BLU): +%4 (now %5/100)</t>",
    _found,
    _satDelta,
    _sat1,
    _opDelta,
    _out1
];

[true, _html]
