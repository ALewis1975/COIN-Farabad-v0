/*
    ARC_fnc_sitrepGateEval

    Shared gate evaluation for SITREP and task-state transitions.
    Produces a canonical result with reason codes for parity between
    client pre-checks and server authority checks.

    Reference: docs/architecture/SITREP_Gate_Parity.md

    Params:
        0: STRING  - gateType (e.g. "UNIT_SITREP_SUBMIT", "UNIT_ACCEPT", "UNIT_COMPLETE", etc.)
        1: HASHMAP - context:
            "taskId"        STRING  - current task ID
            "taskState"     STRING  - current task state (canonical)
            "incidentType"  STRING  - incident type
            "accepted"      BOOL    - is incident accepted
            "closeReady"    BOOL    - is incident marked ready to close
            "sitrepSent"    BOOL    - has SITREP already been sent
            "caller"        OBJECT  - the player/unit requesting (optional for server-only checks)
            "roleAuthorized" BOOL   - is caller role-authorized (pre-evaluated)
            "proximity"     BOOL    - is caller within proximity (pre-evaluated, -1 = not checked)

    Returns:
        HASHMAP with keys:
            "allowed"       BOOL
            "reasonCode"    STRING  (canonical reason code)
            "stage"         STRING  ("client_precheck" | "server_authority" | "shared")

    Canonical reason codes (per SITREP_Gate_Parity.md):
        OK_ALLOWED, OK_IDEMPOTENT,
        E_PAYLOAD_MALFORMED, E_REQUIRED_FIELD_MISSING, E_INVALID_ENUM,
        E_AUTH_SCOPE_DENIED, E_ROLE_NOT_AUTHORIZED,
        E_STATE_NOT_ALLOWED, E_STATE_NOT_READY_FOR_SITREP, E_STATE_NOT_PENDING_TOC, E_STATE_NOT_FOLLOWON_PENDING,
        E_TOKEN_REQUIRED, E_TOKEN_MISMATCH, E_TOKEN_EXPIRED_OR_STALE,
        E_REASON_REQUIRED, E_TEXT_TOO_LONG,
        E_CONFLICT_RETRY, E_SERVER_AUTHORITY_REQUIRED, E_INTERNAL_GUARD_FAILURE
*/

params [
    ["_gateType", "", [""]],
    ["_ctx", createHashMap, [createHashMap]]
];

// sqflint-compatible helpers
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _trimFn = compile "params ['_s']; trim _s";

private _result = createHashMap;
_result set ["allowed", false];
_result set ["reasonCode", "E_INTERNAL_GUARD_FAILURE"];
_result set ["stage", "shared"];

if (_gateType isEqualTo "") exitWith {
    _result set ["reasonCode", "E_REQUIRED_FIELD_MISSING"];
    _result
};

private _gateU = toUpper ([_gateType] call _trimFn);

private _taskId = [_ctx, "taskId", ""] call _hg;
private _taskState = toUpper ([([_ctx, "taskState", ""] call _hg)] call _trimFn);
private _incidentType = toUpper ([([_ctx, "incidentType", ""] call _hg)] call _trimFn);
private _accepted = [_ctx, "accepted", false] call _hg;
private _closeReady = [_ctx, "closeReady", false] call _hg;
private _sitrepSent = [_ctx, "sitrepSent", false] call _hg;
private _roleAuth = [_ctx, "roleAuthorized", false] call _hg;
private _proximity = [_ctx, "proximity", -1] call _hg;

// --- Gate evaluation per type -----------------------------------------------

