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
3. Copy the template configs to real ones (real files are gitignored — they hold your wifi key + root password):
   ```bash
   cp dietpi.txt.example dietpi.txt
   cp dietpi-wifi.txt.example dietpi-wifi.txt
   ```
   Then edit `dietpi.txt` and `dietpi-wifi.txt` and fill in your real wifi SSID + password + root password.
4. After flashing, the SD card appears as a `boot` volume on your Mac. Copy these three files into the root of that volume, **overwriting** the stock ones:
   - `dietpi.txt`
   - `dietpi-wifi.txt`
   - `Automation_Custom_Script.sh`
5. Eject, insert in the Zero W, connect powered hub + disks, apply power.

**First boot takes 30–60 min on a Zero W.** Be patient — apt update + Samba + MiniDLNA install on a single ARMv6 core is slow. Pi reboots once, then is ready.

## What's installed

| Service | Where | Purpose |
|---|---|---|
| ReadyMedia (MiniDLNA) | UPnP auto-discovery | Android TV's **VLC** / **Kodi** / native media player picks up "Pi Media" on the LAN |
| Samba | `\\pi-media\media` or `\\<pi-ip>\media` | File browser from any device, user `carlo` |
| SSH | `ssh carlo@pi-media.local` | Maintenance (dietpi account locked post-setup) |
| MPD + mpc | port `6600` on LAN | Music player daemon pointing at `/mnt`. Control from phone with M.A.L.P. (Android) / MALP (iOS). |
| BlueZ + bluez-alsa | `bluetoothctl` | Pair any Echo as a Bluetooth speaker (one at a time). |
| Voice control (pocketsphinx) | `voice-control.service` (disabled) | **Installed but disabled** — the ARMv6 CPU cannot do real-time STT. See section below. |

## Audio path: MPD → Echo via Bluetooth

Turn one of your Echos into a dumb Bluetooth speaker:

1. On the Echo: *"Alexa, pair Bluetooth"* — it enters pairing mode.
2. On the Pi: `sudo bluetoothctl` then:
   ```
   power on
   agent on
   default-agent
   scan on
   # wait for the Echo's MAC address to appear (e.g. AA:BB:CC:DD:EE:FF)
   pair AA:BB:CC:DD:EE:FF
   trust AA:BB:CC:DD:EE:FF
   connect AA:BB:CC:DD:EE:FF
   quit
   ```
3. Configure MPD's ALSA output to route through the Bluetooth sink (`bluealsa` ALSA plugin). Edit `/etc/mpd.conf`:
   ```
   audio_output {
       type            "alsa"
       name            "Echo Bluetooth"
       device          "bluealsa:DEV=AA:BB:CC:DD:EE:FF,PROFILE=a2dp"
       mixer_type      "software"
   }
   ```
4. `sudo systemctl restart mpd` and test with `mpc play`.

Only **one** Bluetooth speaker can be active at a time. Multi-room requires Snapcast clients, which Echos cannot run. Accept this limit — it's a firmware constraint on every Alexa device.

## Controlling MPD from your phone

No TV needed. Install:
- **Android:** [M.A.L.P.](https://f-droid.org/packages/org.gateshipone.malp/) (F-Droid) — lightweight, works on old phones.
- **iOS:** [MALP](https://apps.apple.com/app/malp/id1442462876).

Point it at `pi-media.local` port `6600`. Browse `/mnt/New_Volume` directly, tap to play. Audio comes out of whichever Bluetooth speaker is currently paired.

## Voice control — why it's installed-but-disabled

I tried. The Pi Zero W 1.1 cannot do real-time speech-to-text. Here's why, so you don't waste hours debugging it:

- **Zero W is BCM2835 — ARMv6 + VFPv2, no NEON.** Every modern speech stack (Vosk, Whisper, openWakeWord) requires NEON and either fails to install (no ARMv6 wheel) or segfaults on boot.
- **Pocketsphinx installs cleanly** (Debian ships an armhf package). On Pi 4/Zero 2 W this works fine. On Zero W 1.1, `arecord | pocketsphinx_continuous` produces audio-buffer **overruns within 5 seconds** because the CPU can't keep up with real-time 16-kHz decoding. The service runs for ~10 seconds, the pipeline chokes, systemd logs "Deactivated successfully" but nothing has actually been transcribed.
- **There is no ARMv6 software fix for this.** It's a raw-CPU ceiling. I left the files in place because:
  - A **Pi Zero 2 W** is a drop-in replacement (same form factor, same GPIO, ~€18) with a quad-core ARMv7 + NEON. On that, pocketsphinx works fine. The service and script will just start working.
  - Or: offload STT to your Mac. Pi captures + streams audio to the Mac, Mac runs whisper.cpp, returns text to the Pi. This needs a small Go/Python bridge — not in this repo yet.

The files that are ready:
- `voice_control.py` installed at `/opt/voice_control.py` on the Pi.
- `voice-control.service` installed at `/etc/systemd/system/`. Enable with `sudo systemctl enable --now voice-control` **after** upgrading to Zero 2 W.
- Grammar supported: `play`, `stop`, `pause`, `next`, `previous`, `louder`, `quieter`, `shuffle on/off`, `update library`, wake word `"hey pi"`.

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

- `dietpi.txt.example` — template for headless first-boot automation (Zero W tuned: 16 MB GPU, 512 MB swap, SMB+DLNA only). Copy to `dietpi.txt` and fill in secrets — `dietpi.txt` is gitignored.
- `dietpi-wifi.txt.example` — template for wifi credentials. Copy to `dietpi-wifi.txt` and fill in. `dietpi-wifi.txt` is gitignored.
- `Automation_Custom_Script.sh` — runs once at end of first boot: fs drivers + udev auto-mount + SMB share + MiniDLNA pointing at /mnt
- `voice_control.py` — pocketsphinx-based voice-command script (installed-but-disabled on Zero W; works on Zero 2 W / Pi 4).
- `voice-control.service` — systemd unit for `voice_control.py`.
- `flash.sh` — macOS SD-flashing helper with osascript sudo-askpass fallback.
- `README.md` — this file
