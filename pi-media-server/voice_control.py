#!/usr/bin/env python3
"""
voice_control.py — offline voice commands for MPD on a Pi Zero W (ARMv6).

Why `pocketsphinx_continuous` and not a Python binding?
  Pi Zero W is BCM2835: ARMv6 + VFPv2, no NEON.
  Vosk / Whisper / openWakeWord need ARMv7+ and NEON — they will not run.
  Debian Trixie ships pocketsphinx 0.8 (old CMU Sphinx), no `python3-pocketsphinx`.
  So we shell out to `pocketsphinx_continuous` and parse its stdout.

Dependencies (apt):
  pocketsphinx pocketsphinx-en-us libpocketsphinx3 alsa-utils mpc

Hardware:
  USB sound card with a mic. `arecord -l` must list it.
  Set VOICE_MIC_DEVICE env var to the ALSA device string.

Grammar (substring match, case-insensitive):
  wake word:  "hey pi" (or whatever you set in VOICE_WAKE)
  commands:   play | stop | pause | next | previous | louder | quieter |
              shuffle on | shuffle off | update library

No LLM, no cloud, no internet. Small whitelist of phrases after the wake word,
then shells out to `mpc`. Accuracy is mediocre on open speech but usable for
a dozen fixed commands.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys
import time
from typing import Callable

# --- configuration ---------------------------------------------------------

# ALSA capture device. Default tries card 1 (first USB card on a Pi Zero W
# where the onboard HDMI audio is card 0). Override via env var.
MIC_DEVICE = os.environ.get("VOICE_MIC_DEVICE", "plughw:1,0")

# Wake word. Two-syllable phrases work best in Sphinx's acoustic model.
WAKE_WORD = os.environ.get("VOICE_WAKE", "hey pi").lower()

# Seconds we stay in "listening for a command" mode after the wake word fires.
COMMAND_WINDOW_SEC = 6

# pocketsphinx en-us model is trained on 16 kHz mono.
SAMPLE_RATE = 16000

# Where the Debian package puts the acoustic model + dictionary.
PS_MODEL_DIR = "/usr/share/pocketsphinx/model/en-us"
HMM = f"{PS_MODEL_DIR}/en-us"
LM = f"{PS_MODEL_DIR}/en-us.lm.bin"
DICT = f"{PS_MODEL_DIR}/cmudict-en-us.dict"

# --- MPD command dispatch --------------------------------------------------


def mpc(*args: str) -> None:
    """Fire-and-forget MPD command. Failures are logged, never raised."""
    try:
        subprocess.run(
            ["mpc", *args], check=False, timeout=5, capture_output=True
        )
    except subprocess.TimeoutExpired:
        print(f"mpc {args}: timeout", file=sys.stderr)


# Longest phrases matched first so "shuffle on" wins over bare "shuffle".
COMMANDS: dict[str, Callable[[], None]] = {
    "play":           lambda: mpc("play"),
    "stop":           lambda: mpc("stop"),
    "pause":          lambda: mpc("pause"),
    "next":           lambda: mpc("next"),
    "previous":       lambda: mpc("prev"),
    "louder":         lambda: mpc("volume", "+10"),
    "quieter":        lambda: mpc("volume", "-10"),
    "shuffle on":     lambda: mpc("random", "on"),
    "shuffle off":    lambda: mpc("random", "off"),
    "update library": lambda: mpc("update"),
}


def dispatch(text: str) -> bool:
    """Return True if any command matched."""
    text = text.lower().strip()
    for phrase in sorted(COMMANDS, key=len, reverse=True):
        if phrase in text:
            print(f"→ {phrase}", flush=True)
            COMMANDS[phrase]()
            return True
    return False


# --- pocketsphinx pipeline -------------------------------------------------


def open_pipeline() -> subprocess.Popen[str]:
    """
    arecord → pocketsphinx_continuous.

    arecord gives us explicit ALSA device control. pocketsphinx_continuous
    reads raw 16-kHz mono S16LE from stdin when `-infile /dev/stdin` is given
    and prints recognized utterances to stdout (one per line).
    """
    arecord = subprocess.Popen(
        [
            "arecord",
            "-D", MIC_DEVICE,
            "-f", "S16_LE",
            "-r", str(SAMPLE_RATE),
            "-c", "1",
            "-q",
            "-t", "raw",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    ps = subprocess.Popen(
        [
            "pocketsphinx_continuous",
            "-hmm", HMM,
            "-lm", LM,
            "-dict", DICT,
            "-infile", "/dev/stdin",
            "-logfn", "/dev/null",  # suppress noisy sphinx log spam
        ],
        stdin=arecord.stdout,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1,  # line-buffered
    )
    assert arecord.stdout is not None
    arecord.stdout.close()  # let arecord exit if ps dies
    return ps


# --- main loop -------------------------------------------------------------


def main() -> int:
    print(
        f"listening on {MIC_DEVICE!r}, wake word = {WAKE_WORD!r}",
        flush=True,
    )

    stop = {"requested": False}
    def _on_term(_signum: int, _frame: object) -> None:
        stop["requested"] = True
    signal.signal(signal.SIGTERM, _on_term)
    signal.signal(signal.SIGINT, _on_term)

    ps = open_pipeline()
    waiting_for_command_until = 0.0
    try:
        assert ps.stdout is not None
        for line in ps.stdout:
            if stop["requested"]:
                break
            text = line.strip().lower()
            if not text:
                continue

            now = time.time()
            if now < waiting_for_command_until:
                if dispatch(text):
                    waiting_for_command_until = 0.0
            elif WAKE_WORD in text:
                print("wake word heard", flush=True)
                waiting_for_command_until = now + COMMAND_WINDOW_SEC
            # else: ignore ambient noise / misfires
    finally:
        ps.terminate()
        try:
            ps.wait(timeout=3)
        except subprocess.TimeoutExpired:
            ps.kill()
    return 0


if __name__ == "__main__":
    sys.exit(main())
