def fuzzy_match(record: dict, keyword: str, searchable_fields: list[str]) -> bool:
    """多字段模糊匹配。空格分隔多关键词，AND逻辑。"""
    if not keyword or not keyword.strip():
        return True

    keywords = [kw.lower() for kw in keyword.strip().split() if kw.strip()]
    if not keywords:
        return True

    for kw in keywords:
        found = False
        for field_name in searchable_fields:
            val = record.get(field_name, "")
            if val is None:
                continue
            if kw in str(val).lower():
                found = True
                break
        if not found:
            return False
    return True


def apply_pagination(items: list, offset: int, limit: int) -> tuple[list, int]:
    """分页，返回 (分页后的列表, 总数)"""
    total = len(items)
    return items[offset: offset + limit], total


def filter_by_field(items: list[dict], field_name: str, value: str | None) -> list[dict]:
    """按字段精确匹配过滤"""
    if not value:
        return items
    return [item for item in items if str(item.get(field_name, "")).strip() == value.strip()]


def filter_by_field_contains(items: list[dict], field_name: str, value: str | None) -> list[dict]:
    """按字段包含匹配过滤"""
    if not value:
        return items
    val_lower = value.lower()
    return [
        item for item in items
        if val_lower in str(item.get(field_name, "")).lower()
    ]
