/*
    ARC WorldTime Events v1 (server-owned)

    Central Asian cultural daily event schedule driven by ARC_worldTimeSnap.
    Computes which prayer times, market periods, and cultural events are currently
    active or upcoming and publishes them for client UI consumption.

    Day-of-week calculation uses Tomohiko Sakamoto's algorithm:
      0=Saturday, 1=Sunday, 2=Monday, 3=Tuesday, 4=Wednesday, 5=Thursday, 6=Friday

    Public state (JIP-safe):
      ARC_worldTimeEvents: ARRAY of STRING — active event names for current time
      ARC_worldTimeNextEvent: ARRAY [STRING name, NUMBER startsAt] — next upcoming event

    Tunable (missionNamespace):
      ARC_worldTimeEvents_enabled (bool) default true
      ARC_worldTimeEvents_broadcastIntervalSec (number) default 30

    Event schedule (approximate Central Asian 40°N latitude, summer):
      Fajr             05.00 – 05.75  (pre-dawn prayer)
      Morning Bazaar   06.50 – 12.50  (MORNING + early WORK phase)
      Dhuhr            12.50 – 13.25  (midday prayer; Jumu'ah replaces on Fridays)
      Jumu'ah          12.00 – 13.50  (Friday congregational prayer, WORK phase)
      Asr              15.50 – 16.25  (afternoon prayer)
      Evening Bazaar   16.50 – 20.25  (WORK late + EVENING phase)
      Maghrib          20.25 – 21.00  (sunset prayer)
      Isha             21.50 – 22.50  (night prayer)
*/

if (!isServer) exitWith {};

// Prevent double-starts.
if (missionNamespace getVariable ["ARC_worldTimeEvents_running", false]) exitWith
{
    diag_log "[ARC][WORLDTIME EVENTS] already running";
};

// Safe defaults
if (isNil { missionNamespace getVariable "ARC_worldTimeEvents_enabled" }) then
{
    missionNamespace setVariable ["ARC_worldTimeEvents_enabled", true, true];
};
private _enabled = missionNamespace getVariable ["ARC_worldTimeEvents_enabled", true];
if (!(_enabled isEqualType true)) then { _enabled = true; };

if (!_enabled) exitWith
{
    diag_log "[ARC][WORLDTIME EVENTS] disabled by ARC_worldTimeEvents_enabled";
};

if (isNil { missionNamespace getVariable "ARC_worldTimeEvents_broadcastIntervalSec" }) then
{
    missionNamespace setVariable ["ARC_worldTimeEvents_broadcastIntervalSec", 30, true];
};

missionNamespace setVariable ["ARC_worldTimeEvents_running", true];

// Wait for server ready before starting loop (worldtime must be online first).
waitUntil { missionNamespace getVariable ["ARC_serverReady", false] };

diag_log "[ARC][WORLDTIME EVENTS] server ready, starting event loop";

// ---------------------------------------------------------------------------
// Event schedule table.
// Each entry: [STRING name, NUMBER startHour, NUMBER endHour, BOOL fridayOnly]
// Hours are decimal 0..24.
// ---------------------------------------------------------------------------
private _eventTable = [
    ["Fajr (pre-dawn prayer)",      5.00, 5.75,  false],
    ["Morning Bazaar",              6.50, 12.50, false],
    ["Dhuhr (midday prayer)",      12.50, 13.25, false],
    ["Jumu'ah (Friday prayer)",    12.00, 13.50, true ],
    ["Asr (afternoon prayer)",     15.50, 16.25, false],
    ["Evening Bazaar",             16.50, 20.25, false],
    ["Maghrib (sunset prayer)",    20.25, 21.00, false],
    ["Isha (night prayer)",        21.50, 22.50, false]
];

// ---------------------------------------------------------------------------
// Day-of-week helper (Tomohiko Sakamoto, 0=Sat … 6=Fri).
// Input: date array [year, month, day, hour, minute]
// ---------------------------------------------------------------------------
private _fnDayOfWeek = {
    params [["_da", [], [[]]]];
    if ((count _da) < 3) exitWith { -1 };
    private _y = _da select 0;
    private _m = _da select 1;
    private _d = _da select 2;
    if (!(_y isEqualType 0) || !(_m isEqualType 0) || !(_d isEqualType 0)) exitWith { -1 };
    if (_m < 3) then { _y = _y - 1; _m = _m + 12; };
    (_d + floor (13 * (_m + 1) / 5) + _y + floor (_y / 4) - floor (_y / 100) + floor (_y / 400)) mod 7
};

// ---------------------------------------------------------------------------
// Event computation.
// Returns [activeEvents, nextEventPair].
// ---------------------------------------------------------------------------
private _fnComputeEvents = {
    params [["_dt", 12.0, [0]], ["_dow", 0, [0]]];

    private _isFriday = (_dow == 6);
    private _active = [];
    private _nextName = "";
    private _nextStart = 25.0;

    {
        private _evName  = _x select 0;
        private _evStart = _x select 1;
        private _evEnd   = _x select 2;
        private _fridayOnly = _x select 3;

        if (_fridayOnly && !_isFriday) then { continue; };

        // Suppress Dhuhr on Fridays (Jumu'ah replaces it).
        if (_evName isEqualTo "Dhuhr (midday prayer)" && { _isFriday }) then { continue; };

        if (_dt >= _evStart && { _dt < _evEnd }) then
        {
            _active pushBack _evName;
        }
        else
        {
            if (_evStart > _dt && { _evStart < _nextStart }) then
            {
                _nextStart = _evStart;
                _nextName  = _evName;
            };
        };
    } forEach _eventTable;

    [_active, [_nextName, _nextStart]]
};

// ---------------------------------------------------------------------------
// Broadcast loop.
// ---------------------------------------------------------------------------
[_eventTable, _fnDayOfWeek, _fnComputeEvents] spawn
{
    params ["_eventTable", "_fnDayOfWeek", "_fnComputeEvents"];

    private _interval = missionNamespace getVariable ["ARC_worldTimeEvents_broadcastIntervalSec", 30];
    if (!(_interval isEqualType 0) || { _interval < 5 }) then { _interval = 30; };

    diag_log format ["[ARC][WORLDTIME EVENTS] loop start (interval=%1s)", _interval];

    while { missionNamespace getVariable ["ARC_worldTimeEvents_running", false] } do
    {
        private _snap = missionNamespace getVariable ["ARC_worldTimeSnap", []];

        if (_snap isEqualType [] && { (count _snap) >= 2 }) then
        {
            private _dateArr = _snap select 0;
            private _dt      = _snap select 1;

            if (!(_dt isEqualType 0)) then { _dt = 12.0; };

            private _dow = [_dateArr] call _fnDayOfWeek;
            if (_dow < 0) then { _dow = 0; };

            private _result = [_dt, _dow] call _fnComputeEvents;
            private _active = _result select 0;
            private _next   = _result select 1;

            missionNamespace setVariable ["ARC_worldTimeEvents",     _active, true];
            missionNamespace setVariable ["ARC_worldTimeNextEvent",  _next,   true];

            if (missionNamespace getVariable ["ARC_debugLogEnabled", false]) then
            {
                diag_log format [
                    "[ARC][WORLDTIME EVENTS] dt=%1 dow=%2 active=%3 next=%4",
                    _dt, _dow, _active, _next
                ];
            };
        };

        sleep _interval;
    };

    diag_log "[ARC][WORLDTIME EVENTS] loop stopped";
};
