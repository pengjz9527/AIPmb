"""交易数据中文key → 英文key映射"""

TRANSACTION_FIELD_MAP = {
    "序号": "seq",
    "来源": "source",
    "交易日期": "date",
    "收支方向": "direction",
    "交易金额": "amount",
    "交易分类": "category",
    "消费细分子类": "subcategory",
    "商户/对手方": "merchant",
    "支付渠道": "payment_channel",
    "账号/卡号": "account_number",
    "币种": "currency",
    # 新增映射（neighborhood / history_today 等 skill 依赖）
    "持卡人姓名": "card_holder",
    "用户姓名": "user_name",
    "商户名称": "merchant",
    "对手方名称": "merchant",
    "交易金额(元)": "amount",
    "记账日期": "date",
    "交易摘要": "summary",
    "交易方式/渠道": "method",
    "交易大类": "category",
}


def map_transaction(row: dict) -> dict:
    """将中文key的交易dict映射为英文key"""
    return {TRANSACTION_FIELD_MAP.get(k, k): v for k, v in row.items() if k in TRANSACTION_FIELD_MAP}


def map_transaction_list(rows: list[dict]) -> list[dict]:
    """批量映射交易列表"""
    return [map_transaction(r) for r in rows]


def map_transaction_summary(stats: list[dict]) -> list[dict]:
    """映射交易汇总"""
    return stats  # already has name/count/total/avg
