from pmb.core.loader import loader
from pmb.utils.search import fuzzy_match, apply_pagination
from pmb.utils.date_utils import parse_date_start, parse_date_end, date_in_range, amount_in_range
from collections import defaultdict

TX_SEARCH_FIELDS_CREDIT = ["交易摘要", "商户名称", "支付渠道", "消费细分子类", "交易分类"]
TX_SEARCH_FIELDS_DEBIT = ["交易大类", "交易方式/渠道", "对手方名称", "来源账号"]


def _merge_transactions(source: str, keyword: str, direction: str,
                        category: str, account: str,
                        date_from: str, date_to: str,
                        amount_min: float | None, amount_max: float | None,
                        user_name: str = "") -> list[dict]:
    """合并信用卡和借记卡交易，返回统一的 dict 列表"""
    results = []

    # 信用卡
    if source in ("all", "credit"):
        for row in loader.load_credit_transactions():
            if user_name and str(row.get("持卡人姓名", "")).strip() != user_name:
                continue
            d = str(row.get("交易日期", ""))
            if not date_in_range(d, date_from, date_to):
                continue
            direc = str(row.get("收支方向", ""))
            if direction and direction == "income" and direc != "收入":
                continue
            if direction and direction == "expense" and direc != "支出":
                continue
            amt = _safe_float(row.get("交易金额", 0))
            if not amount_in_range(amt, amount_min, amount_max):
                continue
            if account and account not in str(row.get("卡号", "")):
                continue
            if category and category not in str(row.get("交易分类", "")) and category not in str(row.get("消费细分子类", "")):
                continue
            if not fuzzy_match(row, keyword, TX_SEARCH_FIELDS_CREDIT):
                continue
            # 统一格式
            results.append({
                "序号": row.get("序号"),
                "来源": "信用卡",
                "交易日期": row.get("交易日期"),
                "收支方向": direc,
                "交易金额": amt,
                "交易分类": row.get("交易分类", ""),
                "消费细分子类": row.get("消费细分子类", ""),
                "商户/对手方": row.get("商户名称", ""),
                "支付渠道": row.get("支付渠道", ""),
                "账号/卡号": row.get("卡号", ""),
                "交易摘要": row.get("交易摘要", ""),
                "_raw": row,
                "_source": "credit",
            })

    # 借记卡
    if source in ("all", "debit"):
        for row in loader.load_debit_transactions():
            if user_name and str(row.get("用户姓名", "")).strip() != user_name:
                continue
            d = str(row.get("记账日期", ""))
            if not date_in_range(d, date_from, date_to):
                continue
            direc = str(row.get("收支方向", ""))
            if direction and direction == "income" and direc != "收入":
                continue
            if direction and direction == "expense" and direc != "支出":
                continue
            amt = _safe_float(row.get("交易金额(元)", 0))
            if not amount_in_range(amt, amount_min, amount_max):
                continue
            if account and account not in str(row.get("来源账号", "")):
                continue
            if category and category not in str(row.get("交易大类", "")):
                continue
            if not fuzzy_match(row, keyword, TX_SEARCH_FIELDS_DEBIT):
                continue
            results.append({
                "序号": row.get("序号"),
                "来源": "借记卡",
                "交易日期": row.get("记账日期"),
                "收支方向": direc,
                "交易金额": amt,
                "交易分类": row.get("交易大类", ""),
                "消费细分子类": "",
                "商户/对手方": row.get("对手方名称", ""),
                "支付渠道": row.get("交易方式/渠道", ""),
                "账号/卡号": row.get("来源账号", ""),
                "交易摘要": "",
                "_raw": row,
                "_source": "debit",
            })

    # 按日期降序排列
    results.sort(key=lambda x: str(x.get("交易日期", "")), reverse=True)
    return results


def list_transactions(
    keyword: str = "",
    source: str = "all",
    direction: str = "",
    category: str = "",
    date_from: str = "",
    date_to: str = "",
    amount_min: float | None = None,
    amount_max: float | None = None,
    account: str = "",
    limit: int = 20,
    offset: int = 0,
    user_name: str = "",
) -> tuple[list[dict], int]:
    df = parse_date_start(date_from) if date_from else None
    dt = parse_date_end(date_to) if date_to else None
    results = _merge_transactions(
        source, keyword, direction, category, account,
        df or "", dt or "", amount_min, amount_max,
        user_name,
    )
    paginated, total = apply_pagination(results, offset, limit)
    return paginated, total


