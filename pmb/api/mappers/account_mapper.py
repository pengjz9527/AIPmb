"""账户数据中文key → 英文key映射"""

ACCOUNT_FIELD_MAP = {
    "序号": "seq",
    "用户姓名": "name",
    "账户类型": "account_type",
    "卡种/产品": "card_product",
    "账号/卡号": "account_number",
    "开户行/发卡行": "branch",
    "币种": "currency",
    "到期日": "expiry_date",
    "最新余额(元)": "balance",
    "信用额度(元)": "credit_limit",
    "账单日": "billing_day",
    "到期还款日": "due_day",
    "本期应还金额(元)": "amount_due",
    "最低还款额(元)": "min_payment",
    "最近交易日期": "last_tx_date",
    "数据来源": "source",
    "备注": "notes",
}


def map_account(row: dict) -> dict:
    """将中文key的账户dict映射为英文key"""
    return {ACCOUNT_FIELD_MAP.get(k, k): v for k, v in row.items() if k in ACCOUNT_FIELD_MAP}


def map_account_list(rows: list[dict]) -> list[dict]:
    """批量映射账户列表"""
    return [map_account(r) for r in rows]


def map_account_summary(items: list[tuple[str, str]]) -> list[dict]:
    """映射账户汇总"""
    return [{"label": label, "value": value} for label, value in items]
