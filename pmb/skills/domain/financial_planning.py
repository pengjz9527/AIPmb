"""理财规划领域 Skill — 收集数据，返回结构化上下文给 LLM"""
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client


class FinancialPlanningSkill(BaseSkill):

    @property
    def name(self) -> str:
        return "financial_planning"

    @property
    def description(self) -> str:
        return "为我制定个性化理财方案。收集账户汇总、消费趋势、可选产品数据，由AI基于数据生成'现状分析/优化建议/产品推荐/预期效果'四个板块的理财方案。"

    @property
    def parameters_schema(self) -> dict:
        return {"type": "object", "properties": {}}

    async def execute(self, **kwargs) -> SkillResult:
        user_name = kwargs.get("user_name", "")

        # 收集账户数据
        api = create_client(user_name=user_name)
        summary_data, _ = await api.get_account_summary()
        summary_dict = {item["label"]: item["value"] for item in summary_data} if summary_data else {}
        all_accounts, _ = await api.list_accounts(limit=1000)

        # 收集消费数据
        monthly_stats, _ = await api.get_consumption_stats(group_by="month", top=6)
        subcategory_stats, _ = await api.get_consumption_stats(group_by="subcategory", top=10)

        # 收集产品数据
        wealth_products, _ = await api.list_products(category="wealth", limit=5)
        fund_products, _ = await api.list_products(category="fund", limit=3)
        deposit_products, _ = await api.list_products(category="deposit", limit=3)

        # 简化产品列表
        def simplify_products(products):
            return [
                {
                    "名称": p.get("name", ""),
                    "类型": p.get("type_label", ""),
                    "风险": p.get("risk_level", ""),
                }
                for p in products
            ]

        # 计算关键数值
        total_balance = 0.0
        total_credit_due = 0.0
        for a in all_accounts:
            at = str(a.get("account_type", ""))
            if "借记" in at:
                try:
                    total_balance += float(a.get("balance", 0) or 0)
                except (TypeError, ValueError):
                    pass
            elif "信用" in at:
                try:
                    total_credit_due += float(a.get("amount_due", 0) or 0)
                except (TypeError, ValueError):
                    pass

        avg_monthly = sum(s["total"] for s in monthly_stats) / max(len(monthly_stats), 1)

        return SkillResult(
            success=True,
            data={
                "account_summary": summary_dict,
                "total_balance": round(total_balance, 2),
                "total_credit_due": round(total_credit_due, 2),
                "monthly_stats": monthly_stats,
                "avg_monthly_expense": round(avg_monthly, 2),
                "subcategory_stats": subcategory_stats,
                "wealth_products": simplify_products(wealth_products),
                "fund_products": simplify_products(fund_products),
                "deposit_products": simplify_products(deposit_products),
            },
            summary=f"已收集理财规划所需数据：{len(all_accounts)}个账户、{len(monthly_stats)}个月消费趋势、"
            f"{len(wealth_products)}款理财+{len(fund_products)}款基金+{len(deposit_products)}款存款产品",
        )