import json
import re
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "data" / "call_listener"
HISTORY_PATH = OUT_DIR / "history.jsonl"
EVENTS_PATH = OUT_DIR / "call_events.log"
REPORT_PATH = OUT_DIR / "call_analysis_latest.txt"
LABELS_PATH = OUT_DIR / "customer_calls" / "labels.tsv"


def load_history() -> list[dict]:
    rows = []
    if not HISTORY_PATH.exists():
        return rows
    for line in HISTORY_PATH.read_text(encoding="utf-8-sig", errors="ignore").splitlines():
        try:
            row = json.loads(line)
        except Exception:
            continue
        if row.get("kind") == "customer":
            rows.append(row)
    return rows


def load_events() -> list[dict]:
    rows = []
    if not EVENTS_PATH.exists():
        return rows
    for line in EVENTS_PATH.read_text(encoding="utf-8-sig", errors="ignore").splitlines():
        item = {"raw": line}
        for part in line.split("\t"):
            if "=" in part:
                key, value = part.split("=", 1)
                item[key] = value
        date_match = re.match(r"^(\d{8})(\d{6})", line)
        if date_match:
            item["ts"] = f"{date_match.group(1)} {date_match.group(2)}"
        rows.append(item)
    return rows


def load_labels() -> list[dict]:
    rows = []
    if not LABELS_PATH.exists():
        return rows
    for line in LABELS_PATH.read_text(encoding="utf-8-sig", errors="ignore").splitlines():
        item = {"raw": line}
        for part in line.split("\t"):
            if "=" in part:
                key, value = part.split("=", 1)
                item[key] = value
        if item:
            rows.append(item)
    return rows


def build_event_calls(events: list[dict]) -> list[dict]:
    calls = []
    current_by_num = {}
    for event in events:
        num = event.get("num", "")
        name = event.get("event", "")
        if not num:
            continue
        if name == "accept_talk":
            call = {
                "num": num,
                "idx": event.get("idx", ""),
                "accept_ts": event.get("ts", ""),
                "manual_x": False,
                "advisor_positive": False,
                "auto_x": False,
            }
            calls.append(call)
            current_by_num[num] = call
        elif name in {"listen_start", "listen_done", "manual_x", "advisor_positive", "auto_x", "auto_positive_skipped_manual_x", "customer_archived"}:
            call = current_by_num.get(num)
            if call is None:
                call = {
                    "num": num,
                    "idx": event.get("idx", ""),
                    "accept_ts": "",
                    "manual_x": False,
                    "advisor_positive": False,
                    "auto_x": False,
                }
                calls.append(call)
                current_by_num[num] = call
            if name == "listen_start":
                call["listen_start_ts"] = event.get("ts", "")
            elif name == "listen_done":
                call.update(
                    {
                        "listen_done_ts": event.get("ts", ""),
                        "decision": event.get("decision", ""),
                        "reason": event.get("reason", ""),
                        "totalMs": event.get("totalMs", ""),
                        "speechMs": event.get("speechMs", ""),
                        "silenceMs": event.get("silenceMs", ""),
                        "peak": event.get("peak", ""),
                        "text": event.get("text", ""),
                    }
                )
            elif name == "manual_x":
                call["manual_x"] = True
            elif name == "advisor_positive":
                call["advisor_positive"] = True
            elif name == "auto_x":
                call["auto_x"] = True
            elif name == "auto_positive_skipped_manual_x":
                call["advisor_positive"] = True
                call["manual_x"] = True
            elif name == "customer_archived":
                call["archive_id"] = event.get("archiveId", "")
                call["operator_positive"] = event.get("operatorPositive", "")
    return calls


def decision_label(decision: str) -> str:
    return {
        "positive": "позитив",
        "manual": "ручной режим",
        "empty": "не распознано",
        "recorded": "только запись",
        "error": "ошибка",
    }.get(decision or "", decision or "нет решения")


