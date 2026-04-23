# Pi Media Server — DietPi image for Raspberry Pi Zero W

Headless Pi Zero W that joins your wifi, auto-mounts every USB disk plugged into a powered hub,
and serves the files to your Android TV over **DLNA** (zero-config discovery) + **Samba** (file browser).

## Honest expectations for Zero W

Pi Zero W is **marginal** for this use case. Read these before buying anything else:

- **No transcoding.** Ever. Your video files must play directly on the Android TV. Stick to H.264/AAC in MP4 or MKV. 4K, HEVC/H.265, or weird codecs → the TV will refuse or stutter.
- **Wifi is the bottleneck.** Single-band 2.4 GHz 802.11n, real-world ~30–50 Mbps. Fine for most 1080p streams, risky for high-bitrate Blu-ray rips.
- **USB bus is shared.** One micro-USB 2.0 OTG port feeds the hub, the hub feeds disks + ethernet (if you add a USB-ethernet adapter) + wifi is internal but competes for the same SoC. Sequential streaming is OK; parallel 3-client streaming is not.
- **RAM is tight.** 512 MB. We disable inotify on MiniDLNA (it watches every file — OOMs with thousands). Library rescans are triggered manually.
- **First scan is slow.** MiniDLNA indexing thousands of files on a Zero W takes **hours**. Plan to leave it overnight after first setup.
- **No Jellyfin / Plex / Emby.** No armhf package, and the CPU wouldn't cope anyway.

If any of these are blockers, a **Pi Zero 2 W** (same form factor, 4× cores, still 512 MB) helps the CPU side; a **Pi 4** removes every bottleneck. But the config in this folder makes a Zero W work within its limits.

## What you need

- **Raspberry Pi Zero W** (with pre-soldered headers or not — headless, doesn't matter).
- **Powered USB 2.0 hub** (4-port+, with its own 5V PSU) — non-negotiable. The Zero W's micro-USB cannot feed spinning HDDs; even 2.5" bus-powered drives will brown-out the Pi.
- **micro-USB OTG adapter** (male micro-USB-B to female USB-A) to plug the hub into the Zero W's data port (the port labeled `USB`, *not* `PWR`).
- microSD card (16GB+, class 10 / A1).
- Official 5V 2.5A Zero-compatible PSU.

## One-time flashing

1. Download DietPi for Zero W: <https://dietpi.com/#downloadinfo> → `Raspberry Pi` → `ARMv6 32-bit (Pi 1 / Zero / Zero W)`.
2. Flash the `.img.xz` to the SD card with **Raspberry Pi Imager** or **balenaEtcher**.
3. After flashing, the SD card appears as a `boot` volume on your Mac. Copy these three files into the root of that volume, **overwriting** the stock ones:
   - `dietpi.txt`
   - `dietpi-wifi.txt`
   - `Automation_Custom_Script.sh`
4. **Before ejecting:**
   - Edit `dietpi-wifi.txt` → put your real SSID + password on lines 1 and 2.
   - Edit `dietpi.txt` → change `AUTO_SETUP_GLOBAL_PASSWORD=changeme-pi-media` to something you'll remember.
5. Eject, insert in the Zero W, connect powered hub + disks, apply power.

**First boot takes 30–60 min on a Zero W.** Be patient — apt update + Samba + MiniDLNA install on a single ARMv6 core is slow. Pi reboots once, then is ready.

## What's installed

| Service | Where | Purpose |
|---|---|---|
| ReadyMedia (MiniDLNA) | UPnP auto-discovery | Android TV's **VLC** / **Kodi** / native media player picks up "Pi Media" on the LAN |
| Samba | `\\pi-media\media` or `\\<pi-ip>\media` | File browser from any device, user `dietpi` |
| SSH | `ssh dietpi@pi-media.local` | Maintenance |

## How disks are mounted

Every external USB disk plugged into the hub auto-mounts read-write under `/mnt/<disk-label>/` (via a udev rule installed by the first-boot script). Supported filesystems: **ext4, exfat, ntfs, vfat, f2fs**. MiniDLNA and Samba both see `/mnt` so new disks appear after a rescan.

## After first boot

```bash
ssh dietpi@pi-media.local        # or the IP shown in your router
sudo dietpi-drive_manager        # verify disks mounted under /mnt
mount | grep /mnt                # sanity check
sudo service minidlna force-reload   # trigger the first library scan (long!)
```

On the Android TV:
- Install **VLC** from the Play Store → **Browsing** → **Local Network** → "Pi Media" shows up → browse folders.
- Or install **Kodi** → add UPnP source.
- Or open the TV's stock "Media Player" / "File Manager" and point it at the SMB share `\\pi-media\media` (user: `dietpi`, password: whatever you set).

## Adding new content

1. Copy files to the disks however you like (SMB from your laptop, or plug disks into your PC first).
2. `sudo service minidlna force-reload` to re-index. This takes a while on Zero W — leave it running.

## Security notes

- Change `AUTO_SETUP_GLOBAL_PASSWORD` in `dietpi.txt` **before flashing**.
- Change the Samba user password after boot: `sudo smbpasswd dietpi`.
- Do not expose any port to the internet. For remote access install Tailscale: `sudo dietpi-software install 172`.
- `dietpi-wifi.txt` stores your wifi key in plaintext on the SD card's boot partition. Wipe it after first successful boot: `sudo rm /boot/dietpi-wifi.txt` (it's no longer read after setup completes).

## Troubleshooting

| Symptom | Fix |
|---|---|
| Pi won't boot with hub attached | Hub is back-feeding the Pi or drawing too much. Power the Pi first, plug the hub second. Check hub's own PSU is connected. |
| Disks not mounted | `lsblk` to see them, `sudo dietpi-drive_manager` to format/mount manually. NTFS disks sometimes need `sudo ntfsfix /dev/sdXN` after unclean unplug from Windows. |
| Android TV can't see "Pi Media" | Both on same wifi + same VLAN. Some guest/IoT wifi networks block multicast (needed for UPnP). Use SMB as fallback. |
| Stuttering / buffering | File isn't direct-play. Re-encode to H.264/AAC MP4 with `ffmpeg -i in.mkv -c:v copy -c:a aac -c:s mov_text out.mp4` if video stream is already H.264. Otherwise: `-c:v libx264 -preset slow -crf 20`. Do this on your laptop — not on the Zero W. |
| MiniDLNA eating RAM / OOM | inotify is off by default in our config. If you turned it back on, turn it back off. |
| Library scan never finishes | Normal on Zero W with thousands of files. `tail -f /var/log/minidlna/minidlna.log` to watch progress. |
| Very slow wifi | Move the Pi closer to the router, or get a Pi Zero 2 W (5 GHz still no, but more stable) or Pi 4. |

## Files in this folder

- `dietpi.txt` — headless first-boot automation (Zero W tuned: 16 MB GPU, 512 MB swap, SMB+DLNA only)
- `dietpi-wifi.txt` — SSID + password (edit before flashing)
- `Automation_Custom_Script.sh` — runs once at end of first boot: fs drivers + udev auto-mount + SMB share + MiniDLNA pointing at /mnt
- `README.md` — this file
