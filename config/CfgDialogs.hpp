/*
    Minimal UI dialog for intel report text entry.

    Notes:
    - Uses standard Arma UI base classes (RscText, RscEdit, RscButton) from the game config.
    - This keeps the "intel log" from being generic; players can type a short summary + details.
*/

// Import base UI classes from the game config so we can inherit safely in mission config.
// Arma 3 v2.02+ supports the `import` keyword for this purpose.
import RscText;
import RscEdit;
import RscButton;
import RscListbox;
import RscCombo;
import RscStructuredText;
import RscControlsGroup;

class ARC_IntelReportDialog
{
    idd = 77001;
    movingEnable = 1;
    enableSimulation = 1;

    onLoad = "uiNamespace setVariable ['ARC_intelDialog_display', _this # 0]; private _d = _this # 0; (_d displayCtrl 1001) ctrlSetText (uiNamespace getVariable ['ARC_intelDialog_category','INTEL']); (_d displayCtrl 1400) ctrlSetText (uiNamespace getVariable ['ARC_intelDialog_defaultSummary','']); (_d displayCtrl 1401) ctrlSetText (uiNamespace getVariable ['ARC_intelDialog_defaultDetails','']);";
    onUnload = "uiNamespace setVariable ['ARC_intelDialog_display', displayNull];";

    class controlsBackground
    {
        class BG: RscText
        {
            idc = 1000;
            x = 0.25;
            y = 0.18;
            w = 0.50;
            h = 0.52;
            colorBackground[] = {0,0,0,0.75};
        };
    };

    class controls
    {
        class Title: RscText
        {
            idc = 1001;
            text = "ARC Intel Report";
            x = 0.26;
            y = 0.19;
            w = 0.48;
            h = 0.04;
        };

        class LabelSummary: RscText
        {
            idc = 1002;
            text = "Summary (one line):";
            x = 0.26;
            y = 0.24;
            w = 0.48;
            h = 0.03;
        };

        class EditSummary: RscEdit
        {
            idc = 1400;
            x = 0.26;
            y = 0.27;
            w = 0.48;
            h = 0.04;
        };

        class LabelDetails: RscText
        {
            idc = 1003;
            text = "Details (optional):";
            x = 0.26;
            y = 0.32;
            w = 0.48;
            h = 0.03;
        };

        class EditDetails: RscEdit
        {
            idc = 1401;
            style = 16; // ST_MULTI
            x = 0.26;
            y = 0.35;
            w = 0.48;
            h = 0.25;
        };

        class BtnOK: RscButton
        {
            idc = 1600;
            text = "OK";
            x = 0.26;
            y = 0.62;
            w = 0.23;
            h = 0.05;
            action = "uiNamespace setVariable ['ARC_intelDialog_result', [true, ctrlText ((findDisplay 77001) displayCtrl 1400), ctrlText ((findDisplay 77001) displayCtrl 1401)]]; closeDialog 1;";
        };

        class BtnCancel: RscButton
        {
            idc = 1601;
            text = "Cancel";
            x = 0.51;
            y = 0.62;
            w = 0.23;
            h = 0.05;
            action = "uiNamespace setVariable ['ARC_intelDialog_result', [false, '', '']]; closeDialog 2;";
        };
    };
};

/*
    Structured SITREP Dialog (UI09)

    Purpose:
      Replace single free-text SITREPs with segmented, SOP-like inputs.
      Client code formats the final SITREP into the existing TOC log pipeline.
*/
class ARC_SitrepDialog
{
    idd = 77301;
    movingEnable = 1;
    enableSimulation = 1;

    onLoad = "uiNamespace setVariable ['ARC_sitrepDialog_display', _this # 0]; [_this # 0] call ARC_fnc_uiSitrepDialogOnLoad;";
    onUnload = "uiNamespace setVariable ['ARC_sitrepDialog_display', displayNull];";

    class controlsBackground
    {
        class BG: RscText
        {
            idc = 77390;
            x = 0.18;
            y = 0.12;
            w = 0.64;
            h = 0.81;
            colorBackground[] = {0,0,0,0.80};
        };

        class TitleBar: RscText
        {
            idc = 77391;
            text = "SITREP";
            x = 0.18;
            y = 0.12;
            w = 0.64;
            h = 0.04;
            colorBackground[] = {0.05,0.05,0.05,0.92};
        };
    };

    class controls
    {
        class Header: RscStructuredText
        {
            idc = 77392;
            x = 0.19;
            y = 0.165;
            w = 0.62;
            h = 0.12;
        };

        class LabelSummary: RscText
        {
            idc = 77301;
            text = "Summary (one line):";
            x = 0.19;
            y = 0.295;
            w = 0.25;
            h = 0.03;
        };
        class EditSummary: RscEdit
        {
            idc = 77310;
            x = 0.19;
            y = 0.325;
            w = 0.62;
            h = 0.04;
        };

        class LabelEnemy: RscText
        {
            idc = 77302;
            text = "Enemy Situation:";
            x = 0.19;
            y = 0.375;
            w = 0.25;
            h = 0.03;
        };
        class EditEnemy: RscEdit
        {
            idc = 77311;
            x = 0.19;
            y = 0.405;
            w = 0.62;
            h = 0.04;
        };

        class LabelFriendly: RscText
        {
            idc = 77303;
            text = "Friendly Forces / Actions:";
            x = 0.19;
            y = 0.455;
            w = 0.25;
            h = 0.03;
        };
        class EditFriendly: RscEdit
        {
            idc = 77312;
            x = 0.19;
            y = 0.485;
            w = 0.62;
            h = 0.04;
        };

