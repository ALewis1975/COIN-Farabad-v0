/*
    ARC_fnc_uiConsoleFormatDetail

    Shared helper: build detail pane HTML from a key-value card schema.

    Replaces per-painter detail-line arrays with a consistent card format.

    Params:
      0: STRING — card title (e.g. "Flight Details", "Incident Summary")
      1: ARRAY  — rows, each element: [label, value]
         - label: STRING — field label
         - value: STRING — field value (may include HTML color tags)
      2: STRING — (optional) footer text

    Returns:
      STRING — structured text HTML for the detail pane
*/

params [
    ["_title", "", [""]],
    ["_rows", [], [[]]],
    ["_footer", "", [""]]
];

private _coyote = "#B89B6B";

private _html = format ["<t size='1.05' color='%1'>%2</t><br/>", _coyote, _title];
_html = _html + format ["<t color='%1'>────────────────────</t><br/>", _coyote];

{
    if (_x isEqualType [] && { (count _x) >= 2 }) then {
        private _label = _x select 0;
        private _value = _x select 1;
        if (!(_label isEqualType "")) then { _label = str _label; };
        if (!(_value isEqualType "")) then { _value = str _value; };
        _html = _html + format ["<t color='%1'>%2:</t>  <t color='#FFFFFF'>%3</t><br/>", _coyote, _label, _value];
    };
} forEach _rows;

if (!(_footer isEqualTo "")) then {
    _html = _html + "<br/>";
    _html = _html + format ["<t size='0.85' color='#888888'>%1</t>", _footer];
};

_html
