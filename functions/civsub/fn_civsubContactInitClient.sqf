/*
    ARC_fnc_civsubContactInitClient

    Client-side: initializes the ALiVE-style CIVSUB contact layer.

    Step 1 scope:
      - No dialog/UI yet.
      - The two addActions are attached per-civilian via server JIP remoteExec.
      - This init reserves a clean hook point for later steps.

    Params: none
*/

if (!hasInterface) exitWith {false};

if (missionNamespace getVariable ["civsub_v1_contact_init", false]) exitWith {true};
missionNamespace setVariable ["civsub_v1_contact_init", true];

true