        class LabelTask: RscText
        {
            idc = 77304;
            text = "Task Status:";
            x = 0.19;
            y = 0.535;
            w = 0.25;
            h = 0.03;
        };
        class EditTask: RscEdit
        {
            idc = 77313;
            x = 0.19;
            y = 0.565;
            w = 0.62;
            h = 0.04;
        };

        class LabelACE: RscText
        {
            idc = 77305;
            text = "ACE Status (Ammo / Casualties / Equipment):";
            x = 0.19;
            y = 0.615;
            w = 0.45;
            h = 0.03;
        };
        class ComboAmmo: RscCombo
        {
            idc = 77321;
            x = 0.19;
            y = 0.645;
            w = 0.20;
            h = 0.04;
        };
        class ComboCasualties: RscCombo
        {
            idc = 77322;
            x = 0.40;
            y = 0.645;
            w = 0.20;
            h = 0.04;
        };
        class ComboEquipment: RscCombo
        {
            idc = 77323;
            x = 0.61;
            y = 0.645;
            w = 0.20;
            h = 0.04;
        };

        class LabelRequests: RscText
        {
            idc = 77306;
            text = "Requests:";
            x = 0.19;
            y = 0.695;
            w = 0.25;
            h = 0.03;
        };
        class EditRequests: RscEdit
        {
            idc = 77314;
            x = 0.19;
            y = 0.725;
            w = 0.62;
            h = 0.04;
        };

        class LabelNotes: RscText
        {
            idc = 77307;
            text = "Notes (optional):";
            x = 0.19;
            y = 0.775;
            w = 0.25;
            h = 0.03;
        };
        class EditNotes: RscEdit
        {
            idc = 77315;
            style = 16; // ST_MULTI
            x = 0.19;
            y = 0.805;
            w = 0.62;
            h = 0.07;
        };

        class BtnSubmit: RscButton
        {
            idc = 77360;
            text = "Submit";
            x = 0.19;
            y = 0.885;
            w = 0.30;
            h = 0.04;
            action = "[] call ARC_fnc_uiSitrepDialogSubmit;";
        };

        class BtnCancel: RscButton
        {
            idc = 77361;
            text = "Cancel";
            x = 0.51;
            y = 0.885;
            w = 0.30;
            h = 0.04;
            action = "[] call ARC_fnc_uiSitrepDialogCancel;";
        };
    };
};

/*
    EOD Disposition Request Dialog

    Purpose:
      Allow field units to request TOC permission for EOD disposition actions
      during IED/VBIED incidents.
*/
class ARC_EodDispoDialog
{
    idd = 78250;
    movingEnable = 1;
    enableSimulation = 1;

    onLoad = "uiNamespace setVariable ['ARC_eodDispo_display', _this # 0]; private _d = _this # 0; private _c = (_d displayCtrl 78210); lbClear _c; private _i0 = _c lbAdd 'Detonate in place (request permission)'; _c lbSetData [_i0,'DET_IN_PLACE']; private _i1 = _c lbAdd 'RTB IED evidence (request permission)'; _c lbSetData [_i1,'RTB_IED']; private _i2 = _c lbAdd 'Tow VBIED for exploitation (request permission)'; _c lbSetData [_i2,'TOW_VBIED']; private _sel = uiNamespace getVariable ['ARC_eodDispo_defaultSel',0]; if (!(_sel isEqualType 0)) then { _sel = 0; }; if (_sel < 0) then { _sel = 0; }; if (_sel > 2) then { _sel = 2; }; _c lbSetCurSel _sel;";
    onUnload = "uiNamespace setVariable ['ARC_eodDispo_display', displayNull];";

    class controlsBackground
    {
        class BG: RscText
        {
            idc = 78201;
            x = 0.25;
            y = 0.22;
            w = 0.50;
            h = 0.40;
            colorBackground[] = {0,0,0,0.80};
        };

        class TitleBar: RscText
        {
            idc = 78202;
            text = "EOD Disposition Request";
            x = 0.25;
            y = 0.22;
            w = 0.50;
            h = 0.04;
            colorBackground[] = {0.05,0.05,0.05,0.92};
        };
    };

    class controls
    {
        class LabelPick: RscText
        {
            idc = 78203;
            text = "Select requested disposition:";
            x = 0.26;
            y = 0.27;
            w = 0.48;
            h = 0.03;
        };

        class ListReq: RscListbox
        {
            idc = 78210;
            x = 0.26;
            y = 0.30;
            w = 0.48;
            h = 0.12;
        };

        class LabelNotes: RscText
        {
            idc = 78204;
            text = "Notes (optional):";
            x = 0.26;
            y = 0.43;
            w = 0.48;
            h = 0.03;
        };

        class EditNotes: RscEdit
        {
            idc = 78211;
            x = 0.26;
            y = 0.46;
            w = 0.48;
            h = 0.08;
        };

        class BtnOK: RscButton
        {
            idc = 78220;
            text = "Submit";
            x = 0.26;
            y = 0.56;
            w = 0.23;
            h = 0.05;
            action = "private _d = findDisplay 78250; private _l = (_d displayCtrl 78210); private _sel = lbCurSel _l; private _rt = if (_sel < 0) then {'DET_IN_PLACE'} else { _l lbData _sel }; private _nt = ctrlText (_d displayCtrl 78211); uiNamespace setVariable ['ARC_eodDispo_result',[true,_rt,_nt]]; closeDialog 1;";
        };

        class BtnCancel: RscButton
        {
            idc = 78221;
            text = "Cancel";
            x = 0.51;
            y = 0.56;
            w = 0.23;
            h = 0.05;
            action = "uiNamespace setVariable ['ARC_eodDispo_result',[false,'','']]; closeDialog 2;";
        };
    };
};

