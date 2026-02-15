/*
    Return tasking flavor based on incident type + zone.

    Params:
        0: STRING - incidentType
        1: STRING - zone (Airbase / GreenZone / Other)

    Returns:
        ARRAY: [taskingFrom, supporting, constraints]
*/

params ["_incidentType", "_zone"];

private _type = toUpper _incidentType;
private _z = toUpper _zone;

private _tasking = "REDFALCON TOC";
private _support = "SHADOW OPS, THUNDER ROUTE 01";
private _constraints = "Standard ROE. Minimize civilian harm. Detain where possible.";

if (_z isEqualTo "AIRBASE") then
{
    _tasking = "FARABAD BDOC";
    _support = "SENTRY LAW 01, SENTRY QRF 01";
    _constraints = "Within JBF perimeter. Expect layered security, ECP procedures, and restricted areas.";
}
else
{
    if (_z isEqualTo "GREENZONE") then
    {
        _tasking = "FARABAD JOC / REDFALCON TOC";
        _support = "Takistan Police Liaison, SHERIFF 11, SHADOW OPS";
        _constraints = "Green Zone political sensitivity. Consider escalation risk and second-order effects.";
    };
};

// Type-specific overrides
switch (_type) do
{
    case "CHECKPOINT":
    {
        if (_z isEqualTo "AIRBASE") then
        {
            _tasking = "SENTRY GATE (ECP)";
            _support = "SENTRY LAW 01, SHERIFF 11";
            _constraints = "ECP procedures. Verify credentials and vehicles. Detain suspicious personnel for SHERIFF HOLDING.";
        }
        else
        {
            _tasking = "THUNDER ROUTE 01";
            _support = "SHERIFF 11, Takistan Police Liaison";
            _constraints = "Route security. Expect traffic and possible crowding. Avoid unnecessary escalation.";
        };
    };

    case "LOGISTICS":
    {
        _tasking = "MAYOR LRS 01";
        _support = "THUNDER ROUTE 01, SHERIFF 11";
        _constraints = "Protect sustainment assets. Keep convoy rolling unless threat forces a halt.";
    };

    case "ESCORT":
    {
        _tasking = "GRIFFIN CONVOY 11";
        _support = "THUNDER ROUTE 01, SHERIFF 11";
        _constraints = "Escort priority. Control spacing and speed. Watch overpasses and choke points.";
    };

    case "IED":
    {
        if (_z isEqualTo "AIRBASE") then
        {
            _tasking = "FARABAD BDOC";
            _support = "SENTRY LAW 01, EOD (as available)";
            _constraints = "Airbase incident. Treat as deliberate intrusion attempt. Secure, isolate, and exploit evidence.";
        }
        else
        {
            _tasking = "REDFALCON TOC";
            _support = "SHADOW OPS, EOD (as available), Takistan Police Liaison";
            _constraints = "Preserve site for exploitation. Search for triggermen and secondary devices.";
        };
    };

    case "CIVIL":
    {
        _tasking = "REDFALCON TOC";
        _support = "Takistan Police Liaison, Civil Affairs (notional)";
        _constraints = "Engage, assess, and report. Reduce friction. Do not create new enemies.";
    };

    case "QRF":
    {
        if (_z isEqualTo "AIRBASE") then
        {
            _tasking = "SENTRY QRF 01";
            _support = "FARABAD BDOC";
            _constraints = "Immediate response inside perimeter. Contain and hand off to BDOC.";
        };
    };
};

[_tasking, _support, _constraints]
