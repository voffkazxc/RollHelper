import argparse
import csv
import json
import os
import shutil
import subprocess
import sys
import time
import wave
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "data" / "call_listener"
BENCH_DIR = OUT_DIR / "benchmarks"
VOSK_MODEL_CACHE = {}
SHERPA_MODEL_CACHE = {}

if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.call_listener.call_listen import classify, transcribe, transcribe_with_fallback, warm_model  # noqa: E402


AUDIO_EXTENSIONS = {".wav", ".mp3", ".m4a", ".ogg", ".flac", ".aac", ".wma"}


def now_stamp() -> str:
    return time.strftime("%Y%m%d_%H%M%S")


def default_inputs() -> list[Path]:
    candidates = []
    for pattern in (
        str(OUT_DIR / "*.wav"),
        str(Path.home() / "Downloads" / "*outgoing*.mp3"),
        str(Path.home() / "Downloads" / "*call*.mp3"),
    ):
        candidates.extend(Path().glob(pattern) if not os.path.isabs(pattern) else [Path(item) for item in __import__("glob").glob(pattern)])
    unique = []
    seen = set()
    for path in candidates:
        resolved = path.resolve()
        if resolved.exists() and resolved.suffix.lower() in AUDIO_EXTENSIONS and resolved not in seen:
            seen.add(resolved)
            unique.append(resolved)
    return sorted(unique, key=lambda item: item.stat().st_mtime, reverse=True)


def collect_inputs(args: argparse.Namespace) -> list[Path]:
    files = []
    for raw in args.inputs:
        path = Path(raw).expanduser()
        if path.is_dir():
            for child in path.rglob("*"):
                if child.suffix.lower() in AUDIO_EXTENSIONS:
                    files.append(child.resolve())
        elif any(char in raw for char in "*?[]"):
            import glob

            for match in glob.glob(raw):
                matched_path = Path(match)
                if matched_path.suffix.lower() in AUDIO_EXTENSIONS:
                    files.append(matched_path.resolve())
        elif path.exists() and path.suffix.lower() in AUDIO_EXTENSIONS:
            files.append(path.resolve())

    if not files:
        files = default_inputs()

    unique = []
    seen = set()
    for path in files:
        if path not in seen:
            seen.add(path)
            unique.append(path)
    return unique[: args.limit] if args.limit > 0 else unique


def wav_duration_seconds(path: Path) -> float | None:
    if path.suffix.lower() != ".wav":
        return None
    try:
        with wave.open(str(path), "rb") as wav:
            return wav.getnframes() / float(wav.getframerate() or 1)
    except Exception:
        return None


def find_ffmpeg() -> str:
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg:
        return ffmpeg
    try:
        import imageio_ffmpeg

        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return ""


def prepare_vosk_wav(path: Path) -> tuple[Path | None, str]:
    prepared_dir = BENCH_DIR / "prepared_audio"
    prepared_dir.mkdir(parents=True, exist_ok=True)
    target = prepared_dir / f"{path.stem}.vosk.wav"
    if target.exists() and target.stat().st_mtime >= path.stat().st_mtime:
        return target, ""

    if path.suffix.lower() == ".wav":
        try:
            with wave.open(str(path), "rb") as wav:
                if wav.getnchannels() == 1 and wav.getsampwidth() == 2 and wav.getframerate() == 16000:
                    return path, ""
        except Exception:
            pass

    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        return None, "ffmpeg_not_found"
    command = [
        ffmpeg,
        "-y",
        "-loglevel",
        "error",
        "-i",
        str(path),
        "-ac",
        "1",
        "-ar",
        "16000",
        "-sample_fmt",
        "s16",
        str(target),
    ]
    completed = subprocess.run(command, capture_output=True, text=True)
    if completed.returncode != 0:
        return None, "ffmpeg_error:" + (completed.stderr.strip() or str(completed.returncode))
    return target, ""


def read_float32_wav(path: Path) -> tuple[np.ndarray | None, int, str]:
    try:
        with wave.open(str(path), "rb") as wav:
            channels = wav.getnchannels()
            sample_width = wav.getsampwidth()
            sample_rate = wav.getframerate()
            raw_audio = wav.readframes(wav.getnframes())
    except Exception as exc:
        return None, 0, "wave_read_error:" + repr(exc)

    if sample_width != 2:
        return None, 0, "wav_needs_16bit"
    samples = np.frombuffer(raw_audio, dtype=np.int16)
    if channels > 1:
        samples = samples.reshape(-1, channels)[:, 0]
    audio = samples.astype(np.float32) / 32768.0
    return audio, sample_rate, ""


def run_faster_whisper(path: Path, model: str, language: str, beam_size: int, fallback: bool, prompt: str = "") -> dict:
    started = time.perf_counter()
    if fallback:
        text, meta, decision, reason = transcribe_with_fallback(path, model, language, beam_size, prompt)
    else:
        text, meta = transcribe(path, model, language, beam_size, prompt)
        decision, reason = classify(text)
    elapsed_ms = int((time.perf_counter() - started) * 1000)
    return {
        "engine": "faster-whisper",
        "model": model,
        "language_request": language,
        "language_detected": meta.get("language", ""),
        "language_probability": meta.get("language_probability", ""),
        "fallback": "yes" if fallback else "no",
        "time_ms": elapsed_ms,
        "decision": decision,
        "reason": reason,
        "text": text,
        "error": "",
    }


