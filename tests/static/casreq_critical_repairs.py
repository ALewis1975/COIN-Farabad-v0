"""CAS integration regression checks, plus optional execution of the actual SQF helper.

Run: python tests/static/casreq_critical_repairs.py --sqfvm ../sqfvm-runtime/sqfvm_windows_x64/sqfvm.exe
These assertions cover wiring and trust boundaries; Arma MP/JIP/UI remains a separate gate.
"""
from pathlib import Path
import argparse
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")
def cas(name):
    return read(f"functions/casreq/fn_casreq{name}.sqf")

class CASIntegration(unittest.TestCase):
    def test_compact_record_contract_is_retained(self):
        source = cas("Open")
        for key in ("casreq_id", "district_id", "state", "requester", "area", "messages", "created_at", "updated_at", "incident_id", "nine_line", "remarks", "result", "closed_at"):
            self.assertIn(f'["{key}",', source)
        self.assertNotIn('"ASSIGNED"', source)
        self.assertNotIn('"PENDING_CLOSE"', cas("Transition"))

    def test_all_mutation_endpoints_bind_sender_before_effects(self):
        for name in ("Open", "Decide", "Execute", "Close"):
            source = cas(name)
            sender = source.index("call ARC_fnc_rpcValidateSender")
            permission = source.index("call ARC_fnc_casreqCan")
            write = source.index('["casreq_v1_records", _records] call ARC_fnc_stateSet')
            self.assertLess(sender, permission, name)
            self.assertLess(permission, write, name)
            self.assertIn("private _reoOwner = remoteExecutedOwner;", source)
            self.assertNotIn('isNil "remoteExecutedOwner"', source)
            self.assertIn("if (canSuspend) exitWith", source)

    def test_controller_identity_is_named_slot_not_classname(self):
        source = cas("Can")
        self.assertIn('localNamespace getVariable ["ARC_casreq_jtacUnit"', source)
        self.assertNotIn("rhsusf_airforce_security_force_rifleman", source)
        self.assertIn('case "DECIDE": {_controller}', source)
        self.assertIn('case "ABORT": {_controller || _requester}', source)
        init = cas("InitServer")
        self.assertIn('missionNamespace getVariable ["jtac", objNull]', init)
        self.assertIn('addMissionEventHandler ["EntityRespawned"', init)
        self.assertIn('isNil {localNamespace getVariable "ARC_casreq_respawnEh"}', init)

    def test_assignment_is_derived_from_server_crew(self):
        source = cas("Decide")
        self.assertIn("getPlayerUID _x", source)
        self.assertIn("forEach crew _aircraft", source)
        self.assertIn('localNamespace getVariable ["ARC_casreq_attackObjects"', source)
        self.assertIn('["crew_uids", _crewUids]', source)
        self.assertIn('case "EXECUTE": {_controller || {_assigned && _inAttackAircraft}}', cas("Can"))
        self.assertIn('localNamespace setVariable ["ARC_casreq_attackObjects", _attackObjects]', cas("AirbaseAvailability"))

    def test_client_cannot_invoke_timeout(self):
        self.assertIn('_result in ["COMPLETE", "ABORT"]', cas("Close"))
        self.assertIn('["notes",', cas("Close"))
        self.assertIn('"TIMEOUT", "SERVER"', cas("Maintain"))
        self.assertIn("_hasBda", cas("Transition"))

    def test_intake_bounds_precede_sequence_allocation(self):
        source = cas("Open")
        allocation = source.index("call ARC_fnc_casreqBuildId")
        for guard in ("count _nineLine != 9", "count _remarks > 500", "count _requestToken > 96", "_ownedOpen >= 3", " >= 20", "_duplicate !=", 'localNamespace getVariable ["ARC_casreq_submitCooldowns"'):
            self.assertLess(source.index(guard), allocation, guard)
        self.assertIn("_key in _seen", source)
        self.assertIn("call ARC_fnc_threadResolveDistrictId", source)
        self.assertNotIn('_unit getVariable ["ARC_casreq_lastSubmitAt"', source)
        self.assertIn("_seq >= 999999", cas("BuildId"))
        self.assertNotIn("truncating to last 6", cas("BuildId"))

    def test_history_and_completed_aggregate_are_bounded(self):
        source = cas("Maintain")
        self.assertIn("count _terminal > 100", source)
        self.assertIn("_records deleteAt _id", source)
        self.assertIn(" >= 7200", source)
        self.assertLess(source.index("_archived = _archived + 1"), source.index("_records deleteAt _id"))
        self.assertIn('"casreq_v1_archived_completed"', cas("CompletedCount"))
        self.assertIn('"COMPLETE"', cas("CompletedCount"))
        self.assertNotIn("spawn", source.split("/*", 1)[-1].split("*/", 1)[-1])

    def test_inbox_is_complete_and_unchanged_snapshots_are_not_rebroadcast(self):
        source = cas("InboxPublish")
        self.assertIn('"casreq_v1_open_index"', source)
        self.assertIn('"casreq_v1_closed_index"', source)
        self.assertIn("call ARC_fnc_casreqSnapshotGet", source)
        self.assertIn('["records", _rows]', source)
        self.assertLess(source.index("_signature isEqualTo"), source.index('setVariable ["ARC_pub_casreqInbox"'))
        self.assertIn("[true] call ARC_fnc_casreqInboxPublish", cas("InitServer"))
        self.assertIn('["casreq_snapshot", _snapshot]', cas("BroadcastDelta"))
        self.assertIn('_snapshot = +_snapshot', cas("SnapshotGet"))

    def test_inputs_use_edit_controls_and_cancel_before_rpc(self):
        for name in ("ClientSubmit", "JtacPrefill"):
            source = cas(name)
            form = source.index("call ARC_fnc_casreqInput")
            cancel = source.index("if !(_form select 0) exitWith {false}", form)
            rpc = source.index('remoteExec ["ARC_fnc_casreqOpen"')
            self.assertLess(cancel, rpc)
            for line in ("(_nineLine select 3) set", "(_nineLine select 6) set", "(_nineLine select 8) set"):
                self.assertIn(line, source)
            self.assertNotIn("call BIS_fnc_guiMessage", source)
        shadow = read("functions/command/fn_intelShadowLeadBridge.sqf")
        self.assertLess(shadow.index("if !(_form select 0) exitWith {false}"), shadow.index('remoteExec ["ARC_fnc_intelQueueSubmit"'))
        self.assertIn('[false, "", "", ""]', cas("Input"))
        dialogs = read("config/CfgDialogs.hpp")
        self.assertIn("class ARC_CasreqInputDialog", dialogs)
        self.assertIn("class Field1: RscEdit", dialogs)

    def test_console_has_live_decide_execute_close_paths(self):
        source = cas("InboxAction")
        for name in ("Decide", "Execute", "Close"):
            self.assertRegex(source, rf'remoteExecCall \["ARC_fnc_casreq{name}", 2\]')
        self.assertIn('case "CAS_INBOX"', read("functions/ui/fn_uiConsoleClickPrimary.sqf"))
        self.assertIn("spawn ARC_fnc_casreqClientInbox", read("functions/ui/fn_uiConsoleClickPrimary.sqf"))
        self.assertNotIn("parseText", source)

    def test_parent_registrations_and_reset_hooks(self):
        functions = read("config/CfgFunctions.hpp")
        remote = read("config/CfgRemoteExec.hpp")
        for helper in ("Can", "Transition", "Maintain", "InboxPublish", "CompletedCount", "Input", "ClientInbox", "InboxAction"):
            self.assertIn(f"class casreq{helper}", functions)
            self.assertNotRegex(remote, rf"class ARC_fnc_casreq{helper}\s*\{{")
        for api in ("Decide", "Execute", "Close"):
            entry = re.search(rf"class ARC_fnc_casreq{api}\s*\{{([^}}]*)\}}", remote)
            self.assertIsNotNone(entry, api)
            self.assertRegex(entry.group(1), r"allowedTargets\s*=\s*2\s*;")
            self.assertNotRegex(entry.group(1), r"jip\s*=\s*1")
        # Omitted per-entry JIP inherits the existing Functions default.
        self.assertRegex(remote, r"class Functions\s*\{\s*mode\s*=\s*1\s*;\s*jip\s*=\s*0")
        for file in ("functions/core/fn_stateInit.sqf", "functions/core/fn_resetAll.sqf"):
            self.assertIn('"casreq_v1_archived_completed"', read(file))
        self.assertIn('"ARC_pub_casreqInbox"', read("functions/core/fn_resetAll.sqf"))
        self.assertIn("call ARC_fnc_casreqMaintain", read("functions/core/fn_publicBroadcastState.sqf"))
        self.assertIn("call ARC_fnc_casreqInboxPublish", read("functions/core/fn_publicBroadcastState.sqf"))
        self.assertIn("call ARC_fnc_casreqCompletedCount", read("functions/core/fn_missionScoreGenerate.sqf"))

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sqfvm", type=Path)
    args = parser.parse_args()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(CASIntegration)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    success = result.wasSuccessful()
    if args.sqfvm:
        proc = subprocess.run([str(args.sqfvm.resolve()), "--automated", "--suppress-welcome", "--input-sqf", "tests/casreq_critical_repairs.sqf"], cwd=ROOT, capture_output=True, text=True)
        output = proc.stdout + proc.stderr
        match = re.search(r"\[CAS_TEST\] checks=(\d+) failures=0", output)
        vm_ok = bool(match) and not any(tag in output for tag in ("[ERR]", "[FAT]", "[CAS_TEST][FAIL]")) and proc.returncode == 0
        print(f"SQF-VM actual production transition: {'PASS' if vm_ok else 'FAIL'}" + (f" ({match.group(1)} checks)" if match else ""))
        if not vm_ok:
            print(output)
        success = success and vm_ok
    raise SystemExit(0 if success else 1)