/*
    TOC Queue Manager (DEPRECATED)
    - Legacy standalone dialog retained only for compatibility fallback.
    - Primary user flow now stays inside ARC_FarabadConsoleDialog CMD/QUEUE mode.
*/
class ARC_TOCQueueManagerDialog
{
    idd = 61000;
    movingEnable = 1;
    enableSimulation = 1;

    onLoad = "uiNamespace setVariable ['ARC_queueMgr_display', _this # 0]; ['TOC Queue','Standalone queue dialog is deprecated; use Console -> TOC/CMD -> TOC QUEUE.'] call ARC_fnc_clientHint; closeDialog 0;";
    onUnload = "uiNamespace setVariable ['ARC_queueMgr_display', displayNull];";

    class controlsBackground
    {
        class BG: RscText
        {
            idc = 61090;
            x = 0.10;
            y = 0.10;
            w = 0.80;
            h = 0.80;
            colorBackground[] = {0,0,0,0.80};
        };
    };

    class controls
    {
        class Title: RscText
        {
            idc = 61091;
            text = "TOC Queue Manager";
            x = 0.11;
            y = 0.11;
            w = 0.78;
            h = 0.04;
            colorBackground[] = {0.05,0.05,0.05,0.90};
        };

        class QueueList: RscListbox
        {
            idc = 61001;
            x = 0.11;
            y = 0.16;
            w = 0.38;
            h = 0.60;
        };

        class Details: RscStructuredText
        {
            idc = 61002;
            x = 0.50;
            y = 0.16;
            w = 0.39;
            h = 0.60;
            colorBackground[] = {0.05,0.05,0.05,0.65};
        };

        class NoteLabel: RscText
        {
            idc = 61003;
            text = "Decision note (optional):";
            x = 0.11;
            y = 0.77;
            w = 0.38;
            h = 0.03;
        };

        class NoteEdit: RscEdit
        {
            idc = 61004;
            x = 0.11;
            y = 0.80;
            w = 0.78;
            h = 0.04;
        };

        class BtnApprove: RscButton
        {
            idc = 61011;
            text = "Approve";
            x = 0.50;
            y = 0.85;
            w = 0.12;
            h = 0.04;
            action = "[true] call ARC_fnc_intelUiQueueManagerDecideSelected;";
        };

        class BtnReject: RscButton
        {
            idc = 61012;
            text = "Reject";
            x = 0.63;
            y = 0.85;
            w = 0.12;
            h = 0.04;
            action = "[false] call ARC_fnc_intelUiQueueManagerDecideSelected;";
        };

        class BtnRefresh: RscButton
        {
            idc = 61013;
            text = "Refresh";
            x = 0.11;
            y = 0.85;
            w = 0.12;
            h = 0.04;
            action = "[] call ARC_fnc_intelUiQueueManagerRefresh;";
        };

        class BtnClose: RscButton
        {
            idc = 61014;
            text = "Close";
            x = 0.77;
            y = 0.85;
            w = 0.12;
            h = 0.04;
            action = "closeDialog 0;";
        };
    };
};

/*
    Farabad Console (UI01/UI02)

    A lightweight, tablet-style console that can be opened from anywhere
    (keybind) when the player has an approved "tablet" item.

    UI01: Shell + tab navigation
    UI02: Handoff tab (Intel Debrief + EPW Processing)
*/
class ARC_FarabadConsoleDialog
{
    idd = 78000;
    movingEnable = 0;
    enableSimulation = 1;

    onLoad = "uiNamespace setVariable ['ARC_console_display', _this # 0]; [_this # 0] call ARC_fnc_uiConsoleApplyLayout; [_this # 0] call ARC_fnc_uiConsoleOnLoad;";
    onUnload = "[] call ARC_fnc_uiConsoleOnUnload; uiNamespace setVariable ['ARC_console_display', displayNull];";

    class controlsBackground
    {
        class Shell: RscText
        {
            idc = 78090;
            x = safeZoneX;
            y = safeZoneY;
            w = safeZoneW;
            h = safeZoneH;
            colorBackground[] = {0.08,0.08,0.08,0.97};
        };

        class ShellBezel: RscText
        {
            idc = 78092;
            x = safeZoneX;
            y = safeZoneY;
            w = safeZoneW;
            h = safeZoneH;
            colorBackground[] = {0.16,0.16,0.16,0.96};
        };

        class ScreenBG: RscText
        {
            idc = 78093;
            x = safeZoneX;
            y = safeZoneY;
            w = safeZoneW;
            h = safeZoneH;
            colorBackground[] = {0.01,0.02,0.02,0.92};
        };

        class GripTL: RscText
        {
            idc = 78094;
            x = safeZoneX;
            y = safeZoneY;
            w = (0.018 * safeZoneW);
            h = (0.018 * safeZoneH);
            colorBackground[] = {0.24,0.24,0.24,1};
        };
        class GripTR: RscText
        {
            idc = 78095;
            x = safeZoneX + (0.982 * safeZoneW);
            y = safeZoneY;
            w = (0.018 * safeZoneW);
            h = (0.018 * safeZoneH);
            colorBackground[] = {0.24,0.24,0.24,1};
        };
        class GripBL: RscText
        {
            idc = 78096;
            x = safeZoneX;
            y = safeZoneY + (0.982 * safeZoneH);
            w = (0.018 * safeZoneW);
            h = (0.018 * safeZoneH);
            colorBackground[] = {0.24,0.24,0.24,1};
        };
        class GripBR: RscText
        {
            idc = 78097;
            x = safeZoneX + (0.982 * safeZoneW);
            y = safeZoneY + (0.982 * safeZoneH);
            w = (0.018 * safeZoneW);
            h = (0.018 * safeZoneH);
            colorBackground[] = {0.24,0.24,0.24,1};
        };

