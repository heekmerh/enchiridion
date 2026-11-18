"""
Even out the loudness of the OSCE heart and lung sound tracks.

Hikma found some recordings barely audible next to others (quietest about
-37 LUFS, loudest about -10). Each track is brought to the same integrated
loudness with ffmpeg's two-pass loudnorm, with a true-peak ceiling so the
louder clicks and snaps are held in rather than clipped. Sample rate,
channel count and bitrate (at least 64 kbps) are kept per file.

Usage:
  python3 normalize_sounds.py FILE.mp3 [FILE.mp3 ...]

Files are rewritten in place. generate_osce_content.py calls normalize()
on every track it copies, so regenerated sounds stay even.
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

TARGET_LUFS = -16.0
TRUE_PEAK = -1.5
LOUDNESS_RANGE = 11.0


def _probe(path: Path) -> dict:
    out = subprocess.run(
        ["ffprobe", "-v", "quiet", "-select_streams", "a:0", "-show_entries",
         "stream=sample_rate,channels,bit_rate", "-of", "json", str(path)],
        check=True, capture_output=True, text=True,
    ).stdout
    return json.loads(out)["streams"][0]


def _measure(path: Path) -> dict:
    filt = f"loudnorm=I={TARGET_LUFS}:TP={TRUE_PEAK}:LRA={LOUDNESS_RANGE}:print_format=json"
    err = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", filt, "-f", "null", "-"],
        check=True, capture_output=True, text=True,
    ).stderr
    return json.loads(err[err.rindex("{"): err.rindex("}") + 1])


def normalize(path: Path) -> None:
    info = _probe(path)
    m = _measure(path)
    filt = (
        f"loudnorm=I={TARGET_LUFS}:TP={TRUE_PEAK}:LRA={LOUDNESS_RANGE}"
        f":measured_I={m['input_i']}:measured_TP={m['input_tp']}"
        f":measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}"
        f":offset={m['target_offset']}:linear=true"
    )
    bitrate = max(int(info.get("bit_rate") or 128000), 64000)
    with tempfile.NamedTemporaryFile(suffix=".mp3", dir=path.parent, delete=False) as tmp:
        tmp_path = Path(tmp.name)
    try:
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-nostats", "-loglevel", "error", "-y", "-i", str(path),
             "-af", filt, "-ar", str(info["sample_rate"]), "-ac", str(info["channels"]),
             "-c:a", "libmp3lame", "-b:a", str(bitrate), "-map_metadata", "-1", str(tmp_path)],
            check=True,
        )
        tmp_path.replace(path)
    finally:
        tmp_path.unlink(missing_ok=True)


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        normalize(Path(arg))
        print(f"normalized {arg}")
