#!/usr/bin/env python3
"""
Simple mock USB/IP responder on port 3240 for automated loopback self-testing.
Accepts 1 connection, responds to OP_REQ_DEVLIST (0x8005) with OP_REP_DEVLIST (0x0005), and exits.
"""
import socket
import struct
import sys

def main():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("127.0.0.1", 3240))
    s.listen(1)
    print("Mock USB/IP server listening on port 3240...", flush=True)

    try:
        conn, addr = s.accept()
        print(f"Connection from {addr}", flush=True)
        req = conn.recv(8)
        if len(req) >= 8:
            version, cmd, status = struct.unpack(">HHI", req[:8])
            if version == 0x0111 and cmd == 0x8005:
                # Reply with OP_REP_DEVLIST: version=0x0111, cmd=0x0005, status=0, ndev=0
                conn.sendall(struct.pack(">HHII", 0x0111, 0x0005, 0, 0))
                print("Replied with OP_REP_DEVLIST", flush=True)
        conn.close()
    finally:
        s.close()

if __name__ == "__main__":
    main()
