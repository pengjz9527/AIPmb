"""理财专家智能体"""
import asyncio
import logging
from pmb.agents.base import BaseAgent, AgentContext, AgentResult

logger = logging.getLogger(__name__)


class FinancialPlannerAgent(BaseAgent):

    managed_skills = [
        "financial_planning", "loan_cost_optimizer",
        "loan_product_recommendation",
    ]

    @property
    def agent_id(self) -> str:
        return "financial_planner"

    @property
    def name(self) -> str:
        return "理财专家"

    @property
    def description(self) -> str:
        return "根据您的财富状况和消费习惯，制定个性化理财方案，不降低消费品味"

    @property
    def avatar(self) -> str:
        return "financial"

    @property
    def system_prompt(self) -> str:
        return """你是一位资深理财专家，专注于为银行客户提供个性化的理财规划方案。
你的核心理念是：理财不是节流，而是让钱更聪明地运转。
你需要：
1. 先全面了解客户的资产状况（存款、信用卡、负债）
2. 分析客户的消费习惯和消费水平
3. 在不降低消费品味的前提下，找出资金优化空间
4. 推荐适合客户风险偏好的银行产品组合
5. 给出具体的资金分配建议（每月可投资金额、产品配比、预期收益）

输出格式要求：
- 给出"现状分析"、"优化建议"、"产品推荐"、"预期效果"四个板块
- 金额精确到元，收益率给出合理区间
- 产品推荐必须严格来自银行实际产品库，禁止虚构产品
- 每个推荐产品必须附带「查看详情」链接（格式：`[查看详情](/product?product_name=产品名称)`）
- 产品详情中必须包含「马上购买」链接（格式：`[马上购买](/buy?product_name=产品名称)`）
- 产品名称必须与产品库中的名称完全一致
- 用Markdown格式输出，使用标题和列表使内容清晰"""

    def can_handle(self, user_message: str) -> float:
        keywords = ["理财", "投资", "规划", "存钱", "收益", "产品推荐", "资金分配",
                     "理财方案", "投资建议", "财富管理", "资产配置"]
        msg = user_message.lower()
        score = 0.0
        for kw in keywords:
            if kw in msg:
                score += 0.35
        return min(score, 1.0)

    def _get_business_rules(self, user_message: str) -> str:
        """获取匹配的业务规则约束文本（降级安全）"""
        try:
            from pmb.llm.prompt_enhancer import PromptEnhancer
            retriever = PromptEnhancer._get_retriever()
            entries = retriever.search_with_cache(user_message)
            return retriever.format_for_prompt(entries)
        except Exception:
            return ""

    async def analyze_stream(
        self, context: AgentContext, event_queue: asyncio.Queue
    ) -> None:
        """流式分析与响应"""
        try:
            await self._analyze_stream_impl(context, event_queue)
        except Exception as e:
            await event_queue.put({
                "type": "error",
                "content": f"理财规划出错: {str(e)}",
                "is_final": True,
            })

    async def _analyze_stream_impl(
        self, context: AgentContext, event_queue: asyncio.Queue
    ) -> None:
        from pmb.llm.context_manager import context_manager
        from pmb.llm.tool_registry import ALL_TOOLS
        from pmb.skills.orchestrator import skill_orchestrator

        conv = context_manager.get_or_create(context.session_id)

        enhanced_prompt = self.system_prompt
        if context.memory_summary:
            enhanced_prompt += "\n" + context.memory_summary

        # 注入业务规则约束（RAG 检索）
        try:
            business_rules = self._get_business_rules(context.user_message)
            if business_rules:
                enhanced_prompt += f"\n\n## 业务规则约束\n{business_rules}"
        except Exception as e:
            logger.warning(f"业务规则注入失败: {e}")

        conv.set_system_prompt(enhanced_prompt)

        messages = conv.get_messages()
        messages.append({"role": "user", "content": context.user_message})

        all_tools = list(ALL_TOOLS) + [
            t for t in skill_orchestrator.to_openai_tools()
            if t["function"]["name"] in {
                "financial_planning", "loan_cost_optimizer",
                "loan_product_recommendation",
                "collect_account_data", "collect_product_data",
                "collect_consumption_data",
            }
        ]

        content_buffer, _ = await self._run_llm_loop(
            context, event_queue, messages, all_tools,
            skill_orchestrator, step_id_prefix="fp",
        )

        conv.add_message("user", context.user_message)
        conv.add_message("assistant", content_buffer)
        await self._emit_ai_done(event_queue, content_buffer)

    async def analyze(self, context: AgentContext) -> AgentResult:
        """同步分析（兼容旧接口，内部使用流式）"""
        data = await self._collect_data(context)

        from pmb.core import consumption_service, product_service
        monthly_stats = consumption_service.get_consumption_stats(group_by="month", top=6, user_name=context.user_name)
        subcategory_stats = consumption_service.get_consumption_stats(group_by="subcategory", top=10, user_name=context.user_name)

        wealth_products, _ = product_service.list_products(category="wealth", limit=5)
        fund_products, _ = product_service.list_products(category="fund", limit=3)
        deposit_products, _ = product_service.list_products(category="deposit", limit=3)

        enhanced_prompt = f"""请为以下客户制定理财方案：

## 客户账户汇总
{data['account_summary']}

## 月度消费趋势（近6个月）
{monthly_stats}

## 消费结构Top10
{subcategory_stats}

## 可选理财产品
{[{"名称": p.get("产品名称/类别", p.get("产品名称", "")), "类型": p.get("产品类型", ""), "风险": p.get("风险等级", "")} for p in wealth_products]}

## 可选基金产品
{[{"名称": p.get("基金类别", ""), "类型": p.get("基金类型", ""), "风险": p.get("风险等级", "")} for p in fund_products]}

## 可选存款产品
{[{"名称": p.get("产品名称", ""), "类型": p.get("产品大类", "")} for p in deposit_products]}

请根据以上数据，为这位客户制定个性化的理财方案，在不降低消费品味的前提下，合理配置资金。"""

        content = await self._call_llm(
            context,
            enhanced_prompt,
            business_rules_text=self._get_business_rules(context.user_message),
        )

        return AgentResult(
            agent_id=self.agent_id,
            agent_name=self.name,
            content=content,
            cards=[
                {"card_type": "wealth_plan", "title": "理财方案概览", "data": {
                    "monthly_stats": monthly_stats,
                    "products": [p.get("产品名称/类别", p.get("产品名称", "")) for p in wealth_products[:3]],
                }},
            ],
            suggested_agents=["income_expense_analyst", "user_profiler"],
        )
