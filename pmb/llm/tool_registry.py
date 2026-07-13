"""Function Calling 工具注册表和执行分发器"""
import json
from pmb.core import account_service, transaction_service, product_service, consumption_service


# 所有可用的Function Calling工具定义
ALL_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "query_accounts",
            "description": "查询用户银行账户信息，包括借记卡余额、信用卡额度等",
            "parameters": {
                "type": "object",
                "properties": {
                    "account_type": {
                        "type": "string",
                        "enum": ["credit", "debit", ""],
                        "description": "账户类型：credit信用卡/debit借记卡/空全部",
                    },
                    "keyword": {"type": "string", "description": "搜索关键词"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "query_transactions",
            "description": "查询交易明细，包括收入和支出记录",
            "parameters": {
                "type": "object",
                "properties": {
                    "source": {"type": "string", "enum": ["credit", "debit", "all"], "description": "数据来源"},
                    "direction": {"type": "string", "enum": ["income", "expense", ""], "description": "收支方向"},
                    "date_from": {"type": "string", "description": "起始日期 YYYY-MM-DD"},
                    "date_to": {"type": "string", "description": "结束日期 YYYY-MM-DD"},
                    "category": {"type": "string", "description": "交易分类"},
                    "limit": {"type": "integer", "description": "返回条数，默认20"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "query_consumption_stats",
            "description": "查询消费统计，支持按月/分类/商户/渠道分组",
            "parameters": {
                "type": "object",
                "properties": {
                    "group_by": {
                        "type": "string",
                        "enum": ["subcategory", "category", "channel", "merchant", "month", "year"],
                        "description": "分组维度",
                    },
                    "date_from": {"type": "string", "description": "起始日期"},
                    "date_to": {"type": "string", "description": "结束日期"},
                    "top": {"type": "integer", "description": "返回前N条，默认10"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "query_products",
            "description": "查询银行产品，包括存款、理财、基金、保险等",
            "parameters": {
                "type": "object",
                "properties": {
                    "category": {
                        "type": "string",
                        "enum": ["deposit", "loan", "wealth", "fund", "insurance", "forex", "gold"],
                        "description": "产品类别",
                    },
                    "keyword": {"type": "string", "description": "搜索关键词"},
                    "risk_level": {"type": "string", "description": "风险等级"},
                    "limit": {"type": "integer", "description": "返回条数"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_account_summary",
            "description": "获取账户汇总信息，包括总余额、信用额度、应还金额等",
            "parameters": {"type": "object", "properties": {}},
        },
    },
]


async def execute_tool(name: str, arguments: dict, user_name: str = "") -> str:
    """执行工具函数，返回JSON字符串结果"""
    try:
        if name == "query_accounts":
            results, total = account_service.list_accounts(
                user_name=user_name,
                account_type=arguments.get("account_type", ""),
                keyword=arguments.get("keyword", ""),
                limit=arguments.get("limit", 20),
            )
            # 简化输出，只返回关键信息
            simplified = []
            for r in results:
                simplified.append({
                    "账户类型": r.get("账户类型", ""),
                    "卡种/产品": r.get("卡种/产品", ""),
                    "最新余额(元)": r.get("最新余额(元)", ""),
                    "信用额度(元)": r.get("信用额度(元)", ""),
                })
            return json.dumps({"total": total, "accounts": simplified}, ensure_ascii=False)

        elif name == "query_transactions":
            results, total = transaction_service.list_transactions(
                user_name=user_name,
                source=arguments.get("source", "all"),
                direction=arguments.get("direction", ""),
                category=arguments.get("category", ""),
                date_from=arguments.get("date_from", ""),
                date_to=arguments.get("date_to", ""),
                limit=arguments.get("limit", 20),
            )
            simplified = []
            for r in results:
                simplified.append({
                    "交易日期": r.get("交易日期", ""),
                    "收支方向": r.get("收支方向", ""),
                    "交易金额": r.get("交易金额", 0),
                    "交易分类": r.get("交易分类", ""),
                    "消费细分子类": r.get("消费细分子类", ""),
                    "商户/对手方": r.get("商户/对手方", ""),
                })
            return json.dumps({"total": total, "transactions": simplified}, ensure_ascii=False)

        elif name == "query_consumption_stats":
            stats = consumption_service.get_consumption_stats(
                user_name=user_name,
                group_by=arguments.get("group_by", "subcategory"),
                date_from=arguments.get("date_from", ""),
                date_to=arguments.get("date_to", ""),
                top=arguments.get("top", 10),
            )
            return json.dumps({"stats": stats}, ensure_ascii=False)

        elif name == "query_products":
            results, total = product_service.list_products(
                category=arguments.get("category", ""),
                keyword=arguments.get("keyword", ""),
                risk_level=arguments.get("risk_level", ""),
                limit=arguments.get("limit", 10),
            )
            simplified = []
            for r in results:
                simplified.append({
                    "银行": r.get("银行", ""),
                    "产品名称": r.get("产品名称", r.get("产品名称/类别", "")),
                    "产品类型": r.get("产品类型", r.get("产品大类", "")),
                    "风险等级": r.get("风险等级", ""),
                    "产品描述": r.get("产品描述", ""),
                })
            return json.dumps({"total": total, "products": simplified}, ensure_ascii=False)

        elif name == "get_account_summary":
            summary = account_service.get_account_summary(user_name=user_name)
            return json.dumps({"summary": dict(summary)}, ensure_ascii=False)

        else:
            return json.dumps({"error": f"未知工具: {name}"}, ensure_ascii=False)

    except Exception as e:
        return json.dumps({"error": str(e)}, ensure_ascii=False)
