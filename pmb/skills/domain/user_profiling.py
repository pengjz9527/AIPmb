"""用户画像领域 Skill — 全维度数据收集，返回画像分析上下文"""
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client


class UserProfilingSkill(BaseSkill):

    @property
    def name(self) -> str:
        return "user_profiling"

    @property
    def description(self) -> str:
        return "从收支和消费行为中提取用户画像数据。输出'画像速写/消费人格/数据洞察/灵感推荐'四板块，用标签+数据组合表达，简洁明快。"

    @property
    def parameters_schema(self) -> dict:
        return {"type": "object", "properties": {}}

    async def execute(self, **kwargs) -> SkillResult:
        user_name = kwargs.get("user_name", "")

        # 收集全维度数据
        api = create_client(user_name=user_name)
        summary_data, _ = await api.get_account_summary()
        summary_dict = {item["label"]: item["value"] for item in summary_data} if summary_data else {}

        subcategory_stats, _ = await api.get_consumption_stats(group_by="subcategory", top=12)
        monthly_stats, _ = await api.get_consumption_stats(group_by="month", top=12)
        channel_stats, _ = await api.get_consumption_stats(group_by="channel", top=5)
        merchant_stats, _ = await api.get_consumption_stats(group_by="merchant", top=15)

        return SkillResult(
            success=True,
            data={
                "account_summary": summary_dict,
                "subcategory_stats": subcategory_stats,
                "monthly_stats": monthly_stats,
                "channel_stats": channel_stats,
                "merchant_stats": merchant_stats,
            },
            summary=f"已收集全维度画像数据：{len(subcategory_stats)}项消费偏好、{len(monthly_stats)}月消费节奏、{len(merchant_stats)}家常去商户",
        )