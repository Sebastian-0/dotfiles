#!/usr/bin/env python3
# Installed as `xclip` in the container. Claude Code reads a pasted image with
# `xclip -selection clipboard -o -t TARGETS` and then `... -t image/<type>`;
# those two reads are forwarded to the host's clipboard-server.py. Everything
# else fails like xclip without a display would.
from __future__ import annotations

import socket
import sys

SOCKET_PATH: str = "/run/claudesafe-clipboard/sock"
TIMEOUT_S: float = 30.0


def requested_target(args: list[str]) -> str | None:
    selection = "primary"
    target = None
    output = False
    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("-selection", "-sel") and i + 1 < len(args):
            selection = args[i + 1]
            i += 1
        elif arg in ("-t", "-target") and i + 1 < len(args):
            target = args[i + 1]
            i += 1
        elif arg in ("-o", "-out"):
            output = True
        i += 1
    if not output or target is None or selection not in ("clipboard", "c"):
        return None
    return target


def main() -> int:
    target = requested_target(sys.argv[1:])
    if target is None:
        print("xclip: only clipboard image reads are supported here", file=sys.stderr)
        return 1
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.settimeout(TIMEOUT_S)
            sock.connect(SOCKET_PATH)
            sock.sendall(target.encode() + b"\n")
            chunks = []
            while chunk := sock.recv(65536):
                chunks.append(chunk)
    except OSError as e:
        print(f"xclip: host clipboard unavailable: {e}", file=sys.stderr)
        return 1
    reply = b"".join(chunks)
    if not reply.startswith(b"0"):
        return 1
    sys.stdout.buffer.write(reply[1:])
    return 0


if __name__ == "__main__":
    sys.exit(main())
