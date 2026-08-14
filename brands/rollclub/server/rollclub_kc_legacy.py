"""RollClub duty reader preserved from the pre-launcher implementation."""


def read_kc_list(bridge, brand="rollclub"):
    """Read visible RollClub delivery rows using the original cached UIA flow."""
    import time

    started_at = time.perf_counter()
    grid_ready_at = started_at
    bridge._com_init()
    auto = bridge.auto
    if auto is None:
        return {"ok": False, "error": "uiautomation not installed"}

    data_panel = None
    cached = 0
    try:
        foreground = bridge._get_foreground_win()
        if bridge._find_by_id(foreground, "DeliveryOrderEditControl", max_depth=8) is not None:
            bridge._kc_panel_cache = None
            return {
                "ok": False,
                "error_code": "ACTIVE_ORDER_CARD",
                "error": "Активна карточка заказа, а не список Доставки",
            }
    except Exception:
        pass

    if bridge._kc_panel_cache is not None:
        try:
            bridge._kc_panel_cache.GetChildren()
            data_panel = bridge._kc_panel_cache
            cached = 1
        except Exception:
            bridge._kc_panel_cache = None

    if data_panel is None:
        window = None
        try:
            root = auto.GetRootControl()
            for candidate in root.GetChildren():
                class_name = candidate.ClassName or ""
                if any(
                    blocked in class_name
                    for blocked in (
                        "Chrome_WidgetWin",
                        "MozillaWindowClass",
                        "ApplicationFrameWindow",
                        "EdgeHTML",
                    )
                ):
                    continue
                title = (candidate.Name or "").lower()
                if (
                    "iiko" in title
                    or "syrve" in title
                    or "office" in title
                    or "back" in title
                ):
                    window = candidate
                    break
        except Exception:
            pass
        if window is None:
            return {"ok": False, "error": "Вікно iiko не знайдено"}

        grid = bridge._find_by_id(window, "gridDeliveries", max_depth=12)
        if grid is None:
            return {
                "ok": False,
                "error": "Список Доставки не відкрито (немає gridDeliveries)",
            }
        try:
            for child in grid.GetChildren():
                if (child.Name or "").strip() == "Панель данных":
                    data_panel = child
                    break
        except Exception:
            pass
        if data_panel is None:
            return {"ok": False, "error": "Панель данных не знайдено"}
        bridge._kc_panel_cache = data_panel

    grid_ready_at = time.perf_counter()
    needed_columns = ("№", "Комментарий", "Оператор", "Статус")
    rows = []
    take = None
    busy_count = 0
    callback_count = 0
    no_post_count = 0
    cancelled_count = 0

    try:
        for row in data_panel.GetChildren():
            row_name = (row.Name or "").strip()
            if not row_name.startswith("Строка"):
                continue
            values = {}
            try:
                for cell in row.GetChildren():
                    name = cell.Name or ""
                    column = name.split(" row ")[0].strip() if " row " in name else name
                    if column not in needed_columns:
                        continue
                    _, value = bridge._kc_cell(cell)
                    values[column] = value
            except Exception:
                pass

            delivery = {
                "no": values.get("№", ""),
                "comment": values.get("Комментарий", ""),
                "operator": values.get("Оператор", ""),
                "status": values.get("Статус", ""),
            }
            rows.append(delivery)
            if take is not None:
                continue

            status = delivery["status"] or ""
            if "тмен" in status or "касов" in status:
                cancelled_count += 1
            elif (delivery["operator"] or "").strip():
                busy_count += 1
            else:
                comment = delivery["comment"] or ""
                if "Пост" not in comment:
                    no_post_count += 1
                elif "Передзвонити" in comment or "Перезвонить" in comment:
                    callback_count += 1
                else:
                    take = delivery
                    break
    except Exception as error:
        return {"ok": False, "error": "read rows: %s" % error}

    reason = ""
    if take is None:
        reason = (
            "всього %d: зайнято %d, передзвонити %d, без Пост %d, відмінені %d"
            % (
                len(rows),
                busy_count,
                callback_count,
                no_post_count,
                cancelled_count,
            )
        )

    bridge._log(
        "KC-LIST LEGACY timing s: cached=%d find=%.2f read_rows=%.2f TOTAL=%.2f rows=%d"
        % (
            cached,
            grid_ready_at - started_at,
            time.perf_counter() - grid_ready_at,
            time.perf_counter() - started_at,
            len(rows),
        )
    )
    return {
        "ok": True,
        "count": len(rows),
        "rows": rows,
        "take": take,
        "reason": reason,
        "take_no": (
            int(take["no"])
            if take and str(take["no"]).strip().isdigit()
            else 0
        ),
    }
