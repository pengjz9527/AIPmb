"""消费数据中文key → 英文key映射"""

CONSUMPTION_FIELD_MAP = {
    "序号": "seq",
    "交易日期": "date",
    "收支方向": "direction",
    "交易金额": "amount",
    "消费细分子类": "subcategory",
    "交易分类": "category",
    "商户名称": "merchant",
    "支付渠道": "channel",
    "卡号": "card_number",
    "交易摘要": "summary",
}


def map_consumption(row: dict) -> dict:
    """将中文key的消费dict映射为英文key"""
    return {CONSUMPTION_FIELD_MAP.get(k, k): v for k, v in row.items() if k in CONSUMPTION_FIELD_MAP}


def map_consumption_list(rows: list[dict]) -> list[dict]:
    """批量映射消费列表"""
    return [map_consumption(r) for r in rows]


def map_consumption_stats(stats: list[dict]) -> list[dict]:
    """映射消费统计"""
    return stats  # already has name/count/total/avg
