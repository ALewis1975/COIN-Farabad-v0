/*
    Farabad Helmet-Cam / ISR-Map Screen Feed - shared helpers.

    Two feed modes share the same managed screen pool as uasScreen:

      HELM  — attaches a PiP camera to a dismounted soldier's head/torso that
              carries ItemcTabHCam.  Cycles through qualifying friendly units.

      MAP   — positions a static nadir PiP camera above an area of interest
              (ARC_activeIncidentPos if set, otherwise the map centre) at a
              configurable altitude, giving a bird's-eye ISR overview of the AO.

    Authority model mirrors uasScreen:
    - Server owns the active feed snapshot (ARC_helmScreenFeedSnapshot).
    - Clients render local PiP cameras from that snapshot.
    - No persistence; JIP reconstructs from the public snapshot.
*/

ARC_fnc_helmScreenEnsureDefaults = {
    if (!isServer) exitWith {true};

    private _setDefault = {
        params ["_key", "_value", ["_public", false]];
        if (isNil { missionNamespace getVariable _key }) then
        {
            missionNamespace setVariable [_key, _value, _public];
        };
    };

    ["ARC_helmScreenEnabled", true, isServer] call _setDefault;

    // Reuse the same managed-screen pool as uasScreen; missions may override
    // ARC_helmScreenObjectVarNames to use a different list.
    ["ARC_helmScreenObjectVarNames", missionNamespace getVariable ["ARC_uasScreenObjectVarNames", [
        "ARC_toc_screen_4",
        "ARC_toc_screen_5",
        "ARC_toc_screen_1",
        "ARC_toc_screen_2",
        "ARC_toc_screen_3",
        "ARC_toc_air_1",
        "ARC_toc_air_2",
        "ARC_toc_FSE",
        "ARC_toc_intel_1",
        "ARC_toc_intel_2",
        "ARC_toc_ops_1",
        "ARC_toc_ops_2",
        "ARC_toc_ops_3",
        "ARC_toc_ops_4",
        "ARC_toc_ops_5",
        "ARC_toc_UAS_1",
        "ARC_toc_XO"
    ]], isServer] call _setDefault;

    ["ARC_helmScreenRequireAuthorizedRole", false, isServer] call _setDefault;
    ["ARC_helmScreenAllowedSides", ["WEST"], isServer] call _setDefault;
    ["ARC_helmScreenHelmCamItem", "ItemcTabHCam", isServer] call _setDefault;
    ["ARC_helmScreenTextureSelection", 0, isServer] call _setDefault;
    ["ARC_helmScreenCameraOffset", [0, 0, 0.15], isServer] call _setDefault;
    ["ARC_helmScreenCameraFov", 0.70, isServer] call _setDefault;
    ["ARC_helmScreenIdleTexture", "#(argb,8,8,3)color(0,0,0,1)", isServer] call _setDefault;

    // ISR map / overhead camera settings
    ["ARC_helmScreenMapAltM", 350, isServer] call _setDefault;
    ["ARC_helmScreenMapFov", 0.65, isServer] call _setDefault;

    true
};

// ---------------------------------------------------------------------------
// Screen pool helpers (mirrors uasScreen_common so screens can be shared)
// ---------------------------------------------------------------------------

ARC_fnc_helmScreenResolveManagedScreens = {
    [] call ARC_fnc_helmScreenEnsureDefaults;

    private _names = missionNamespace getVariable ["ARC_helmScreenObjectVarNames", []];
    if (!(_names isEqualType [])) then { _names = []; };

    private _all = allMissionObjects "All";
    private _objects = [];
    {
        if (!(_x isEqualType "")) then { continue; };

        private _name = _x;
        private _obj = missionNamespace getVariable [_name, objNull];

        if (isNull _obj) then
        {
            private _needle = toLower _name;
            {
                if ((toLower (vehicleVarName _x)) isEqualTo _needle) exitWith { _obj = _x; };
            } forEach _all;

            if (!isNull _obj) then
            {
                missionNamespace setVariable [_name, _obj, false];
            };
        };

        if (!isNull _obj) then { _objects pushBackUnique _obj; };
    } forEach _names;

    _objects
};

