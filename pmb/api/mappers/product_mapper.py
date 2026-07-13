"""产品数据中文key → 英文key映射"""

PRODUCT_FIELD_MAP = {
    "银行": "bank",
    "产品名称": "name",
    "产品名称/类别": "name",
    "基金类别": "name",
    "产品名称/业务": "name",
    "产品类别": "category",
    "产品大类": "type_label",
    "产品类型": "type_label",
    "基金类型": "type_label",
    "业务类型": "type_label",
    "保险类型": "type_label",
    "产品描述": "description",
    "风险等级": "risk_level",
}


def map_product(row: dict) -> dict:
    """将中文key的产品dict映射为英文key"""
    mapped = {}
    used_en = set()
    for k, v in row.items():
        en = PRODUCT_FIELD_MAP.get(k)
        if en and en not in used_en:
            mapped[en] = v
            used_en.add(en)
    # 附加分类信息
    if "_product_category" in row:
        mapped["category_label"] = row["_product_category"]
    if "_product_key" in row:
        mapped["category"] = row["_product_key"]
    return mapped


def map_product_list(rows: list[dict]) -> list[dict]:
    """批量映射产品列表"""
    return [map_product(r) for r in rows]


def map_product_categories(cats: list[dict]) -> list[dict]:
    """映射产品类别"""
    result = []
    for c in cats:
        result.append({
            "key": c.get("类别标识", ""),
            "name": c.get("类别名称", ""),
            "count": c.get("产品数量", 0),
            "bank_distribution": c.get("银行分布", ""),
        })
    return result
