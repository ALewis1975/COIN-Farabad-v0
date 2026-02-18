/*
    ARC_fnc_uiConsoleActionS2Primary

    Client: executes the currently selected S2 Ops action.
*/

if (!hasInterface) exitWith {false};

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
private _kind = if ((count _parts) > 0) then { toUpper (_parts # 0) } else { "NONE" };
private _arg  = if ((count _parts) > 1) then { _parts # 1 } else { "" };
if (!(_arg isEqualType "")) then { _arg = ""; };
_arg = trim _arg;

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
    uiNamespace setVariable ["ARC_console_civsubLastResult", createHashMap];
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
			if (_d isEqualType "" && { (trim _d) isNotEqualTo "" }) then { _method = toUpper _d; };
		};

		if (!isNull _cmbCat && { (lbSize _cmbCat) > 0 }) then
		{
			private _i = lbCurSel _cmbCat;
			private _d = if (_i >= 0) then { _cmbCat lbData _i } else { "" };
			if (_d isEqualType "" && { (trim _d) isNotEqualTo "" }) then { _cat = toUpper _d; };
		};

		switch (_method) do
		{
			case "CURSOR":
			{
				if (_cat isNotEqualTo "SIGHTING") exitWith
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

        private _qMap = createHashMapFromArray [
            ["Q_LIVE", "Where do you live?"],
            ["Q_WORK", "Where do you work?"],
            ["Q_IEDS", "Have you seen any IEDs?"],
            ["Q_INS", "Have you seen any insurgent activity?"],
            ["Q_OP_US", "What is your opinion of us?"],
            ["Q_OP_AREA", "What is the overall opinion of us in the area?"]
        ];

        private _qlbl = _qMap getOrDefault [_arg, _arg];
        private _payload = createHashMapFromArray [["qid", _arg], ["label", _qlbl]];
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
        private _did = trim _arg;
        if (_did isEqualTo "") exitWith { ["Census", "No district selected."] call ARC_fnc_clientToast; };

        private _pub = missionNamespace getVariable [format ["civsub_v1_district_pub_%1", _did], []];
        if (!(_pub isEqualType [])) then { _pub = []; };
        private _hasPub = ((count _pub) > 0);


        private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
        if (_districts isEqualType []) then { _districts = createHashMapFromArray _districts; };
        if !(_districts isEqualType createHashMap) then { _districts = createHashMap; };

        private _d = _districts getOrDefault [_did, createHashMap];
        if (_d isEqualType []) then { _d = createHashMapFromArray _d; };
        if !(_d isEqualType createHashMap) exitWith
        {
            if (_hasPub) then
            {
                ["Census", "District snapshot exists, but full district details are not available on the client yet. Re-open after the next CIVSUB tick."] call ARC_fnc_clientToast;
            }
            else
            {
                ["Census", "District not found."] call ARC_fnc_clientToast;
            };
        };

        private _c = _d getOrDefault ["centroid", []];
        if !(_c isEqualType [] && { (count _c) >= 2 }) exitWith
        {
            if (_hasPub) then
            {
                ["Census", "Centroid unavailable on client. Re-open after the next CIVSUB tick."] call ARC_fnc_clientToast;
            }
            else
            {
                ["Census", "No centroid for district."] call ARC_fnc_clientToast;
            };
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
			if (_d isEqualType "" && { (trim _d) isNotEqualTo "" }) then { _type = toUpper _d; };
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
            if (_x isEqualType [] && { (count _x) >= 5 } && { (_x # 0) isEqualTo _arg }) exitWith { _pos = _x # 4; };
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
