from pmb.core.loader import loader
from pmb.core.models import Account
from pmb.utils.search import fuzzy_match, apply_pagination

ACCOUNT_SEARCH_FIELDS = ["用户姓名", "账号/卡号", "卡种/产品", "开户行/发卡行", "账户类型"]


def _load_account_rows() -> list[dict]:
    """加载账户数据行，过滤掉汇总行（序号不是数字的行）"""
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


def list_accounts(
    user_name: str = "",
    keyword: str = "",
    account_type: str = "",
    limit: int = 20,
    offset: int = 0,
) -> tuple[list[dict], int]:
    """列出账户信息，支持用户名、关键词和类型过滤"""
    rows = _load_account_rows()
    if user_name:
        rows = [r for r in rows if str(r.get("用户姓名", "")).strip() == user_name]
    results = []
    for row in rows:
        if not fuzzy_match(row, keyword, ACCOUNT_SEARCH_FIELDS):
            continue
        if account_type:
            at = str(row.get("账户类型", ""))
            if account_type == "credit" and "信用" not in at:
                continue
            if account_type == "debit" and "借记" not in at:
                continue
        results.append(row)
    paginated, total = apply_pagination(results, offset, limit)
    return paginated, total


def get_account(account_id: str) -> dict | None:
    """按账号/卡号查询账户详情"""
    rows = _load_account_rows()
    for row in rows:
        num = str(row.get("账号/卡号", ""))
        if account_id in num or num in account_id:
            return row
    return None


def get_account_summary(user_name: str = "") -> list[tuple[str, str]]:
    """获取账户汇总信息"""
    rows = _load_account_rows()
    if user_name:
        rows = [r for r in rows if str(r.get("用户姓名", "")).strip() == user_name]
    total_debit = 0.0
    total_credit_limit = 0.0
    credit_due = ""
    debit_count = 0
    credit_count = 0

    for row in rows:
        at = str(row.get("账户类型", ""))
        if "借记" in at:
            debit_count += 1
            try:
                bal = float(row.get("最新余额(元)", 0) or 0)
                total_debit += bal
            except (TypeError, ValueError):
                pass
        elif "信用" in at:
            credit_count += 1
            try:
                limit_val = float(row.get("信用额度(元)", 0) or 0)
                total_credit_limit += limit_val
            except (TypeError, ValueError):
                pass
            due = str(row.get("本期应还金额(元)", "") or "")
            if due:
                credit_due = due

    return [
        ("客户姓名", str(rows[0].get("用户姓名", "")) if rows else ""),
        ("银行", "招商银行"),
        ("总账户数", f"{debit_count + credit_count}个（借记卡{debit_count} + 信用卡{credit_count}）"),
        ("借记卡总余额", f"¥{total_debit:,.2f}"),
        ("信用卡总额度", f"¥{total_credit_limit:,.2f}"),
        ("信用卡当期应还", credit_due or "无"),
    ]


# 列表视图显示的列
LIST_COLUMNS = ["序号", "账户类型", "卡种/产品", "账号/卡号", "开户行/发卡行", "最新余额(元)", "信用额度(元)"]
LIST_LABELS = ["序号", "账户类型", "卡种/产品", "账号/卡号", "开户行/发卡行", "最新余额(元)", "信用额度(元)"]

# 详情视图显示的全部列
DETAIL_COLUMNS = [
    "序号", "用户姓名", "账户类型", "卡种/产品", "账号/卡号", "开户行/发卡行",
    "币种", "到期日", "最新余额(元)", "信用额度(元)", "账单日", "到期还款日",
    "本期应还金额(元)", "最低还款额(元)", "最近交易日期", "数据来源", "备注",
]
DETAIL_LABELS = [
    "序号", "用户姓名", "账户类型", "卡种/产品", "账号/卡号", "开户行/发卡行",
    "币种", "到期日", "最新余额(元)", "信用额度(元)", "账单日", "到期还款日",
    "本期应还金额(元)", "最低还款额(元)", "最近交易日期", "数据来源", "备注",
]
