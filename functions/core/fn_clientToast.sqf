/*
    ARC_fnc_clientToast

    Client: lightweight "toast" notification for command-cycle UX.

    Why this exists:
      - systemChat is easy to miss
      - Several workflows depend on the player realizing a step is pending (accept order, debrief, process EPW)

    Params:
      0: STRING title
      1: STRING body (optional)
      2: NUMBER duration seconds (optional, default 5)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_title", ""],
    ["_body", ""],
    ["_duration", 5]
];

if (!(_title isEqualType "")) then { _title = str _title; };
if (!(_body isEqualType "")) then { _body = str _body; };
if (!(_duration isEqualType 0)) then { _duration = 5; };
_duration = (_duration max 2) min 12;

private _scale = missionNamespace getVariable ["ARC_uiToastScale", 0.85];
if (!(_scale isEqualType 0)) then { _scale = 0.85; };
_scale = (_scale max 0.6) min 1.2;

private _titleSize = 1.15 * _scale;
private _bodySize = 0.95 * _scale;

private _bodyPart = if (_body isEqualTo "") then { "" } else { format ["<br/><t size='%1' color='#DDDDDD'>%2</t>", _bodySize, _body] };

private _text = format [
    "<t font='PuristaMedium' size='%1' color='#FFFFFF'>%2</t>%3",
    _titleSize,
    _title,
    _bodyPart
];

// Upper-right-ish so it doesn't fight the task timer HUD.
[_text, 0.62, 0.14, _duration, 0.25] spawn BIS_fnc_dynamicText;

// Light audio cue (safe even if sound is overridden).
playSound "Hint";

// Also mirror to chat for logging/screenshots.
if (_body isEqualTo "") then
{
    systemChat format ["[ARC] %1", _title];
}
else
{
    systemChat format ["[ARC] %1 - %2", _title, _body];
};

true
