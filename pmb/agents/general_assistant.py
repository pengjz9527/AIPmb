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

    async def analyze(self, context: AgentContext) -> AgentResult:
        """兼容旧接口（同步调用），实际使用 analyze_stream"""
        queue = asyncio.Queue()
        await self.analyze_stream(context, queue)
        result = AgentResult(agent_id=self.agent_id, agent_name=self.name, content="", cards=[])
        return result

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
        """analyze_stream 的实际实现，异常由外层捕获"""
        from pmb.llm.qwen import QwenLLM
        from pmb.llm.context_manager import context_manager
        from pmb.llm.tool_registry import ALL_TOOLS, execute_tool
        from pmb.skills.orchestrator import skill_orchestrator

        conv = context_manager.get_or_create(context.session_id)

        # 将用户历史记忆注入 system prompt
        enhanced_prompt = self.system_prompt
        if context.memory_summary:
            enhanced_prompt += "\n" + context.memory_summary

        # 注入业务规则约束（RAG 检索 + 模板组装）
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

        llm = QwenLLM()
        # 合并 ALL_TOOLS + Skills
        all_tools = list(ALL_TOOLS) + skill_orchestrator.to_openai_tools()

        # === 阶段1: 意图识别 ===
        await event_queue.put({
            "type": "thinking_step",
            "step_id": "phase_intent",
            "skill_name": "_orchestrator",
            "display_name": "意图识别",
            "status": "invoking",
            "message": "分析用户问题，识别服务意图...",
            "phase": "intent",
            "phase_order": 1,
        })

        max_rounds = 5
        while max_rounds > 0:
            stream = llm.chat_stream(messages=messages, tools=all_tools)
            content_buffer = ""
            reasoning_buffer = ""
            tool_calls_buffer: list = []

            async for chunk in stream:
                # 推理链
                if chunk.reasoning_content:
                    reasoning_buffer += chunk.reasoning_content
                    await event_queue.put({
                        "type": "reasoning_chunk",
                        "content": chunk.reasoning_content,
                    })

                # 文本内容
                if chunk.content:
                    content_buffer += chunk.content
                    await event_queue.put({
                        "type": "ai_chunk",
                        "content": chunk.content,
                        "is_final": False,
                    })

                # 工具调用
                if chunk.tool_calls:
                    for tc in chunk.tool_calls:
                        skill_display = self._skill_display_name(tc.name)
                        # 标记意图识别完成
                        await event_queue.put({
                            "type": "thinking_step",
                            "step_id": "phase_intent",
                            "skill_name": "_orchestrator",
                            "display_name": "意图识别",
                            "status": "completed",
                            "message": f"识别到意图：需要调用{skill_display}技能",
                            "phase": "intent",
                            "phase_order": 1,
                        })
                        # === 阶段2: Skill编排 ===
                        await event_queue.put({
                            "type": "thinking_step",
                            "step_id": "phase_orchestrate",
                            "skill_name": "_orchestrator",
                            "display_name": "Skill编排",
                            "status": "invoking",
                            "message": f"编排执行计划：调用{skill_display}获取数据...",
                            "phase": "orchestrate",
                            "phase_order": 2,
                        })
                        # === 阶段3: 数据收集 ===
                        await event_queue.put({
                            "type": "thinking_step",
                            "step_id": tc.id or f"call_{len(tool_calls_buffer)}",
                            "skill_name": tc.name,
                            "display_name": skill_display,
                            "status": "invoking",
                            "message": f"正在调用{skill_display}...",
                            "phase": "collect",
                            "phase_order": 3,
                        })
                        tool_calls_buffer.append(tc)

            # 处理 tool calls
            if tool_calls_buffer:
                assistant_msg = {
                    "role": "assistant",
                    "content": content_buffer or None,
                    "tool_calls": [
                        {
                            "id": tc.id or f"call_{i}",
                            "type": "function",
                            "function": {
                                "name": tc.name,
                                "arguments": json.dumps(tc.arguments, ensure_ascii=False),
                            },
                        }
                        for i, tc in enumerate(tool_calls_buffer)
                    ],
                }
                # Kimi 模型要求：当 assistant 消息包含 tool_calls 时，
                # 必须同时携带 reasoning_content 字段
                if reasoning_buffer:
                    assistant_msg["reasoning_content"] = reasoning_buffer
                messages.append(assistant_msg)

                for tc in tool_calls_buffer:
                    tc_id = tc.id or f"call_{tool_calls_buffer.index(tc)}"
                    try:
                        # 判断是 Skill 还是原始 Tool
                        if tc.name in skill_orchestrator.get_skill_names():
                            result, summary = await skill_orchestrator.execute_skill(
                                tc.name, tc.arguments,
                                user_name=context.user_name,
                                session_id=context.session_id,
                            )
                        else:
                            raw_result = await execute_tool(tc.name, tc.arguments, user_name=context.user_name)
                            result = raw_result  # execute_tool 返回 JSON 字符串
                            summary = f"工具 {tc.name} 执行完成"

                        await event_queue.put({
                            "type": "thinking_step",
                            "step_id": tc_id,
                            "skill_name": tc.name,
                            "display_name": self._skill_display_name(tc.name),
                            "status": "completed",
                            "message": summary if isinstance(summary, str) else str(summary),
                            "phase": "collect",
                            "phase_order": 3,
                        })

                        tool_content = (
                            json.dumps(result.data, ensure_ascii=False)
                            if hasattr(result, 'data')
                            else str(result)
                        )
                    except Exception as e:
                        tool_content = json.dumps({"error": str(e)}, ensure_ascii=False)
                        await event_queue.put({
                            "type": "thinking_step",
                            "step_id": tc_id,
                            "skill_name": tc.name,
                            "display_name": self._skill_display_name(tc.name),
                            "status": "error",
                            "message": f"执行出错: {str(e)}",
                            "phase": "collect",
                            "phase_order": 3,
                        })

                    messages.append({
                        "role": "tool",
                        "tool_call_id": tc_id,
                        "content": tool_content,
                    })

                # Skill编排完成
                await event_queue.put({
                    "type": "thinking_step",
                    "step_id": "phase_orchestrate",
                    "skill_name": "_orchestrator",
                    "display_name": "Skill编排",
                    "status": "completed",
                    "message": f"已完成{len(tool_calls_buffer)}个技能的数据收集",
                    "phase": "orchestrate",
                    "phase_order": 2,
                })

                # === 阶段4: 分析生成 ===
                await event_queue.put({
                    "type": "thinking_step",
                    "step_id": "phase_analyze",
                    "skill_name": "_orchestrator",
                    "display_name": "分析生成",
                    "status": "invoking",
                    "message": "基于收集的数据生成分析报告...",
                    "phase": "analyze",
                    "phase_order": 4,
                })

                await event_queue.put({"type": "thinking_done"})
                max_rounds -= 1
                continue  # 回到循环顶部，继续调 LLM

            # 无 tool_calls，这是最终回复
            # 分析生成完成
            await event_queue.put({
                "type": "thinking_step",
                "step_id": "phase_analyze",
                "skill_name": "_orchestrator",
                "display_name": "分析生成",
                "status": "completed",
                "message": "报告生成完成",
                "phase": "analyze",
                "phase_order": 4,
            })

            conv.add_message("user", context.user_message)
            conv.add_message("assistant", content_buffer)
            await event_queue.put({
                "type": "ai_done",
                "content": content_buffer,
                "is_final": True,
            })
            break

    @staticmethod
    def _skill_display_name(name: str) -> str:
        """技能名称的中文展示名"""
        mapping = {
            "collect_account_data": "查询账户数据",
            "collect_consumption_data": "查询消费统计",
            "collect_product_data": "查询产品库",
            "collect_transaction_data": "查询交易明细",
            "calculate_survival": "计算续航",
            "compute_user_tags": "计算用户标签",
            "financial_planning": "理财规划",
            "consumption_analysis": "消费分析",
            "life_recommendation": "生活推荐",
            "user_profiling": "用户画像",
            "income_forecast": "收入趋势预测",
            "expense_pattern_detector": "消费模式检测",
            "reimbursement_organizer": "报销清单整理",
        }
        return mapping.get(name, name)