def get_vosk_model(model_path: str):
    from vosk import Model

    if model_path not in VOSK_MODEL_CACHE:
        VOSK_MODEL_CACHE[model_path] = Model(model_path)
    return VOSK_MODEL_CACHE[model_path]


def run_vosk(path: Path, model_path: str, grammar: bool = False) -> dict:
    started = time.perf_counter()
    result = {
        "engine": "vosk-grammar" if grammar else "vosk",
        "model": model_path,
        "language_request": "",
        "language_detected": "",
        "language_probability": "",
        "fallback": "no",
        "time_ms": 0,
        "decision": "skipped",
        "reason": "",
        "text": "",
        "error": "",
    }
    if not model_path:
        result["reason"] = "vosk_model_path_not_set"
        return result
    wav_path, prepare_error = prepare_vosk_wav(path)
    if wav_path is None:
        result["reason"] = prepare_error
        return result
    try:
        from vosk import KaldiRecognizer, SetLogLevel

        SetLogLevel(-1)

        with wave.open(str(wav_path), "rb") as wav:
            if wav.getnchannels() != 1 or wav.getsampwidth() != 2:
                result["reason"] = "vosk_needs_mono_16bit_wav"
                return result
            model = get_vosk_model(model_path)
            if grammar:
                phrases = [
                    "да спасибо",
                    "так дякую",
                    "все хорошо",
                    "все добре",
                    "все нормально",
                    "все отлично",
                    "все чудово",
                    "было хорошо",
                    "було добре",
                    "сподобалось",
                    "понравилось",
                    "вкусно",
                    "смачно",
                    "не понравилось",
                    "не сподобалось",
                    "не положили",
                    "не довезли",
                    "проблема",
                    "жалоба",
                    "скарга",
                    "долго",
                    "довго",
                    "[unk]",
                ]
                recognizer = KaldiRecognizer(model, wav.getframerate(), json.dumps(phrases, ensure_ascii=False))
            else:
                recognizer = KaldiRecognizer(model, wav.getframerate())
            parts = []
            while True:
                data = wav.readframes(4000)
                if not data:
                    break
                if recognizer.AcceptWaveform(data):
                    parts.append(json.loads(recognizer.Result()).get("text", ""))
            parts.append(json.loads(recognizer.FinalResult()).get("text", ""))
            text = " ".join(part for part in parts if part).strip()
            decision, reason = classify(text)
            result.update({"decision": decision, "reason": reason, "text": text})
    except Exception as exc:
        result.update({"decision": "error", "reason": "vosk_error", "error": repr(exc)})
    finally:
        result["time_ms"] = int((time.perf_counter() - started) * 1000)
    return result


def get_sherpa_nemo_ctc(model_dir: str, num_threads: int):
    import sherpa_onnx

    key = (model_dir, num_threads)
    if key not in SHERPA_MODEL_CACHE:
        model_path = Path(model_dir)
        SHERPA_MODEL_CACHE[key] = sherpa_onnx.OfflineRecognizer.from_nemo_ctc(
            model=str(model_path / "model.int8.onnx"),
            tokens=str(model_path / "tokens.txt"),
            num_threads=num_threads,
            sample_rate=16000,
            feature_dim=80,
            decoding_method="greedy_search",
            debug=False,
            provider="cpu",
        )
    return SHERPA_MODEL_CACHE[key]


def run_sherpa_nemo_ctc(path: Path, model_dir: str, num_threads: int) -> dict:
    started = time.perf_counter()
    result = {
        "engine": "sherpa-nemo-ctc",
        "model": model_dir,
        "language_request": "",
        "language_detected": "",
        "language_probability": "",
        "fallback": "no",
        "time_ms": 0,
        "decision": "skipped",
        "reason": "",
        "text": "",
        "error": "",
    }
    if not model_dir:
        result["reason"] = "sherpa_model_path_not_set"
        return result

    wav_path, prepare_error = prepare_vosk_wav(path)
    if wav_path is None:
        result["reason"] = prepare_error
        return result

    try:
        recognizer = get_sherpa_nemo_ctc(model_dir, num_threads)
        audio, sample_rate, audio_error = read_float32_wav(wav_path)
        if audio is None:
            result["reason"] = audio_error
            return result
        stream = recognizer.create_stream()
        stream.accept_waveform(sample_rate, audio)
        recognizer.decode_stream(stream)
        text = getattr(stream.result, "text", str(stream.result)).strip()
        decision, reason = classify(text)
        result.update({"decision": decision, "reason": reason, "text": text})
    except Exception as exc:
        result.update({"decision": "error", "reason": "sherpa_error", "error": repr(exc)})
    finally:
        result["time_ms"] = int((time.perf_counter() - started) * 1000)
    return result


