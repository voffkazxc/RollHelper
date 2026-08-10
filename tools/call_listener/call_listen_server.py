import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.call_listener.call_listen import (  # noqa: E402
    OUT_DIR,
    listen_sherpa_stream_with_fallback,
    record_until_silence_with_fallback,
    record_wav,
    transcribe_sherpa,
    transcribe_with_fallback,
    warm_model,
    warm_sherpa,
    warm_sherpa_stream,
    write_outputs,
)


HOST = "127.0.0.1"
PORT = 8765


def _get(params, name, default):
    value = params.get(name, [default])[0]
    return default if value == "" else value


def _get_int(params, name, default):
    return int(float(_get(params, name, default)))


def _get_float(params, name, default):
    return float(_get(params, name, default))


def _listen(params):
    wav_path = OUT_DIR / "last_call.wav"
    device = _get_int(params, "device", 0)
    device_index = device if device > 0 else None
    model = _get(params, "model", "tiny")
    engine = _get(params, "engine", "whisper").lower()
    language = _get(params, "language", "ru")
    prompt = _get(params, "prompt", "")
    beam_size = _get_int(params, "beam_size", 1)
    seconds = _get_float(params, "seconds", 6)
    until_silence = _get_int(params, "until_silence", 1) == 1
    no_transcribe = _get_int(params, "no_transcribe", 0) == 1
    result = {
        "ok": False,
        "decision": "error",
        "reason": "",
        "text": "",
        "error": "",
    }
    if engine in ("sherpa_stream", "sherpa-stream", "stream"):
        result.update(
            listen_sherpa_stream_with_fallback(
                seconds,
                device_index,
                wav_path,
                _get_float(params, "silence_seconds", 0.45),
                _get_float(params, "min_speech_seconds", 0.6),
                _get_float(params, "start_timeout", 4),
                _get_int(params, "rms_threshold", 10),
                _get_float(params, "relative_silence_ratio", 0.25),
                _get_float(params, "max_speech_seconds", 0.0),
            )
        )
        write_outputs(result, _get(params, "kind", ""))
        return result

    if until_silence:
        result.update(
            record_until_silence_with_fallback(
                seconds,
                device_index,
                wav_path,
                _get_float(params, "silence_seconds", 0.45),
                _get_float(params, "min_speech_seconds", 0.6),
                _get_float(params, "start_timeout", 4),
                _get_int(params, "rms_threshold", 10),
                _get_float(params, "relative_silence_ratio", 0.25),
                _get_float(params, "max_speech_seconds", 0.0),
            )
        )
    else:
        result.update(record_wav(seconds, device_index, wav_path))

    if no_transcribe:
        result.update({"ok": True, "decision": "recorded", "reason": "no_transcribe"})
    elif engine == "sherpa":
        text, meta = transcribe_sherpa(wav_path)
        from tools.call_listener.call_listen import classify

        decision, reason = classify(text)
        result.update(meta)
        result.update({"ok": True, "text": text, "decision": decision, "reason": reason})
    else:
        text, meta, decision, reason = transcribe_with_fallback(wav_path, model, language, beam_size, prompt)
        meta["engine"] = "faster-whisper"
        result.update(meta)
        result.update({"ok": True, "text": text, "decision": decision, "reason": reason})
    write_outputs(result, _get(params, "kind", ""))
    return result


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self._json({"ok": True})
            return
        if parsed.path == "/warmup":
            params = parse_qs(parsed.query)
            engine = _get(params, "engine", "whisper").lower()
            model = _get(params, "model", "base")
            if engine in ("sherpa_stream", "sherpa-stream", "stream"):
                warm_sherpa_stream()
                self._json({"ok": True, "engine": "sherpa_stream", "model": "sherpa-onnx-streaming-t-one-russian-2025-09-08", "warmed": True})
            elif engine == "sherpa":
                warm_sherpa()
                self._json({"ok": True, "engine": "sherpa", "model": "sherpa-nemo-ctc-ru", "warmed": True})
            else:
                warm_model(model)
                self._json({"ok": True, "engine": "faster-whisper", "model": model, "warmed": True})
            return
        if parsed.path != "/listen":
            self.send_error(404)
            return
        try:
            self._json(_listen(parse_qs(parsed.query)))
        except Exception as exc:
            result = {"ok": False, "decision": "error", "reason": "", "text": "", "error": repr(exc)}
            write_outputs(result)
            self._json(result, status=500)

    def log_message(self, format, *args):
        return

    def _json(self, payload, status=200):
        raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)


def main():
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
