#!/bin/bash
#---------------------------------------------------------------
# First-boot setup for Pi Zero W media server (DLNA + Samba only).
# Runs once after DietPi installs Samba (45) and ReadyMedia (37).
#
# Purpose:
#   1. Install filesystem drivers so any USB disk mounts (ntfs / exfat / btrfs / f2fs)
#   2. Install a udev rule that auto-mounts USB disks under /mnt/<LABEL>/
#   3. Expose /mnt as a Samba share so the TV / laptop can browse everything
#   4. Point ReadyMedia (MiniDLNA) at /mnt with inotify off (low RAM)
# Log: /var/tmp/dietpi/logs/dietpi-automation_custom_script.log
#---------------------------------------------------------------
set -euo pipefail

log() { echo "[pi-media-setup] $*"; }

#------- 1. Filesystem drivers -------
log "Installing filesystem drivers"
apt-get update -y
apt-get install -y --no-install-recommends \
    ntfs-3g exfat-fuse exfatprogs f2fs-tools udisks2

#------- 2. Auto-mount USB disks by label -------
log "Installing udev auto-mount rule"
mkdir -p /mnt
cat >/usr/local/sbin/pi-media-automount <<'EOF'
#!/bin/bash
# Called by udev on USB block-device add/remove
set -eu
ACTION="${1:-}"
DEVNAME="${2:-}"            # e.g. sda1
[ -z "$DEVNAME" ] && exit 0
DEV="/dev/$DEVNAME"

mountpoint_for() {
    local label
    label="$(lsblk -no LABEL "$DEV" 2>/dev/null | head -n1 | tr -cs 'A-Za-z0-9._-' '_' | sed 's/^_//;s/_$//')"
    [ -z "$label" ] && label="usb-$DEVNAME"
    echo "/mnt/$label"
}

case "$ACTION" in
    add)
        MP="$(mountpoint_for)"
        mkdir -p "$MP"
        /usr/bin/udisksctl mount --no-user-interaction -b "$DEV" 2>/dev/null || \
        mount "$DEV" "$MP" 2>/dev/null || true
        logger -t pi-media-automount "mounted $DEV at $MP"
        ;;
    remove)
        logger -t pi-media-automount "removed $DEV"
        ;;
esac
EOF
chmod +x /usr/local/sbin/pi-media-automount

cat >/etc/udev/rules.d/99-pi-media-automount.rules <<'EOF'
# Auto-mount USB block devices (partitions only)
ACTION=="add",    KERNEL=="sd[a-z][0-9]", SUBSYSTEMS=="usb", RUN+="/usr/local/sbin/pi-media-automount add %k"
ACTION=="remove", KERNEL=="sd[a-z][0-9]", SUBSYSTEMS=="usb", RUN+="/usr/local/sbin/pi-media-automount remove %k"
EOF
udevadm control --reload-rules

#------- 3. Samba share of /mnt -------
log "Configuring Samba share 'media' -> /mnt"
SMB_CONF=/etc/samba/smb.conf
if ! grep -q '^\[media\]' "$SMB_CONF" 2>/dev/null; then
    cat >>"$SMB_CONF" <<'EOF'

[media]
    comment = External USB disks
    path = /mnt
    browseable = yes
    read only = no
    guest ok = no
    valid users = dietpi
    create mask = 0664
    directory mask = 0775
    follow symlinks = yes
    wide links = yes
    unix extensions = no
    # Zero W — keep memory footprint minimal
    socket options = TCP_NODELAY IPTOS_LOWDELAY
EOF
    systemctl restart smbd || true
fi

#------- 4. ReadyMedia / MiniDLNA — low-RAM profile -------
log "Pointing ReadyMedia at /mnt (inotify OFF, manual rescan)"
MDL_CONF=/etc/minidlna.conf
if [ -f "$MDL_CONF" ]; then
    sed -i '/^media_dir=/d;/^inotify=/d;/^friendly_name=/d' "$MDL_CONF"
    cat >>"$MDL_CONF" <<'EOF'
media_dir=A,/mnt
media_dir=V,/mnt
media_dir=P,/mnt
friendly_name=Pi Media
# inotify watches every file — on 512 MB RAM with thousands of files this OOMs.
# Set off; trigger a rescan manually after adding content:
#   sudo service minidlna force-reload
inotify=no
EOF
    systemctl restart minidlna || true
fi

log "pi-media first-boot setup complete"
exit 0
