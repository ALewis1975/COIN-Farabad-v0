/*
    ARC_fnc_civsubContactDialogUpdateRightPane

    Right pane behavior (hard rule):
      - Action mode: show a non-interactive DETAILS pane (StructuredText) with action-specific instructions/status.
      - Questions mode: show the Questions listbox (interactive) and hide the DETAILS pane.

    This prevents the "details-as-listbox" regression where selecting instruction lines breaks QUESTION routing.

    Params:
      0: actionId (string)
*/

if (!hasInterface) exitWith { true };

params [ ["_actionId", "", [""]] ];

private _d = uiNamespace getVariable ["ARC_civsubInteract_display", displayNull];
if (isNull _d) exitWith { true };

private _lbl = _d displayCtrl 78302;
private _lbQ = _d displayCtrl 78311;
private _grp = _d displayCtrl 78312;
private _txt = _d displayCtrl 78313;

if (isNull _lbl || isNull _lbQ || isNull _grp || isNull _txt) exitWith { true };

private _civ = uiNamespace getVariable ["ARC_civsubInteract_target", objNull];

private _showQuestions = {
    params ["_show"];

    _lbQ ctrlShow _show;
    _lbQ ctrlEnable _show;
    _grp ctrlShow (!_show);
    _grp ctrlEnable (!_show);

    if (_show) then {
        // prevent accidental selection state from Action mode
        _txt ctrlSetStructuredText parseText "";
    } else {
        // prevent stale question routing
        _lbQ lbSetCurSel -1;
        uiNamespace setVariable ["ARC_civsubInteract_selectedQid", ""];
    };
};

// Helper: render DETAILS text
private _setDetails = {
    params ["_title", "_htmlBody"]; 
    _lbl ctrlSetText _title;
    _txt ctrlSetStructuredText parseText _htmlBody;
};

// Helper: build a simple "bulleted" details block
private _detailsBlock = {
    params ["_lines"]; 
    private _out = "";
    {
        _out = _out + format ["<t size='0.9'>%1</t><br/>", _x];
    } forEach _lines;
    _out
};