def write_reports(rows: list[dict]) -> tuple[Path, Path, Path]:
    BENCH_DIR.mkdir(parents=True, exist_ok=True)
    stamp = now_stamp()
    json_path = BENCH_DIR / f"benchmark_{stamp}.jsonl"
    csv_path = BENCH_DIR / f"benchmark_{stamp}.csv"
    txt_path = BENCH_DIR / f"benchmark_{stamp}.txt"

    fields = [
        "file",
        "duration_s",
        "engine",
        "model",
        "language_request",
        "language_detected",
        "language_probability",
        "fallback",
        "time_ms",
        "decision",
        "reason",
        "text",
        "error",
    ]
    with json_path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")
    with csv_path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)

    lines = ["=== RollHouse local ASR benchmark ===", ""]
    for row in rows:
        lines.extend(
            [
                f"{row['file']}",
                f"  {row['engine']} {row['model']} lang={row['language_request']} fallback={row['fallback']} time={row['time_ms']}ms",
                f"  decision={row['decision']} reason={row['reason']}",
                f"  text={row['text']}",
                f"  error={row['error']}",
                "",
            ]
        )
    txt_path.write_text("\n".join(lines), encoding="utf-8")

    (BENCH_DIR / "latest.jsonl").write_text(json_path.read_text(encoding="utf-8"), encoding="utf-8")
    (BENCH_DIR / "latest.csv").write_text(csv_path.read_text(encoding="utf-8-sig"), encoding="utf-8-sig")
    (BENCH_DIR / "latest.txt").write_text(txt_path.read_text(encoding="utf-8"), encoding="utf-8")
    return json_path, csv_path, txt_path


def print_summary(rows: list[dict], txt_path: Path) -> None:
    print(f"Report: {txt_path}")
    print("")
    for row in rows:
        name = Path(row["file"]).name
        text = row["text"].replace("\n", " ")
        if len(text) > 140:
            text = text[:137] + "..."
        print(
            f"{name} | {row['engine']} {row['model']} {row['language_request']} | "
            f"{row['time_ms']}ms | {row['decision']} | {row['reason']} | {text}"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description="Benchmark local ASR engines on saved RollHouse call audio.")
    parser.add_argument("inputs", nargs="*", help="Audio files, folders, or globs. Defaults to recent call wav/mp3 files.")
    parser.add_argument("--models", default="base", help="faster-whisper models, comma-separated.")
    parser.add_argument("--skip-whisper", action="store_true")
    parser.add_argument("--languages", default="ru,uk,auto", help="Languages to test, comma-separated.")
    parser.add_argument("--beam-size", type=int, default=1)
    parser.add_argument("--prompt", type=str, default="")
    parser.add_argument("--no-fallback", action="store_true")
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--vosk-model", default=os.environ.get("VOSK_MODEL", ""))
    parser.add_argument("--include-vosk", action="store_true")
    parser.add_argument("--include-vosk-grammar", action="store_true")
    parser.add_argument("--include-sherpa", action="store_true")
    parser.add_argument("--sherpa-model", default=os.environ.get("SHERPA_MODEL", ""))
    parser.add_argument("--sherpa-threads", type=int, default=2)
    args = parser.parse_args()

    files = collect_inputs(args)
    if not files:
        print("No audio files found.")
        return 2

    rows = []
    models = [item.strip() for item in args.models.split(",") if item.strip()]
    languages = [item.strip() for item in args.languages.split(",") if item.strip()]

    if args.skip_whisper:
        models = []
    for model in models:
        if not model:
            continue
        try:
            warm_started = time.perf_counter()
            warm_model(model)
            print(f"warm {model}: {int((time.perf_counter() - warm_started) * 1000)}ms")
        except Exception as exc:
            print(f"warm {model}: error {exc!r}")

    for path in files:
        duration = wav_duration_seconds(path)
        for model in models:
            for language in languages:
                try:
                    row = run_faster_whisper(path, model, language, args.beam_size, not args.no_fallback, args.prompt)
                except Exception as exc:
                    row = {
                        "engine": "faster-whisper",
                        "model": model,
                        "language_request": language,
                        "language_detected": "",
                        "language_probability": "",
                        "fallback": "yes" if not args.no_fallback else "no",
                        "time_ms": 0,
                        "decision": "error",
                        "reason": "faster_whisper_error",
                        "text": "",
                        "error": repr(exc),
                    }
                row.update({"file": str(path), "duration_s": "" if duration is None else round(duration, 3)})
                rows.append(row)
        if args.include_vosk:
            for grammar in (False, True) if args.include_vosk_grammar else (False,):
                row = run_vosk(path, args.vosk_model, grammar)
                row.update({"file": str(path), "duration_s": "" if duration is None else round(duration, 3)})
                rows.append(row)
        if args.include_sherpa:
            row = run_sherpa_nemo_ctc(path, args.sherpa_model, args.sherpa_threads)
            row.update({"file": str(path), "duration_s": "" if duration is None else round(duration, 3)})
            rows.append(row)

    _, _, txt_path = write_reports(rows)
    print_summary(rows, txt_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
