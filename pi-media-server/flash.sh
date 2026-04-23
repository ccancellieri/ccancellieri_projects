#!/bin/bash
#---------------------------------------------------------------
# flash.sh — flash DietPi to an SD card on macOS and drop config files.
#
# Usage:
#   ./flash.sh               # interactive: asks you to pick the disk
#   ./flash.sh /dev/diskN    # non-interactive: uses this disk (still confirms)
#   DRY_RUN=1 ./flash.sh ... # prints commands, writes nothing
#
# What it does:
#   1. Verifies image SHA256
#   2. Lists removable disks, asks you to pick one (or validates the arg)
#   3. Shows a summary + requires typing YES to proceed
#   4. Unmounts the target disk
#   5. Decompresses + dd-writes the image to the RAW device (rdisk = fast)
#   6. Re-mounts the boot partition
#   7. Copies dietpi.txt, dietpi-wifi.txt, Automation_Custom_Script.sh onto boot
#   8. Ejects
#
# Requirements: macOS, xz (brew install xz or `brew install --cask macfuse` already has it)
#---------------------------------------------------------------
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMG_XZ="$HERE/DietPi_RPi1-ARMv6-Trixie.img.xz"
SHA256_FILE="$HERE/DietPi_RPi1-ARMv6-Trixie.img.xz.sha256"
CONFIG_FILES=(dietpi.txt dietpi-wifi.txt Automation_Custom_Script.sh)

DRY_RUN="${DRY_RUN:-0}"
run() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "[dry-run] $*"
    else
        eval "$@"
    fi
}

die() { echo "ERROR: $*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

#--- preflight ---
need diskutil
need shasum
need xz
need dd
[ -f "$IMG_XZ" ]       || die "image not found: $IMG_XZ"
[ -f "$SHA256_FILE" ]  || die "sha256 not found: $SHA256_FILE"
for f in "${CONFIG_FILES[@]}"; do
    [ -f "$HERE/$f" ] || die "config file missing: $HERE/$f"
done

#--- wifi creds sanity check ---
if grep -q "YOUR_SSID_HERE\|YOUR_WIFI_PASSWORD_HERE" "$HERE/dietpi-wifi.txt"; then
    die "dietpi-wifi.txt still has placeholder SSID/password. Edit it first."
fi
if grep -q "^AUTO_SETUP_GLOBAL_PASSWORD=changeme-pi-media" "$HERE/dietpi.txt"; then
    echo "WARNING: dietpi.txt still has default password 'changeme-pi-media'."
    read -r -p "Continue anyway? [y/N] " ans
    [ "${ans:-N}" = "y" ] || [ "${ans:-N}" = "Y" ] || die "aborted by user"
fi

#--- verify image checksum ---
echo "==> Verifying image SHA256"
( cd "$HERE" && shasum -a 256 -c "$(basename "$SHA256_FILE")" ) || die "checksum mismatch"

#--- pick target disk ---
TARGET="${1:-}"
if [ -z "$TARGET" ]; then
    echo
    echo "==> Physical disks:"
    diskutil list physical
    echo
    read -r -p "Enter target disk identifier (e.g. /dev/disk4): " TARGET
fi
[[ "$TARGET" =~ ^/dev/disk[0-9]+$ ]] || die "invalid disk path: $TARGET (expected /dev/diskN)"
[ "$TARGET" = "/dev/disk0" ]         && die "refusing to write to disk0 (boot disk)"
[ "$TARGET" = "/dev/disk1" ]         && die "refusing to write to disk1"

DISK_INFO="$(diskutil info "$TARGET" 2>/dev/null || true)"
[ -z "$DISK_INFO" ] && die "disk not found: $TARGET"
DISK_SIZE="$(echo "$DISK_INFO" | awk -F': +' '/Disk Size/ {print $2; exit}')"
DISK_INTERNAL="$(echo "$DISK_INFO" | awk -F': +' '/Device Location/ {print $2; exit}')"
DISK_PROTOCOL="$(echo "$DISK_INFO" | awk -F': +' '/Protocol/ {print $2; exit}')"
DISK_REMOVABLE="$(echo "$DISK_INFO" | awk -F': +' '/Removable Media/ {print $2; exit}')"

#--- summary + confirmation ---
echo
echo "================================================================"
echo " TARGET:        $TARGET"
echo " Size:          $DISK_SIZE"
echo " Location:      $DISK_INTERNAL"
echo " Protocol:      $DISK_PROTOCOL"
echo " Removable:     $DISK_REMOVABLE"
echo " Image:         $IMG_XZ"
echo " Configs:       ${CONFIG_FILES[*]}"
echo "================================================================"
echo " THIS WILL WIPE ALL DATA ON $TARGET."
echo "================================================================"
echo
read -r -p "Type YES (uppercase) to proceed: " CONFIRM
[ "$CONFIRM" = "YES" ] || die "aborted — nothing written"

#--- unmount ---
echo "==> Unmounting $TARGET"
run "diskutil unmountDisk $TARGET"

#--- flash via rdisk for speed ---
RAW="${TARGET/disk/rdisk}"
echo "==> Flashing (this takes ~3–6 min on a USB 3 reader, ~10 min on internal SD reader)"

# If stdin is not a TTY (e.g. invoked from a non-interactive tool), fall back to
# a macOS GUI password prompt via osascript so sudo still works.
if [ ! -t 0 ] && [ -z "${SUDO_ASKPASS:-}" ]; then
    ASKPASS_HELPER="$(mktemp -t pi-media-askpass)"
    cat >"$ASKPASS_HELPER" <<'APEOF'
#!/bin/bash
/usr/bin/osascript -e 'display dialog "Enter your Mac password to flash the SD card (sudo dd):" default answer "" with hidden answer with title "pi-media-server flash.sh"' -e 'text returned of result'
APEOF
    chmod +x "$ASKPASS_HELPER"
    export SUDO_ASKPASS="$ASKPASS_HELPER"
    SUDO="sudo -A"
    trap 'rm -f "$ASKPASS_HELPER"' EXIT
else
    SUDO="sudo"
fi

if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] xz -dc \"$IMG_XZ\" | $SUDO dd of=\"$RAW\" bs=4m status=progress"
else
    xz -dc "$IMG_XZ" | $SUDO dd of="$RAW" bs=4m status=progress
    sync
fi

#--- re-mount boot partition ---
echo "==> Re-mounting boot partition"
# macOS will auto-remount; give it a second
sleep 3
BOOT_MP=""
for i in 1 2 3 4 5; do
    BOOT_MP="$(diskutil info "${TARGET}s1" 2>/dev/null | awk -F': +' '/Mount Point/ {print $2; exit}')"
    [ -n "$BOOT_MP" ] && break
    run "diskutil mountDisk $TARGET" >/dev/null 2>&1 || true
    sleep 2
done
[ -n "$BOOT_MP" ] || die "could not locate boot partition mount point for ${TARGET}s1"
echo "    boot partition: $BOOT_MP"

#--- copy configs ---
echo "==> Copying config files to $BOOT_MP"
for f in "${CONFIG_FILES[@]}"; do
    run "cp \"$HERE/$f\" \"$BOOT_MP/$f\""
done

#--- sync + eject ---
run "sync"
echo "==> Ejecting"
run "diskutil eject $TARGET"

echo
echo "DONE. Insert the SD into the Pi Zero W, connect powered USB hub + disks, apply power."
echo "First boot takes ~30–60 min. Find the Pi at http://pi-media.local or check your router."
