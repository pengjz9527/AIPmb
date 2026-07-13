"""收集交易数据 Skill"""
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client


class CollectTransactionDataSkill(BaseSkill):

    @property
    def name(self) -> str:
        return "collect_transaction_data"

    @property
    def description(self) -> str:
        return "查询用户交易流水明细，包括收入和支出记录。当用户询问交易明细、账单、最近消费时调用。"

    @property
    def parameters_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "direction": {
                    "type": "string",
                    "enum": ["income", "expense", ""],
                    "description": "收支方向",
                },
                "date_from": {"type": "string", "description": "起始日期 YYYY-MM-DD"},
                "date_to": {"type": "string", "description": "结束日期 YYYY-MM-DD"},
                "category": {"type": "string", "description": "交易分类"},
                "limit": {"type": "integer", "description": "返回条数，默认20"},
                "user_name": {"type": "string", "description": "用户姓名，用于数据隔离"},
            },
        }

    async def execute(self, **kwargs) -> SkillResult:
        direction = kwargs.get("direction", "")
        date_from = kwargs.get("date_from", "")
        date_to = kwargs.get("date_to", "")
        category = kwargs.get("category", "")
        limit = kwargs.get("limit", 20)
        user_name = kwargs.get("user_name", "")

        api = create_client(user_name=user_name)
        transactions, total = await api.list_transactions(
            direction=direction,
            date_from=date_from,
            date_to=date_to,
            category=category,
            limit=limit,
        )

        simplified = []
        for t in transactions:
            simplified.append({
                "日期": t.get("date", ""),
                "方向": t.get("direction", ""),
                "金额": t.get("amount", 0),
                "分类": t.get("category", ""),
                "子类": t.get("subcategory", ""),
                "商户": t.get("merchant", ""),
            })

        return SkillResult(
            success=True,
            data={"transactions": simplified, "total": total},
            summary=f"已获取{len(simplified)}条交易记录（共{total}条）",
        )