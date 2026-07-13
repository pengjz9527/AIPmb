from pmb.core.loader import loader
from pmb.core.config import PRODUCT_CATEGORY_NAMES
from pmb.utils.search import fuzzy_match, apply_pagination, filter_by_field_contains

PRODUCT_SEARCH_FIELDS = ["银行", "产品名称", "产品大类", "产品类型", "基金类别", "基金类型",
                         "产品名称/类别", "产品名称/业务", "业务类型", "产品类别",
                         "保险类型", "产品描述"]


def list_products(
    keyword: str = "",
    category: str = "",
    bank: str = "",
    risk_level: str = "",
    limit: int = 20,
    offset: int = 0,
) -> tuple[list[dict], int]:
    """列出产品，支持跨类别和跨银行搜索"""
    from pmb.core.config import PRODUCT_FILES

    results = []
    categories = [category] if category else list(PRODUCT_FILES.keys())

    for cat in categories:
        rows = loader.load_products(cat)
        cat_name = PRODUCT_CATEGORY_NAMES.get(cat, cat)
        for row in rows:
            row["_product_category"] = cat_name
            row["_product_key"] = cat
            if not fuzzy_match(row, keyword, PRODUCT_SEARCH_FIELDS):
                continue
            if bank and bank not in str(row.get("银行", "")):
                continue
            if risk_level:
                rl = str(row.get("风险等级", ""))
                if risk_level not in rl:
                    continue
            results.append(row)

    paginated, total = apply_pagination(results, offset, limit)
    return paginated, total


def get_product(product_name: str, category: str = "") -> dict | None:
    """按产品名称精确/模糊查询"""
    from pmb.core.config import PRODUCT_FILES

    # 确定要搜索的类别
    categories = [category] if category else list(PRODUCT_FILES.keys())

    # 先尝试精确匹配
    for cat in categories:
        rows = loader.load_products(cat)
        cat_name = PRODUCT_CATEGORY_NAMES.get(cat, cat)
        for row in rows:
            # 尝试各种可能的产品名称列
            name_fields = ["产品名称", "产品名称/类别", "基金类别", "产品名称/业务"]
            for nf in name_fields:
                if product_name.strip() == str(row.get(nf, "")).strip():
                    row["_product_category"] = cat_name
                    row["_product_key"] = cat
                    return row

    # 再尝试模糊匹配
    for cat in categories:
        rows = loader.load_products(cat)
        cat_name = PRODUCT_CATEGORY_NAMES.get(cat, cat)
        for row in rows:
            name_fields = ["产品名称", "产品名称/类别", "基金类别", "产品名称/业务"]
            for nf in name_fields:
                if product_name.lower() in str(row.get(nf, "")).lower():
                    row["_product_category"] = cat_name
                    row["_product_key"] = cat
                    return row

    return None


def get_product_summary(bank: str = "", category: str = "") -> list[dict]:
    """产品统计汇总"""
    from pmb.core.config import PRODUCT_FILES

    stats = []
    categories = [category] if category else list(PRODUCT_FILES.keys())

    for cat in categories:
        rows = loader.load_products(cat)
        cat_name = PRODUCT_CATEGORY_NAMES.get(cat, cat)
        if bank:
            rows = [r for r in rows if bank in str(r.get("银行", ""))]
        if rows:
            # 按银行分组
            bank_counts = {}
            for r in rows:
                b = str(r.get("银行", ""))
                bank_counts[b] = bank_counts.get(b, 0) + 1
            for b, count in bank_counts.items():
                stats.append({"name": f"{cat_name} - {b}", "count": count, "total": 0, "avg": 0})

    return stats


def get_categories() -> list[dict]:
    """列出所有产品类别及数量"""
    from pmb.core.config import PRODUCT_FILES

    result = []
    for cat, filepath in PRODUCT_FILES.items():
        rows = loader.load_products(cat)
        cat_name = PRODUCT_CATEGORY_NAMES.get(cat, cat)
        # 按银行统计
        banks = {}
        for r in rows:
            b = str(r.get("银行", ""))
            banks[b] = banks.get(b, 0) + 1
        bank_str = ", ".join(f"{b}: {c}" for b, c in banks.items())
        result.append({
            "类别标识": cat,
            "类别名称": cat_name,
            "产品数量": len(rows),
            "银行分布": bank_str,
        })
    return result


# 列表视图列（通用字段）
LIST_COLUMNS = ["_product_category", "银行", "产品名称", "产品大类", "产品类型", "基金类别", "基金类型",
                "产品名称/类别", "产品名称/业务", "业务类型", "产品类别", "保险类型", "风险等级"]

# 只显示非空的列
def _get_list_display_cols(row: dict) -> list[str]:
    """从通用列中获取该记录有值的列"""
    result = ["_product_category", "银行"]
    name_col = None
    for nc in ["产品名称", "产品名称/类别", "基金类别", "产品名称/业务"]:
        if nc in row and row.get(nc):
            name_col = nc
            break
    if name_col:
        result.append(name_col)

    type_col = None
    for tc in ["产品大类", "产品类型", "基金类型", "业务类型", "产品类别", "保险类型"]:
        if tc in row and row.get(tc):
            type_col = tc
            break
    if type_col:
        result.append(type_col)

    if row.get("风险等级"):
        result.append("风险等级")
    return result
