/*
  ARC_clearLightbarToastClient.sqf
  Farabad COIN - Clears Police Extended "Lightbar ON" toast (client-side)

  Purpose:
    - Clears hint/cutText/titleText overlays shortly after mission start
    - Intended to remove the "Lightbar ON" helper window shown when CODE2_On.sqf runs

  Locality:
    - Client only (hasInterface)
*/

if (!hasInterface) exitWith {};

[] spawn {
  uiSleep 0.25;
  hintSilent "";
  cutText ["", "PLAIN"];
  titleText ["", "PLAIN"];

  // Second pass in case the mod prints slightly later
  uiSleep 0.75;
  hintSilent "";
  cutText ["", "PLAIN"];
  titleText ["", "PLAIN"];
};
