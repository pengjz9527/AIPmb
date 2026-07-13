"""收集消费数据 Skill"""
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client


class CollectConsumptionDataSkill(BaseSkill):

    @property
    def name(self) -> str:
        return "collect_consumption_data"

    @property
    def description(self) -> str:
        return "查询用户消费统计数据，支持按子类/大类/商户/渠道/月份分组。当用户询问消费分析、支出情况、消费结构时调用。"

    @property
    def parameters_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "group_by": {
                    "type": "string",
                    "enum": ["subcategory", "category", "channel", "merchant", "month"],
                    "description": "分组维度",
                },
                "date_from": {"type": "string", "description": "起始日期 YYYY-MM-DD"},
                "date_to": {"type": "string", "description": "结束日期 YYYY-MM-DD"},
                "top": {"type": "integer", "description": "返回前N条，默认10"},
                "user_name": {"type": "string", "description": "用户姓名，用于数据隔离"},
            },
        }

    async def execute(self, **kwargs) -> SkillResult:
        group_by = kwargs.get("group_by", "subcategory")
        date_from = kwargs.get("date_from", "")
        date_to = kwargs.get("date_to", "")
        top = kwargs.get("top", 10)
        user_name = kwargs.get("user_name", "")

        api = create_client(user_name=user_name)
        stats, _ = await api.get_consumption_stats(
            group_by=group_by, date_from=date_from, date_to=date_to, top=top,
        )

        total_amount = sum(s.get("total", 0) for s in stats)
        return SkillResult(
            success=True,
            data={"stats": stats, "group_by": group_by, "total_amount": total_amount},
            summary=f"已获取{len(stats)}条消费统计（{group_by}维度），合计¥{total_amount:,.2f}",
        )