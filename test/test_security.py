#!/usr/bin/python3 -I
"""Security checks for the combine helper's state and input boundaries."""

from __future__ import annotations

import importlib.machinery
import importlib.util
import json
import os
import stat
import tempfile
import unittest
from pathlib import Path


def load_combine():
    path = Path(__file__).resolve().parents[1] / "bin" / "combine"
    loader = importlib.machinery.SourceFileLoader("combine", str(path))
    spec = importlib.util.spec_from_loader("combine", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


C = load_combine()


class SinkNameTests(unittest.TestCase):
    def test_accepts_pipewire_names(self):
        self.assertTrue(C.valid_sink_name("bluez_output.AA_BB_CC_DD_EE_FF.1"))
        self.assertTrue(C.valid_sink_name("alsa_output.pci-0000_2c_00.4.analog-stereo"))

    def test_rejects_option_and_path_shapes(self):
        self.assertFalse(C.valid_sink_name("-evil"))
        self.assertFalse(C.valid_sink_name("../x"))
        self.assertFalse(C.valid_sink_name("a/b"))
        self.assertFalse(C.valid_sink_name("a;b"))
        self.assertFalse(C.valid_sink_name("a b"))
        self.assertFalse(C.valid_sink_name(""))
        self.assertFalse(C.valid_sink_name("."))
        self.assertFalse(C.valid_sink_name(".."))


class PlainTextTests(unittest.TestCase):
    def test_strips_markup_and_controls(self):
        self.assertEqual(C.plain("<img src=x>AirPods"), "img src=xAirPods")
        self.assertNotIn("\x1b", C.plain("\x1b[31mred"))
        self.assertLessEqual(len(C.plain("n" * 400)), C.MAX_LABEL)


class StateFileTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def test_write_does_not_follow_symlink(self):
        victim = Path(self.tmp.name) / "victim"
        victim.write_text("must survive\n", encoding="utf-8")
        dirfd = C.open_dir_chain(C.STATE_DIR_PARTS, home=self.home)
        try:
            os.symlink(str(victim), C.STATE_NAME, dir_fd=dirfd)
            C.write_atomic(dirfd, C.STATE_NAME, b'{"slaves":[],"previousDefault":""}\n')
        finally:
            os.close(dirfd)
        self.assertEqual(victim.read_text(encoding="utf-8"), "must survive\n")
        state_path = Path(self.home, *C.STATE_DIR_PARTS, C.STATE_NAME)
        self.assertTrue(state_path.is_file())
        self.assertFalse(state_path.is_symlink())

    def test_read_refuses_symlink(self):
        victim = Path(self.tmp.name) / "victim"
        victim.write_text('{"slaves":["owned"],"previousDefault":""}\n', encoding="utf-8")
        dirfd = C.open_dir_chain(C.STATE_DIR_PARTS, home=self.home)
        try:
            os.symlink(str(victim), C.STATE_NAME, dir_fd=dirfd)
            with self.assertRaises(OSError):
                C.read_bounded(dirfd, C.STATE_NAME)
        finally:
            os.close(dirfd)

    def test_read_refuses_group_writable_oversize_via_size(self):
        dirfd = C.open_dir_chain(C.STATE_DIR_PARTS, home=self.home)
        try:
            payload = b"n" * (C.MAX_STATE_BYTES + 2)
            fd = os.open(
                C.STATE_NAME,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
                0o600,
                dir_fd=dirfd,
            )
            try:
                os.write(fd, payload)
            finally:
                os.close(fd)
            with self.assertRaises(PermissionError):
                C.read_bounded(dirfd, C.STATE_NAME)
        finally:
            os.close(dirfd)

    def test_parse_state_rejects_bad_names(self):
        raw = json.dumps({"slaves": ["../etc"], "previousDefault": ""}).encode()
        self.assertIsNone(C.parse_state_bytes(raw))
        raw = json.dumps({"slaves": ["ok"], "previousDefault": "-x"}).encode()
        parsed = C.parse_state_bytes(raw)
        self.assertEqual(parsed["previousDefault"], "")

    def test_state_dir_is_0700(self):
        dirfd = C.open_dir_chain(C.STATE_DIR_PARTS, home=self.home)
        try:
            info = os.fstat(dirfd)
            self.assertTrue(stat.S_ISDIR(info.st_mode))
            self.assertEqual(info.st_mode & 0o777, 0o700)
        finally:
            os.close(dirfd)


if __name__ == "__main__":
    unittest.main()
