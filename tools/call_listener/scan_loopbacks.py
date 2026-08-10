import argparse
import json
import time
import wave
from pathlib import Path

import numpy as np

try:
    import pyaudiowpatch as pyaudio

    AUDIO_BACKEND = "pyaudiowpatch"
except ImportError:
    import pyaudio

    AUDIO_BACKEND = "pyaudio"


ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "data" / "call_listener"


def audioop_rms(raw_audio: bytes) -> int:
    if not raw_audio:
        return 0
    samples = np.frombuffer(raw_audio, dtype=np.int16)
    if samples.size == 0:
        return 0
    return int(np.sqrt(np.mean(samples.astype(np.float64) ** 2)))


def mix_to_mono(raw_audio: bytes, input_channels: int) -> bytes:
    if input_channels <= 1 or not raw_audio:
        return raw_audio
    samples = np.frombuffer(raw_audio, dtype=np.int16)
    usable = (len(samples) // input_channels) * input_channels
    if not usable:
        return b""
    return samples[:usable].reshape(-1, input_channels).mean(axis=1).astype(np.int16).tobytes()


def select_best(rows: list[dict], prefer_names: list[str]) -> tuple[dict, str]:
    usable_rows = [row for row in rows if row["peak_rms"] >= 80]
    non_microphone_rows = [
        row
        for row in usable_rows
        if "microphone" not in row["name"].lower() and "мікрофон" not in row["name"].lower()
    ]
    preferred_rows = [
        row
        for row in non_microphone_rows
        if any(name.lower() in row["name"].lower() for name in prefer_names)
    ]
    if preferred_rows:
        return preferred_rows[0], "prefer_name_non_microphone_loopback"
    if non_microphone_rows:
        return non_microphone_rows[0], "prefer_non_microphone_loopback"
    if usable_rows:
        return usable_rows[0], "fallback_any_usable_loopback"
    return (rows or [{}])[0], "fallback_loudest_loopback"


def scan(seconds: float, prefer_names: list[str]) -> dict:
    audio = pyaudio.PyAudio()
    streams = []
    devices = []
    try:
        for index in range(audio.get_device_count()):
            info = audio.get_device_info_by_index(index)
            if int(info.get("maxInputChannels", 0)) <= 0:
                continue
            if not info.get("isLoopbackDevice"):
                continue
            devices.append(
                {
                    "index": index,
                    "name": str(info.get("name", "")),
                    "rate": int(info.get("defaultSampleRate") or 16000),
                    "channels": max(1, int(info.get("maxInputChannels") or 1)),
                    "peak_rms": 0,
                    "avg_rms": 0,
                    "samples": 0,
                    "frames": [],
                }
            )

        for dev in devices:
            def make_callback(target):
                def on_audio(in_data, frame_count, time_info, status):
                    mono = mix_to_mono(in_data or b"", target["channels"])
                    rms = audioop_rms(mono)
                    target["peak_rms"] = max(target["peak_rms"], rms)
                    target["avg_rms"] += rms
                    target["samples"] += 1
                    target["frames"].append(mono)
                    return (None, pyaudio.paContinue)

                return on_audio

            try:
                stream = audio.open(
                    format=pyaudio.paInt16,
                    channels=dev["channels"],
                    rate=dev["rate"],
                    input=True,
                    input_device_index=dev["index"],
                    frames_per_buffer=1024,
                    stream_callback=make_callback(dev),
                )
                stream.start_stream()
                streams.append(stream)
            except Exception as exc:
                dev["error"] = repr(exc)

        time.sleep(seconds)
    finally:
        for stream in streams:
            try:
                stream.stop_stream()
                stream.close()
            except Exception:
                pass
        audio.terminate()

    rows = []
    for dev in devices:
        samples = int(dev.get("samples") or 0)
        avg_rms = int(dev["avg_rms"] / samples) if samples else 0
        frames = b"".join(dev.get("frames") or [])
        wav_path = OUT_DIR / "scan_loopbacks" / f"device_{dev['index']}.wav"
        if frames:
            wav_path.parent.mkdir(parents=True, exist_ok=True)
            with wave.open(str(wav_path), "wb") as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2)
                wf.setframerate(dev["rate"])
                wf.writeframes(frames)
        rows.append(
            {
                "index": dev["index"],
                "name": dev["name"],
                "rate": dev["rate"],
                "peak_rms": int(dev["peak_rms"]),
                "avg_rms": avg_rms,
                "wav": str(wav_path) if frames else "",
                "error": dev.get("error", ""),
            }
        )

    rows.sort(key=lambda item: item["peak_rms"], reverse=True)
    best, selection_rule = select_best(rows, prefer_names)
    raw_best = rows[0] if rows else {}
    return {
        "ok": bool(rows),
        "backend": AUDIO_BACKEND,
        "seconds": seconds,
        "best_index": best.get("index", 0),
        "best_name": best.get("name", ""),
        "best_peak_rms": best.get("peak_rms", 0),
        "raw_best_index": raw_best.get("index", 0),
        "raw_best_name": raw_best.get("name", ""),
        "raw_best_peak_rms": raw_best.get("peak_rms", 0),
        "selection_rule": selection_rule,
        "prefer_names": prefer_names,
        "rows": rows,
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
    }


def write_outputs(result: dict) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "last_channel_scan.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = [
        "[ChannelScan]",
        f"Ok={1 if result.get('ok') else 0}",
        f"Backend={result.get('backend', '')}",
        f"Seconds={result.get('seconds', '')}",
        f"BestIndex={result.get('best_index', '')}",
        f"BestName={result.get('best_name', '')}",
        f"BestPeakRms={result.get('best_peak_rms', '')}",
        f"RawBestIndex={result.get('raw_best_index', '')}",
        f"RawBestName={result.get('raw_best_name', '')}",
        f"RawBestPeakRms={result.get('raw_best_peak_rms', '')}",
        f"SelectionRule={result.get('selection_rule', '')}",
        f"PreferNames={'|'.join(result.get('prefer_names') or [])}",
        f"Timestamp={result.get('timestamp', '')}",
    ]
    (OUT_DIR / "last_channel_scan.ini").write_text("\n".join(lines) + "\n", encoding="utf-8")
    text_rows = [
        "=== LOOPBACK CHANNEL SCAN ===",
        f"best: [{result.get('best_index')}] peak={result.get('best_peak_rms')} {result.get('best_name')}",
        f"raw_best: [{result.get('raw_best_index')}] peak={result.get('raw_best_peak_rms')} {result.get('raw_best_name')}",
        f"rule: {result.get('selection_rule')}",
        "",
    ]
    for row in result.get("rows", []):
        text_rows.append(
            f"[{row['index']:>2}] peak={row['peak_rms']:<5} avg={row['avg_rms']:<5} {row['name']} wav={row['wav']}"
        )
    (OUT_DIR / "last_channel_scan.txt").write_text("\n".join(text_rows) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seconds", type=float, default=3.0)
    parser.add_argument("--prefer-name", action="append", default=[])
    args = parser.parse_args()
    result = scan(args.seconds, args.prefer_name)
    write_outputs(result)
    print((OUT_DIR / "last_channel_scan.txt").read_text(encoding="utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