switch (_gateU) do {

    case "UNIT_ACCEPT": {
        if (_taskId isEqualTo "") exitWith {
            _result set ["reasonCode", "E_REQUIRED_FIELD_MISSING"];
        };
        if (!(_taskState isEqualTo "OFFERED")) exitWith {
            _result set ["reasonCode", "E_STATE_NOT_ALLOWED"];
        };
        if (!_roleAuth) exitWith {
            _result set ["reasonCode", "E_ROLE_NOT_AUTHORIZED"];
        };
        _result set ["allowed", true];
        _result set ["reasonCode", "OK_ALLOWED"];
    };

    case "UNIT_PROGRESS": {
        if (_taskId isEqualTo "") exitWith {
            _result set ["reasonCode", "E_REQUIRED_FIELD_MISSING"];
        };
        if (!(_taskState in ["ACCEPTED", "IN_PROGRESS"])) exitWith {
            _result set ["reasonCode", "E_STATE_NOT_ALLOWED"];
        };
        if (!_roleAuth) exitWith {
            _result set ["reasonCode", "E_ROLE_NOT_AUTHORIZED"];
        };
        _result set ["allowed", true];
        _result set ["reasonCode", "OK_ALLOWED"];
    };

    case "UNIT_COMPLETE": {
        if (_taskId isEqualTo "") exitWith {
            _result set ["reasonCode", "E_REQUIRED_FIELD_MISSING"];
        };
        if (!(_taskState in ["ACCEPTED", "IN_PROGRESS"])) exitWith {
            _result set ["reasonCode", "E_STATE_NOT_ALLOWED"];
        };
        if (!_roleAuth) exitWith {
            _result set ["reasonCode", "E_ROLE_NOT_AUTHORIZED"];
        };
        _result set ["allowed", true];
        _result set ["reasonCode", "OK_ALLOWED"];
    };

    case "UNIT_NOTE": {
        if (_taskId isEqualTo "") exitWith {
            _result set ["reasonCode", "E_REQUIRED_FIELD_MISSING"];
        };
        private _allowedStates = ["ACCEPTED", "IN_PROGRESS", "COMPLETE_PENDING_SITREP", "SITREP_SUBMITTED_PENDING_TOC", "FOLLOWON_ORDERED_PENDING_UNIT_ACK"];
        if (!(_taskState in _allowedStates)) exitWith {
            _result set ["reasonCode", "E_STATE_NOT_ALLOWED"];
        };
        _result set ["allowed", true];
        _result set ["reasonCode", "OK_ALLOWED"];
    };

    case "UNIT_SITREP_SUBMIT": {
        // Primary SITREP gate (client pre-check + server authority share this logic)
        if (_taskId isEqualTo "") exitWith {
            _result set ["reasonCode", "E_REQUIRED_FIELD_MISSING"];
        };
        if (!_accepted) exitWith {
            _result set ["reasonCode", "E_STATE_NOT_ALLOWED"];
        };
        // IED incidents can submit SITREP before closeReady
        if (!(_incidentType isEqualTo "IED")) then {
            if (!_closeReady) exitWith {
                _result set ["reasonCode", "E_STATE_NOT_READY_FOR_SITREP"];
            };
        };
        if (_sitrepSent) exitWith {
            _result set ["reasonCode", "OK_IDEMPOTENT"];
        };
        if (!_roleAuth) exitWith {
            _result set ["reasonCode", "E_ROLE_NOT_AUTHORIZED"];
        };
        // Proximity check (only evaluated if provided; -1 = not checked / N/A)
        if (_proximity isEqualType true) then {
            if (!_proximity) exitWith {
                _result set ["reasonCode", "E_AUTH_SCOPE_DENIED"];
            };
        };
        _result set ["allowed", true];
        _result set ["reasonCode", "OK_ALLOWED"];
    };

    case "TOC_DECISION": {
        if (_taskId isEqualTo "") exitWith {
            _result set ["reasonCode", "E_REQUIRED_FIELD_MISSING"];
        };
        if (!(_taskState isEqualTo "SITREP_SUBMITTED_PENDING_TOC")) exitWith {
            _result set ["reasonCode", "E_STATE_NOT_PENDING_TOC"];
        };
        if (!_roleAuth) exitWith {
            _result set ["reasonCode", "E_ROLE_NOT_AUTHORIZED"];
        };
        _result set ["allowed", true];
        _result set ["reasonCode", "OK_ALLOWED"];
    };

    case "UNIT_FOLLOWON_ACK": {
        if (_taskId isEqualTo "") exitWith {
            _result set ["reasonCode", "E_REQUIRED_FIELD_MISSING"];
        };
        if (!(_taskState isEqualTo "FOLLOWON_ORDERED_PENDING_UNIT_ACK")) exitWith {
            _result set ["reasonCode", "E_STATE_NOT_FOLLOWON_PENDING"];
        };
        if (!_roleAuth) exitWith {
            _result set ["reasonCode", "E_ROLE_NOT_AUTHORIZED"];
        };
        _result set ["allowed", true];
        _result set ["reasonCode", "OK_ALLOWED"];
    };

    case "UNIT_FOLLOWON_UNABLE": {
        if (_taskId isEqualTo "") exitWith {
            _result set ["reasonCode", "E_REQUIRED_FIELD_MISSING"];
        };
        if (!(_taskState isEqualTo "FOLLOWON_ORDERED_PENDING_UNIT_ACK")) exitWith {
            _result set ["reasonCode", "E_STATE_NOT_FOLLOWON_PENDING"];
        };
        _result set ["allowed", true];
        _result set ["reasonCode", "OK_ALLOWED"];
    };

    default {
        _result set ["reasonCode", "E_INVALID_ENUM"];
    };
};

_result
