/*
    ARC_fnc_uiConsoleActionS2Primary

    Client: executes the currently selected S2 Ops action.
*/

if (!hasInterface) exitWith {false};

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
private _trimFn   = compile "params ['_s']; trim _s";
private _hg       = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _display = uiNamespace getVariable ["ARC_console_display", displayNull];
if (isNull _display) exitWith {false};

private _ctrlList = _display displayCtrl 78011;
if (isNull _ctrlList) exitWith {false};

// S2 workflow dropdowns (optional, only present in UI09+)
private _cmbMethod = _display displayCtrl 78051;
private _cmbCat    = _display displayCtrl 78053;
private _cmbLead   = _display displayCtrl 78055;

private _sel = lbCurSel _ctrlList;
private _data = if (_sel >= 0) then { _ctrlList lbData _sel } else { "" };
if (!(_data isEqualType "")) then { _data = ""; };

private _parts = _data splitString "|";
private _kind = if ((count _parts) > 0) then { toUpper (_parts select 0) } else { "NONE" };
private _arg  = if ((count _parts) > 1) then { _parts select 1 } else { "" };
if (!(_arg isEqualType "")) then { _arg = ""; };
_arg = [_arg] call _trimFn;

private _civReqAction = {
    params ["_actionId", ["_payload", createHashMap, [createHashMap, []]], ["_label", "", [""]]];

    private _civ = uiNamespace getVariable ["ARC_civsubInteract_target", objNull];
    if (isNull _civ) exitWith {
        ["CIVSUB", "No active civilian interaction context."] call ARC_fnc_clientToast;
        false
    };

    private _disp = uiNamespace getVariable ["ARC_console_display", displayNull];
    if (!isNull _disp) then { [_disp, false] call ARC_fnc_uiConsoleIntelPaint; };

    [_civ, player, _actionId, _payload] remoteExecCall ["ARC_fnc_civsubContactReqAction", 2];

    if !(_label isEqualTo "") then {
        ["CIVSUB", format ["%1 requested...", _label]] call ARC_fnc_clientToast;
    };

    true
};

private _clearCivContext = {
    uiNamespace setVariable ["ARC_civsubInteract_target", objNull];
    uiNamespace setVariable ["ARC_civsubInteract_mode", "A"];
    uiNamespace setVariable ["ARC_civsubInteract_lastPane", "A"];
    uiNamespace setVariable ["ARC_civsubInteract_selectedQid", ""];
    uiNamespace setVariable ["ARC_civsubInteract_snapshot", createHashMap];
    uiNamespace setVariable ["ARC_civsubInteract_idCardHtml", ""];
    uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", false];
    uiNamespace setVariable ["ARC_civsubInteract_hasUserOutput", false];
    uiNamespace setVariable ["ARC_civsubInteract_lastResultType", ""];
};

