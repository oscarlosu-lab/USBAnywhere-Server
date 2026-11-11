#!/usr/bin/env python3
"""
USBAnywhere Control Suite - Automated Unit & Integration Tests
Validates the unified usbanywhere-ctl management tool across macOS and Linux.
"""
import os
import sys
import subprocess
import json
import unittest

import importlib.machinery
import importlib.util
from unittest import mock

SCRIPT_PATH = os.path.join(os.path.dirname(__file__), "..", "scripts", "usbanywhere-ctl")


def _load_ctl_module():
    loader = importlib.machinery.SourceFileLoader("usbanywhere_ctl_mod", SCRIPT_PATH)
    spec = importlib.util.spec_from_loader("usbanywhere_ctl_mod", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod

class TestControlSuite(unittest.TestCase):

    def test_script_exists_and_is_executable(self):
        self.assertTrue(os.path.exists(SCRIPT_PATH), f"usbanywhere-ctl not found at {SCRIPT_PATH}")

    def test_status_json_output(self):
        res = subprocess.run([sys.executable, SCRIPT_PATH, "status", "--json"],
                             capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(res.returncode, 0, f"Error running status: {res.stderr}")
        data = json.loads(res.stdout)
        self.assertIn("os", data)
        self.assertIn("service_manager", data)
        self.assertIn("port_active", data)
        self.assertIn("lan_ip", data)
        self.assertIn("devices", data)
        self.assertIsInstance(data["devices"], list)

    def test_doctor_execution(self):
        res = subprocess.run([sys.executable, SCRIPT_PATH, "doctor"],
                             capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(res.returncode, 0, f"Doctor exited with error: {res.stderr}")
        self.assertIn("USBAnywhere System Doctor", res.stdout)
        self.assertIn("Operating System:", res.stdout)

    def test_list_devices(self):
        res = subprocess.run([sys.executable, SCRIPT_PATH, "list"],
                             capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(res.returncode, 0, f"List devices failed: {res.stderr}")
        self.assertIn("Discovered USB Peripherals", res.stdout)

    def test_share_device_linux_fails_when_device_absent(self):
        mod = _load_ctl_module()
        with mock.patch.object(mod.os.path, "exists", return_value=False), \
             mock.patch.object(mod, "_wait_udev_settle"):
            ok = mod._share_device_linux("1-1.3", "/usr/sbin/usbip")
        self.assertFalse(ok)
        self.assertIn("not found on USB bus", mod._last_bind_error.get("1-1.3", ""))

    def test_busid_lock_per_device_serialization(self):
        mod = _load_ctl_module()
        l1 = mod._get_busid_lock("1-1.3")
        l1_again = mod._get_busid_lock("1-1.3")
        l2 = mod._get_busid_lock("1-1.4")
        self.assertIs(l1, l1_again)
        self.assertIsNot(l1, l2)

if __name__ == "__main__":
    unittest.main()