switch (_actionId) do {
    case "ASK_QUESTIONS": {
        [true] call _showQuestions;
        _lbl ctrlSetText "Questions";

        lbClear _lbQ;
        {
            private _qid = _x select 0;
            private _ql  = _x select 1;
            private _i = _lbQ lbAdd _ql;
            _lbQ lbSetData [_i, _qid];
        } forEach [
            ["Q_LIVE", "Where do you live?"],
            ["Q_WORK", "Where do you work?"],
            ["Q_IEDS", "Have you seen any IEDs?"],
            ["Q_INS",  "Have you seen any insurgent activity?"],
            ["Q_OP_US", "What is your opinion of us?"],
            ["Q_OP_AREA", "What is the overall opinion of us in the area?" ]
        ];

        _lbQ lbSetCurSel -1;
        true
    };

    default {
        [false] call _showQuestions;

        // Refresh supply counts opportunistically (keeps Food/Water accurate if player inventory changed).
        private _snap = uiNamespace getVariable ["ARC_civsubInteract_snapshot", createHashMap];
        if (_snap isEqualType createHashMap) then { [_d, _snap] call ARC_fnc_civsubInteractUpdateHeaderStats; };

        // Common context
        private _foodCnt  = uiNamespace getVariable ["ARC_civsubInteract_foodCount", 0];
        private _waterCnt = uiNamespace getVariable ["ARC_civsubInteract_waterCount", 0];

        private _sat = if (!isNull _civ) then { (_civ getVariable ["civsub_need_satiation", 50]) } else { -1 };
        private _hyd = if (!isNull _civ) then { (_civ getVariable ["civsub_need_hydration", 50]) } else { -1 };
        private _out = if (!isNull _civ) then { (_civ getVariable ["civsub_outlook_blufor", 50]) } else { -1 };

        private _gainFood = missionNamespace getVariable ["ARC_civsubAidFoodGain", 20];
        if !(_gainFood isEqualType 0) then { _gainFood = 20; };
        private _gainWater = missionNamespace getVariable ["ARC_civsubAidWaterGain", 20];
        if !(_gainWater isEqualType 0) then { _gainWater = 20; };

        switch (_actionId) do {

            case "CHECK_ID": {
                private _cardHtml = uiNamespace getVariable ["ARC_civsubInteract_idCardHtml", ""]; 

                private _lines = [
                    "<t size='1.0' color='#CFE8FF'>Instructions</t>",
                    "Execute to verify identity.",
                    "",
                    format ["<t size='0.85'>Your supplies: Food %1 | Water %2</t>", _foodCnt, _waterCnt]
                ];
                private _base = [_lines] call _detailsBlock;
                private _full = _base;
                if !(_cardHtml isEqualTo "") then {
                    _full = _full + "<br/>" + _cardHtml;
                };
                ["Check ID", _full] call _setDetails;
            };

            case "BACKGROUND_CHECK": {
                private _html = [[
                    "<t size='1.0' color='#CFE8FF'>Instructions</t>",
                    "Execute to run a background check (flags/warrants).",
                    "Results appear in the response pane below."
                ]] call _detailsBlock;
                ["Background", _html] call _setDetails;
            };

            case "DETAIN": {
                private _det = if (!isNull _civ) then { _civ getVariable ["civsub_status_detained", false] } else { false };
                private _html = [[
                    "<t size='1.0' color='#CFE8FF'>Instructions</t>",
                    "Execute to detain the civilian.",
                    "The civilian stays pinned after closing the dialog.",
                    format ["<t size='0.85'>Status: %1</t>", if (_det) then {"DETAINED"} else {"Not detained"}]
                ]] call _detailsBlock;
                ["Detain", _html] call _setDetails;
            };

            case "RELEASE": {
                private _det = if (!isNull _civ) then { _civ getVariable ["civsub_status_detained", false] } else { false };
                private _html = [[
                    "<t size='1.0' color='#CFE8FF'>Instructions</t>",
                    "Execute to release the civilian.",
                    "Movement resumes after session end.",
                    format ["<t size='0.85'>Status: %1</t>", if (_det) then {"DETAINED"} else {"Not detained"}]
                ]] call _detailsBlock;
                ["Release", _html] call _setDetails;
            };

            case "AID_RATIONS": {
                private _html = [[
                    "<t size='1.0' color='#CFE8FF'>Supplies</t>",
                    format ["Food on-hand: %1", _foodCnt],
                    "",
                    "<t size='1.0' color='#CFE8FF'>Civilian</t>",
                    format ["Hunger (satiation): %1 / 100", (_sat max 0) min 100],
                    format ["Outlook (BLUFOR): %1 / 100", (_out max 0) min 100],
                    "",
                    format ["<t size='0.85'>Expected: Food +%1, Outlook improves</t>", _gainFood],
                    "Execute consumes 1 food item if available."
                ]] call _detailsBlock;
                ["Give Food", _html] call _setDetails;
            };

            case "AID_WATER": {
                private _html = [[
                    "<t size='1.0' color='#CFE8FF'>Supplies</t>",
                    format ["Water on-hand: %1", _waterCnt],
                    "",
                    "<t size='1.0' color='#CFE8FF'>Civilian</t>",
                    format ["Thirst (hydration): %1 / 100", (_hyd max 0) min 100],
                    format ["Outlook (BLUFOR): %1 / 100", (_out max 0) min 100],
                    "",
                    format ["<t size='0.85'>Expected: Water +%1, Outlook improves</t>", _gainWater],
                    "Execute consumes 1 water item if available."
                ]] call _detailsBlock;
                ["Give Water", _html] call _setDetails;
            };

            default {
                private _html = [[
                    "Select an action on the left.",
                    "Or select Ask Questions to view questions."
                ]] call _detailsBlock;
                ["Details", _html] call _setDetails;
            };
        };
    };
};

true
