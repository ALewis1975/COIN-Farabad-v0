#!/usr/bin/env python3
"""CIVSUB retention source guards + decision model, NOT Arma runtime execution.

Run: python3 tests/static/civsub_scene_retention_checks.py
Use FARABAD_ROOT to run the source guards against another source fixture.
The model tests explain boundary cases; they do not execute the SQF functions.
"""
from __future__ import annotations

import os
import re
import unittest
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(os.environ.get("FARABAD_ROOT", Path(__file__).resolve().parents[2]))
NAMES = ("fn_civsubCivIsProtected.sqf", "fn_civsubCivDespawnUnit.sqf", "fn_civsubCivCleanupTick.sqf")


def source(name: str) -> str:
    return (ROOT / "functions" / "civsub" / name).read_text(encoding="utf-8")


def code_only(text: str) -> str:
    """Strip SQF strings/comments, preserving line breaks for delimiter checks."""
    token = re.compile(r'/\*.*?\*/|//[^\n]*|"(?:""|[^"])*"|\'(?:\'\'|[^\'])*\'', re.S)
    return token.sub(lambda m: "".join("\n" if c == "\n" else " " for c in m[0]), text)


@dataclass
class Actor:
    nid: str
    local_task: object = ""
    overlay_task: object = ""
    persist: bool = False
    pin: bool = False
    captive: bool = False
    handcuffed: bool = False
    detained: bool = False
    handed_off: bool = False
    stopped: bool = False
    stop_owner: str = ""
    stop_ts: float = 0
    alive: bool = True
    player: bool = False
    deleted: bool = False


@dataclass
class Context:
    active_task: object = "ARC_inc_1"
    deferred: list = field(default_factory=list)
    now: float = 1000
    ttl: float = 900


def protected(actor: Actor, context: Context) -> bool:
    """Decision-table model of the intended contract, not an SQF interpreter."""
    if actor.persist:
        return True
    owners = [x for x in (actor.local_task, actor.overlay_task) if isinstance(x, str) and x]
    if owners:
        if isinstance(context.active_task, str) and context.active_task and context.active_task in owners:
            return True
        if actor.nid and isinstance(context.deferred, list):
            if any(isinstance(x, list) and len(x) >= 4 and x[0] == actor.nid for x in context.deferred):
                return True
    ttl = min(3600, max(60, context.ttl))
    interaction = actor.stopped and bool(actor.stop_owner) and actor.stop_ts > 0 and context.now - actor.stop_ts <= ttl
    return bool(actor.pin or interaction or actor.captive or actor.handcuffed or actor.detained or actor.handed_off)


def consume(registry: dict[str, Actor], queue: list[str], context: Context) -> list[tuple[str, str]]:
    """Model the bounded consumption and BOOL result handling, not district scanning."""
    results = []
    for _ in range(min(6, len(queue))):
        key = queue.pop(0)
        actor = registry.get(key)
        if actor is None or actor.deleted:
            registry.pop(key, None)
            continue
        if not actor.alive or actor.player or protected(actor, context):
            results.append((key, "RETAINED"))
        else:
            actor.deleted = True
            registry.pop(key)
            results.append((key, "DELETED"))
    return results


