"""通用助手智能体（小易）— 唯一入口，通过 Skill 编排 + LLM Function Calling 提供服务"""
import json
import asyncio
import logging
from pmb.agents.base import BaseAgent, AgentContext, AgentResult

logger = logging.getLogger(__name__)


class GeneralAssistantAgent(BaseAgent):
    """通用助手（小易）：唯一智能体，通过 LLM + Skill 工具编排提供服务"""

    @property
    def agent_id(self) -> str:
        return "general_assistant"

    @property
    def name(self) -> str:
        return "小易"

    @property
    def description(self) -> str:
        return "银行AI助手，通过智能编排技能为您提供全面的银行服务"

    @property
    def avatar(self) -> str:
        return "general"

    @property
    def system_prompt(self) -> str:
        return """你是招商银行AI助手"小易"，专注于为用户提供个人银行服务。

你可以通过调用工具函数获取实时数据。重要规则：

1. **使用技能（Skill）处理复杂任务**：
   - 理财规划 → 调用 financial_planning 技能
   - 消费分析/续航测算 → 调用 consumption_analysis 技能
   - 收入趋势预测/消费规划/收支平衡 → 调用 income_forecast 技能
   - 产品推荐/优惠推荐 → 调用 life_recommendation 技能
   - 用户画像 → 调用 user_profiling 技能
   - 技能会返回完整数据，你基于这些数据生成分析报告

2. **简单查询直接使用工具**：
   - 查余额/账户 → query_accounts 或 collect_account_data
   - 查交易 → query_transactions 或 collect_transaction_data
   - 查消费 → collect_consumption_data

3. **输出格式要求（重要）**：
   - 复杂分析（理财方案、消费分析、产品推荐、用户画像）必须使用以下格式输出：
     ```
     ## 结论概要
     （2-3句话概括核心结论，用简洁的语言让用户快速了解结果）

     ---DETAIL---

     ## 详细分析
     （展开的完整分析内容，使用 Markdown 格式）
     ```
   - 简单查询（查余额、查交易、简单问答）直接输出，不需要分隔符

4. **产品推荐约束（重要）**：
   - 所有推荐的产品必须严格来自产品库数据，禁止虚构产品
   - 每个推荐产品必须给出产品简介（1-2句话），然后在简介下方同时提供两个链接：
     - 「产品详情」链接：`[产品详情](/product?product_name=产品名称)`
     - 「一键购买」链接：`[一键购买](/buy?product_name=产品名称)`
   - 产品名称必须与产品库中的名称完全一致
   - 链接必须使用绝对路径格式，以 / 开头，确保前端可以正确解析跳转
   - 产品推荐排版示例：
     ```
     ### 产品名称
     产品简介描述文字，说明该产品的特点和适合你的原因。
     [产品详情](/product?product_name=产品名称) | [一键购买](/buy?product_name=产品名称)
     ```

5. **回答风格**：
   - 中文回复，金额格式化为"¥x,xxx.xx"
   - 用简洁友好的方式回答问题
   - 用Markdown格式输出，使用标题和列表使内容清晰

当前用户是招商银行客户。"""

    def can_handle(self, user_message: str) -> float:
        return 0.1

    async def analyze_stream(
        self, context: AgentContext, event_queue: asyncio.Queue
    ) -> None:
        """
        流式分析与响应。
        通过 event_queue 发送事件：thinking_step / reasoning_chunk / ai_chunk / ai_done
        """
        try:
            await self._analyze_stream_impl(context, event_queue)
        except Exception as e:
            await event_queue.put({
                "type": "error",
                "content": f"智能体处理出错: {str(e)}",
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

        try:
            from pmb.llm.prompt_enhancer import PromptEnhancer
            enhanced_prompt = PromptEnhancer.build(
                agent_system_prompt=enhanced_prompt,
                user_query=context.user_message,
            )
        except Exception as e:
            logger.warning(f"业务规则注入失败（降级为原始 prompt）: {e}")

        conv.set_system_prompt(enhanced_prompt)

        messages = conv.get_messages()
        messages.append({"role": "user", "content": context.user_message})

        all_tools = list(ALL_TOOLS) + skill_orchestrator.to_openai_tools()

        content_buffer, _ = await self._run_llm_loop(
            context, event_queue, messages, all_tools,
            skill_orchestrator, step_id_prefix="ga",
        )

        conv.add_message("user", context.user_message)
        conv.add_message("assistant", content_buffer)
        await self._emit_ai_done(event_queue, content_buffer)