        class TitleBar: RscText
        {
            idc = 78091;
            
            colorText[] = {0.722,0.608,0.420,1};
text = "FARABAD CONSOLE";
            x = safeZoneX;
            y = safeZoneY;
            w = safeZoneW;
            h = (0.045 * safeZoneH);
            colorBackground[] = {0.04,0.06,0.06,0.95};
        };

        class StatusStripBG: RscText
        {
            idc = 78098;
            x = safeZoneX;
            y = safeZoneY + (0.045 * safeZoneH);
            w = safeZoneW;
            h = (0.03 * safeZoneH);
            colorBackground[] = {0.03,0.08,0.08,0.90};
        };

        // Dock layout anchor (UI runtime may switch to this frame when
        // ARC_console_layoutMode is set to "DOCK_RIGHT").
        class DockFrameAnchor: RscText
        {
            idc = 78099;
            x = safeZoneX + (0.66 * safeZoneW);
            y = safeZoneY + (0.01 * safeZoneH);
            w = (0.34 * safeZoneW);
            h = (0.98 * safeZoneH);
            colorBackground[] = {0,0,0,0};
        };

    };

    class controls
    {
        // TSH-INC1: Top status strip — four labeled indicators (NET / GPS / BATT / SYNC).
        // Each indicator is display-only in this increment (readout text and color only).
        // IDCs preserved: 78060=NET, 78061=GPS, 78062=BATT, 78063=SYNC (was RscButton, now RscText).
        class StatusNet: RscText
        {
            idc = 78060;
            text = "NET: --";
            x = safeZoneX + (0.010 * safeZoneW);
            y = safeZoneY + (0.049 * safeZoneH);
            w = (0.220 * safeZoneW);
            h = (0.022 * safeZoneH);
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.722,0.608,0.420,1};
        };

