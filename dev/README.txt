ARC Dev Tools v2 (solo-friendly)
================================

Drop the 'dev' folder into your mission root:
  dev\ARC_selfTest.sqf
  dev\ARC_bumpSnapshot.sqf

Run (Debug Console):
  [] execVM "dev\ARC_selfTest.sqf";
  [true] execVM "dev\ARC_selfTest.sqf";
  [] execVM "dev\ARC_bumpSnapshot.sqf";

These scripts ALWAYS write to RPT using [ARC][DEV] lines (no dependency on ARC_debugLogEnabled).
