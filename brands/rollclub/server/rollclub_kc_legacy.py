"""RollClub duty reader preserved from the pre-launcher implementation."""


def _read_cell(control):
    """Read a delivery-grid cell without depending on the mutable bridge module."""
    name = ""
    try:
        name = (control.Name or "").strip()
    except Exception:
        pass

    column = name
    for sep in (" row ", " рядок ", " строка "):
        if sep in column.lower():
            idx = column.lower().find(sep)
            column = column[:idx].strip()
            break

    def read_value(candidate):
        for getter in (
            lambda item: item.GetValuePattern().Value,
            lambda item: item.GetLegacyIAccessiblePattern().Value,
        ):
            try:
                value = getter(candidate)
                if value and str(value).strip():
                    return str(value).strip()
            except Exception:
                pass
        return ""

    value = read_value(control)
    if not value:
        try:
            for child in control.GetChildren():
                value = read_value(child)
                if value:
                    break
        except Exception:
            pass
    return column, value


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
                cname = (child.Name or "").strip()
                if cname in ("Панель данных", "Панель даних", "Data Panel") or ("Панель" in cname and ("дан" in cname or "данн" in cname)):
                    data_panel = child
                    break
        except Exception:
            pass
        if data_panel is None:
            return {"ok": False, "error": "Панель данных не знайдено"}
        bridge._kc_panel_cache = data_panel

    grid_ready_at = time.perf_counter()
    needed_columns = ("№", "Комментарий", "Коментар", "Оператор", "Статус")
    rows = []
    take = None
    busy_count = 0
    callback_count = 0
    no_post_count = 0
    cancelled_count = 0
    cell_error_count = 0
    filter_x = 0
    filter_y = 0
    first_row_x = 0
    first_row_y = 0

    try:
        children = data_panel.GetChildren()
    except Exception as error:
        return {"ok": False, "error": "get data_panel children: %s" % error}

    for row in children:
        try:
            row_name = (row.Name or "").strip()
            row_name_lower = row_name.lower()
            if "фильтр" in row_name_lower or "фільтр" in row_name_lower or "filter" in row_name_lower:
                try:
                    for cell in row.GetChildren():
                        cname = (cell.Name or "").lower()
                        if cname.startswith("№") or " №" in cname or "№ " in cname:
                            crect = getattr(cell, "BoundingRectangle", None)
                            if crect and crect.width() > 10 and crect.height() > 5:
                                filter_x = int(crect.xcenter())
                                filter_y = int(crect.ycenter())
                                break
                except Exception:
                    pass
                continue

            if not (row_name.startswith("Строка") or row_name.startswith("Рядок") or row_name.startswith("Row")):
                continue

            values = {}
            cell_no_rect = None
            try:
                for cell in row.GetChildren():
                    name = cell.Name or ""
                    column = name
                    for sep in (" row ", " рядок ", " строка "):
                        if sep in column.lower():
                            idx = column.lower().find(sep)
                            column = column[:idx].strip()
                            break
                    if column == "№":
                        crect = getattr(cell, "BoundingRectangle", None)
                        if crect and crect.width() > 10 and crect.height() > 5:
                            cell_no_rect = crect
                    if column not in needed_columns:
                        continue
                    _, value = _read_cell(cell)
                    values[column] = value
            except Exception:
                cell_error_count += 1

            if first_row_x == 0:
                if cell_no_rect:
                    first_row_x = int(cell_no_rect.xcenter())
                    first_row_y = int(cell_no_rect.ycenter())
                    if filter_x == 0:
                        filter_x = first_row_x
                        filter_y = int(cell_no_rect.top - max(8, cell_no_rect.height() // 2))
                else:
                    try:
                        rrect = getattr(row, "BoundingRectangle", None)
                        if rrect and rrect.width() > 20 and rrect.height() > 8:
                            first_row_x = int(rrect.left + min(60, rrect.width() // 4))
                            first_row_y = int(rrect.ycenter())
                            if filter_x == 0:
                                filter_x = first_row_x
                                filter_y = int(rrect.top - max(8, rrect.height() // 2))
                    except Exception:
                        pass

            delivery = {
                "no": values.get("№", ""),
                "comment": values.get("Комментарий") or values.get("Коментар") or "",
                "operator": values.get("Оператор", ""),
                "status": values.get("Статус", ""),
            }
            rows.append(delivery)

            status = (delivery["status"] or "").lower()
            if "тмен" in status or "касов" in status or "ancel" in status:
                cancelled_count += 1
            elif (delivery["operator"] or "").strip():
                busy_count += 1
            else:
                comment = delivery["comment"] or ""
                comment_lower = comment.lower()
                if "пост" not in comment_lower and "post" not in comment_lower:
                    no_post_count += 1
                elif "передзвонити" in comment_lower or "перезвонить" in comment_lower:
                    callback_count += 1
                else:
                    take = delivery
                    if cell_no_rect:
                        take["click_x"] = int(cell_no_rect.xcenter())
                        take["click_y"] = int(cell_no_rect.ycenter())
                    elif first_row_x > 0:
                        take["click_x"] = first_row_x
                        take["click_y"] = first_row_y
                    break
        except Exception:
            continue

    reason = ""
    if take is None:
        if rows and not any(row["no"] for row in rows):
            reason = "рядки знайдені, але значення клітинок не прочитані"
        else:
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
        "KC-LIST LEGACY timing s: cached=%d find=%.2f read_rows=%.2f TOTAL=%.2f rows=%d cell_errors=%d"
        % (
            cached,
            grid_ready_at - started_at,
            time.perf_counter() - grid_ready_at,
            time.perf_counter() - started_at,
            len(rows),
            cell_error_count,
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
        "filter_x": filter_x,
        "filter_y": filter_y,
        "first_row_x": first_row_x,
        "first_row_y": first_row_y,
    }