        class StatusGps: RscText
        {
            idc = 78061;
            text = "GPS: --";
            x = safeZoneX + (0.255 * safeZoneW);
            y = safeZoneY + (0.049 * safeZoneH);
            w = (0.220 * safeZoneW);
            h = (0.022 * safeZoneH);
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.722,0.608,0.420,1};
        };

        class StatusBatt: RscText
        {
            idc = 78062;
            text = "BATT: --";
            x = safeZoneX + (0.500 * safeZoneW);
            y = safeZoneY + (0.049 * safeZoneH);
            w = (0.220 * safeZoneW);
            h = (0.022 * safeZoneH);
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.722,0.608,0.420,1};
        };

        class StatusSync: RscText
        {
            idc = 78063;
            text = "SYNC: --";
            x = safeZoneX + (0.745 * safeZoneW);
            y = safeZoneY + (0.049 * safeZoneH);
            w = (0.220 * safeZoneW);
            h = (0.022 * safeZoneH);
            colorBackground[] = {0,0,0,0};
            colorText[] = {0.722,0.608,0.420,1};
        };

        class Tabs: RscListbox
        {
            idc = 78001;
            x = safeZoneX + (0.012 * safeZoneW);
            y = safeZoneY + (0.082 * safeZoneH);
            w = (0.226 * safeZoneW);
            h = (0.826 * safeZoneH);
            tooltip = "Select a console tab.";
            colorText[] = {0.722,0.608,0.420,1};
            colorSelect[] = {0.722,0.608,0.420,1};
            colorSelect2[] = {0.722,0.608,0.420,1};
            colorSelectBackground[] = {0.2,0.2,0.2,0.9};
            colorSelectBackground2[] = {0.2,0.2,0.2,0.9};
            onLBSelChanged = "_this call ARC_fnc_uiConsoleSelectTab;";
        };

        // Main panel (scrollable)
        class MainGroup: RscControlsGroup
        {
            idc = 78015;
            x = safeZoneX + (0.242 * safeZoneW);
            y = safeZoneY + (0.082 * safeZoneH);
            w = (0.756 * safeZoneW);
            h = (0.826 * safeZoneH);

            class controls
            {
                class Main: RscStructuredText
                {
                    idc = 78010;
                    x = 0.005;
                    y = 0.005;
                    w = 0.99;
                    h = 0.99;
                    colorBackground[] = {0.05,0.05,0.05,0.65};
                    colorText[] = {0.722,0.608,0.420,1};
                    tooltip = "Main content panel (scroll).";
                };
            };
        };

        class MainList: RscListbox
        {
            idc = 78011;
            x = safeZoneX + (0.242 * safeZoneW);
            y = safeZoneY + (0.082 * safeZoneH);
            w = (0.266 * safeZoneW);
            h = (0.826 * safeZoneH);
            colorBackground[] = {0.05,0.05,0.05,0.65};
            colorText[] = {0.722,0.608,0.420,1};
            colorSelect[] = {0.722,0.608,0.420,1};
            colorSelect2[] = {0.722,0.608,0.420,1};
            colorSelectBackground[] = {0.2,0.2,0.2,0.9};
            colorSelectBackground2[] = {0.2,0.2,0.2,0.9};
            tooltip = "Select an item. Details show on the right.";
            onLBSelChanged = "_this call ARC_fnc_uiConsoleMainListSelChanged;";
        };

        // Details panel (scrollable)
        class MainDetailsGroup: RscControlsGroup
        {
            idc = 78016;
            x = safeZoneX + (0.516 * safeZoneW);
            y = safeZoneY + (0.082 * safeZoneH);
            w = (0.482 * safeZoneW);
            h = (0.826 * safeZoneH);

            class controls
            {
                class MainDetails: RscStructuredText
                {
                    idc = 78012;
                    x = 0.005;
                    y = 0.005;
                    w = 0.99;
                    h = 0.99;
                    colorBackground[] = {0.05,0.05,0.05,0.65};
                    colorText[] = {0.722,0.608,0.420,1};
                    tooltip = "";
                };
            };
        };

        // -------------------------------------------------------------------
        // Intelligence (S2) tab workflow controls (hidden by default)
        // These are shown/managed by ARC_fnc_uiConsoleIntelPaint.
        // -------------------------------------------------------------------
        class S2_LabelMethod: RscText
        {
            idc = 78050;
            text = "Collection:";
            x = safeZoneX + (0.52 * safeZoneW);
            y = safeZoneY + (0.085 * safeZoneH);
            w = (0.10 * safeZoneW);
            h = (0.03 * safeZoneH);
            colorBackground[] = {0,0,0,0};
                    colorText[] = {0.722,0.608,0.420,1};
};
        class S2_ComboMethod: RscCombo
        {
            idc = 78051;
            x = safeZoneX + (0.63 * safeZoneW);
            y = safeZoneY + (0.085 * safeZoneH);
            w = (0.30 * safeZoneW);
            h = (0.04 * safeZoneH);
        };
        class S2_LabelCategory: RscText
        {
            idc = 78052;
            text = "Category:";
            x = safeZoneX + (0.52 * safeZoneW);
            y = safeZoneY + (0.135 * safeZoneH);
            w = (0.10 * safeZoneW);
            h = (0.03 * safeZoneH);
            colorBackground[] = {0,0,0,0};
                    colorText[] = {0.722,0.608,0.420,1};
};
        class S2_ComboCategory: RscCombo
        {
            idc = 78053;
            x = safeZoneX + (0.63 * safeZoneW);
            y = safeZoneY + (0.135 * safeZoneH);
            w = (0.30 * safeZoneW);
            h = (0.04 * safeZoneH);
        };
        class S2_LabelLeadType: RscText
        {
            idc = 78054;
            text = "Lead Type:";
            x = safeZoneX + (0.52 * safeZoneW);
            y = safeZoneY + (0.085 * safeZoneH);
            w = (0.10 * safeZoneW);
            h = (0.03 * safeZoneH);
            colorBackground[] = {0,0,0,0};
                    colorText[] = {0.722,0.608,0.420,1};
};
        class S2_ComboLeadType: RscCombo
        {
            idc = 78055;
            x = safeZoneX + (0.63 * safeZoneW);
            y = safeZoneY + (0.085 * safeZoneH);
            w = (0.30 * safeZoneW);
            h = (0.04 * safeZoneH);
        };

        // -------------------------------------------------------------------
        // Operations (S3) tab: 3 frames (Incidents / Orders / Leads)
        // Hidden by default; shown/managed by ARC_fnc_uiConsoleOpsPaint.
        // -------------------------------------------------------------------
        class OpsFrameInc_BG: RscText
        {
            idc = 78030;
            x = safeZoneX + (0.242 * safeZoneW);
            y = safeZoneY + (0.08 * safeZoneH);
            w = (0.266 * safeZoneW);
            h = (0.20 * safeZoneH);
            colorBackground[] = {0.05,0.05,0.05,0.65};
        };
        class OpsFrameInc_Label: RscText
        {
            idc = 78031;
            text = "INCIDENTS / TASKS";
            x = safeZoneX + (0.242 * safeZoneW);
            y = safeZoneY + (0.08 * safeZoneH);
            w = (0.266 * safeZoneW);
            h = (0.03 * safeZoneH);
            colorBackground[] = {0.05,0.05,0.05,0.92};
        };
        class OpsListIncidents: RscListbox
        {
            idc = 78032;
            x = safeZoneX + (0.242 * safeZoneW);
            y = safeZoneY + (0.11 * safeZoneH);
            w = (0.266 * safeZoneW);
            h = (0.17 * safeZoneH);
            colorBackground[] = {0.05,0.05,0.05,0.65};
            tooltip = "Incidents (current + recent).";
            onLBSelChanged = "_this call ARC_fnc_uiConsoleOpsSelChanged;";
        };

        class OpsFrameOrd_BG: RscText
        {
            idc = 78033;
            x = safeZoneX + (0.242 * safeZoneW);
            y = safeZoneY + (0.305 * safeZoneH);
            w = (0.266 * safeZoneW);
            h = (0.20 * safeZoneH);
            colorBackground[] = {0.05,0.05,0.05,0.65};
        };
        class OpsFrameOrd_Label: RscText
        {
            idc = 78034;
            text = "ORDERS / FRAGOS";
            x = safeZoneX + (0.242 * safeZoneW);
            y = safeZoneY + (0.305 * safeZoneH);
            w = (0.266 * safeZoneW);
            h = (0.03 * safeZoneH);
            colorBackground[] = {0.05,0.05,0.05,0.92};
        };
        class OpsListOrders: RscListbox
        {
            idc = 78035;
            x = safeZoneX + (0.242 * safeZoneW);
            y = safeZoneY + (0.335 * safeZoneH);
            w = (0.266 * safeZoneW);
            h = (0.17 * safeZoneH);
            colorBackground[] = {0.05,0.05,0.05,0.65};
            tooltip = "TOC-issued orders for units.";
            onLBSelChanged = "_this call ARC_fnc_uiConsoleOpsSelChanged;";
        };

        class OpsFrameLead_BG: RscText
        {
            idc = 78036;
            x = safeZoneX + (0.242 * safeZoneW);
            y = safeZoneY + (0.525 * safeZoneH);
            w = (0.266 * safeZoneW);
            h = (0.385 * safeZoneH);
            colorBackground[] = {0.05,0.05,0.05,0.65};
        };
        class OpsFrameLead_Label: RscText
        {
            idc = 78037;
            text = "LEADS / TIPS";
            x = safeZoneX + (0.242 * safeZoneW);
            y = safeZoneY + (0.525 * safeZoneH);
            w = (0.266 * safeZoneW);
            h = (0.03 * safeZoneH);
            colorBackground[] = {0.05,0.05,0.05,0.92};
        };
        class OpsListLeads: RscListbox
        {
            idc = 78038;
            x = safeZoneX + (0.242 * safeZoneW);
            y = safeZoneY + (0.555 * safeZoneH);
            w = (0.266 * safeZoneW);
            h = (0.355 * safeZoneH);
            colorBackground[] = {0.05,0.05,0.05,0.65};
            tooltip = "S2/S3 leads and follow-on targets.";
            onLBSelChanged = "_this call ARC_fnc_uiConsoleOpsSelChanged;";
        };

        class BtnPrimary: RscButton
        {
            idc = 78021;
            text = "ACTION";
            x = safeZoneX + (0.24 * safeZoneW);
            y = safeZoneY + (0.93 * safeZoneH);
            w = (0.20 * safeZoneW);
            h = (0.055 * safeZoneH);
            tooltip = "Primary action (context-sensitive).";
            // UI04+: button routing is tab-aware. Do not bind directly to a single action.
            // NOTE: UI event handlers are unscheduled; spawn to ensure scheduled context for dialogs/prompts.
            action = "[] spawn ARC_fnc_uiConsoleClickPrimary;";
        };

        class BtnSecondary: RscButton
        {
            idc = 78022;
            text = "ALT";
            x = safeZoneX + (0.49 * safeZoneW);
            y = safeZoneY + (0.93 * safeZoneH);
            w = (0.20 * safeZoneW);
            h = (0.055 * safeZoneH);
            tooltip = "Secondary action (context-sensitive).";
            // NOTE: UI event handlers are unscheduled; spawn to ensure scheduled context for dialogs/prompts.
            action = "[] spawn ARC_fnc_uiConsoleClickSecondary;";
        };

        class BtnRefresh: RscButton
        {
            idc = 78023;
            text = "REFRESH";
            x = safeZoneX + (0.71 * safeZoneW);
            y = safeZoneY + (0.93 * safeZoneH);
            w = (0.10 * safeZoneW);
            h = (0.055 * safeZoneH);
            tooltip = "Refresh the current view.";
            action = "[] call ARC_fnc_uiConsoleRefresh;";
        };

        class BtnClose: RscButton
        {
            idc = 78024;
            text = "CLOSE";
            x = safeZoneX + (0.82 * safeZoneW);
            y = safeZoneY + (0.93 * safeZoneH);
            w = (0.12 * safeZoneW);
            h = (0.055 * safeZoneH);
            tooltip = "Close the console.";
            action = "closeDialog 0;";
        };
    };
};

