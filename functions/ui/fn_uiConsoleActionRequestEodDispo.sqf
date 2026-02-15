/*
    ARC_fnc_uiConsoleActionRequestEodDispo

    Legacy client action (formerly used from OPS primary button during IED incidents).

    Authoritative behavior:
      - EOD disposition requests are submitted in the SAME flow as the close-out SITREP.
      - This separate action is intentionally disabled to keep SITREP as the backbone.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

["EOD", "Submit a close-out SITREP to request EOD disposition."] call ARC_fnc_clientToast;
false
