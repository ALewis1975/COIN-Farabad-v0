/*
    ARC_fnc_consoleThemeGet

    Returns Farabad Console UI theme colors.

    Output:
      HASHMAP with keys:
        bezelOuter, bezelGreen, bezelInner, screen,
        text, border,
        statusGreen, statusAmber, statusRed

    Notes:
    - Colors are RGBA arrays with 0..1 floats.
    - Kept in code to avoid adding texture assets.
*/

private _t = createHashMap;

// Bezel layers (rugged tablet)
_t set ["bezelOuter", [0.169,0.184,0.200,1]];  // gunmetal outer
_t set ["bezelGreen", [0.184,0.243,0.184,1]];  // OD green ring
_t set ["bezelInner", [0.118,0.133,0.149,1]];  // gunmetal inner

// Screen + typography
_t set ["screen",     [0.039,0.043,0.047,1]];  // near-black screen
_t set ["text",       [0.722,0.608,0.420,1]];  // coyote text
_t set ["border",     [0.765,0.659,0.459,1]];  // coyote border (slightly brighter)

// Status / prompts (R/A/G)
_t set ["statusGreen", [0.247,0.639,0.302,1]];
_t set ["statusAmber", [0.851,0.643,0.255,1]];
_t set ["statusRed",   [0.784,0.298,0.298,1]];

_t