/*
    Follow-on Selector (UI05)

    Purpose:
      Provide a clean, non-addAction way for leaders to submit follow-on requests
      (RTB/HOLD/PROCEED) that are routed into the existing TOC queue system.

    The free-text note entry still uses ARC_IntelReportDialog via the command
    function ARC_fnc_intelClientRequestFollowOn.
*/
class ARC_FollowOnDialog
{
    idd = 78100;
    movingEnable = 1;
    enableSimulation = 1;

    onLoad = "uiNamespace setVariable ['ARC_followOn_display', _this # 0]; [_this # 0] call ARC_fnc_uiFollowOnDialogOnLoad;";
    onUnload = "uiNamespace setVariable ['ARC_followOn_display', displayNull];";

    class controlsBackground
    {
        class BG: RscText
        {
            idc = 78190;
            x = 0.20;
            y = 0.16;
            w = 0.60;
            h = 0.79;
            colorBackground[] = {0,0,0,0.80};
        };

        class TitleBar: RscText
        {
            idc = 78191;
            text = "FOLLOW-ON REQUEST";
            x = 0.20;
            y = 0.16;
            w = 0.60;
            h = 0.04;
            colorBackground[] = {0.05,0.05,0.05,0.92};
        };
    };

    class controls
    {
        class Header: RscStructuredText
        {
            idc = 78192;
            x = 0.21;
            y = 0.205;
            w = 0.58;
            h = 0.17;
        };

        class LabelRequest: RscText
        {
            idc = 78101;
            text = "Requested follow-on:";
            x = 0.21;
            y = 0.385;
            w = 0.25;
            h = 0.03;
        };
        class ComboRequest: RscCombo
        {
            idc = 78102;
            x = 0.46;
            y = 0.382;
            w = 0.33;
            h = 0.04;
            onLBSelChanged = "[] call ARC_fnc_uiFollowOnDialogUpdate;";
        };

        class LabelPurpose: RscText
        {
            idc = 78103;
            text = "RTB purpose:";
            x = 0.21;
            y = 0.432;
            w = 0.25;
            h = 0.03;
        };
        class ComboPurpose: RscCombo
        {
            idc = 78104;
            x = 0.46;
            y = 0.429;
            w = 0.33;
            h = 0.04;
        };

