"""用户管理服务"""
from pmb.core.loader import loader
from pmb.utils.search import apply_pagination


def _load_account_rows() -> list[dict]:
    """加载有效账户数据"""
    rows = loader.load_accounts()
    result = []
    for row in rows:
        seq = row.get("序号")
        try:
            int(seq)
            result.append(row)
        except (TypeError, ValueError):
            continue
    return result


def list_users(keyword: str = "", limit: int = 20, offset: int = 0) -> tuple[list[dict], int]:
    """列出所有用户，从账户数据中按姓名去重聚合"""
    rows = _load_account_rows()
    # 按姓名聚合
    user_map: dict[str, dict] = {}
    for row in rows:
        name = str(row.get("用户姓名", "")).strip()
        if not name:
            continue
        if keyword and keyword not in name:
            continue
        if name not in user_map:
            user_map[name] = {
                "name": name,
                "account_count": 0,
                "debit_count": 0,
                "credit_count": 0,
                "total_balance": 0.0,
                "total_credit_limit": 0.0,
            }
        info = user_map[name]
        info["account_count"] += 1
        at = str(row.get("账户类型", ""))
        if "借记" in at:
            info["debit_count"] += 1
            try:
                info["total_balance"] += float(row.get("最新余额(元)", 0) or 0)
            except (ValueError, TypeError):
                pass
        elif "信用" in at:
            info["credit_count"] += 1
            try:
                info["total_credit_limit"] += float(row.get("信用额度(元)", 0) or 0)
            except (ValueError, TypeError):
                pass

    user_list = list(user_map.values())
    user_list.sort(key=lambda x: x["total_balance"], reverse=True)
    paginated, total = apply_pagination(user_list, offset, limit)
    return paginated, total


def get_user_detail(name: str) -> dict | None:
    """获取用户详情：账户、交易统计、消费摘要"""
    rows = _load_account_rows()
    user_accounts = [r for r in rows if str(r.get("用户姓名", "")).strip() == name]
    if not user_accounts:
        return None

    # 账户信息
    accounts = []
    total_balance = 0.0
    total_credit = 0.0
    for acc in user_accounts:
        at = str(acc.get("账户类型", ""))
        try:
            bal = float(acc.get("最新余额(元)", 0) or 0)
        except (ValueError, TypeError):
            bal = 0.0
        try:
            limit_val = float(acc.get("信用额度(元)", 0) or 0)
        except (ValueError, TypeError):
            limit_val = 0.0
        if "借记" in at:
            total_balance += bal
        elif "信用" in at:
            total_credit += limit_val
        accounts.append({
            "账户类型": acc.get("账户类型", ""),
            "卡种/产品": acc.get("卡种/产品", ""),
            "账号/卡号": acc.get("账号/卡号", ""),
            "最新余额(元)": acc.get("最新余额(元)", ""),
            "信用额度(元)": acc.get("信用额度(元)", ""),
            "本期应还金额(元)": acc.get("本期应还金额(元)", ""),
            "到期还款日": acc.get("到期还款日", ""),
        })

    # 消费统计
    credit_txs = _get_user_credit_tx(name)
    stats = _compute_consumption_stats(credit_txs)

    return {
        "name": name,
        "accounts": accounts,
        "account_count": len(accounts),
        "total_balance": round(total_balance, 2),
        "total_credit_limit": round(total_credit, 2),
        "transaction_count": len(credit_txs),
        "consumption_stats": stats,
    }


def get_user_accounts(name: str) -> list[dict]:
    """获取用户所有账户"""
    rows = _load_account_rows()
    return [r for r in rows if str(r.get("用户姓名", "")).strip() == name]


def get_user_transactions(name: str, limit: int = 20, offset: int = 0) -> tuple[list[dict], int]:
    """获取用户交易记录"""
    credit_txs = _get_user_credit_tx(name)
    results = []
    for tx in credit_txs:
        results.append({
            "序号": tx.get("序号"),
            "交易日期": tx.get("交易日期"),
            "收支方向": tx.get("收支方向"),
            "交易金额": _safe_float(tx.get("交易金额", 0)),
            "交易分类": tx.get("交易分类", ""),
            "消费细分子类": tx.get("消费细分子类", ""),
            "商户名称": tx.get("商户名称", ""),
            "支付渠道": tx.get("支付渠道", ""),
            "交易摘要": tx.get("交易摘要", ""),
        })
    results.sort(key=lambda x: str(x.get("交易日期", "")), reverse=True)
    paginated, total = apply_pagination(results, offset, limit)
    return paginated, total


def get_user_consumption_stats(name: str, group_by: str = "subcategory", top: int = 10) -> list[dict]:
    """获取用户消费统计"""
    credit_txs = _get_user_credit_tx(name)
    return _compute_consumption_stats(credit_txs, group_by, top)


def get_user_summary(name: str) -> dict | None:
    """获取用户汇总信息"""
    detail = get_user_detail(name)
    if detail is None:
        return None
    return {
        "name": detail["name"],
        "account_count": detail["account_count"],
        "total_balance": detail["total_balance"],
        "total_credit_limit": detail["total_credit_limit"],
        "transaction_count": detail["transaction_count"],
        "top_categories": detail["consumption_stats"][:5],
    }


def _get_user_credit_tx(name: str) -> list[dict]:
    """获取用户信用卡交易"""
    return [r for r in loader.load_credit_transactions()
            if str(r.get("持卡人姓名", "")).strip() == name]


def _compute_consumption_stats(transactions: list[dict], group_by: str = "subcategory", top: int = 10) -> list[dict]:
    """计算消费统计"""
    from collections import defaultdict
    groups = defaultdict(lambda: {"count": 0, "total": 0.0})
    for tx in transactions:
        direction = str(tx.get("收支方向", ""))
        if direction != "支出":
            continue
        amt = _safe_float(tx.get("交易金额", 0))
        if group_by == "subcategory":
            key = str(tx.get("消费细分子类", "") or "") or "未分类"
        elif group_by == "category":
            key = str(tx.get("交易分类", "") or "") or "未知"
        elif group_by == "merchant":
            key = str(tx.get("商户名称", "") or "") or "未知"
        elif group_by == "month":
            d = str(tx.get("交易日期", ""))
            key = d[:7] if len(d) >= 7 else d
        else:
            key = "全部"
        groups[key]["count"] += 1
        groups[key]["total"] += amt
    sorted_groups = sorted(groups.items(), key=lambda x: x[1]["total"], reverse=True)
    if top > 0:
        sorted_groups = sorted_groups[:top]
    return [
        {"name": name, "count": g["count"], "total": round(g["total"], 2),
         "avg": round(g["total"] / g["count"], 2) if g["count"] > 0 else 0}
        for name, g in sorted_groups
    ]


def _safe_float(v) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0