def get_transaction(seq_no: int, source: str = "credit", user_name: str = "") -> dict | None:
    if source == "credit":
        for row in loader.load_credit_transactions():
            if user_name and str(row.get("持卡人姓名", "")).strip() != user_name:
                continue
            if _safe_int(row.get("序号")) == seq_no:
                return {
                    "序号": row.get("序号"),
                    "来源": "信用卡",
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
    elif source == "debit":
        for row in loader.load_debit_transactions():
            if user_name and str(row.get("用户姓名", "")).strip() != user_name:
                continue
            if _safe_int(row.get("序号")) == seq_no:
                return {
                    "序号": row.get("序号"),
                    "来源": "借记卡",
                    "记账日期": row.get("记账日期"),
                    "收支方向": row.get("收支方向"),
                    "交易金额(元)": row.get("交易金额(元)"),
                    "联机余额(元)": row.get("联机余额(元)"),
                    "交易大类": row.get("交易大类"),
                    "交易方式/渠道": row.get("交易方式/渠道"),
                    "对手方名称": row.get("对手方名称"),
                    "对手方账号/卡号": row.get("对手方账号/卡号"),
                    "来源账号": row.get("来源账号"),
                    "开户行": row.get("开户行"),
                    "币种": row.get("币种"),
                }
    return None


def get_transaction_summary(
    source: str = "all",
    date_from: str = "",
    date_to: str = "",
    group_by: str = "month",
    user_name: str = "",
) -> list[dict]:
    df = parse_date_start(date_from) if date_from else None
    dt = parse_date_end(date_to) if date_to else None
    results = _merge_transactions(
        source, "", "", "", "", df or "", dt or "", None, None,
        user_name,
    )

    groups = defaultdict(lambda: {"count": 0, "total": 0.0})
    for row in results:
        d = str(row.get("交易日期", ""))
        if group_by == "month":
            key = d[:7] if len(d) >= 7 else d  # YYYY-MM
        elif group_by == "year":
            key = d[:4] if len(d) >= 4 else d
        elif group_by == "category":
            key = str(row.get("交易分类", "未知"))
        elif group_by == "subcategory":
            key = str(row.get("消费细分子类", "")) or str(row.get("交易分类", "未知"))
        else:
            key = "全部"

        amt = row.get("交易金额", 0)
        direc = str(row.get("收支方向", ""))
        if direc == "支出":
            groups[key]["total"] += float(amt)
            groups[key]["count"] += 1
        elif direc == "收入":
            groups[key]["count"] += 1
            # 收入单独统计（在支出统计中不加）

    # 构建统计结果
    stats = []
    for name in sorted(groups.keys(), reverse=True):
        g = groups[name]
        stats.append({
            "name": name,
            "count": g["count"],
            "total": round(g["total"], 2),
            "avg": round(g["total"] / g["count"], 2) if g["count"] > 0 else 0,
        })

    return stats


# 列表视图列
LIST_COLUMNS = ["序号", "来源", "交易日期", "收支方向", "交易金额", "交易分类", "消费细分子类", "商户/对手方", "支付渠道", "账号/卡号"]
LIST_LABELS = ["序号", "来源", "交易日期", "收支方向", "交易金额", "交易分类", "消费子类", "商户/对手方", "支付渠道", "账号/卡号"]

CREDIT_DETAIL_COLUMNS = [
    "序号", "来源", "账单月份", "持卡人姓名", "卡号", "交易日期", "记账日期",
    "交易分类", "收支方向", "交易摘要", "支付渠道", "商户名称", "消费细分子类",
    "交易金额", "交易地金额", "币种",
]
DEBIT_DETAIL_COLUMNS = [
    "序号", "来源", "记账日期", "收支方向", "交易金额(元)", "联机余额(元)",
    "交易大类", "交易方式/渠道", "对手方名称", "对手方账号/卡号", "来源账号", "开户行", "币种",
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
