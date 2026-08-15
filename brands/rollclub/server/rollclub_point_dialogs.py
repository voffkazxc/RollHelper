"""RollClub-specific dialogs shown while assigning a delivery point."""


def _read_pattern_value(control):
    for pattern_name in ("GetValuePattern", "GetLegacyIAccessiblePattern"):
        try:
            pattern = getattr(control, pattern_name)()
            value = getattr(pattern, "Value", "")
            if value:
                return str(value)
        except Exception:
            pass
    return ""


def dialog_text(control, max_depth=4, max_nodes=120):
    parts = []
    pending = [(control, 0)]
    visited = 0

    while pending and visited < max_nodes:
        current, depth = pending.pop(0)
        visited += 1

        try:
            name = str(current.Name or "").strip()
        except Exception:
            name = ""
        value = _read_pattern_value(current).strip()

        if name:
            parts.append(name)
        if value and value != name:
            parts.append(value)

        if depth >= max_depth:
            continue
        try:
            pending.extend((child, depth + 1) for child in current.GetChildren())
        except Exception:
            pass

    return " ".join(parts)


def is_known_find_point_dialog(control):
    text = dialog_text(control).lower().replace("ё", "е")
    title = ""
    try:
        title = str(control.Name or "").strip().lower().replace("ё", "е")
    except Exception:
        pass

    if title in {
        "сумма заказа",
        "внимание",
        "предупреждение",
        "увага",
        "попередження",
    }:
        return True

    has_price = "цен" in text or "цін" in text
    has_location = any(
        marker in text
        for marker in (
            "город",
            "міст",
            "населен",
            "обратите внимание",
            "зверніть увагу",
            "другие цены",
            "інші ціни",
        )
    )
    return has_price and has_location