switch (_kind) do
{
	case "INTEL_LOG":
	{
		// Consolidated intel logging (UI09-HF)
		private _method = "MAP";
		private _cat = "SIGHTING";

		if (!isNull _cmbMethod && { (lbSize _cmbMethod) > 0 }) then
		{
			private _i = lbCurSel _cmbMethod;
			private _d = if (_i >= 0) then { _cmbMethod lbData _i } else { "" };
			if (_d isEqualType "" && { !([_d] call _trimFn isEqualTo "") }) then { _method = toUpper _d; };
		};

		if (!isNull _cmbCat && { (lbSize _cmbCat) > 0 }) then
		{
			private _i = lbCurSel _cmbCat;
			private _d = if (_i >= 0) then { _cmbCat lbData _i } else { "" };
			if (_d isEqualType "" && { !([_d] call _trimFn isEqualTo "") }) then { _cat = toUpper _d; };
		};

		switch (_method) do
		{
			case "CURSOR":
			{
				if (!(_cat isEqualTo "SIGHTING")) exitWith
				{
					["S2 Ops", "Cursor logging only supports Sighting. Use Map Click for other categories."] call ARC_fnc_clientToast;
				};
				[] call ARC_fnc_clientLogCursorSighting;
			};


			default
			{
				[_cat] call ARC_fnc_clientBeginIntelMapClick;
				["S2 Ops", format ["Intel log started (%1).", _cat]] call ARC_fnc_clientToast;
			};
		};
	};

    case "CIV_CONTACT_CHECK_ID":
    {
        ["CHECK_ID", createHashMap, "Check ID"] call _civReqAction;
    };

    case "CIV_CONTACT_BACKGROUND":
    {
        ["BACKGROUND_CHECK", createHashMap, "Background check"] call _civReqAction;
    };

    case "CIV_CONTACT_GIVE_FOOD":
    {
        ["AID_RATIONS", createHashMap, "Give Food"] call _civReqAction;
    };

    case "CIV_CONTACT_GIVE_WATER":
    {
        ["AID_WATER", createHashMap, "Give Water"] call _civReqAction;
    };

    case "CIV_CONTACT_DETAIN":
    {
        ["DETAIN", createHashMap, "Detain"] call _civReqAction;
    };

    case "CIV_CONTACT_RELEASE":
    {
        ["RELEASE", createHashMap, "Release"] call _civReqAction;
    };

    case "CIV_CONTACT_HANDOFF":
    {
        ["HANDOFF_SHERIFF", createHashMap, "Sheriff handoff"] call _civReqAction;
    };

    case "CIV_CONTACT_QUESTION":
    {
        if (_arg isEqualTo "") exitWith { ["CIVSUB", "No question selected."] call ARC_fnc_clientToast; };

        private _qMap = [[
            ["Q_LIVE", "Where do you live?"],
            ["Q_WORK", "Where do you work?"],
            ["Q_IEDS", "Have you seen any IEDs?"],
            ["Q_INS", "Have you seen any insurgent activity?"],
            ["Q_OP_US", "What is your opinion of us?"],
            ["Q_OP_AREA", "What is the overall opinion of us in the area?"]
        ]] call _hmCreate;

        private _qlbl = [_qMap, _arg, _arg] call _hg;
        private _payload = [[["qid", _arg], ["label", _qlbl]]] call _hmCreate;
        ["QUESTION", _payload, "Question"] call _civReqAction;
    };

    case "CIV_CONTACT_END":
    {
        private _civ = uiNamespace getVariable ["ARC_civsubInteract_target", objNull];
        if (!isNull _civ) then {
            [_civ, player, true] remoteExecCall ["ARC_fnc_civsubInteractEndSession", 2];
        };

        call _clearCivContext;
        uiNamespace setVariable ["ARC_console_intelSelData", ""];
        ["CIVSUB", "Interaction mode ended. Returning to S2 tools."] call ARC_fnc_clientToast;
        [_display, true] call ARC_fnc_uiConsoleIntelPaint;
    };


	
    case "CIV_CENSUS_OPEN":
    {
        uiNamespace setVariable ["ARC_console_intelMode", "CENSUS"];
        uiNamespace setVariable ["ARC_console_intelSelData", ""];
        [_display, true] call ARC_fnc_uiConsoleIntelPaint;
    };

    case "CIV_CENSUS_BACK":
    {
        uiNamespace setVariable ["ARC_console_intelMode", "TOOLS"];
        uiNamespace setVariable ["ARC_console_intelSelData", ""];
        [_display, true] call ARC_fnc_uiConsoleIntelPaint;
    };

    case "CIV_CENSUS_DID":
    {
        private _did = [_arg] call _trimFn;
        if (_did isEqualTo "") exitWith { ["Census", "No district selected."] call ARC_fnc_clientToast; };

        private _pub = missionNamespace getVariable [format ["civsub_v1_district_pub_%1", _did], []];
        if (!(_pub isEqualType [])) then { _pub = []; };

        if ((count _pub) == 0) exitWith
        {
            ["Census", "No district snapshot yet. Re-open after the next CIVSUB tick."] call ARC_fnc_clientToast;
        };

        private _ph = [_pub] call _hmCreate;
        private _c = [_ph, "centroid", []] call _hg;
        if (!(_c isEqualType [] && { (count _c) >= 2 })) exitWith
        {
            ["Census", "Centroid unavailable. Re-open after the next CIVSUB tick."] call ARC_fnc_clientToast;
        };

        openMap [true, false];
        mapAnimAdd [0.6, 0.35, _c];
        mapAnimCommit;
    };

	case "LEAD_REQ":
	{
		// Consolidated lead request (UI09-HF)
			private _type = if (_arg isEqualTo "") then {"RECON"} else {toUpper _arg};
		if (!isNull _cmbLead && { (lbSize _cmbLead) > 0 }) then
		{
			private _i = lbCurSel _cmbLead;
			private _d = if (_i >= 0) then { _cmbLead lbData _i } else { "" };
			if (_d isEqualType "" && { !([_d] call _trimFn isEqualTo "") }) then { _type = toUpper _d; };
		};
		[_type] call ARC_fnc_intelClientBeginLeadRequestMapClick;
		["S2 Ops", format ["Lead request started (%1).", _type]] call ARC_fnc_clientToast;
	};

    case "INTEL_MAP":
    {
	        if (_arg isEqualTo "") exitWith {};
	        private _catOld = toUpper _arg;
	        [_catOld] call ARC_fnc_clientBeginIntelMapClick;
	        ["S2 Ops", format ["Intel log started (%1).", _catOld]] call ARC_fnc_clientToast;
    };

    case "CURSOR_SIGHTING":
    {
        [] call ARC_fnc_clientLogCursorSighting;
    };

		// (Older UI09 used LEAD_REQ|TYPE; handled above via _arg fallback)

    case "REFRESH_INTEL":
    {
        [] remoteExec ["ARC_fnc_tocRequestRefreshIntel", 2];
        ["S2 Ops", "Intel refresh requested."] call ARC_fnc_clientToast;
    };

    // S2 district influence heat-map toggle (Roadmap #5)
    case "DISTRICT_HEAT_MAP":
    {
        private _heatMapOn = uiNamespace getVariable ["ARC_s2_districtHeatMap", false];
        if (!(_heatMapOn isEqualType true) && !(_heatMapOn isEqualType false)) then { _heatMapOn = false; };
        _heatMapOn = !_heatMapOn;
        uiNamespace setVariable ["ARC_s2_districtHeatMap", _heatMapOn];
        [_heatMapOn] call ARC_fnc_worldDistrictMarkersUpdate;
        private _msg = if (_heatMapOn) then {"District heat-map ON — markers show dominant influence axis."} else {"District heat-map OFF."};
        ["S2 Ops", _msg] call ARC_fnc_clientToast;
        // Refresh tab so the [ON]/[OFF] label updates.
        [_display, true] call ARC_fnc_uiConsoleS2Paint;
    };

    case "S2_SHOW_LEADS":
    {
        [] call ARC_fnc_tocShowLeadPoolLocal;
    };

    case "S2_SHOW_THREADS":
    {
        [] call ARC_fnc_tocShowThreadsLocal;
    };

    case "S2_SHOW_INTEL":
    {
        [] call ARC_fnc_tocShowLatestIntel;
    };

    case "FEED":
    {
        // UI09: intel feed entry shortcut (center map on the intel entry)
        if (_arg isEqualTo "") exitWith {};

        private _intelLog = missionNamespace getVariable ["ARC_pub_intelLog", []];
        if (!(_intelLog isEqualType [])) then { _intelLog = []; };

        private _pos = [];
        {
            if (_x isEqualType [] && { (count _x) >= 5 } && { (_x select 0) isEqualTo _arg }) exitWith { _pos = _x select 4; };
        } forEach _intelLog;

        if (_pos isEqualType [] && { (count _pos) >= 2 }) then
        {
            openMap [true, false];
            mapAnimAdd [0.6, 0.25, _pos];
            mapAnimCommit;
        }
        else
        {
            ["Intel Feed", "Could not resolve that intel entry position."] call ARC_fnc_clientToast;
        };
    };

    default
    {
        ["S2 Ops", "Select an action first."] call ARC_fnc_clientToast;
    };
};

true
