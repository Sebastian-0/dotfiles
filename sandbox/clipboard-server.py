#!/usr/bin/env python3
# Runs on the host for the length of a claudesafe session and answers the
# container's xclip stand-in (xclip-shim.py). Only image types are ever read
# from the clipboard, so copied text (passwords included) stays on the host.
# Exits, deleting its directory, once its parent (the exec'd docker run) is gone.
#
# Protocol: one request line, "TARGETS" or an image MIME type. The reply is
# b"0" followed by the data, or b"1" on any failure.
from __future__ import annotations

import os
import shutil
import socketserver
import subprocess
import sys
import threading
import time

IMAGE_TYPES: frozenset[str] = frozenset(
    "image/" + t for t in ("png", "jpeg", "jpg", "webp", "gif", "bmp")
)
TIMEOUT_S: float = 25.0


def clipboard_command(request: str) -> list[str] | None:
    if os.environ.get("WAYLAND_DISPLAY") and shutil.which("wl-paste"):
        if request == "TARGETS":
            return ["wl-paste", "--list-types"]
        return ["wl-paste", "--type", request]
    if os.environ.get("DISPLAY") and shutil.which("xclip"):
        return ["xclip", "-selection", "clipboard", "-o", "-t", request]
    return None


def read_clipboard(request: str) -> bytes | None:
    if request != "TARGETS" and request not in IMAGE_TYPES:
        return None
    command = clipboard_command(request)
    if command is None:
        return None
    try:
        result = subprocess.run(
            command,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            timeout=TIMEOUT_S,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    if request == "TARGETS":
        lines = result.stdout.decode("utf-8", "replace").splitlines()
        return "".join(t + "\n" for t in lines if t in IMAGE_TYPES).encode()
    return result.stdout


class Handler(socketserver.StreamRequestHandler):
    timeout = 5.0

    def handle(self) -> None:
        request = self.rfile.readline(64).decode("ascii", "replace").strip()
        data = read_clipboard(request)
        self.wfile.write(b"1" if data is None else b"0" + data)


# One request at a time, so the container cannot start host processes without limit.
class Server(socketserver.UnixStreamServer):
    pass


def exit_with_parent(directory: str, socket_path: str) -> None:
    parent = os.getppid()
    while os.getppid() == parent:
        time.sleep(1)
    try:
        os.unlink(socket_path)
        os.rmdir(directory)
    except OSError:
        pass
    os._exit(0)


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} <directory>")
    directory = sys.argv[1]
    if clipboard_command("TARGETS") is None:
        sys.exit("no usable clipboard tool for this display")
    socket_path = os.path.join(directory, "sock")
    threading.Thread(
        target=exit_with_parent, args=(directory, socket_path), daemon=True
    ).start()
    with Server(socket_path, Handler) as server:
        server.serve_forever()


if __name__ == "__main__":
    main()