        class LabelHoldIntent: RscText
        {
            idc = 78105;
            text = "HOLD intent:";
            x = 0.21;
            y = 0.432;
            w = 0.25;
            h = 0.03;
        };
        class ComboHoldIntent: RscCombo
        {
            idc = 78106;
            x = 0.46;
            y = 0.429;
            w = 0.20;
            h = 0.04;
        };
        class LabelHoldMinutes: RscText
        {
            idc = 78107;
            text = "Min:";
            x = 0.67;
            y = 0.432;
            w = 0.05;
            h = 0.03;
        };
        class EditHoldMinutes: RscEdit
        {
            idc = 78108;
            x = 0.72;
            y = 0.429;
            w = 0.07;
            h = 0.04;
        };

        class LabelProceedIntent: RscText
        {
            idc = 78109;
            text = "PROCEED intent:";
            x = 0.21;
            y = 0.432;
            w = 0.25;
            h = 0.03;
        };
        class ComboProceedIntent: RscCombo
        {
            idc = 78110;
            x = 0.46;
            y = 0.429;
            w = 0.33;
            h = 0.04;
        };

        class LabelRationale: RscText
        {
            idc = 78111;
            text = "Rationale:";
            x = 0.21;
            y = 0.482;
            w = 0.25;
            h = 0.03;
        };
        class EditRationale: RscEdit
        {
            idc = 78112;
            x = 0.21;
            y = 0.512;
            w = 0.58;
            h = 0.04;
        };

        class LabelConstraints: RscText
        {
            idc = 78113;
            text = "Constraints:";
            x = 0.21;
            y = 0.562;
            w = 0.25;
            h = 0.03;
        };
        class EditConstraints: RscEdit
        {
            idc = 78114;
            x = 0.21;
            y = 0.592;
            w = 0.58;
            h = 0.04;
        };

        class LabelSupport: RscText
        {
            idc = 78115;
            text = "Support request:";
            x = 0.21;
            y = 0.642;
            w = 0.25;
            h = 0.03;
        };
        class EditSupport: RscEdit
        {
            idc = 78116;
            x = 0.21;
            y = 0.672;
            w = 0.58;
            h = 0.04;
        };

        class LabelNotes: RscText
        {
            idc = 78117;
            text = "Notes (optional):";
            x = 0.21;
            y = 0.722;
            w = 0.25;
            h = 0.03;
        };
        class EditNotes: RscEdit
        {
            idc = 78118;
            style = 16; // ST_MULTI
            x = 0.21;
            y = 0.752;
            w = 0.58;
            h = 0.12;
        };

        class BtnSubmit: RscButton
        {
            idc = 78120;
            text = "Submit";
            x = 0.21;
            y = 0.88;
            w = 0.28;
            h = 0.05;
            action = "[] call ARC_fnc_uiFollowOnDialogSubmit;";
        };

        class BtnCancel: RscButton
        {
            idc = 78121;
            text = "Cancel";
            x = 0.51;
            y = 0.88;
            w = 0.28;
            h = 0.05;
            action = "[] call ARC_fnc_uiFollowOnDialogCancel;";
        };
    };
};

class ARC_CloseoutDialog
{
    idd = 78200;
    movingEnable = 1;
    enableSimulation = 1;

    onLoad = "uiNamespace setVariable ['ARC_closeout_display', _this # 0]; uiNamespace setVariable ['ARC_closeout_result', nil]; private _d = _this # 0; private _body = uiNamespace getVariable ['ARC_closeout_body','']; (_d displayCtrl 78202) ctrlSetStructuredText parseText _body; private _lb = _d displayCtrl 78201; lbClear _lb; _lb lbAdd 'SUCCEEDED'; _lb lbAdd 'FAILED'; private _sel = uiNamespace getVariable ['ARC_closeout_defaultSel', 1]; if (!(_sel isEqualType 0)) then { _sel = 1; }; if (_sel < 0) then { _sel = 0; }; if (_sel > 1) then { _sel = 1; }; _lb lbSetCurSel _sel;";
    onUnload = "uiNamespace setVariable ['ARC_closeout_display', displayNull];";

    class controlsBackground
    {
        class BG: RscText
        {
            idc = 78290;
            x = 0.28;
            y = 0.20;
            w = 0.44;
            h = 0.50;
            colorBackground[] = {0,0,0,0.85};
        };

        class TitleBar: RscText
        {
            idc = 78291;
            text = 'INCIDENT CLOSEOUT';
            x = 0.28;
            y = 0.20;
            w = 0.44;
            h = 0.04;
            colorBackground[] = {0.05,0.05,0.05,0.92};
        };
    };

    class controls
    {
        class Body: RscStructuredText
        {
            idc = 78202;
            x = 0.29;
            y = 0.25;
            w = 0.42;
            h = 0.26;
            colorBackground[] = {0.05,0.05,0.05,0.65};
        };

        class Options: RscListbox
        {
            idc = 78201;
            x = 0.29;
            y = 0.52;
            w = 0.42;
            h = 0.10;
        };

        class BtnSubmit: RscButton
        {
            idc = 78211;
            text = 'Submit';
            x = 0.29;
            y = 0.64;
            w = 0.20;
            h = 0.05;
            action = "private _d = findDisplay 78200; private _lb = _d displayCtrl 78201; uiNamespace setVariable ['ARC_closeout_result', [true, lbCurSel _lb]]; closeDialog 1;";
        };

        class BtnCancel: RscButton
        {
            idc = 78212;
            text = 'Cancel';
            x = 0.51;
            y = 0.64;
            w = 0.20;
            h = 0.05;
            action = "uiNamespace setVariable ['ARC_closeout_result', [false, -1]]; closeDialog 2;";
        };
    };
};


