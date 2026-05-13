#!/bin/bash
# Remap a user/group to a target UID/GID and re-own its home directory.
# Idempotent: if the user already has the requested UID/GID, this is a no-op.
#
# Usage: remap-user.sh <username> <uid> <gid>
#
# Used at image build time (sandbox base) so the runtime user matches the
# host's UID/GID for clean bind-mount permissions. Project overlays that swap
# the base image entirely can call this script again with their own user.
set -euo pipefail

USERNAME="${1:?username required}"
TARGET_UID="${2:?uid required}"
TARGET_GID="${3:?gid required}"

if ! id -u "$USERNAME" > /dev/null 2>&1; then
    echo "remap-user: user '$USERNAME' does not exist" >&2
    exit 1
fi

CURRENT_UID="$(id -u "$USERNAME")"
CURRENT_GID="$(id -g "$USERNAME")"
HOME_DIR="$(getent passwd "$USERNAME" | cut -d: -f6)"

if [ "$CURRENT_GID" != "$TARGET_GID" ]; then
    groupmod -g "$TARGET_GID" "$USERNAME"
fi
if [ "$CURRENT_UID" != "$TARGET_UID" ]; then
    usermod -u "$TARGET_UID" "$USERNAME"
fi

if [ -d "$HOME_DIR" ]; then
    chown -R "$TARGET_UID:$TARGET_GID" "$HOME_DIR"
fi
