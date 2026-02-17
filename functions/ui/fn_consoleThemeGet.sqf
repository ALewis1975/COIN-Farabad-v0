/*
    ARC_fnc_consoleThemeGet

    Canonical path: functions/ui/fn_consoleThemeGet.sqf

    Returns Farabad Console UI theme colors as a HashMap of RGBA arrays.

    Canonical keys:
      bezelOuter, bezelGreen, bezelInner, screen,
      text, border,
      statusGreen, statusAmber, statusRed

    Backward-compatible aliases (same values):
      gunmetalOuter -> bezelOuter
      greenRing     -> bezelGreen
      gunmetalInner -> bezelInner
      screenBlack   -> screen
      coyoteText    -> text
      coyoteBorder  -> border
*/

private _t = createHashMap;

// Canonical key set
_t set ["bezelOuter",  [0.169,0.184,0.200,1]];  // gunmetal outer
_t set ["bezelGreen",  [0.184,0.243,0.184,1]];  // OD green ring
_t set ["bezelInner",  [0.118,0.133,0.149,1]];  // gunmetal inner
_t set ["screen",      [0.039,0.043,0.047,1]];  // near-black screen
_t set ["text",        [0.722,0.608,0.420,1]];  // coyote text
_t set ["border",      [0.765,0.659,0.459,1]];  // coyote border
_t set ["statusGreen", [0.247,0.639,0.302,1]];
_t set ["statusAmber", [0.851,0.643,0.255,1]];
_t set ["statusRed",   [0.784,0.298,0.298,1]];

// Legacy aliases kept for migration compatibility.
_t set ["gunmetalOuter", _t get "bezelOuter"];
_t set ["greenRing",     _t get "bezelGreen"];
_t set ["gunmetalInner", _t get "bezelInner"];
_t set ["screenBlack",   _t get "screen"];
_t set ["coyoteText",    _t get "text"];
_t set ["coyoteBorder",  _t get "border"];

_t
