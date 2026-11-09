#!/usr/bin/env bash
# install.sh — install the fanctl door for the fan-boost widget.
# Run once, with sudo, from the plugin directory.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
TARGET=/usr/local/bin/fanctl
SUDOERS=/etc/sudoers.d/20-fanctl
USER_NAME=${SUDO_USER:-$(id -un)}

[ "$(id -u)" -eq 0 ] || { echo "install.sh: run it with sudo" >&2; exit 1; }
[ -f "$HERE/fanctl" ] || { echo "install.sh: fanctl not found beside install.sh" >&2; exit 1; }

install -o root -g root -m 0755 "$HERE/fanctl" "$TARGET"
echo "installed $TARGET"

SUDOERS_TMP=$(mktemp)
trap 'rm -f "$SUDOERS_TMP"' EXIT
printf '%s ALL=(root) NOPASSWD: %s\n' "$USER_NAME" "$TARGET" > "$SUDOERS_TMP"
visudo -cf "$SUDOERS_TMP" >/dev/null || { echo "install.sh: refusing to install an invalid sudoers rule" >&2; exit 1; }
install -o root -g root -m 0440 "$SUDOERS_TMP" "$SUDOERS"
echo "installed $SUDOERS — $USER_NAME may run $TARGET without a password"

"$TARGET" status >/dev/null 2>&1 || true
echo
echo "probe:  sudo $TARGET status"
echo "boost:  sudo $TARGET max 300"
echo "auto:   sudo $TARGET auto"
