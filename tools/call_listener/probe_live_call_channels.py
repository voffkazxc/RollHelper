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
PROBE_DIR = OUT_DIR / "live_channel_probe"


def mix_to_mono(raw_audio: bytes, channels: int) -> bytes:
    if channels <= 1 or not raw_audio:
        return raw_audio
    samples = np.frombuffer(raw_audio, dtype=np.int16)
    usable = (len(samples) // channels) * channels
    if not usable:
        return b""
    return samples[:usable].reshape(-1, channels).mean(axis=1).astype(np.int16).tobytes()


def rms(raw_audio: bytes) -> int:
    if not raw_audio:
        return 0
    samples = np.frombuffer(raw_audio, dtype=np.int16)
    if not samples.size:
        return 0
    return int(np.sqrt(np.mean(samples.astype(np.float64) ** 2)))


def stats(raw_audio: bytes) -> dict:
    samples = np.frombuffer(raw_audio, dtype=np.int16)
    if not samples.size:
        return {"rms": 0, "peak": 0, "nonzero_percent": 0.0}
    abs_samples = np.abs(samples.astype(np.int32))
    return {
        "rms": int(np.sqrt(np.mean(samples.astype(np.float64) ** 2))),
        "peak": int(abs_samples.max()),
        "nonzero_percent": round(float(np.mean(abs_samples > 100) * 100), 2),
    }


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


def probe(seconds: float, prefer_names: list[str]) -> dict:
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
                    "frames": [],
                    "peak_rms": 0,
                    "avg_rms": 0,
                    "samples": 0,
                }
            )

        for dev in devices:
            def make_callback(target):
                def on_audio(in_data, frame_count, time_info, status):
                    mono = mix_to_mono(in_data or b"", target["channels"])
                    value = rms(mono)
                    target["peak_rms"] = max(target["peak_rms"], value)
                    target["avg_rms"] += value
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

    PROBE_DIR.mkdir(parents=True, exist_ok=True)
    rows = []
    for dev in devices:
        raw_audio = b"".join(dev.get("frames") or [])
        wav_path = PROBE_DIR / f"call_device_{dev['index']}.wav"
        if raw_audio:
            with wave.open(str(wav_path), "wb") as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2)
                wf.setframerate(dev["rate"])
                wf.writeframes(raw_audio)
        sample_count = int(dev.get("samples") or 0)
        audio_stats = stats(raw_audio)
        rows.append(
            {
                "index": dev["index"],
                "name": dev["name"],
                "rate": dev["rate"],
                "peak_rms": int(dev.get("peak_rms") or 0),
                "avg_rms": int((dev.get("avg_rms") or 0) / sample_count) if sample_count else 0,
                "duration_sec": round(len(np.frombuffer(raw_audio, dtype=np.int16)) / max(1, dev["rate"]), 2),
                "rms": audio_stats["rms"],
                "peak": audio_stats["peak"],
                "nonzero_percent": audio_stats["nonzero_percent"],
                "wav": str(wav_path) if raw_audio else "",
                "error": dev.get("error", ""),
            }
        )
    rows.sort(key=lambda item: (item["peak_rms"], item["rms"], item["nonzero_percent"]), reverse=True)
    best, selection_rule = select_best(rows, prefer_names)
    result = {
        "ok": bool(rows),
        "backend": AUDIO_BACKEND,
        "seconds": seconds,
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "best": best,
        "selection_rule": selection_rule,
        "prefer_names": prefer_names,
        "rows": rows,
    }
    return result


def write_outputs(result: dict) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "live_channel_probe.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    best = result.get("best") or (result.get("rows") or [{}])[0]
    ini_lines = [
        "[LiveProbe]",
        f"Ok={1 if result.get('ok') else 0}",
        f"Backend={result.get('backend', '')}",
        f"Seconds={result.get('seconds', '')}",
        f"BestIndex={best.get('index', '')}",
        f"BestName={best.get('name', '')}",
        f"BestPeakRms={best.get('peak_rms', 0)}",
        f"BestRms={best.get('rms', 0)}",
        f"BestPeak={best.get('peak', 0)}",
        f"BestNonzeroPercent={best.get('nonzero_percent', 0)}",
        f"BestWav={best.get('wav', '')}",
        f"SelectionRule={result.get('selection_rule', '')}",
        f"PreferNames={'|'.join(result.get('prefer_names') or [])}",
        f"Timestamp={result.get('timestamp', '')}",
    ]
    (OUT_DIR / "live_channel_probe.ini").write_text("\n".join(ini_lines) + "\n", encoding="utf-8")
    lines = [
        "=== LIVE CALL CHANNEL PROBE ===",
        f"time: {result.get('timestamp')}",
        f"seconds: {result.get('seconds')}",
        f"backend: {result.get('backend')}",
        f"selected: [{best.get('index', '')}] peak_rms={best.get('peak_rms', 0)} {best.get('name', '')}",
        f"rule: {result.get('selection_rule')}",
        "",
        "Запускай это ВО ВРЕМЯ разговора, когда клиент говорит.",
        "Нужен канал, где peak/rms/nonzero заметно выше нуля именно на голосе клиента.",
        "",
    ]
    for row in result.get("rows", []):
        lines.append(
            f"[{row['index']:>2}] peak_rms={row['peak_rms']:<5} rms={row['rms']:<5} peak={row['peak']:<6} nonzero={row['nonzero_percent']:<6}% {row['name']} wav={row['wav']}"
        )
    text = "\n".join(lines) + "\n"
    (OUT_DIR / "live_channel_probe.txt").write_text(text, encoding="utf-8")
    print(text)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seconds", type=float, default=8.0)
    parser.add_argument("--prefer-name", action="append", default=[])
    args = parser.parse_args()
    write_outputs(probe(args.seconds, args.prefer_name))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