/*
    CIVSUB Interact Dialog (ALiVE-style surface)

    Step 2 scope:
      - UI shell only.
      - Executes only local placeholders.
      - Session end triggers ARC_fnc_civsubInteractEndSession (server) via onUnload.
*/
class ARC_CivsubInteractDialog
{
    idd = 78300;
    movingEnable = 0;
    enableSimulation = 1;

    onLoad = "uiNamespace setVariable ['ARC_civsubInteract_display', _this # 0]; [_this # 0] call ARC_fnc_civsubContactDialogOnLoad;";
    onUnload = "[_this # 0] call ARC_fnc_civsubContactDialogOnUnload; uiNamespace setVariable ['ARC_civsubInteract_display', displayNull];";

    class controlsBackground
    {
        class BG: RscText
        {
            idc = 78390;
            x = 0.18;
            y = 0.18;
            w = 0.64;
            h = 0.74;
            colorBackground[] = {0,0,0,0.85};
        };

        class TitleBar: RscText
        {
            idc = 78391;
            text = "CIV INTERACT";
            x = 0.18;
            y = 0.18;
            w = 0.64;
            h = 0.04;
            colorBackground[] = {0.05,0.05,0.05,0.92};
        };
    };

    class controls
    {
        class Header: RscStructuredText
        {
            idc = 78392;
            x = 0.19;
            y = 0.23;
            w = 0.62;
            h = 0.07;
            colorBackground[] = {0.05,0.05,0.05,0.65};
        };

        class LabelActions: RscText
        {
            idc = 78301;
            text = "Actions";
            x = 0.19;
            y = 0.315;
            w = 0.30;
            h = 0.03;
        };

        class ActionsList: RscListbox
        {
            idc = 78310;
            x = 0.19;
            y = 0.345;
            w = 0.30;
            h = 0.32;
        
            colorText[] = {1,1,1,1};
            colorSelect[] = {1,1,1,1};
            colorSelect2[] = {1,1,1,1};
            colorSelectBackground[] = {0.2,0.2,0.2,0.9};
            colorSelectBackground2[] = {0.2,0.2,0.2,0.9};
            rowHeight = 0.035;
            sizeEx = 0.035;
            onLBSelChanged = "_this call ARC_fnc_civsubContactDialogOnActionSelChanged;";
};

        class LabelQuestions: RscText
        {
            idc = 78302;
            text = "Questions";
            x = 0.51;
            y = 0.315;
            w = 0.30;
            h = 0.03;
        };

        class QuestionsList: RscListbox
        {
            idc = 78311;
            x = 0.51;
            y = 0.345;
            w = 0.30;
            h = 0.32;
        
            colorText[] = {1,1,1,1};
            colorSelect[] = {1,1,1,1};
            colorSelect2[] = {1,1,1,1};
            colorSelectBackground[] = {0.2,0.2,0.2,0.9};
            colorSelectBackground2[] = {0.2,0.2,0.2,0.9};
            rowHeight = 0.035;
            sizeEx = 0.035;
            // Route selection changes through the handler so we can ignore selections in Action mode.
            onLBSelChanged = "_this call ARC_fnc_civsubContactDialogOnQuestionSelChanged;";
};

        // Right pane details (Action mode). This sits behind/alongside QuestionsList and is toggled via ctrlShow.
        class RightDetailsGroup: RscControlsGroup
        {
            idc = 78312;
            x = 0.51;
            y = 0.345;
            w = 0.30;
            h = 0.32;
            colorBackground[] = {0.05,0.05,0.05,0.0};

            class VScrollbar { width = 0.021; };
            class HScrollbar { height = 0; };

            class controls
            {
                class RightDetails: RscStructuredText
                {
                    idc = 78313;
                    x = 0;
                    y = 0;
                    w = 0.30;
                    h = 1.20;
                };
            };
        };

        class ResponseGroup: RscControlsGroup
{
    idc = 78319;
    x = 0.19;
    y = 0.67;
    w = 0.62;
    h = 0.17;
    colorBackground[] = {0.05,0.05,0.05,0.65};

    class VScrollbar
    {
        width = 0.021;
    };
    class HScrollbar
    {
        height = 0;
    };

    class controls
    {
        class Response: RscStructuredText
        {
            idc = 78320;
            x = 0;
            y = 0;
            w = 0.62;
            h = 0.60;
        };
    };
};


        
        // --- ID CARD OVERLAY (shown when Check ID succeeds) --------------------
        class IdOverlayBG: RscText
        {
            idc = 78360;
            x = 0.19;
            y = 0.23;
            w = 0.62;
            h = 0.61;
            colorBackground[] = {0,0,0,0.92};
        };

        class IdOverlayCard: RscStructuredText
        {
            idc = 78361;
            x = 0.205;
            y = 0.285;
            w = 0.59;
            h = 0.44;
            colorBackground[] = {0.96,0.95,0.90,1};
        };

        class IdOverlayBack: RscButton
        {
            idc = 78362;
            text = "Back";
            x = 0.51;
            y = 0.81;
            w = 0.30;
            h = 0.03;
            action = "[] call ARC_fnc_civsubContactDialogHideIdOverlay;";
        };

class BtnExecute: RscButton
        {
            idc = 78330;
            text = "Execute";
            x = 0.19;
            y = 0.85;
            w = 0.30;
            h = 0.04;
            action = "[] call ARC_fnc_civsubContactDialogExecute;";
        };

        class BtnClose: RscButton
        {
            idc = 78331;
            text = "Close";
            x = 0.51;
            y = 0.85;
            w = 0.30;
            h = 0.04;
            action = "closeDialog 0;";
        };
    };
};
