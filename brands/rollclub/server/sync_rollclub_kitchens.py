import argparse
import csv
import datetime as dt
import io
import os
import re
import shutil
import sys
import urllib.request
from pathlib import Path


SHEET_ID = "1rB6x0pqJo0btI2XFKvM5a_5qVCiVSOfMgV7xUbcQbiU"
SHEET_GID = "832902847"
CSV_URL = f"https://docs.google.com/spreadsheets/d/{SHEET_ID}/export?format=csv&gid={SHEET_GID}"

NAME_ALIASES = {
    "ТРЦ Мегамолл": "Мегамолл",
    "Стрільці": "Лук'янівка",
    "Січових Стрільців": "Лук'янівка",
}

DEFAULT_KML_KEYS = {
    "РЕСТОРАН": "Конституції",
    "НД": "Нові",
    "Приморська": "Приморська",
    "Мудрого": "Мудрого",
    "Антонова": "Антонова",
    "Драгоманова": "Драгоманова",
    "Лук'янівка": "Стрільців",
    "Троєщина": "Лаврухіна",
    "Крива Липа": "Липа",
    "БЦ": "Церква",
    "Фудотека": "Фудотека",
    "ТРЦ Екватор": "Екватор",
    "Мегамолл": "Мегамолл",
}


def root_dir() -> Path:
    return Path(__file__).resolve().parents[1]


def kitchens_paths() -> list[Path]:
    paths: list[Path] = []

    # 1. Environment variable if set by AHK
    env_user_data = os.environ.get("ROLLHELPER_ROLLCLUB_USERDATA")
    if env_user_data:
        p = Path(env_user_data) / "RkKitchens.ini"
        if p not in paths:
            paths.append(p)

    # 2. Local AppData UserData path
    local_app_data = os.environ.get("LOCALAPPDATA")
    if local_app_data:
        user_ini = Path(local_app_data) / "Programs" / "RollHelper" / "UserData" / "rollclub" / "RkKitchens.ini"
        if user_ini not in paths and user_ini.parent.exists():
            paths.append(user_ini)

    # 3. Development workspace brand path
    brand_dev = root_dir() / "RollHelper" / "brands" / "rollclub" / "RkKitchens.ini"
    if brand_dev not in paths:
        paths.append(brand_dev)

    # 4. Package directory if running inside package
    package_ini = root_dir() / "brands" / "rollclub" / "RkKitchens.ini"
    if package_ini not in paths and package_ini.parent.exists():
        paths.append(package_ini)

    return paths


def clean_cell(value: str) -> str:
    return re.sub(r"\s+", " ", (value or "").replace("\ufeff", "")).strip()


def extract_section_and_address(raw_name: str, known_names: set[str]) -> tuple[str, str] | None:
    text = clean_cell(raw_name)
    match = re.match(r"^\[([^\]]+)\]\s*(.*)$", text)
    if match:
        return clean_cell(match.group(1)), clean_cell(match.group(2))

    text_lower = text.lower()
    for needle, canonical in NAME_ALIASES.items():
        if needle.lower() in text_lower:
            return canonical, text

    for known_name in sorted(known_names, key=len, reverse=True):
        if known_name.lower() in text_lower:
            return known_name, text

    return None


def parse_existing_kml_keys(path: Path) -> dict[str, str]:
    keys: dict[str, str] = {}
    if not path.exists():
        return keys

    current = ""
    for line in path.read_text(encoding="utf-8-sig", errors="replace").splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1].strip()
            continue
        if current and line.startswith("KmlKey="):
            keys[current] = line.split("=", 1)[1].strip()
    return keys


