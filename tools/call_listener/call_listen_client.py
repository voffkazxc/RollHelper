import argparse
import subprocess
import sys
import time
from pathlib import Path
from urllib.error import URLError
from urllib.parse import urlencode
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[2]
SERVER = ROOT / "tools" / "call_listener" / "call_listen_server.py"
URL = "http://127.0.0.1:8765"


def start_server():
    subprocess.Popen(
        [sys.executable, str(SERVER)],
        cwd=str(ROOT),
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def wait_health(timeout=8):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urlopen(URL + "/health", timeout=0.5) as response:
                return response.status == 200
        except Exception:
            time.sleep(0.15)
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seconds", type=float, default=6)
    parser.add_argument("--device", type=int, default=0)
    parser.add_argument("--engine", default="whisper")
    parser.add_argument("--model", default="tiny")
    parser.add_argument("--language", default="ru")
    parser.add_argument("--prompt", type=str, default="")
    parser.add_argument("--beam-size", type=int, default=1)
    parser.add_argument("--until-silence", action="store_true")
    parser.add_argument("--silence-seconds", type=float, default=0.45)
    parser.add_argument("--min-speech-seconds", type=float, default=0.6)
    parser.add_argument("--start-timeout", type=float, default=4)
    parser.add_argument("--rms-threshold", type=int, default=10)
    parser.add_argument("--relative-silence-ratio", type=float, default=0.25)
    parser.add_argument("--max-speech-seconds", type=float, default=0.0)
    parser.add_argument("--no-transcribe", action="store_true")
    parser.add_argument("--warm-model-only", action="store_true")
    parser.add_argument("--kind", default="")
    args = parser.parse_args()

    if not wait_health(timeout=0.2):
        start_server()
        if not wait_health():
            raise SystemExit("call listener server did not start")

    if args.warm_model_only:
        params = {"engine": args.engine, "model": args.model}
        try:
            with urlopen(URL + "/warmup?" + urlencode(params), timeout=30) as response:
                sys.stdout.buffer.write(response.read())
            return
        except URLError as exc:
            raise SystemExit(str(exc))

    params = {
        "seconds": args.seconds,
        "device": args.device,
        "model": args.model,
        "engine": args.engine,
        "language": args.language,
        "prompt": args.prompt,
        "beam_size": args.beam_size,
        "until_silence": 1 if args.until_silence else 0,
        "silence_seconds": args.silence_seconds,
        "min_speech_seconds": args.min_speech_seconds,
        "start_timeout": args.start_timeout,
        "rms_threshold": args.rms_threshold,
        "relative_silence_ratio": args.relative_silence_ratio,
        "max_speech_seconds": args.max_speech_seconds,
        "no_transcribe": 1 if args.no_transcribe else 0,
        "kind": args.kind,
    }
    try:
        with urlopen(URL + "/listen?" + urlencode(params), timeout=max(12, args.seconds + 10)) as response:
            sys.stdout.buffer.write(response.read())
    except URLError as exc:
        raise SystemExit(str(exc))


if __name__ == "__main__":
    main()
