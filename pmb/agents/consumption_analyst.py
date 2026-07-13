"""消费分析智能体"""
from pmb.agents.base import BaseAgent, AgentContext, AgentResult


class ConsumptionAnalystAgent(BaseAgent):

    @property
    def agent_id(self) -> str:
        return "consumption_analyst"

    @property
    def name(self) -> str:
        return "消费分析师"

    @property
    def description(self) -> str:
        return "分析您的消费状况，计算不同消费标准下的资金续航月数"

    @property
    def avatar(self) -> str:
        return "consumption"

    @property
    def system_prompt(self) -> str:
        return """你是一位专业的消费分析师，擅长通过数据洞察帮助客户了解自己的消费真相。
你的核心任务是回答"如果没了收入，我还能撑多久"这个关键问题。
你需要：
1. 计算当前总可用资金（存款余额 - 信用卡应还）
2. 分析月均消费（区分"维持现状"和"最低生存"两个档次）
3. 计算两个场景的续航月数
4. 给出降低消费标准的具体建议（按消费子类逐项分析可压缩空间）
5. 给出最长续航方案

输出格式要求：
- 给出"现状诊断"、"续航测算"、"降级方案"、"极限续航"四个板块
- 续航月数精确到0.1个月
- 降级方案按消费子类逐项给出压缩比例建议
- 用对比表格呈现"当前消费"vs"建议消费"
- 用Markdown格式输出"""

    def can_handle(self, user_message: str) -> float:
        keywords = ["消费分析", "撑多久", "收入中断", "失业", "降消费", "节省", "预算",
                     "还能撑", "断粮", "生活费", "节约", "消费真相", "财务危机"]
        msg = user_message.lower()
        score = 0.0
        for kw in keywords:
            if kw in msg:
                score += 0.4
        return min(score, 1.0)

    async def analyze(self, context: AgentContext) -> AgentResult:
        data = await self._collect_data(context)

        from pmb.core import consumption_service
        monthly_stats = consumption_service.get_consumption_stats(group_by="month", top=12, user_name=context.user_name)
        subcategory_stats = consumption_service.get_consumption_stats(group_by="subcategory", top=15, user_name=context.user_name)
        category_stats = consumption_service.get_consumption_stats(group_by="category", top=10, user_name=context.user_name)

        # 计算关键数值
        total_assets = 0.0
        total_liabilities = 0.0
        for item in data.get("account_summary", {}).items():
            pass  # summary是list[tuple]格式，需从账户数据重新计算

        from pmb.core import account_service
        all_accounts, _ = account_service.list_accounts(user_name=context.user_name, limit=1000)
        for acc in all_accounts:
            at = str(acc.get("账户类型", ""))
            if "借记" in at:
                try:
                    total_assets += float(acc.get("最新余额(元)", 0) or 0)
                except (TypeError, ValueError):
                    pass
            elif "信用" in at:
                try:
                    total_liabilities += float(acc.get("本期应还金额(元)", 0) or 0)
                except (TypeError, ValueError):
                    pass

        available = total_assets - total_liabilities
        avg_monthly = sum(s["total"] for s in monthly_stats) / max(len(monthly_stats), 1)
        months_current = available / avg_monthly if avg_monthly > 0 else float("inf")

        enhanced_prompt = f"""请为以下客户进行消费分析和续航测算：

## 资金状况
- 总可用资金（存款余额 - 信用卡应还）: ¥{available:,.2f}
- 总资产（借记卡余额）: ¥{total_assets:,.2f}
- 总负债（信用卡应还）: ¥{total_liabilities:,.2f}

## 月度消费趋势
{monthly_stats}

## 消费结构明细（按子类）
{subcategory_stats}

## 消费大类占比
{category_stats}

## 初步测算
- 月均消费: ¥{avg_monthly:,.2f}
- 不降标准续航月数: {months_current:.1f}个月

请基于以上数据，给出详细的分析报告，包括两个场景的续航测算和逐项降级建议。"""

        content = await self._call_llm(context, enhanced_prompt)

        return AgentResult(
            agent_id=self.agent_id,
            agent_name=self.name,
            content=content,
            cards=[
                {"card_type": "survival_calc", "title": "续航测算", "data": {
                    "available_funds": round(available, 2),
                    "avg_monthly_expense": round(avg_monthly, 2),
                    "months_current_standard": round(months_current, 1),
                    "subcategory_stats": subcategory_stats[:8],
                }},
            ],
            suggested_agents=["financial_planner", "user_profiler"],
        )