def parse_sheet_rows(text: str, existing_kml: dict[str, str]) -> list[dict[str, str]]:
    rows = list(csv.reader(io.StringIO(text)))
    if not rows:
        return []

    header = [clean_cell(c).lower() for c in rows[0]]
    col_map = {}
    hours = {}
    for i, h in enumerate(header):
        hour = re.fullmatch(r"([01]?\d|2[0-3])(?::([0-5]\d))?", h)
        if hour:
            hours.setdefault(f"{int(hour[1]):02d}:{hour[2] or '00'}", []).append(i)
        elif re.search(r"місто|город|city", h):
            col_map["name"] = i
        elif re.search(r"адмін|admin", h):
            col_map["admin"] = i
        elif re.search(r"примітк|примечан|note", h):
            col_map["remark"] = i
        elif re.search(r"(?:стоп|stop).*?(?:цех|workshop)|workshop", h):
            col_map["workshop"] = i
        elif re.search(r"стоп|stop", h):
            col_map["stop"] = i
        elif re.search(r"центр|center", h):
            col_map["center"] = i
        elif re.search(r"\bсв\b|самовивіз|самовывоз|pickup", h):
            col_map["pickup"] = i
        elif re.search(r"дальн|far", h):
            col_map["far"] = i
        elif re.search(r"терминал|термінал|terminal", h):
            col_map["terminal"] = i

    required = {"name", "center", "pickup", "far", "stop", "workshop"}
    if missing := required - col_map.keys():
        raise ValueError(f"Kitchen sheet headers missing: {', '.join(sorted(missing))}")

    updated = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d%H%M%S")

    kitchens: list[dict[str, str]] = []
    current_city = ""
    known_names = set(existing_kml.keys()) | set(DEFAULT_KML_KEYS.keys())

    for row in rows[1:]:
        row = list(row) + [""] * len(header)
        cell = lambda key: clean_cell(row[col_map[key]]) if key in col_map else ""
        first = cell("name")
        if not first:
            continue

        other_cells = [clean_cell(c) for i, c in enumerate(row) if i != col_map["name"] and clean_cell(c)]
        if not other_cells and not first.startswith("[") and not any(alias.lower() in first.lower() for alias in NAME_ALIASES):
            current_city = first.title()
            continue

        parsed = extract_section_and_address(first, known_names)
        if parsed is None:
            current_city = first.title()
            continue

        name, address_from_first = parsed
        name = NAME_ALIASES.get(name, name)
        for needle, canon in NAME_ALIASES.items():
            if needle.lower() in name.lower():
                name = canon
                break

        admin = cell("admin")
        note = cell("remark")
        rem_parts = [p for p in (admin, note) if p]
        remark = " | ".join(rem_parts)

        center = cell("center") or "Стандарт"
        pickup = cell("pickup") or "Стандарт"
        far = cell("far") or "Стандарт"
        stop = clean_stop(cell("stop"))
        terminal = cell("terminal")
        available, limited = [], []
        for time, columns in sorted(hours.items()):
            states = [slot_state(row[i]) for i in columns]
            # Conflicting/unknown duplicates cannot advertise capacity.
            if all(s == "available" for s in states):
                available.append(time)
            elif all(s in ("available", "limited") for s in states):
                limited.append(time)

        kml = existing_kml.get(name) or DEFAULT_KML_KEYS.get(name, "")

        kitchens.append(
            {
                "Name": name,
                "City": current_city,
                "Address": address_from_first,
                "KmlKey": kml,
                "Remark": remark,
                "Center": center,
                "Pickup": pickup,
                "FarZone": far,
                "StopList": stop,
                "Terminal": terminal,
                "StopWorkshop": clean_stop(cell("workshop")),
                "PreorderAvailable": ", ".join(available),
                "PreorderLimited": ", ".join(limited),
                "SlotsLoaded": "1" if hours else "0",
                "DataVersion": "2",
                "UpdatedUTC": updated,
            }
        )

    return kitchens


def clean_stop(value: str) -> str:
    if value.casefold() in ("стандарт", "standard", "нет", "немає", "нема", "-", "—"):
        return ""
    return value


def slot_state(value: str) -> str:
    markers = set(value) & set("🟢🟡🔴⚪⚫🔘🟠")
    if markers == {"🟢"}:
        return "available"
    if markers == {"🟡"}:
        return "limited"
    return "unavailable"


INI_FIELDS = ("City", "Address", "KmlKey", "Remark", "Center", "Pickup", "FarZone",
              "StopList", "Terminal", "StopWorkshop", "PreorderAvailable", "PreorderLimited",
              "SlotsLoaded", "DataVersion", "UpdatedUTC")


def write_ini_file(path: Path, kitchens: list[dict[str, str]]) -> None:
    now = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines = [
        "; ===========================================================",
        "; База кухонь Rollclub",
        "; Джерело: Google Sheet",
        f"; LastSync: {now}",
        "; Status: ok | slow | nonstandard | stopped",
        "; Редагування — кнопка Кухні у пульті або Google Sheet",
        "; ===========================================================",
        "",
    ]

    for kitchen in kitchens:
        lines.append(f"[{kitchen['Name']}]")
        for key in INI_FIELDS:
            value = kitchen.get(key, "")
            if key == "KmlKey" and not value:
                continue
            lines.append(f"{key}={value}")
        lines.append("")

    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        backup = path.with_suffix(path.suffix + ".bak_sheet")
        shutil.copy2(path, backup)
    path.write_text("\n".join(lines), encoding="utf-8-sig")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    target_paths = kitchens_paths()
    existing_kml = dict(DEFAULT_KML_KEYS)
    for p in target_paths:
        backup_path = p.with_suffix(p.suffix + ".bak_sheet")
        existing_kml.update(parse_existing_kml_keys(backup_path))
        existing_kml.update(parse_existing_kml_keys(p))

    with urllib.request.urlopen(CSV_URL, timeout=15) as response:
        text = response.read().decode("utf-8-sig")

    kitchens = parse_sheet_rows(text, existing_kml)
    if not kitchens:
        raise RuntimeError("Google Sheet parsed successfully, but no kitchens were found")

    written_paths = []
    for p in target_paths:
        write_ini_file(p, kitchens)
        written_paths.append(str(p))

    if not args.quiet:
        print(f"OK: synced {len(kitchens)} kitchens -> {', '.join(written_paths)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
