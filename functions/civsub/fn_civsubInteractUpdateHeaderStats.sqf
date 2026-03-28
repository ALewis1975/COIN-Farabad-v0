/*
    ARC_fnc_civsubInteractUpdateHeaderStats

    Client-side: formats and writes the CIV Interact dialog header.
    Adds:
      - Player on-hand Food/Water counts (based on allowed lists + keyword matching)
      - CIV needs (Satiation/Hydration) and BLUFOR outlook (0-100)

    Params:
      0: display (DISPLAY)
      1: snapshot (HashMap)

    Returns: bool
*/

if (!hasInterface) exitWith { true };

params [
    ["_d", displayNull, [displayNull]],
    ["_snap", createHashMap, [createHashMap]]
];

if (isNull _d) exitWith { true };

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _hdr = _d displayCtrl 78392;
if (isNull _hdr) exitWith { true };

// ----- Snapshot fields -----
private _name = [_snap, "name_display", "Unknown"] call _hg;
private _serial = [_snap, "passport_serial", ""] call _hg;
private _did = [_snap, "districtId", ""] call _hg;
private _det = [_snap, "detained", false] call _hg;
private _known = [_snap, "known", false] call _hg;

private _sat = [_snap, "need_satiation", -1] call _hg;
private _hyd = [_snap, "need_hydration", -1] call _hg;
private _out = [_snap, "outlook_blufor", -1] call _hg;

// ----- Player inventory counts -----
private _inv = (items player) + (magazines player);

// Food allowed + keywords
private _foodDefaults = [
    "ACE_Humanitarian_Ration_Item",
    "ACE_Sunflower_Seeds_Item",
    "ACE_MRE_BeefStew","ACE_MRE_ChickenTikkaMasala","ACE_MRE_SteakVegetables","ACE_MRE_CreamChickenSoup",
    "ACE_MRE_MeatballsPasta","ACE_MRE_LambCurry","ACE_MRE_ChickenHerb",
    "ACE_Banana","ACE_Can_Franta","ACE_Can_RedGull"
];
private _foodAllowed = missionNamespace getVariable ["ARC_civsubAidFoodItems", _foodDefaults];
if !(_foodAllowed isEqualType []) then { _foodAllowed = _foodDefaults; };

private _foodKw = missionNamespace getVariable ["ARC_civsubAidFoodKeywords", ["humanitarian","sunflower"]];
if !(_foodKw isEqualType []) then { _foodKw = ["humanitarian","sunflower"]; };

private _waterDefaults = [
    "ACE_Canteen","ACE_Canteen_Half","ACE_WaterBottle","ACE_WaterBottle_Half",
    "ACE_Can_Franta","ACE_Can_RedGull"
];
private _waterAllowed = missionNamespace getVariable ["ARC_civsubAidWaterItems", _waterDefaults];
if !(_waterAllowed isEqualType []) then { _waterAllowed = _waterDefaults; };

private _waterKw = missionNamespace getVariable ["ARC_civsubAidWaterKeywords", ["water","canteen","bottle"]];
if !(_waterKw isEqualType []) then { _waterKw = ["water","canteen","bottle"]; };

private _countByAllowAndKw = {
    params ["_invArr","_allow","_kw"];
    private _c = 0;

    {
        private _cls = _x;

        if (_cls in _allow) then {
            _c = _c + 1;
        } else {
            // keyword match by displayName (CfgWeapons then CfgMagazines)
            private _dn = getText (configFile >> "CfgWeapons" >> _cls >> "displayName");
            if (_dn isEqualTo "") then { _dn = getText (configFile >> "CfgMagazines" >> _cls >> "displayName"); };

            if !(_dn isEqualTo "") then {
                private _dnL = toLower _dn;
                {
                    private _k = toLower _x;
                    if ((_dnL find _k) >= 0) exitWith { _c = _c + 1; };
                } forEach _kw;
            };
        };
    } forEach _invArr;

    _c
};

private _foodCnt = [_inv, _foodAllowed, _foodKw] call _countByAllowAndKw;
private _waterCnt = [_inv, _waterAllowed, _waterKw] call _countByAllowAndKw;

// Cache counts for right-pane DETAILS rendering.
uiNamespace setVariable ["ARC_civsubInteract_foodCount", _foodCnt];
uiNamespace setVariable ["ARC_civsubInteract_waterCount", _waterCnt];

// ----- Header formatting -----
private _serialLine = if (_serial isEqualTo "") then {"Serial: N/A"} else {format ["Serial: %1", _serial]};
private _didLine = if (_did isEqualTo "") then {"District: N/A"} else {format ["District: %1", _did]};
private _knownLine = if (_known) then {"Status: VERIFIED"} else {"Status: UNVERIFIED"};
private _detLine = if (_det) then {"Custody: DETAINED"} else {"Custody: NOT DETAINED"};

private _supLine = format ["Supplies: Food %1 | Water %2", _foodCnt, _waterCnt];

private _needLine = "Needs: N/A";
if ((_sat isEqualType 0) && (_hyd isEqualType 0)) then {
    private _satC = (_sat max 0) min 100;
    private _hydC = (_hyd max 0) min 100;

    private _outS = "Outlook: N/A";
    if (_out isEqualType 0) then { _outS = format ["Outlook(BLU): %1", ((_out max 0) min 100)]; };

    _needLine = format ["Needs: Food %1 | Water %2 | %3", _satC, _hydC, _outS];
};

_hdr ctrlSetStructuredText parseText format [
    "<t size='1.05'>Civilian: %1</t><br/>" +
    "<t size='0.82'>%2 | %3</t><br/>" +
    "<t size='0.82'>%4 | %5</t><br/>" +
    "<t size='0.78'>%6</t><br/>" +
    "<t size='0.78'>%7</t>",
    _name,
    _serialLine,
    _didLine,
    _knownLine,
    _detLine,
    _supLine,
    _needLine
];

true
