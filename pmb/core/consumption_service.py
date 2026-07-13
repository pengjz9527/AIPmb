from pmb.core.loader import loader
from pmb.utils.search import fuzzy_match, apply_pagination
from pmb.utils.date_utils import parse_date_start, parse_date_end, date_in_range, amount_in_range
from collections import defaultdict

CONSUMPTION_SEARCH_FIELDS = ["商户名称", "消费细分子类", "支付渠道", "交易摘要", "交易分类"]


def list_consumption(
    keyword: str = "",
    subcategory: str = "",
    category: str = "",
    channel: str = "",
    date_from: str = "",
    date_to: str = "",
    amount_min: float | None = None,
    amount_max: float | None = None,
    limit: int = 20,
    offset: int = 0,
    user_name: str = "",
) -> tuple[list[dict], int]:
    """列出消费记录"""
    results = []
    for row in loader.load_credit_transactions():
        if user_name and str(row.get("持卡人姓名", "")).strip() != user_name:
            continue
        d = str(row.get("交易日期", ""))
        if not date_in_range(d, date_from, date_to):
            continue
        if subcategory and subcategory not in str(row.get("消费细分子类", "")):
            continue
        if category and category not in str(row.get("交易分类", "")):
            continue
        if channel and channel not in str(row.get("支付渠道", "")):
            continue
        amt = _safe_float(row.get("交易金额", 0))
        if not amount_in_range(amt, amount_min, amount_max):
            continue
        if not fuzzy_match(row, keyword, CONSUMPTION_SEARCH_FIELDS):
            continue
        results.append({
            "序号": row.get("序号"),
            "交易日期": row.get("交易日期"),
            "收支方向": row.get("收支方向"),
            "交易金额": amt,
            "消费细分子类": row.get("消费细分子类", ""),
            "交易分类": row.get("交易分类", ""),
            "商户名称": row.get("商户名称", ""),
            "支付渠道": row.get("支付渠道", ""),
            "卡号": row.get("卡号", ""),
            "交易摘要": row.get("交易摘要", ""),
            "_raw": row,
        })

    # 按日期降序
    results.sort(key=lambda x: str(x.get("交易日期", "")), reverse=True)
    paginated, total = apply_pagination(results, offset, limit)
    return paginated, total


def get_consumption(seq_no: int, user_name: str = "") -> dict | None:
    """按序号查询消费记录详情"""
    for row in loader.load_credit_transactions():
        if user_name and str(row.get("持卡人姓名", "")).strip() != user_name:
            continue
        if _safe_int(row.get("序号")) == seq_no:
            return {
                "序号": row.get("序号"),
                "账单月份": row.get("账单月份"),
                "持卡人姓名": row.get("持卡人姓名"),
                "卡号": row.get("卡号"),
                "交易日期": row.get("交易日期"),
                "记账日期": row.get("记账日期"),
                "交易分类": row.get("交易分类"),
                "收支方向": row.get("收支方向"),
                "交易摘要": row.get("交易摘要"),
                "支付渠道": row.get("支付渠道"),
                "商户名称": row.get("商户名称"),
                "消费细分子类": row.get("消费细分子类"),
                "交易金额": row.get("交易金额"),
                "交易地金额": row.get("交易地金额"),
                "币种": row.get("币种"),
            }
    return None


def get_consumption_stats(
    group_by: str = "subcategory",
    date_from: str = "",
    date_to: str = "",
    top: int = 10,
    user_name: str = "",
) -> list[dict]:
    """消费统计分析"""
    groups = defaultdict(lambda: {"count": 0, "total": 0.0})

    for row in loader.load_credit_transactions():
        if user_name and str(row.get("持卡人姓名", "")).strip() != user_name:
            continue
        d = str(row.get("交易日期", ""))
        if not date_in_range(d, date_from, date_to):
            continue

        direc = str(row.get("收支方向", ""))
        amt = _safe_float(row.get("交易金额", 0))

        # 只统计支出
        if direc != "支出":
            continue

        if group_by == "subcategory":
            key = str(row.get("消费细分子类", "") or "") or "未分类"
        elif group_by == "category":
            key = str(row.get("交易分类", "") or "") or "未知"
        elif group_by == "channel":
            key = str(row.get("支付渠道", "") or "") or "未知"
        elif group_by == "merchant":
            key = str(row.get("商户名称", "") or "") or "未知"
        elif group_by == "month":
            key = d[:7] if len(d) >= 7 else d
        elif group_by == "year":
            key = d[:4] if len(d) >= 4 else d
        else:
            key = "全部"

        groups[key]["count"] += 1
        groups[key]["total"] += amt

    # 按总金额降序
    sorted_groups = sorted(groups.items(), key=lambda x: x[1]["total"], reverse=True)
    if top > 0:
        sorted_groups = sorted_groups[:top]

    stats = []
    for name, g in sorted_groups:
        stats.append({
            "name": name,
            "count": g["count"],
            "total": round(g["total"], 2),
            "avg": round(g["total"] / g["count"], 2) if g["count"] > 0 else 0,
        })

    return stats


LIST_COLUMNS = ["序号", "交易日期", "收支方向", "交易金额", "消费细分子类", "交易分类", "商户名称", "支付渠道", "卡号"]
LIST_LABELS = ["序号", "交易日期", "收支方向", "交易金额", "消费子类", "交易分类", "商户名称", "支付渠道", "卡号"]

DETAIL_COLUMNS = [
    "序号", "账单月份", "持卡人姓名", "卡号", "交易日期", "记账日期",
    "交易分类", "收支方向", "交易摘要", "支付渠道", "商户名称", "消费细分子类",
    "交易金额", "交易地金额", "币种",
]


def _safe_float(v) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def _safe_int(v) -> int:
    try:
        return int(v)
    except (TypeError, ValueError):
        return 0
