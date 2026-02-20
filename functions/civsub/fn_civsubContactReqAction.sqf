/*
    ARC_fnc_civsubContactReqAction

    Server-side: dispatches a dialog action for a CIVSUB-managed civilian.

    Step 3: wires CHECK_ID end-to-end by reusing ARC_fnc_civsubInteractShowPapers.

    Params:
      0: civ (object)
      1: actor (object)
      2: actionId (string)
      3: payload (any) - reserved for future use

    Returns: bool
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

params [
    ["_civ", objNull, [objNull]],
    ["_actor", objNull, [objNull]],
    ["_actionId", "", [""]],
    ["_payload", [], [[], "", 0, true, objNull, createHashMap]]
];

if (isNull _civ || {isNull _actor}) exitWith {false};
if !(isPlayer _actor) exitWith {false};
if (_actionId isEqualTo "") exitWith {false};
if !(_civ getVariable ["civsub_v1_isCiv", false]) exitWith {false};

// Dedicated MP hardening:
// If this function was invoked via remoteExec, bind actor identity to the network sender.
if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        if ((owner _actor) != _reo) exitWith {
            diag_log format ["[CIVSUB][SEC] ACTION denied: sender-owner mismatch reo=%1 actorOwner=%2 action=%3 actor=%4 civ=%5",
                _reo,
                owner _actor,
                _actionId,
                name _actor,
                _civ getVariable ["civ_uid", ""]
            ];

            ["<t size='0.9'>Action denied (authority mismatch).</t>"] remoteExecCall ["ARC_fnc_civsubContactClientReceiveResult", _actor];
            false
        };
    };
};

// Basic proximity validation to reduce abuse/spam.
if ((_actor distance _civ) > 6) exitWith {
    ["<t size='0.9'>Too far from civilian.</t>"] remoteExecCall ["ARC_fnc_civsubContactClientReceiveResult", _actor];
    false
};

switch (_actionId) do {
    case "CHECK_ID": {
            // Dialog-native Check ID: no chat output; returns payload for embedded overlay.
            private _res = [_actor, _civ] call ARC_fnc_civsubContactActionCheckId;
            private _ok = false;
            private _payload = createHashMap;

            if (_res isEqualType [] && {(count _res) >= 2}) then {
                _ok = _res select 0;
                _payload = _res select 1;
                if (_payload isEqualType []) then { _payload = createHashMapFromArray _payload; };
                if !(_payload isEqualType createHashMap) then { _payload = createHashMap; };
            };

            private _html = "";
            private _serial = _payload getOrDefault ["passport_serial", ""];
            if (_ok) then {
                // Gate VERIFIED on minimum identity payload completeness.
                // A result is only genuinely VERIFIED when a valid passport serial
                // is present. Without it the underlying identity record is incomplete
                // and displaying VERIFIED would be misleading.
                if (_serial isEqualTo "") then {
                    _ok = false;
                    _payload set ["reason", "INCOMPLETE_IDENTITY"];
                };
            };

            if (_ok) then {
                _html = format [
                    "<t size='0.95' color='#CFE8FF'>CHECK ID</t><br/>" +
                    "<t size='0.9'>Result: <t color='#77FF77'>VERIFIED</t></t><br/>" +
                    "<t size='0.85'>Serial: %1</t><br/>" +
                    "<t size='0.85'>Embedded ID card opened.</t>",
                    _serial
                ];
            } else {
                private _reason = "";
                if (_payload isEqualType createHashMap) then { _reason = _payload getOrDefault ["reason", ""]; };
                private _msg = switch (_reason) do {
                    case "NO_DISTRICT": {"This civilian has no district ID."};
                    case "DISTRICT_LOOKUP_FAIL": {"District lookup failed."};
                    case "REFUSED": {"Civilian refused to show papers."};
                    case "INCOMPLETE_IDENTITY": {"Identity record is incomplete. Run a background check first."};
                    default {"Check ID failed."};
                };
                _html = format ["<t size='0.95' color='#CFE8FF'>CHECK ID</t><br/><t size='0.9'>%1</t>", _msg];
            };

            private _out = createHashMapFromArray [
                ["ok", _ok],
                ["type", "CHECK_ID"],
                ["html", _html],
                ["payload", _payload]
            ];

            [_out] remoteExecCall ["ARC_fnc_civsubContactClientReceiveResult", _actor];

            if (_ok) then {
                // Refresh snapshot so the dialog header updates.
                [_civ, _actor] call ARC_fnc_civsubContactReqSnapshot;
            };

            true
    };

    case "BACKGROUND_CHECK": {
        // Dialog-safe MDT background check (fail-soft + dispatcher-safe).
        private _res = [];
        private _ok = false;
        private _step = _civ getVariable ["civsub_bg_lastStep", "?"];
        private _html = format ["<t size='0.9'>Background Check failed (server error at %1). Try again.</t>", _step];

        private _nil = isNil {
            _res = [_actor, _civ] call ARC_fnc_civsubContactActionBackgroundCheck;
        };

        if (!_nil && {_res isEqualType [] && {(count _res) >= 2}}) then {
            _ok = _res select 0;
            _html = _res select 1;

            if !(_html isEqualType "") then {
                _step = _civ getVariable ["civsub_bg_lastStep", _step];
                diag_log format ["[CIVSUB][ERR] BACKGROUND_CHECK invalid payload civ=%1 actor=%2 step=%3 did=%4 payloadType=%5",
                    name _civ,
                    getPlayerUID _actor,
                    _step,
                    _civ getVariable ["civsub_districtId",""],
                    typeName _html
                ];
                _ok = false;
                _html = format ["<t size='0.9'>Background Check failed (server error at %1). Try again.</t>", _step];
            } else {
                if ((count _html) == 0) then {
                    _step = _civ getVariable ["civsub_bg_lastStep", _step];
                    diag_log format ["[CIVSUB][ERR] BACKGROUND_CHECK empty html civ=%1 actor=%2 step=%3 did=%4",
                        name _civ,
                        getPlayerUID _actor,
                        _step,
                        _civ getVariable ["civsub_districtId",""]
                    ];
                    _ok = false;
                    _html = format ["<t size='0.9'>Background Check failed (server error at %1). Try again.</t>", _step];
                };
            };
        } else {
            _step = _civ getVariable ["civsub_bg_lastStep", _step];
            diag_log format ["[CIVSUB][ERR] BACKGROUND_CHECK action script error civ=%1 actor=%2 step=%3 did=%4",
                name _civ,
                getPlayerUID _actor,
                _step,
                _civ getVariable ["civsub_districtId",""]
            ];
            _html = format ["<t size='0.9'>Background Check failed (server error at %1). Try again.</t>", _step];
        };

        private _out = createHashMapFromArray [
            ["ok", _ok],
            ["type", "BACKGROUND_CHECK"],
            ["html", _html],
            ["payload", createHashMap]
        ];
        [_out] remoteExecCall ["ARC_fnc_civsubContactClientReceiveResult", _actor];

        if (_ok) then {
            // refresh header snapshot (identity likely touched)
            [_civ, _actor] call ARC_fnc_civsubContactReqSnapshot;
        };

        true
    };

    case "DETAIN": {
        private _res = [_actor, _civ] call ARC_fnc_civsubContactActionDetain;
        private _ok = false;
        private _html = "<t size='0.9'>Detain failed.</t>";
        if (_res isEqualType [] && {(count _res) >= 2}) then {
            _ok = _res select 0;
            _html = _res select 1;
        };

        private _out = createHashMapFromArray [
            ["ok", _ok],
            ["type", "DETAIN"],
            ["html", _html],
            ["payload", createHashMap]
        ];
        [_out] remoteExecCall ["ARC_fnc_civsubContactClientReceiveResult", _actor];

        // refresh header snapshot
        [_civ, _actor] call ARC_fnc_civsubContactReqSnapshot;
        true
    };

    case "HANDOFF_SHERIFF": {
        private _ok = [_actor, _civ] call ARC_fnc_civsubInteractHandoffSheriff;
        private _html = if (_ok) then {
            "<t size='0.95' color='#CFE8FF'>HANDOFF</t><br/><t size='0.9'>Sheriff handoff accepted.</t>"
        } else {
            "<t size='0.95' color='#CFE8FF'>HANDOFF</t><br/><t size='0.9'>Sheriff handoff failed. Check distance/custody/cuffs requirements.</t>"
        };

        private _out = createHashMapFromArray [
            ["ok", _ok],
            ["type", "HANDOFF_SHERIFF"],
            ["html", _html],
            ["payload", createHashMap]
        ];
        [_out] remoteExecCall ["ARC_fnc_civsubContactClientReceiveResult", _actor];

        if (_ok) then { [_civ, _actor] call ARC_fnc_civsubContactReqSnapshot; };
        true
    };

    case "RELEASE": {
        private _res = [_actor, _civ] call ARC_fnc_civsubContactActionRelease;
        private _ok = false;
        private _html = "<t size='0.9'>Release failed.</t>";
        if (_res isEqualType [] && {(count _res) >= 2}) then {
            _ok = _res select 0;
            _html = _res select 1;
        };

        private _out = createHashMapFromArray [
            ["ok", _ok],
            ["type", "RELEASE"],
            ["html", _html],
            ["payload", createHashMap]
        ];
        [_out] remoteExecCall ["ARC_fnc_civsubContactClientReceiveResult", _actor];

        // refresh header snapshot
        [_civ, _actor] call ARC_fnc_civsubContactReqSnapshot;
        true
    };

    case "AID_RATIONS": {
        private _res = [_actor, _civ] call ARC_fnc_civsubContactActionGiveFood;
        private _ok = false;
        private _html = "<t size='0.9'>Aid failed.</t>";
        if (_res isEqualType [] && {(count _res) >= 2}) then {
            _ok = _res select 0;
            _html = _res select 1;
        };

        private _out = createHashMapFromArray [
            ["ok", _ok],
            ["type", "AID_RATIONS"],
            ["html", _html],
            ["payload", createHashMap]
        ];
        [_out] remoteExecCall ["ARC_fnc_civsubContactClientReceiveResult", _actor];

        if (_ok) then { [_civ, _actor] call ARC_fnc_civsubContactReqSnapshot; };
        true
    };

    case "AID_WATER": {
        private _res = [_actor, _civ] call ARC_fnc_civsubContactActionGiveWater;
        private _ok = false;
        private _html = "<t size='0.9'>Aid failed.</t>";
        if (_res isEqualType [] && {(count _res) >= 2}) then {
            _ok = _res select 0;
            _html = _res select 1;
        };

        private _out = createHashMapFromArray [
            ["ok", _ok],
            ["type", "AID_WATER"],
            ["html", _html],
            ["payload", createHashMap]
        ];
        [_out] remoteExecCall ["ARC_fnc_civsubContactClientReceiveResult", _actor];

        if (_ok) then { [_civ, _actor] call ARC_fnc_civsubContactReqSnapshot; };
        true
    };



    case "QUESTION": {
        private _res = [_actor, _civ, _payload] call ARC_fnc_civsubContactActionQuestion;
        private _ok = false;
        private _html = "<t size='0.9'>No response.</t>";
        private _pl = createHashMap;

        if (_res isEqualType [] && {(count _res) >= 3}) then {
            _ok = _res select 0;
            _html = _res select 1;
            _pl = _res select 2;
            if (_pl isEqualType []) then { _pl = createHashMapFromArray _pl; };
            if !(_pl isEqualType createHashMap) then { _pl = createHashMap; };
        };

        private _out = createHashMapFromArray [
            ["ok", _ok],
            ["type", "QUESTION"],
            ["html", _html],
            ["payload", _pl]
        ];
        [_out] remoteExecCall ["ARC_fnc_civsubContactClientReceiveResult", _actor];
        true
    };

    default {
        [format ["<t size='0.9'>%1</t><br/><t size='0.85'>Not wired yet.</t>", _actionId]] remoteExecCall ["ARC_fnc_civsubContactClientReceiveResult", _actor];
        false
    };
};
