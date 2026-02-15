/*
    ARC_fnc_intelClientCanRequestFollowOn

    Client: gate for player follow-on requests.

    Policy (Farabad COIN):
      - Follow-on requests are submitted as part of the SITREP workflow.
      - A separate "Request Follow-on" action is disabled to keep the loop clean and prevent
        out-of-band queue items and stale issued orders.

    Returns:
      BOOL (always false)
*/

if (!hasInterface) exitWith {false};

// Keep the role check so unauthorized users don't leak UI actions in edge cases.
if (!([player] call ARC_fnc_rolesIsAuthorized)) exitWith {false};

false