class SourceGuards(unittest.TestCase):
    def test_balanced_delimiters(self):
        texts = [(name, source(name)) for name in NAMES]
        texts.append(("fn_cleanupTick.sqf", (ROOT / "functions/core/fn_cleanupTick.sqf").read_text(encoding="utf-8")))
        for name, text in texts:
            with self.subTest(file=name):
                stack = []
                for char in code_only(text):
                    if char in "([{":
                        stack.append(char)
                    elif char in ")]}":
                        self.assertTrue(stack, "unmatched closing delimiter")
                        self.assertEqual(stack.pop(), {")": "(", "]": "[", "}": "{"}[char])
                self.assertFalse(stack, "unclosed delimiter")

    def test_existing_owner_keys_only(self):
        text = source(NAMES[0])
        for key in ("ARC_localSupportTaskId", "ARC_overlayTaskId", '"activeTaskId"', '"cleanupQueue"', '"ARC_persistInAO"'):
            self.assertIn(key, text)
        self.assertNotIn("setVariable", text)
        self.assertNotIn("ARC_fnc_stateSet", text)

    def test_stale_tags_need_live_owner(self):
        text = source(NAMES[0])
        self.assertIn("_activeTaskId in _taskIds", text)
        self.assertIn("(_x select 0) isEqualTo _nid", text)
        self.assertIn("(count _x) >= 4", text)
        self.assertIn('!(_x isEqualTo "")', text)

    def test_identity_result_leaves_function(self):
        text = source(NAMES[0])
        self.assertTrue(text.rstrip().endswith("_identityProtected"))
        self.assertIn('"status_detained"', text)
        self.assertIn('"status_handedOff"', text)
        self.assertNotRegex(text, r'status_(?:detained|handedOff)[^\n]*exitWith')

    def test_interaction_and_captive_contract_remains(self):
        text = source(NAMES[0])
        for token in ("civsub_v1_pinned", "civsub_v1_stopOwnerUid", "civsub_v1_stopTs", "civsub_v1_interactionProtectionTtl_s", "captive _u", "ace_captives_isHandcuffed"):
            self.assertIn(token, text)
        self.assertIn("(_ttl max 60) min 3600", text)

    def test_final_guard_precedes_delete_in_critical_section(self):
        text = source(NAMES[1])
        critical = text.index("isNil {")
        guard = text.index("call ARC_fnc_civsubCivIsProtected")
        deletion = text.index("deleteVehicle _unit;")
        success = text.index("_deleted = true;")
        sleep = text.index("uiSleep 0.01;")
        self.assertLess(critical, guard)
        self.assertLess(guard, deletion)
        self.assertLess(deletion, success)
        self.assertLess(success, sleep)
        self.assertIn("if (!_deleted) exitWith {false};", text)
        self.assertIn("!alive _unit", text)
        self.assertIn("isPlayer _unit", text)

    def test_caller_respects_refused_deletion(self):
        text = source(NAMES[2])
        self.assertIn("_remove = [_u] call ARC_fnc_civsubCivDespawnUnit;", text)
        self.assertIn("if (_remove) then { _reg deleteAt _k; };", text)
        self.assertIn("_retainedCount = _retainedCount + 1;", text)

    def test_body_workflow_and_batch_bound_remain(self):
        text = source(NAMES[2])
        self.assertIn("private _max = 6;", text)
        self.assertIn('"civsub_v1_dead_ts"', text)
        self.assertIn('"civsub_v1_dead_districtId"', text)
        self.assertIn("_q deleteAt 0", text)
        self.assertEqual(text.count("_samples pushBack"), 1)

    def test_snapshot_is_versioned_and_server_local(self):
        text = source(NAMES[2])
        self.assertRegex(text, r'"civsub_v1_civ_cleanup_snapshot",\s*\[1, serverTime,[^\n]+\],\s*false')
        self.assertIn("if (!isServer) exitWith", text)

    def test_core_cleanup_respects_reassignment_but_keeps_force(self):
        text = (ROOT / "functions/core/fn_cleanupTick.sqf").read_text(encoding="utf-8")
        guard = text.index("_activeTaskId in _ownerTaskIds")
        self.assertLess(guard, text.index("deleteVehicle _obj;"))
        self.assertIn('"ARC_localSupportTaskId"', text)
        self.assertIn('"ARC_overlayTaskId"', text)
        self.assertIn("if (!_force) then", text[:guard])
        self.assertIn("_new pushBack [_nid, _objPos, _radius, _earliest, _label];", text[guard:])

    def test_diagnostics_identify_entities_without_toasts(self):
        for name in NAMES[1:]:
            text = source(name)
            for field in ("actor=SERVER", "netId=", "civ_uid=", "localTask=", "overlayTask=", "grid="):
                self.assertIn(field, text)
            self.assertNotIn("clientToast", text)
            self.assertNotIn("remoteExec", text)
        self.assertIn("source=%8", source(NAMES[1]))


