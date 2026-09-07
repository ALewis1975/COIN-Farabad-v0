private _clockGet = compile "params ['_h','_k']; (_h) get _k";
private _clockMap = compile "params ['_pairs']; createHashMapFromArray _pairs";
/* Standalone SQF-VM or Arma: executes the production pure clock helpers. */
private _core = compile preprocessFileLineNumbers "functions/core/fn_stateRebaseClock.sqf";
private _civ = compile preprocessFileLineNumbers "functions/civsub/fn_civsubPersistRebaseClock.sqf";
private _passed = 0;
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["CLOCK FAIL: %1", _label]};
    _passed = _passed + 1;
    diag_log format ["CLOCK PASS: %1", _label];
};
private _get = {
    params ["_pairs", "_key"];
    private _i = -1;
    { if ((_x select 0) isEqualTo _key) exitWith { _i = _forEachIndex; }; } forEach _pairs;
    if (_i < 0) exitWith {[]};
    (_pairs select _i) select 1
};
private _casRecord = ([[["created_at", 13800], ["messages", [[["at", 14000]]]]]] call _clockMap);
private _source = [
    ["persistenceClock", [1,14400,[],"FREEZE_OFFLINE"]],
    ["activeExecStartedAt",13900], ["activeExecArrivalReq",900],
    ["activeExecDeadlineAt",15000], ["activeExecHoldAccum",125],
    ["activeIedEvidenceCreatedAt",-1], ["sustainLastAt",14350],
    ["leadPool", [["L1","IED","lead",[500,800,0],0.8,13800,15000,"","","","",[]]]],
    ["casreq_v1_records", ([[["R1",_casRecord]]] call _clockMap)],
    ["unknownSubsystem", [["distance",14400],["TTL_seconds",900]]]
];
private _restored = [_source,14400,30] call _core;
[([_restored,"activeExecDeadlineAt"] call _get) == 630, "600-second deadline survives four-hour clock reset"] call _assert;
[([_restored,"activeExecStartedAt"] call _get) == 0, "execution remains started after clock reset"] call _assert;
[([_restored,"activeExecArrivalReq"] call _get) == 430, "arrival budget retains 400 seconds remaining"] call _assert;
[([_restored,"activeExecHoldAccum"] call _get) == 125, "accumulated hold duration unchanged"] call _assert;
[([_restored,"activeIedEvidenceCreatedAt"] call _get) == -1, "unset timestamp sentinel preserved"] call _assert;
[([_restored,"sustainLastAt"] call _get) == 30, "supply decay restarts without offline drain"] call _assert;
private _lead = ([_restored,"leadPool"] call _get) select 0;
[(_lead select 5) == -570 && {(_lead select 6) == 630}, "lead age and remaining TTL preserved"] call _assert;
[(_lead select 3) isEqualTo [500,800,0] && {(_lead select 4) == 0.8}, "position and strength untouched"] call _assert;
[([_casRecord, "created_at"] call _clockGet) == 13800, "HashMap profile input not mutated"] call _assert;
private _restoredRecord = [[_restored,"casreq_v1_records"] call _get, "R1"] call _clockGet;
[([_restoredRecord, "created_at"] call _clockGet) == -570, "CAS record age survives restart"] call _assert;
[([_restored,"unknownSubsystem"] call _get) isEqualTo ([_source,"unknownSubsystem"] call _get), "unknown non-time values preserved"] call _assert;
private _again = [_source,14400,30] call _core;
[_again isEqualTo _restored, "repeated load from same profile is idempotent"] call _assert;
private _savedAgain = [_restored,30,30] call _core;
private _secondRestart = [_savedAgain,30,10] call _core;
[([_secondRestart,"activeExecDeadlineAt"] call _get) == 610, "second restart preserves remaining duration"] call _assert;
private _edge = [[["casreq_v1_records",([[["EDGE",[["created_at",99]]]]] call _clockMap)]],100,0] call _core;
private _edgeAgain = [_edge,0,30] call _core;
private _edgeRec = [[_edgeAgain,"casreq_v1_records"] call _get, "EDGE"] call _clockGet;
[([_edgeRec,"created_at"] call _get) == 29,"historical minus-one timestamp is not mistaken for a sentinel"] call _assert;
private _vbied = [["activeVbiedAlerted",true],["activeVbiedAlertAt",14340],["activeVbiedPauseSince",-1],["activeVbiedElapsedBeforeLoad",0]];
private _vbiedLoaded = [_vbied,14400,30] call _core;
[([_vbiedLoaded,"activeVbiedElapsedBeforeLoad"] call _get) == 30,"VBIED elapsed time lost to start sentinel clamp is carried"] call _assert;
_vbied set [2,["activeVbiedPauseSince",14370]];
private _pausedLoaded = [_vbied,14400,10] call _core;
[([_pausedLoaded,"activeVbiedElapsedBeforeLoad"] call _get) == 30,"VBIED active pause deducted from elapsed carry"] call _assert;

private _district = ["D_TEST",[100,200],700,1000,45,55,35,45,55,35,50,50,50,15000,14700,14300];
private _civSource = [["version",1],["districts",[_district]],["identities",[]],["crimedb",[]],["persistenceClock",[1,14400,[],"FREEZE_OFFLINE"]]];
private _civRestored = [_civSource,30] call _civ;
private _d = ([_civRestored,"districts"] call _get) select 0;
[(_d select 13) == 630 && {(_d select 14) == 330}, "CIVSUB cooldown remaining times preserved"] call _assert;
[(_district select 13) == 15000, "CIVSUB profile tuple untouched"] call _assert;
[(_d select 7) == 45 && {(_d select 3) == 1000}, "CIVSUB influence and population unchanged"] call _assert;
private _legacy = [["version",1],["districts",[_district]],["identities",[]],["crimedb",[]]];
private _migrated = [_legacy,30] call _civ;
private _m = ([_migrated,"districts"] call _get) select 0;
[(_m select 13) == 3630 && {(_m select 14) == 1830}, "unanchored CIVSUB legacy cooldowns bounded explicitly"] call _assert;
private _bad = [["persistenceClock",[99,14400,[],"FREEZE_OFFLINE"]]];
[([_bad,30] call _civ) isEqualTo [], "future CIVSUB clock fails closed"] call _assert;
diag_log format ["CLOCK REGRESSION COMPLETE: %1 PASS", _passed];
