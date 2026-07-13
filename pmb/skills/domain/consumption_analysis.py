"""消费分析领域 Skill — 收集数据，返回续航分析上下文"""
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client


class ConsumptionAnalysisSkill(BaseSkill):

    @property
    def name(self) -> str:
        return "consumption_analysis"

    @property
    def description(self) -> str:
        return "分析我的消费状况和生存能力。计算在不同消费标准下资金能支撑多久，给出逐项降级建议。输出'现状诊断/续航测算/降级方案/极限续航'四个板块。"

    @property
    def parameters_schema(self) -> dict:
        return {"type": "object", "properties": {}}

    async def execute(self, **kwargs) -> SkillResult:
        user_name = kwargs.get("user_name", "")

        # 收集账户数据（计算可用资金）
        api = create_client(user_name=user_name)
        all_accounts, _ = await api.list_accounts(limit=1000)
        total_assets = 0.0
        total_liabilities = 0.0
        for a in all_accounts:
            at = str(a.get("account_type", ""))
            if "借记" in at:
                try:
                    total_assets += float(a.get("balance", 0) or 0)
                except (TypeError, ValueError):
                    pass
            elif "信用" in at:
                try:
                    total_liabilities += float(a.get("amount_due", 0) or 0)
                except (TypeError, ValueError):
                    pass

        available = total_assets - total_liabilities

        # 收集消费数据
        monthly_stats, _ = await api.get_consumption_stats(group_by="month", top=12)
        subcategory_stats, _ = await api.get_consumption_stats(group_by="subcategory", top=15)
        category_stats, _ = await api.get_consumption_stats(group_by="category", top=10)

        avg_monthly = sum(s["total"] for s in monthly_stats) / max(len(monthly_stats), 1)
        months_current = available / avg_monthly if avg_monthly > 0 else float("inf")

        return SkillResult(
            success=True,
            data={
                "total_assets": round(total_assets, 2),
                "total_liabilities": round(total_liabilities, 2),
                "available_funds": round(available, 2),
                "monthly_stats": monthly_stats,
                "avg_monthly_expense": round(avg_monthly, 2),
                "months_current_standard": round(months_current, 1),
                "subcategory_stats": subcategory_stats,
                "category_stats": category_stats,
            },
            summary=f"当前可用资金¥{available:,.2f}，月均消费¥{avg_monthly:,.2f}，不降标准可续航{months_current:.1f}个月",
        )