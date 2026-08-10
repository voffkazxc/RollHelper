import argparse
import configparser
import json
import queue
import re
import sys
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
CONFIG_PATH = ROOT / "brands" / "rollhouse" / "RkConfig.ini"

POSITIVE_PATTERNS = [
    r"\bда\b",
    r"\bтак\b",
    r"\bага\b",
    r"\bугу\b",
    r"все\s+(хорошо|добре|отлично|чудово|нормально)",
    r"все\s+.*\b(хорошо|добре|отлично|чудово|нормально)\b",
    r"було\s+.*\b(добре|чудово|нормально)\b",
    r"было\s+.*\b(хорошо|отлично|нормально)\b",
    r"все\s+сподобал",
    r"все\s+понрав",
    r"понравил",
    r"сподобал",
    r"вкусн",
    r"смачн",
    r"дякую",
    r"спасибо",
    r"претензий\s+нет",
    r"нема[єе]\s+претенз",
    r"нарекан",
    r"некогда\s+говор",
    r"нет\s+времени",
]

NEGATIVE_PATTERNS = [
    r"не\s+понрав",
    r"не\s+сподоб",
    r"плохо",
    r"жах",
    r"ужас",
    r"холодн",
    r"невкусн",
    r"несмачн",
    r"опоздал",
    r"довго",
    r"долго",
    r"проблем",
    r"жалоб",
    r"скарг",
    r"не\s+довез",
    r"не\s+полож",
]


def normalize_text(text: str) -> str:
    text = text.lower().replace("ё", "е")
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def classify(text: str) -> tuple[str, str]:
    cleaned = normalize_text(text)
    if not cleaned:
        return "empty", "text_empty"

    negative_hits = [pattern for pattern in NEGATIVE_PATTERNS if re.search(pattern, cleaned)]
    if negative_hits:
        return "manual", "negative_or_problem:" + ",".join(negative_hits[:3])

    positive_hits = [pattern for pattern in POSITIVE_PATTERNS if re.search(pattern, cleaned)]
    word_count = len(cleaned.split())
    if positive_hits and word_count <= 24:
        return "positive", "positive_short:" + ",".join(positive_hits[:3])

    if positive_hits:
        return "manual", "positive_but_long"

    return "manual", "unknown"


def read_ini_device() -> int | None:
    parser = configparser.ConfigParser()
    parser.optionxform = str
    if not CONFIG_PATH.exists():
        return None
    parser.read(CONFIG_PATH, encoding="utf-8-sig")
    try:
        value = parser.get("CallListen", "Device", fallback="").strip()
        if not value:
            value = parser.get("CallListen", "DeviceIndex", fallback="").strip()
        device_index = int(value) if value else None
        return device_index if device_index and device_index > 0 else None
    except Exception:
        return None


def candidate_devices(audio: pyaudio.PyAudio, requested: int | None) -> list[int]:
    if requested is not None:
        info = audio.get_device_info_by_index(requested)
        if int(info.get("maxInputChannels", 0)) > 0:
            return [requested]
        raise RuntimeError(f"Device {requested} is not an input device")

    priorities = [
        "sonar - chat",
        "chat",
        "sonar - gaming",
        "gaming",
        "headset earphone",
        "speakers (high",
        "speakers",
        "sonar - stream",
        "stream",
        "sonar - media",
        "stereo mix",
        "what u hear",
    ]
    candidates: list[tuple[int, str]] = []
    for index in range(audio.get_device_count()):
        info = audio.get_device_info_by_index(index)
        if int(info.get("maxInputChannels", 0)) <= 0:
            continue
        is_loopback = bool(info.get("isLoopbackDevice"))
        name = str(info.get("name", ""))
        lower = name.lower()
        if requested is None and ("microphone" in lower or "мікрофон" in lower):
            continue
        if requested is None and not is_loopback:
            continue
        for rank, needle in enumerate(priorities):
            if needle in lower:
                loopback_bonus = -100 if is_loopback else 0
                candidates.append((rank + loopback_bonus, index))
                break

    ordered: list[int] = []
    if candidates:
        candidates.sort()
        ordered.extend(index for _, index in candidates)

    for index in range(audio.get_device_count()):
        info = audio.get_device_info_by_index(index)
        name = str(info.get("name", "")).lower()
        if requested is None and ("microphone" in name or "мікрофон" in name):
            continue
        if requested is None and not bool(info.get("isLoopbackDevice")):
            continue
        if int(info.get("maxInputChannels", 0)) > 0 and index not in ordered:
            ordered.append(index)
    return ordered