def detect_issue(row: dict) -> str:
    decision = row.get("decision", "")
    reason = row.get("reason", "")
    text = (row.get("text") or "").strip()
    vad_reason = row.get("vad_reason", "")
    peak = int(float(row.get("vad_peak_rms") or 0))
    speech = int(float(row.get("vad_speech_ms") or 0))
    engine = row.get("engine") or row.get("model") or ""
    if decision == "empty" and vad_reason == "start_timeout":
        return "не дождались первой фразы: возможно, слух стартовал поздно"
    if decision == "empty" and peak == 0:
        return "канал не дал звука"
    if decision == "empty" and peak >= 80 and speech >= 500:
        if "sherpa-stream" in engine:
            return "звук есть, но streaming ASR вернул пустой текст"
        return "звук есть, но распознавание вернуло пустой текст"
    if decision == "manual" and len(text) <= 2 and peak >= 80:
        return "распознало обрывок вместо фразы"
    if decision == "positive" and "дякую" in reason:
        return "старый риск: позитив сработал по слишком широкому «дякую»"
    if decision == "positive" and not text:
        return "позитив без текста, надо проверить"
    if decision == "manual" and "negative_or_problem" in reason:
        return "правильно ушло оператору из-за возможной жалобы"
    if decision == "manual" and "positive_with_problem_tail" in reason:
        return "правильно ушло оператору: позитив с «но/кроме»"
    if decision == "positive":
        return "сработало как позитив"
    return "ручная проверка"


def main() -> int:
    history = load_history()
    events = load_events()
    labels = load_labels()
    event_calls = build_event_calls(events)
    recent = history[-25:]
    decisions = Counter(row.get("decision", "") for row in recent)
    engines = Counter(row.get("engine") or row.get("model") or "unknown" for row in recent)
    issues = Counter(detect_issue(row) for row in recent)
    manual_x_by_num = defaultdict(int)
    for event in events:
        if event.get("event") == "manual_x":
            manual_x_by_num[event.get("num", "")] += 1
    recent_calls = event_calls[-25:]
    operator_positive_calls = [call for call in recent_calls if call.get("manual_x") or call.get("operator_positive") == "1"]
    system_positive_calls = [call for call in recent_calls if call.get("decision") == "positive" or call.get("advisor_positive") or call.get("auto_x")]
    caught_operator_positive = [
        call
        for call in operator_positive_calls
        if call.get("decision") == "positive" or call.get("advisor_positive") or call.get("auto_x")
    ]

    lines = [
        "=== Анализ обзвона RollHouse ===",
        f"Всего customer-записей: {len(history)}",
        f"В последнем срезе: {len(recent)}",
        f"Архивных меток labels.tsv: {len(labels)}",
        "",
        "Метрика по последним звонкам из call_events.log:",
        f"- звонков в срезе: {len(recent_calls)}",
        f"- оператор пометил позитивом через X: {len(operator_positive_calls)}",
        f"- система/советник поймал positive: {len(system_positive_calls)}",
        f"- поймано из операторских positive: {len(caught_operator_positive)}/{len(operator_positive_calls)}",
        "",
        "Решения:",
    ]
    for key, count in decisions.most_common():
        lines.append(f"- {decision_label(key)}: {count}")
    lines.extend(["", "Движки:"])
    for key, count in engines.most_common():
        lines.append(f"- {key}: {count}")
    lines.extend(["", "Что видно по проблемам:"])
    for key, count in issues.most_common():
        lines.append(f"- {key}: {count}")
    lines.extend(["", "Последние звонки:"])
    for call in recent_calls[-12:]:
        text = (call.get("text") or "").replace("\n", " ").strip()
        if len(text) > 70:
            text = text[:67] + "..."
        flags = []
        if call.get("manual_x"):
            flags.append("X вручную")
        if call.get("advisor_positive"):
            flags.append("advisor+")
        if call.get("auto_x"):
            flags.append("auto-X")
        flag_text = ", ".join(flags) if flags else "без X"
        lines.append(
            f"- {call.get('listen_done_ts') or call.get('accept_ts')}: {call.get('num')} idx={call.get('idx')}; "
            f"{decision_label(call.get('decision', ''))}; peak={call.get('peak', '')}; total={call.get('totalMs', '')}ms; "
            f"{flag_text}; «{text}»"
        )
    lines.extend(["", "Последние customer-записи ASR:"])
    for row in recent[-12:]:
        ts = row.get("history_ts", "")
        decision = decision_label(row.get("decision", ""))
        issue = detect_issue(row)
        peak = row.get("vad_peak_rms", "")
        speech = row.get("vad_speech_ms", "")
        asr = row.get("asr_decode_ms", "")
        engine = row.get("engine") or row.get("model") or ""
        text = (row.get("text") or "").replace("\n", " ").strip()
        if len(text) > 70:
            text = text[:67] + "..."
        lines.append(f"- {ts}: {decision}; peak={peak}; speech={speech}ms; asr={asr}; {issue}; {engine}; «{text}»")
    lines.extend(["", "Ручной X по номерам:"])
    if manual_x_by_num:
        for num, count in sorted(manual_x_by_num.items(), key=lambda item: item[1], reverse=True)[:12]:
            lines.append(f"- {num}: {count}")
    else:
        lines.append("- нет данных")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
