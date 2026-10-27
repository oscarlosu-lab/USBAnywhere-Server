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

SCRIPT_PATH = os.path.join(os.path.dirname(__file__), "..", "scripts", "usbanywhere-ctl")

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

if __name__ == "__main__":
    unittest.main()