def record_wav(seconds: float, device_index: int | None, wav_path: Path) -> dict:
    audio = pyaudio.PyAudio()
    try:
        last_error = None
        stream = None
        device = None
        info = None
        rate = 16000
        input_channels = 1
        frames_per_buffer = 1024
        for candidate in candidate_devices(audio, device_index):
            try:
                candidate_info = audio.get_device_info_by_index(candidate)
                candidate_rate = int(candidate_info.get("defaultSampleRate") or 16000)
                candidate_channels = max(1, int(candidate_info.get("maxInputChannels") or 1))
                stream = audio.open(
                    format=pyaudio.paInt16,
                    channels=candidate_channels,
                    rate=candidate_rate,
                    input=True,
                    input_device_index=candidate,
                    frames_per_buffer=frames_per_buffer,
                )
                device = candidate
                info = candidate_info
                rate = candidate_rate
                input_channels = candidate_channels
                break
            except Exception as exc:
                last_error = exc
        if stream is None or device is None or info is None:
            raise RuntimeError(f"No input device could be opened: {last_error!r}")
        frames = []
        started = time.time()
        try:
            if info.get("isLoopbackDevice"):
                stream.stop_stream()
                stream.close()

                def on_audio(in_data, frame_count, time_info, status):
                    if in_data:
                        frames.append(in_data)
                    return (None, pyaudio.paContinue)

                stream = audio.open(
                    format=pyaudio.paInt16,
                    channels=input_channels,
                    rate=rate,
                    input=True,
                    input_device_index=device,
                    frames_per_buffer=frames_per_buffer,
                    stream_callback=on_audio,
                )
                stream.start_stream()
                time.sleep(max(0.05, seconds))
            else:
                total_reads = int(rate / frames_per_buffer * seconds)
                for _ in range(max(1, total_reads)):
                    frames.append(stream.read(frames_per_buffer, exception_on_overflow=False))
        finally:
            stream.stop_stream()
            stream.close()

        wav_path.parent.mkdir(parents=True, exist_ok=True)
        raw_audio = b"".join(frames)
        if not raw_audio:
            silent_samples = max(1, int(rate * seconds)) * input_channels
            raw_audio = (np.zeros(silent_samples, dtype=np.int16)).tobytes()
        output_channels = input_channels
        if input_channels > 1 and raw_audio:
            samples = np.frombuffer(raw_audio, dtype=np.int16)
            usable = (len(samples) // input_channels) * input_channels
            if usable:
                mixed = samples[:usable].reshape(-1, input_channels).mean(axis=1).astype(np.int16)
                raw_audio = mixed.tobytes()
                output_channels = 1

        with wave.open(str(wav_path), "wb") as wf:
            wf.setnchannels(output_channels)
            wf.setsampwidth(audio.get_sample_size(pyaudio.paInt16))
            wf.setframerate(rate)
            wf.writeframes(raw_audio)

        return {
            "device_index": device,
            "device_name": info.get("name", ""),
            "device_loopback": bool(info.get("isLoopbackDevice")),
            "audio_backend": AUDIO_BACKEND,
            "rate": rate,
            "channels": output_channels,
            "input_channels": input_channels,
            "seconds": round(time.time() - started, 2),
            "wav": str(wav_path),
        }
    finally:
        audio.terminate()


def mix_to_mono(raw_audio: bytes, input_channels: int) -> tuple[bytes, int]:
    if input_channels <= 1 or not raw_audio:
        return raw_audio, input_channels
    samples = np.frombuffer(raw_audio, dtype=np.int16)
    usable = (len(samples) // input_channels) * input_channels
    if not usable:
        return b"", 1
    mixed = samples[:usable].reshape(-1, input_channels).mean(axis=1).astype(np.int16)
    return mixed.tobytes(), 1


def record_until_silence(
    max_seconds: float,
    device_index: int | None,
    wav_path: Path,
    silence_seconds: float,
    min_speech_seconds: float,
    start_timeout: float,
    rms_threshold: int,
) -> dict:
    audio = pyaudio.PyAudio()
    try:
        last_error = None
        stream = None
        device = None
        info = None
        rate = 16000
        input_channels = 1
        frames_per_buffer = 1024
        for candidate in candidate_devices(audio, device_index):
            try:
                candidate_info = audio.get_device_info_by_index(candidate)
                candidate_rate = int(candidate_info.get("defaultSampleRate") or 16000)
                candidate_channels = max(1, int(candidate_info.get("maxInputChannels") or 1))
                stream = audio.open(
                    format=pyaudio.paInt16,
                    channels=candidate_channels,
                    rate=candidate_rate,
                    input=True,
                    input_device_index=candidate,
                    frames_per_buffer=frames_per_buffer,
                )
                device = candidate
                info = candidate_info
                rate = candidate_rate
                input_channels = candidate_channels
                break
            except Exception as exc:
                last_error = exc
        if stream is None or device is None or info is None:
            raise RuntimeError(f"No input device could be opened: {last_error!r}")

        audio_queue = None
        if info.get("isLoopbackDevice"):
            stream.stop_stream()
            stream.close()
            audio_queue = queue.Queue()

            def on_audio(in_data, frame_count, time_info, status):
                audio_queue.put(in_data or b"")
                return (None, pyaudio.paContinue)

            stream = audio.open(
                format=pyaudio.paInt16,
                channels=input_channels,
                rate=rate,
                input=True,
                input_device_index=device,
                frames_per_buffer=frames_per_buffer,
                stream_callback=on_audio,
            )
            stream.start_stream()

        frames = []
        started = time.time()
        speech_started_at = None
        last_voice_at = None
        peak_rms = 0
        speech_ms = 0
        reason = "max_seconds"
        try:
            while True:
                now = time.time()
                elapsed = now - started
                if elapsed >= max_seconds:
                    break
                if speech_started_at is None and elapsed >= start_timeout:
                    reason = "start_timeout"
                    break

                if audio_queue is not None:
                    try:
                        chunk = audio_queue.get(timeout=max(0.02, frames_per_buffer / rate))
                    except queue.Empty:
                        chunk = (np.zeros(frames_per_buffer * input_channels, dtype=np.int16)).tobytes()
                else:
                    chunk = stream.read(frames_per_buffer, exception_on_overflow=False)
                mono_chunk, _ = mix_to_mono(chunk, input_channels)
                rms = audioop_rms(mono_chunk)
                peak_rms = max(peak_rms, rms)
                is_voice = rms >= rms_threshold

                if is_voice:
                    if speech_started_at is None:
                        speech_started_at = now
                    last_voice_at = now
                    frames.append(chunk)
                elif speech_started_at is not None:
                    frames.append(chunk)
                    speech_ms = int((now - speech_started_at) * 1000)
                    silent_ms = int((now - (last_voice_at or now)) * 1000)
                    if speech_ms >= int(min_speech_seconds * 1000) and silent_ms >= int(silence_seconds * 1000):
                        reason = "silence_after_speech"
                        break

            if speech_started_at is not None:
                speech_ms = int((time.time() - speech_started_at) * 1000)
                silence_ms = int((time.time() - (last_voice_at or time.time())) * 1000)
            else:
                speech_ms = 0
                silence_ms = 0
        finally:
            stream.stop_stream()
            stream.close()

        wav_path.parent.mkdir(parents=True, exist_ok=True)
        raw_audio = b"".join(frames)
        if not raw_audio:
            silent_samples = max(1, int(rate * 0.25)) * input_channels
            raw_audio = (np.zeros(silent_samples, dtype=np.int16)).tobytes()
        raw_audio, output_channels = mix_to_mono(raw_audio, input_channels)

        with wave.open(str(wav_path), "wb") as wf:
            wf.setnchannels(output_channels)
            wf.setsampwidth(audio.get_sample_size(pyaudio.paInt16))
            wf.setframerate(rate)
            wf.writeframes(raw_audio)

        return {
            "device_index": device,
            "device_name": info.get("name", ""),
            "device_loopback": bool(info.get("isLoopbackDevice")),
            "audio_backend": AUDIO_BACKEND,
            "rate": rate,
            "channels": output_channels,
            "input_channels": input_channels,
            "seconds": round(time.time() - started, 2),
            "wav": str(wav_path),
            "vad_mode": True,
            "vad_reason": reason,
            "vad_rms_threshold": rms_threshold,
            "vad_peak_rms": peak_rms,
            "vad_speech_ms": speech_ms,
            "vad_silence_ms": silence_ms,
        }
    finally:
        audio.terminate()


def record_until_silence_with_fallback(
    max_seconds: float,
    device_index: int | None,
    wav_path: Path,
    silence_seconds: float,
    min_speech_seconds: float,
    start_timeout: float,
    rms_threshold: int,
) -> dict:
    if device_index is not None:
        return record_until_silence(
            max_seconds,
            device_index,
            wav_path,
            silence_seconds,
            min_speech_seconds,
            start_timeout,
            rms_threshold,
        )

    audio = pyaudio.PyAudio()
    try:
        candidates = candidate_devices(audio, None)
    finally:
        audio.terminate()

    last_result = None
    for candidate in candidates:
        result = record_until_silence(
            max_seconds,
            candidate,
            wav_path,
            silence_seconds,
            min_speech_seconds,
            start_timeout,
            rms_threshold,
        )
        last_result = result
        if not (
            result.get("vad_reason") == "start_timeout"
            and int(result.get("vad_peak_rms") or 0) == 0
        ):
            return result

    if last_result is None:
        raise RuntimeError("No input device candidates found")
    return last_result


def audioop_rms(raw_audio: bytes) -> int:
    if not raw_audio:
        return 0
    import audioop

    return audioop.rms(raw_audio, 2)


def transcribe(wav_path: Path, model_name: str, language: str, beam_size: int) -> tuple[str, dict]:
    from faster_whisper import WhisperModel

    model = WhisperModel(model_name, device="cpu", compute_type="int8")
    kwargs = {
        "vad_filter": True,
        "beam_size": beam_size,
        "best_of": beam_size,
    }
    if language and language.lower() != "auto":
        kwargs["language"] = language
    segments, info = model.transcribe(
        str(wav_path),
        **kwargs,
    )
    text = " ".join(segment.text.strip() for segment in segments).strip()
    meta = {
        "model": model_name,
        "requested_language": language,
        "language": getattr(info, "language", ""),
        "language_probability": float(getattr(info, "language_probability", 0.0) or 0.0),
    }
    return text, meta


def transcribe_with_fallback(wav_path: Path, model_name: str, language: str, beam_size: int) -> tuple[str, dict, str, str]:
    text, meta = transcribe(wav_path, model_name, language, beam_size)
    decision, reason = classify(text)
    if decision == "positive":
        return text, meta, decision, reason

    detected = str(meta.get("language") or "")
    probability = float(meta.get("language_probability") or 0)
    should_retry = reason == "unknown" or language in ("ru", "uk") or detected not in ("uk", "ru") or probability < 0.65
    if not should_retry:
        return text, meta, decision, reason

    attempts = [{"language": language, "text": text, "decision": decision, "reason": reason}]
    if language == "ru":
        fallback_languages = ("uk", "auto")
    elif language == "uk":
        fallback_languages = ("ru", "auto")
    else:
        fallback_languages = ("ru", "uk")
    for fallback_language in fallback_languages:
        fallback_text, fallback_meta = transcribe(wav_path, model_name, fallback_language, beam_size)
        fallback_decision, fallback_reason = classify(fallback_text)
        attempts.append(
            {
                "language": fallback_language,
                "text": fallback_text,
                "decision": fallback_decision,
                "reason": fallback_reason,
            }
        )
        if fallback_decision == "positive":
            fallback_meta["language_fallback"] = f"auto->{fallback_language}"
            fallback_meta["language_fallback_from"] = detected
            fallback_meta["language_fallback_attempts"] = json.dumps(attempts, ensure_ascii=False)
            return fallback_text, fallback_meta, fallback_decision, fallback_reason

    return text, meta, decision, reason


def write_outputs(result: dict) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "last_result.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    lines = [
        "[CallListen]",
        f"Decision={result.get('decision', '')}",
        f"Reason={result.get('reason', '')}",
        f"Text={result.get('text', '').replace(chr(10), ' ')}",
        f"DeviceIndex={result.get('device_index', '')}",
        f"DeviceName={result.get('device_name', '')}",
        f"DeviceLoopback={result.get('device_loopback', '')}",
        f"AudioBackend={result.get('audio_backend', '')}",
        f"Model={result.get('model', '')}",
        f"RequestedLanguage={result.get('requested_language', '')}",
        f"DetectedLanguage={result.get('language', '')}",
        f"LanguageFallback={result.get('language_fallback', '')}",
        f"LanguageFallbackFrom={result.get('language_fallback_from', '')}",
        f"VadMode={result.get('vad_mode', '')}",
        f"VadReason={result.get('vad_reason', '')}",
        f"VadSpeechMs={result.get('vad_speech_ms', '')}",
        f"VadSilenceMs={result.get('vad_silence_ms', '')}",
        f"VadPeakRms={result.get('vad_peak_rms', '')}",
        f"Wav={result.get('wav', '')}",
        f"Error={result.get('error', '')}",
    ]
    (OUT_DIR / "last_result.ini").write_text("\n".join(lines) + "\n", encoding="utf-8")
    summary = (
        f"decision: {result.get('decision')}\n"
        f"reason: {result.get('reason')}\n"
        f"text: {result.get('text')}\n"
        f"device: [{result.get('device_index')}] {result.get('device_name')}\n"
        f"loopback: {result.get('device_loopback')}\n"
        f"backend: {result.get('audio_backend')}\n"
        f"model: {result.get('model', '')}\n"
        f"language: requested={result.get('requested_language', '')} detected={result.get('language', '')} prob={result.get('language_probability', '')}\n"
        f"fallback: {result.get('language_fallback', '')} from {result.get('language_fallback_from', '')}\n"
        f"vad: mode={result.get('vad_mode', '')} reason={result.get('vad_reason', '')} speech_ms={result.get('vad_speech_ms', '')} silence_ms={result.get('vad_silence_ms', '')} peak_rms={result.get('vad_peak_rms', '')}\n"
        f"wav: {result.get('wav')}\n"
        f"error: {result.get('error', '')}\n"
    )
    (OUT_DIR / "last_result.txt").write_text(summary, encoding="utf-8")


def write_compare_outputs(result: dict, rows: list[dict]) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    payload = dict(result)
    payload["compare"] = rows
    (OUT_DIR / "last_compare.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    lines = [
        "=== CALL LISTENER COMPARE ===",
        f"device: [{result.get('device_index')}] {result.get('device_name')}",
        f"loopback: {result.get('device_loopback')}",
        f"wav: {result.get('wav')}",
        "",
    ]
    for row in rows:
        lines.extend(
            [
                f"--- {row.get('requested_language')} / {row.get('model')} ---",
                f"detected: {row.get('language')} prob={row.get('language_probability')}",
                f"decision: {row.get('decision')} reason={row.get('reason')}",
                f"text: {row.get('text')}",
                "",
            ]
        )
    (OUT_DIR / "last_compare.txt").write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="RollHouse call listener diagnostic")
    parser.add_argument("--seconds", type=float, default=8.0)
    parser.add_argument("--device", type=int, default=None)
    parser.add_argument("--model", default="small")
    parser.add_argument("--language", default="uk")
    parser.add_argument("--beam-size", type=int, default=3)
    parser.add_argument("--compare", action="store_true")
    parser.add_argument("--compare-languages", default="uk,ru,auto")
    parser.add_argument("--until-silence", action="store_true")
    parser.add_argument("--silence-seconds", type=float, default=1.0)
    parser.add_argument("--min-speech-seconds", type=float, default=1.5)
    parser.add_argument("--start-timeout", type=float, default=4.0)
    parser.add_argument("--rms-threshold", type=int, default=120)
    parser.add_argument("--no-transcribe", action="store_true")
    args = parser.parse_args()

    requested_device = args.device if args.device is not None else read_ini_device()
    wav_path = OUT_DIR / "last_call.wav"
    result = {
        "ok": False,
        "decision": "error",
        "reason": "",
        "text": "",
        "error": "",
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
    }

    try:
        if args.until_silence:
            result.update(
                record_until_silence_with_fallback(
                    args.seconds,
                    requested_device,
                    wav_path,
                    args.silence_seconds,
                    args.min_speech_seconds,
                    args.start_timeout,
                    args.rms_threshold,
                )
            )
        else:
            result.update(record_wav(args.seconds, requested_device, wav_path))
        if args.no_transcribe:
            result.update({"ok": True, "decision": "recorded", "reason": "no_transcribe"})
        elif args.compare:
            rows = []
            for language in [item.strip() for item in args.compare_languages.split(",") if item.strip()]:
                text, meta = transcribe(wav_path, args.model, language, max(1, args.beam_size))
                decision, reason = classify(text)
                row = dict(meta)
                row.update({"text": text, "decision": decision, "reason": reason})
                rows.append(row)
            result.update({"ok": True, "decision": "compare", "reason": "compare_languages"})
            write_compare_outputs(result, rows)
            print((OUT_DIR / "last_compare.txt").read_text(encoding="utf-8"))
            return 0
        else:
            text, meta, decision, reason = transcribe_with_fallback(
                wav_path,
                args.model,
                args.language,
                max(1, args.beam_size),
            )
            result.update(meta)
            result.update({"ok": True, "text": text, "decision": decision, "reason": reason})
    except Exception as exc:
        result["error"] = repr(exc)

    write_outputs(result)
    print((OUT_DIR / "last_result.txt").read_text(encoding="utf-8"))
    return 0 if result.get("ok") else 2


if __name__ == "__main__":
    raise SystemExit(main())
