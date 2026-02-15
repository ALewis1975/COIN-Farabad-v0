/*
    ARC_fnc_intelUiOpenQueueManager

    Client: open the TOC Queue Manager dialog.

    Intended users: TOC S3 / Command (queue approvers).
*/

if (!hasInterface) exitWith {false};

// Safety: require an authorized role, but allow view-only access for non-approvers.
if !([player] call ARC_fnc_rolesIsAuthorized) exitWith { false };

if !([player] call ARC_fnc_rolesCanApproveQueue) then
{
    ["TOC Queue", "View-only: Approve/Reject disabled (S3/Command only)."] call ARC_fnc_clientHint;
};

createDialog "ARC_TOCQueueManagerDialog";
true
