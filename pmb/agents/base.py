"""Agent基类定义"""
import json
import asyncio
import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any

from pmb.llm.tool_registry import ALL_TOOLS

logger = logging.getLogger(__name__)


@dataclass
class AgentContext:
    """智能体上下文，跨Agent共享"""
    session_id: str
    user_message: str
    user_name: str = ""            # 用户标识（用于长期记忆关联）
    memory_summary: str = ""       # 历史对话记忆摘要（注入 system prompt）
    conversation_history: list[dict] = field(default_factory=list)
    user_profile: dict | None = None
    account_summary: dict | None = None
    consumption_stats: dict | None = None


@dataclass
class AgentCard:
    """结构化卡片数据"""
    card_type: str
    title: str
    data: Any = None


@dataclass
class AgentResult:
    """智能体输出结果"""
    agent_id: str
    agent_name: str
    content: str
    cards: list[dict] = field(default_factory=list)
    suggested_agents: list[str] = field(default_factory=list)
    metadata: dict = field(default_factory=dict)
    next_suggestions: list[dict] = field(default_factory=list)


class BaseAgent(ABC):
    """智能体基类，所有Agent必须继承"""

    @property
    @abstractmethod
    def agent_id(self) -> str:
        """智能体唯一标识"""

    @property
    @abstractmethod
    def name(self) -> str:
        """智能体显示名称"""

    @property
    @abstractmethod
    def description(self) -> str:
        """智能体能力描述"""

    @property
    @abstractmethod
    def avatar(self) -> str:
        """智能体头像标识"""

    @property
    @abstractmethod
    def system_prompt(self) -> str:
        """专属System Prompt"""

    @property
    def tools(self) -> list[dict]:
        """该智能体可使用的Function Calling工具定义"""
        return ALL_TOOLS

    # 该 Agent 管理的 Skill 列表，None 表示全部可用
    managed_skills: list[str] | None = None

    @abstractmethod
    async def analyze_stream(
        self, context: AgentContext, event_queue: asyncio.Queue
    ) -> None:
        """流式分析方法 — 子类必须实现。
        通过 event_queue 发送事件：thinking_step / reasoning_chunk / ai_chunk / ai_done / agent_changed / error
        """

    async def analyze(self, context: AgentContext) -> AgentResult:
        """同步分析方法 — 基类默认实现，内部包装 analyze_stream"""
        queue = asyncio.Queue()
        await self.analyze_stream(context, queue)
        return AgentResult(
            agent_id=self.agent_id,
            agent_name=self.name,
            content="",
            cards=[],
        )

    def can_handle(self, user_message: str) -> float:
        """意图匹配度评分（0.0~1.0），子类可覆盖"""
        return 0.0

    async def _collect_data(self, context: AgentContext) -> dict:
        """收集基础数据，子类可扩展"""
        from pmb.core import account_service, consumption_service

        data = {}
        user_name = context.user_name

        if context.account_summary is None:
            summary = account_service.get_account_summary(user_name=user_name)
            context.account_summary = dict(summary)
        data["account_summary"] = context.account_summary

        if context.consumption_stats is None:
            stats = consumption_service.get_consumption_stats(group_by="subcategory", top=10, user_name=user_name)
            context.consumption_stats = stats
        data["consumption_stats"] = context.consumption_stats

        return data

    async def _call_llm(
        self,
        context: AgentContext,
        enhanced_prompt: str,
        business_rules_text: str = "",
    ) -> str:
        """调用LLM生成分析结果（非流式，保留给旧调用方兼容）"""
        from pmb.llm.qwen import QwenLLM
        from pmb.llm.context_manager import context_manager

        conv = context_manager.get_or_create(context.session_id)

        enhanced_system_prompt = self.system_prompt
        if business_rules_text:
            enhanced_system_prompt += f"\n\n## 业务规则约束\n{business_rules_text}"
        conv.set_system_prompt(enhanced_system_prompt)

        messages = conv.get_messages()
        messages.append({"role": "user", "content": enhanced_prompt})

        llm = QwenLLM()
        response = await llm.chat(messages=messages, tools=self.tools)

        max_rounds = 5
        while response.tool_calls and max_rounds > 0:
            from pmb.llm.tool_registry import execute_tool
            assistant_msg = {"role": "assistant", "content": response.content, "tool_calls": [
                {"id": tc.id, "type": "function", "function": {"name": tc.name, "arguments": json.dumps(tc.arguments, ensure_ascii=False)}}
                for tc in response.tool_calls
            ]}
            if hasattr(response, 'reasoning_content') and response.reasoning_content:
                assistant_msg["reasoning_content"] = response.reasoning_content
            messages.append(assistant_msg)

            for tc in response.tool_calls:
                result = await execute_tool(tc.name, tc.arguments)
                messages.append({
                    "role": "tool",
                    "tool_call_id": tc.id,
                    "content": result,
                })

            response = await llm.chat(messages=messages, tools=self.tools)
            max_rounds -= 1

        conv.add_message("user", context.user_message)
        conv.add_message("assistant", response.content)

        return response.content

    # ===== 流式管线：公共 emit 事件方法 =====

    @staticmethod
    async def _emit_thinking_step(
        event_queue: asyncio.Queue,
        step_id: str,
        display_name: str,
        status: str,
        message: str,
        skill_name: str = "",
        phase: str = "",
        phase_order: int = 0,
    ) -> None:
        """发送 thinking_step 事件"""
        await event_queue.put({
            "type": "thinking_step",
            "step_id": step_id,
            "skill_name": skill_name or step_id,
            "display_name": display_name,
            "status": status,
            "message": message,
            "phase": phase,
            "phase_order": phase_order,
        })

    @staticmethod
    async def _emit_ai_chunk(event_queue: asyncio.Queue, content: str) -> None:
        """发送 ai_chunk 事件"""
        await event_queue.put({
            "type": "ai_chunk",
            "content": content,
            "is_final": False,
        })

    @staticmethod
    async def _emit_reasoning_chunk(event_queue: asyncio.Queue, content: str) -> None:
        """发送 reasoning_chunk 事件"""
        await event_queue.put({
            "type": "reasoning_chunk",
            "content": content,
        })

    @staticmethod
    async def _emit_ai_done(
        event_queue: asyncio.Queue,
        content: str,
        next_suggestions: list[dict] | None = None,
    ) -> None:
        """发送 ai_done 事件"""
        await event_queue.put({
            "type": "ai_done",
            "content": content,
            "is_final": True,
            "next_suggestions": next_suggestions or [],
        })

    @staticmethod
    async def _emit_thinking_done(event_queue: asyncio.Queue) -> None:
        """发送 thinking_done 事件"""
        await event_queue.put({"type": "thinking_done"})

    # ===== 流式管线：核心 LLM + Tool/Skill 执行循环 =====

    async def _run_llm_loop(
        self,
        context: AgentContext,
        event_queue: asyncio.Queue,
        messages: list[dict],
        tools: list[dict],
        skill_orchestrator,
        step_id_prefix: str = "",
        max_rounds: int = 5,
    ) -> tuple[str, dict]:
        """核心流式 LLM + Tool/Skill 执行循环。

        发送五阶段 thinking_step 事件（意图识别→Skill编排→数据收集→分析生成→建议生成），
        自动处理 tool_calls（区分 Skill 和原始 Tool），返回 (final_content, collected_skill_data)。

        Returns:
            (content_buffer, collected_skill_data): 最终LLM生成的文本和收集的Skill数据
        """
        from pmb.llm.qwen import QwenLLM
        from pmb.llm.tool_registry import execute_tool

        llm = QwenLLM()
        content_buffer = ""
        collected_skill_data: dict = {}
        pid = step_id_prefix

        # === 阶段1: 意图识别 ===
        await self._emit_thinking_step(
            event_queue, f"phase_intent_{pid}", "意图识别", "invoking",
            "分析用户问题，识别服务意图...", phase="intent", phase_order=1,
        )

        while max_rounds > 0:
            stream = llm.chat_stream(messages=messages, tools=tools)
            reasoning_buffer = ""
            tool_calls_buffer: list = []
            intent_identified = False

            async for chunk in stream:
                if chunk.reasoning_content:
                    reasoning_buffer += chunk.reasoning_content
                    await self._emit_reasoning_chunk(event_queue, chunk.reasoning_content)

                if chunk.content:
                    content_buffer += chunk.content
                    await self._emit_ai_chunk(event_queue, chunk.content)

                if chunk.tool_calls:
                    if not intent_identified:
                        intent_identified = True
                        skill_display = self._skill_display_name(chunk.tool_calls[0].name)
                        await self._emit_thinking_step(
                            event_queue, f"phase_intent_{pid}", "意图识别", "completed",
                            f"识别到意图：需要调用{skill_display}技能", phase="intent", phase_order=1,
                        )
                        # === 阶段2: Skill编排 ===
                        await self._emit_thinking_step(
                            event_queue, f"phase_orchestrate_{pid}", "Skill编排", "invoking",
                            f"编排执行计划：调用{skill_display}获取数据...", phase="orchestrate", phase_order=2,
                        )
                    for tc in chunk.tool_calls:
                        await self._emit_thinking_step(
                            event_queue, tc.id or f"call_{len(tool_calls_buffer)}",
                            self._skill_display_name(tc.name), "invoking",
                            f"正在调用{self._skill_display_name(tc.name)}...",
                            skill_name=tc.name, phase="collect", phase_order=3,
                        )
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
                if reasoning_buffer:
                    assistant_msg["reasoning_content"] = reasoning_buffer
                messages.append(assistant_msg)

                for tc in tool_calls_buffer:
                    tc_id = tc.id or f"call_{len(collected_skill_data)}"
                    try:
                        if tc.name in skill_orchestrator.get_skill_names():
                            result, summary = await skill_orchestrator.execute_skill(
                                tc.name, tc.arguments,
                                user_name=context.user_name,
                                session_id=context.session_id,
                            )
                            collected_skill_data[tc.name] = result.data if hasattr(result, 'data') else {}
                        else:
                            raw_result = await execute_tool(tc.name, tc.arguments, user_name=context.user_name)
                            result = raw_result
                            summary = f"工具 {tc.name} 执行完成"

                        await self._emit_thinking_step(
                            event_queue, tc_id, self._skill_display_name(tc.name), "completed",
                            str(summary), skill_name=tc.name, phase="collect", phase_order=3,
                        )

                        tool_content = (
                            json.dumps(result.data, ensure_ascii=False)
                            if hasattr(result, 'data')
                            else str(result)
                        )
                    except Exception as e:
                        tool_content = json.dumps({"error": str(e)}, ensure_ascii=False)
                        await self._emit_thinking_step(
                            event_queue, tc_id, self._skill_display_name(tc.name), "error",
                            f"执行出错: {str(e)}", skill_name=tc.name, phase="collect", phase_order=3,
                        )

                    messages.append({
                        "role": "tool",
                        "tool_call_id": tc_id,
                        "content": tool_content,
                    })

                # Skill编排完成
                await self._emit_thinking_step(
                    event_queue, f"phase_orchestrate_{pid}", "Skill编排", "completed",
                    f"已完成{len(tool_calls_buffer)}个技能的数据收集", phase="orchestrate", phase_order=2,
                )
                # === 阶段4: 分析生成 ===
                await self._emit_thinking_step(
                    event_queue, f"phase_analyze_{pid}", "分析生成", "invoking",
                    "基于收集的数据生成分析报告...", phase="analyze", phase_order=4,
                )
                await self._emit_thinking_done(event_queue)
                content_buffer = ""  # 重置，因为 LLM 接下来会输出新的分析内容
                max_rounds -= 1
                continue

            # 无 tool_calls，最终回复
            await self._emit_thinking_step(
                event_queue, f"phase_analyze_{pid}", "分析生成", "completed",
                "报告生成完成", phase="analyze", phase_order=4,
            )
            break

        return content_buffer, collected_skill_data

    @staticmethod
    def _skill_display_name(name: str) -> str:
        """技能名称的中文展示名 — 子类可覆盖扩展"""
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
            "neighborhood_profiler": "邻里画像",
            "loan_cost_optimizer": "贷款成本优化",
            "loan_product_recommendation": "贷款产品推荐",
            "knowledge_search": "知识搜索",
            "hidden_habits_explorer": "隐秘习惯探索",
            "payment_reminder": "缴费提醒",
            "history_today": "往年今日",
            "marketing_lead_analyzer": "营销线索分析",
        }
        return mapping.get(name, name)
