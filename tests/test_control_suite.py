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

    def test_pairing_manager_shared_state_file(self):
        import tempfile
        mod = _load_ctl_module()
        with tempfile.TemporaryDirectory() as td:
            sf = os.path.join(td, "pairing_state.json")
            m1 = mod.PairingManager(state_file=sf)
            m2 = mod.PairingManager(state_file=sf)
            code, _ = m1.create_pairing_code()
            ok, tok, _ = m2.verify_pairing_code(code)
            self.assertTrue(ok)
            self.assertTrue(len(tok) == 32)
            ok2, _, _ = m1.verify_pairing_code(code)
            self.assertFalse(ok2)

    def test_handle_control_client_pair_create_loopback_only_and_status_ok(self):
        import socket as _sock
        mod = _load_ctl_module()
        class FakeSock:
            def __init__(self, payload: bytes):
                self._payload = payload
                self.sent = bytearray()
                self.closed = False
            def settimeout(self, t): pass
            def recv(self, n):
                d = self._payload[:n]
                self._payload = self._payload[n:]
                return d
            def sendall(self, d): self.sent.extend(d)
            def close(self): self.closed = True

        with mock.patch.object(mod, "load_policy", return_value={"allow_all_ips": True, "control_token": ""}), \
             mock.patch.object(mod, "ensure_tls_cert", return_value=("", "", "ab" * 32)):
            s_remote = FakeSock(b"PAIR_CREATE\n")
            mod.handle_control_client(s_remote, ("198.51.100.50", 12345))
            resp_r = json.loads(s_remote.sent.decode("utf-8"))
            self.assertEqual(resp_r["status"], "DENIED")

            s_local = FakeSock(b"PAIR_CREATE\n")
            mod.handle_control_client(s_local, ("127.0.0.1", 12345))
            resp_l = json.loads(s_local.sent.decode("utf-8"))
            self.assertEqual(resp_l["status"], "OK")
            self.assertEqual(len(resp_l["code"]), 6)

            s_status = FakeSock(b"STATUS\n")
            mod.handle_control_client(s_status, ("127.0.0.1", 12345))
            resp_s = json.loads(s_status.sent.decode("utf-8"))
            self.assertEqual(resp_s["status"], "OK")

    def test_mcp_stdout_isolation_on_share(self):
        import io, contextlib, importlib.util
        mcp_path = os.path.join(os.path.dirname(__file__), "..", "scripts", "usbanywhere-mcp.py")
        spec = importlib.util.spec_from_file_location("usbanywhere_mcp_test", mcp_path)
        mcp = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mcp)

        class FakeCtl:
            @staticmethod
            def share_device(busid, reset_device=False):
                print(f"Device {busid} bound via usbip.")
                return True
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            res = mcp.call_tool("usb_share_device", {"busid": "2-1"}, ctl_mod=FakeCtl())
        self.assertTrue(res["ok"])
        self.assertEqual(buf.getvalue(), "")

if __name__ == "__main__":
    unittest.main()
