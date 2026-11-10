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

RAPL_CONF=/etc/tmpfiles.d/50-rapl-read.conf
RAPL_WANT=1
for arg in "$@"; do
  case $arg in
    --no-rapl) RAPL_WANT=0 ;;
    --rapl) RAPL_WANT=1 ;;
  esac
done

if [ "$RAPL_WANT" -eq 1 ]; then
  cat > "$RAPL_CONF" <<'RAPL'
# Written by the fan-boost plugin's install.sh: let an ordinary user read the
# package energy counter so the widget can show live power. Delete this file
# and reboot (or chmod 0400 the file) to restore the kernel's default.
z /sys/class/powercap/intel-rapl:0/energy_uj 0444 root root -
z /sys/class/powercap/amd-rapl:0/energy_uj 0444 root root -
RAPL
  systemd-tmpfiles --create "$RAPL_CONF" >/dev/null 2>&1 \
    && echo "installed $RAPL_CONF — package power is readable by an ordinary user"
fi

"$TARGET" status >/dev/null 2>&1 || true
echo
echo "probe:  sudo $TARGET status   (WATTS appears once the power counter is readable)"
echo "boost:  sudo $TARGET max 300"
echo "auto:   sudo $TARGET auto"