class DecisionModel(unittest.TestCase):
    def test_local_scene_before_arrival(self):
        self.assertTrue(protected(Actor("2:1", local_task="ARC_inc_1"), Context()))

    def test_overlay_before_arrival(self):
        self.assertTrue(protected(Actor("2:2", overlay_task="ARC_inc_1"), Context()))

    def test_pending_sitrep_does_not_release_active_owner(self):
        self.assertTrue(protected(Actor("2:1", local_task="ARC_inc_1"), Context(now=10000)))

    def test_deferred_owner_after_closure(self):
        self.assertTrue(protected(Actor("2:1", local_task="ARC_inc_1"), Context(active_task="", deferred=[["2:1", [0, 0, 0], 1000, 1025, "localSupport"]])))

    def test_stale_task_tag_does_not_pin(self):
        self.assertFalse(protected(Actor("2:1", local_task="ARC_inc_0"), Context()))

    def test_empty_and_malformed_tags_do_not_pin(self):
        for tag in ("", None, [], 123, False):
            with self.subTest(tag=tag):
                self.assertFalse(protected(Actor("2:1", local_task=tag), Context(active_task=tag)))

    def test_deferred_membership_requires_exact_netid(self):
        ctx = Context(active_task="", deferred=[["2:99", [0, 0, 0], 1000, 0]])
        self.assertFalse(protected(Actor("2:1", local_task="ARC_inc_1"), ctx))

    def test_malformed_deferred_entries_do_not_pin(self):
        ctx = Context(active_task="", deferred=[None, 9, "2:1", [], ["2:1"]])
        self.assertFalse(protected(Actor("2:1", local_task="ARC_inc_1"), ctx))

    def test_explicit_persistence(self):
        self.assertTrue(protected(Actor("2:1", persist=True), Context()))

    def test_existing_protections(self):
        for flag in ("pin", "captive", "handcuffed", "detained", "handed_off"):
            with self.subTest(flag=flag):
                self.assertTrue(protected(Actor("2:1", **{flag: True}), Context()))

    def test_fresh_interaction_retains_queued_actor(self):
        actor = Actor("2:1", stopped=True, stop_owner="player", stop_ts=950)
        registry, queue = {actor.nid: actor}, [actor.nid]
        self.assertEqual(consume(registry, queue, Context()), [(actor.nid, "RETAINED")])
        self.assertIn(actor.nid, registry)
        self.assertFalse(queue)
        self.assertFalse(actor.deleted)

    def test_expired_interaction_can_be_evicted(self):
        actor = Actor("2:1", stopped=True, stop_owner="player", stop_ts=1)
        self.assertFalse(protected(actor, Context()))

    def test_untagged_ambient_eviction_still_works(self):
        actor = Actor("2:1")
        registry, queue = {actor.nid: actor}, [actor.nid]
        self.assertEqual(consume(registry, queue, Context()), [(actor.nid, "DELETED")])
        self.assertFalse(registry)
        self.assertTrue(actor.deleted)

    def test_dead_or_player_not_deleted(self):
        for flags in ({"alive": False}, {"player": True}):
            actor = Actor("2:1", **flags)
            registry = {actor.nid: actor}
            self.assertEqual(consume(registry, [actor.nid], Context()), [(actor.nid, "RETAINED")])
            self.assertFalse(actor.deleted)

    def test_six_entry_bound(self):
        registry = {f"2:{i}": Actor(f"2:{i}") for i in range(10)}
        queue = list(registry)
        self.assertEqual(len(consume(registry, queue, Context())), 6)
        self.assertEqual(len(queue), 4)
        self.assertEqual(len(registry), 4)

    def test_core_reassignment_decision(self):
        # Separate model of the core consumer: only explicit active-task ownership,
        # not generic captive/identity protection, gates ordinary deferred deletion.
        actor = Actor("2:1", local_task="ARC_inc_2")
        for active, force, retain in (("ARC_inc_2", False, True), ("ARC_inc_2", True, False), ("", False, False), ("ARC_inc_3", False, False)):
            with self.subTest(active=active, force=force):
                got = not force and bool(active) and active in (actor.local_task, actor.overlay_task)
                self.assertEqual(got, retain)

    def test_repeat_cleanup_and_release(self):
        actor = Actor("2:1", local_task="ARC_inc_1")
        registry, queue = {actor.nid: actor}, [actor.nid]
        self.assertEqual(consume(registry, queue, Context()), [(actor.nid, "RETAINED")])
        self.assertEqual(consume(registry, queue, Context()), [])
        queue.append(actor.nid)  # later scan after ownership release
        self.assertEqual(consume(registry, queue, Context(active_task="")), [(actor.nid, "DELETED")])
        self.assertEqual(consume(registry, [actor.nid], Context(active_task="")), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