ARC_fnc_helmScreenIsManaged = {
    params [["_obj", objNull, [objNull]]];
    if (isNull _obj) exitWith {false};

    [] call ARC_fnc_helmScreenEnsureDefaults;
    private _names = missionNamespace getVariable ["ARC_helmScreenObjectVarNames", []];
    if (!(_names isEqualType [])) then { _names = []; };

    private _varName = toLower (vehicleVarName _obj);
    private _managed = false;

    {
        if (!(_x isEqualType "")) then { continue; };
        private _name = _x;
        if (_varName != "" && { (toLower _name) isEqualTo _varName }) exitWith { _managed = true; };

        private _namedObj = missionNamespace getVariable [_name, objNull];
        if (!isNull _namedObj && { _namedObj isEqualTo _obj }) exitWith { _managed = true; };
    } forEach _names;

    _managed
};

// ---------------------------------------------------------------------------
// Helmet-cam unit discovery
// ---------------------------------------------------------------------------

ARC_fnc_helmScreenGetHelmCamUnits = {
    [] call ARC_fnc_helmScreenEnsureDefaults;

    private _allowed = missionNamespace getVariable ["ARC_helmScreenAllowedSides", ["WEST"]];
    if (!(_allowed isEqualType [])) then { _allowed = ["WEST"]; };

    private _allowedU = [];
    {
        if (_x isEqualType "") then { _allowedU pushBackUnique (toUpper _x); };
    } forEach _allowed;

    private _item = missionNamespace getVariable ["ARC_helmScreenHelmCamItem", "ItemcTabHCam"];
    if (!(_item isEqualType "")) then { _item = "ItemcTabHCam"; };

    private _unitHasConfiguredItem = {
        params [["_u", objNull, [objNull]], ["_i", "", [""]]];
        if (_i isEqualTo "") exitWith {true};
        if (isNull _u) exitWith {false};

        private _inventory = [];
        _inventory append (items _u);
        _inventory append (assignedItems _u);
        _inventory append (weapons _u);
        _inventory append (magazines _u);

        {
            if (_x != "") then { _inventory pushBack _x; };
        } forEach [
            headgear _u,
            goggles _u,
            hmd _u,
            uniform _u,
            vest _u,
            backpack _u
        ];

        _i in _inventory
    };

    private _units = [];
    {
        private _u = _x;
        if (isNull _u || {!alive _u} || {!isPlayer _u}) then { continue; };

        private _sideStr = toUpper str (side (group _u));
        if ((count _allowedU) > 0 && {!(_sideStr in _allowedU)}) then { continue; };

        if ([_u, _item] call _unitHasConfiguredItem) then
        {
            _units pushBackUnique _u;
        };
    } forEach allPlayers;

    _units
};

// ---------------------------------------------------------------------------
// Short display labels
// ---------------------------------------------------------------------------

ARC_fnc_helmScreenUnitLabel = {
    params [["_unit", objNull, [objNull]]];
    if (isNull _unit) exitWith {"UNKNOWN UNIT"};

    private _name = name _unit;
    if (_name isEqualTo "") then { _name = "Unknown"; };

    private _grp = groupId (group _unit);
    if (_grp isEqualTo "") then { _grp = "?GRP"; };

    format ["%1 (%2) GR %3", _name, _grp, mapGridPosition _unit]
};

ARC_fnc_helmScreenUnitShortLabel = {
    params [["_unit", objNull, [objNull]]];
    if (isNull _unit) exitWith {"UNKNOWN"};

    private _name = name _unit;
    if (_name isEqualTo "") then { _name = "Unknown"; };
    _name
};

// ---------------------------------------------------------------------------
// Snapshot record helpers
// ---------------------------------------------------------------------------

ARC_fnc_helmScreenFindRecordIndex = {
    params [["_snapshot", [], [[]]], ["_screenNid", "", [""]]];

    private _idx = -1;
    {
        if (_x isEqualType [] && { (_x param [0, ""]) isEqualTo _screenNid }) exitWith
        {
            _idx = _forEachIndex;
        };
    } forEach _snapshot;

    _idx
};

true
