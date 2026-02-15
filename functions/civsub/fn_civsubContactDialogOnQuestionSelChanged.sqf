/*
    ARC_fnc_civsubContactDialogOnQuestionSelChanged

    Handles QuestionsList selection changes:
      - If in Questions mode, marks lastPane "Q"
      - If not in Questions mode, cancels selection (right pane is details-only).
*/

if (!hasInterface) exitWith { true };

params [["_ctrl", controlNull, [controlNull]], ["_idx", -1, [0]]];

private _mode = uiNamespace getVariable ["ARC_civsubInteract_mode", "A"];
if (_mode isEqualTo "Q") then {
    uiNamespace setVariable ["ARC_civsubInteract_lastPane", "Q"];

    // Capture the selected question id so Execute does not depend on listbox contents elsewhere.
    private _qid = "";
    if (!isNull _ctrl && {_idx >= 0}) then {
        _qid = _ctrl lbData _idx;
    };
    uiNamespace setVariable ["ARC_civsubInteract_selectedQid", _qid];
} else {
    // prevent accidental routing; details pane is not selectable in action mode
    if (!isNull _ctrl) then { _ctrl lbSetCurSel -1; };
    uiNamespace setVariable ["ARC_civsubInteract_selectedQid", ""]; 
};

true
