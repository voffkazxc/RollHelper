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
            lambda item: item.GetLegacyIAccessiblePattern().Name,
            lambda item: item.Name,
        ):
            try:
                value = getter(candidate)
                if value and str(value).strip():
                    val_str = str(value).strip()
                    if any(sep in val_str.lower() for sep in (" row ", " рядок ", " строка ")):
                        continue
                    if val_str.lower() == column.lower():
                        continue
                    return val_str
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
            cached_children = bridge._kc_panel_cache.GetChildren()
            if cached_children and len(cached_children) > 0:
                data_panel = bridge._kc_panel_cache
                children = cached_children
                cached = 1
            else:
                bridge._kc_panel_cache = None
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
            grid_children = grid.GetChildren()
            for child in grid_children:
                cname = (child.Name or "").strip().lower()
                if "дан" in cname or "data" in cname or "panel" in cname or "панель" in cname:
                    data_panel = child
                    break
            if data_panel is None:
                for child in grid_children:
                    sub = child.GetChildren()
                    if sub and len(sub) > 0:
                        data_panel = child
                        break
        except Exception:
            pass
        if data_panel is None:
            return {"ok": False, "error": "Панель данных не знайдено"}
        bridge._kc_panel_cache = data_panel
        try:
            children = data_panel.GetChildren()
        except Exception as error:
            bridge._kc_panel_cache = None
            return {"ok": False, "error": "get data_panel children: %s" % error}

    grid_ready_at = time.perf_counter()
    needed_columns = ("№", "Номер", "Комментарий", "Коментар", "Оператор", "Статус")
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

    for row in children:
        try:
            row_name = (row.Name or "").strip()
            row_name_lower = row_name.lower()
            if "фильтр" in row_name_lower or "фільтр" in row_name_lower or "filter" in row_name_lower:
                try:
                    for cell in row.GetChildren():
                        cname = (cell.Name or "").lower()
                        if cname.startswith("№") or " №" in cname or "№ " in cname or "номер" in cname:
                            crect = getattr(cell, "BoundingRectangle", None)
                            if crect and crect.width() > 10 and crect.height() > 5:
                                filter_x = int(crect.xcenter())
                                filter_y = int(crect.ycenter())
                                break
                except Exception:
                    pass
                continue

            if any(skip in row_name_lower for skip in ("заголовок", "header", "колонк", "скролл", "scroll", "прокрут")):
                continue

            values = {}
            cell_no_rect = None
            try:
                cells = row.GetChildren()
            except Exception:
                cells = []

            for cell in cells:
                name = cell.Name or ""
                column = name
                for sep in (" row ", " рядок ", " строка "):
                    if sep in column.lower():
                        idx = column.lower().find(sep)
                        column = column[:idx].strip()
                        break
                if column in ("№", "Номер"):
                    crect = getattr(cell, "BoundingRectangle", None)
                    if crect and crect.width() > 10 and crect.height() > 5:
                        cell_no_rect = crect
                if column not in needed_columns:
                    continue
                _, value = _read_cell(cell)
                values[column] = value

            if not values and not any(k in row_name_lower for k in ("строк", "рядок", "row", "запис")):
                continue

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
                "no": values.get("№") or values.get("Номер") or "",
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
                if "передзвонити" in comment_lower or "перезвонить" in comment_lower:
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

    if len(rows) == 0:
        bridge._kc_panel_cache = None

    reason = ""
    if take is None:
        if rows and not any(row["no"] for row in rows):
            reason = "рядки знайдені, але значення клітинок не прочитані"
        else:
            reason = (
                "всього %d: зайнято %d, передзвонити %d, відмінені %d"
                % (
                    len(rows),
                    busy_count,
                    callback_count,
                    cancelled_count,
                )
            )

    info_str = ""
    if take:
        info_str = "TAKE: №%s (op='%s', st='%s', comm='%s')" % (take.get("no"), take.get("operator"), take.get("status"), take.get("comment"))
    elif rows:
        info_str = "NO_TAKE: first=%s" % (", ".join("№%s[%s]" % (r.get("no"), r.get("operator") or "free") for r in rows[:3]))
    else:
        info_str = "ZERO_ROWS (data_panel children: %d)" % len(children)
        if children:
            child_names = [repr(getattr(c, "Name", None)) for c in children[:5]]
            info_str += " names=[%s]" % (", ".join(child_names))

    bridge._log(
        "KC-LIST LEGACY timing s: cached=%d find=%.2f read_rows=%.2f TOTAL=%.2f rows=%d cell_errors=%d | %s"
        % (
            cached,
            grid_ready_at - started_at,
            time.perf_counter() - grid_ready_at,
            time.perf_counter() - started_at,
            len(rows),
            cell_error_count,
            info_str,
        )
    )
    clean_take_no = 0
    if take and take.get("no"):
        import re
        m = re.search(r"\d+", str(take["no"]))
        if m:
            clean_take_no = int(m.group())

    return {
        "ok": True,
        "count": len(rows),
        "rows": rows,
        "take": take,
        "reason": reason,
        "take_no": clean_take_no,
        "filter_x": filter_x,
        "filter_y": filter_y,
        "first_row_x": first_row_x,
        "first_row_y": first_row_y,
    }
