"""Agent基类定义"""
import json
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any

from pmb.llm.tool_registry import ALL_TOOLS


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

    @abstractmethod
    async def analyze(self, context: AgentContext) -> AgentResult:
        """核心分析方法"""

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
        """调用LLM生成分析结果

        Args:
            context: Agent上下文
            enhanced_prompt: 增强后的用户prompt
            business_rules_text: 业务规则约束文本（注入 system_prompt）
        """
        from pmb.llm.qwen import QwenLLM
        from pmb.llm.context_manager import context_manager

        conv = context_manager.get_or_create(context.session_id)

        # 将业务规则约束注入 system_prompt
        enhanced_system_prompt = self.system_prompt
        if business_rules_text:
            enhanced_system_prompt += f"\n\n## 业务规则约束\n{business_rules_text}"
        conv.set_system_prompt(enhanced_system_prompt)

        # 注入增强prompt作为用户消息
        messages = conv.get_messages()
        messages.append({"role": "user", "content": enhanced_prompt})

        llm = QwenLLM()  # 自动从 .env 加载 API Key
        response = await llm.chat(messages=messages, tools=self.tools)

        # 处理tool calls
        max_rounds = 5
        while response.tool_calls and max_rounds > 0:
            from pmb.llm.tool_registry import execute_tool
            # Kimi 推理模型需要保留 reasoning_content
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

        # 保存到上下文
        conv.add_message("user", context.user_message)
        conv.add_message("assistant", response.content)

        return response.content
