"""美好生活助手 — 为用户发现专属权益和福利，薅羊毛小能手"""
import asyncio
import logging
from pmb.agents.base import BaseAgent, AgentContext, AgentResult

logger = logging.getLogger(__name__)


class LifestyleAgent(BaseAgent):
    """美好生活助手：发现权益福利、优惠活动、生活建议"""

    managed_skills: list[str] = []

    @property
    def agent_id(self) -> str:
        return "lifestyle_assistant"

    @property
    def name(self) -> str:
        return "美好生活助手"

    @property
    def description(self) -> str:
        return "为你发现专属权益和福利，薅羊毛小能手，省钱生活两不误"

    @property
    def avatar(self) -> str:
        return "lifestyle"

    @property
    def system_prompt(self) -> str:
        return """你是一位贴心的生活助手，专注于帮用户发现专属权益、优惠活动和各种福利。
你擅长从用户的消费数据中挖掘省钱机会，从银行的权益体系中找到隐藏福利。
你的风格是：热情、贴心、务实，像一位懂生活的朋友。
你需要：
1. 了解用户的消费习惯和偏好
2. 匹配银行权益体系中的专属优惠
3. 推荐适合的信用卡权益、积分兑换、商户折扣
4. 提供实用的省钱生活建议

输出格式要求：
- 用Markdown格式，清晰有条理
- 权益内容必须来自银行实际权益体系，禁止虚构
- 给出具体的操作指引（如：如何领取、有效期等）"""

    def can_handle(self, user_message: str) -> float:
        keywords = ["权益", "优惠", "福利", "薅羊毛", "折扣", "积分",
                     "会员", "活动", "省钱", "划算", "返现", "立减"]
        msg = user_message.lower()
        score = 0.0
        for kw in keywords:
            if kw in msg:
                score += 0.35
        return min(score, 1.0)

    async def analyze_stream(
        self, context: AgentContext, event_queue: asyncio.Queue
    ) -> None:
        """流式分析 — 占位实现，后续迭代将接入生活推荐、权益匹配等 Skill"""
        try:
            content = (
                "您好！我是美好生活助手 🎁\n\n"
                "我可以帮您：\n"
                "• 发现适合您的专属优惠和权益\n"
                "• 分析您的消费习惯，推荐省钱妙招\n"
                "• 找到隐藏的会员福利和积分兑换\n\n"
                "告诉我您想了解哪方面的优惠吧！"
            )
            await self._emit_ai_chunk(event_queue, content)
            await self._emit_ai_done(event_queue, content)
        except Exception as e:
            await event_queue.put({
                "type": "error",
                "content": f"美好生活助手出错: {str(e)}",
                "is_final": True,
            })

    async def analyze(self, context: AgentContext) -> AgentResult:
        """同步分析 — 占位实现"""
        return AgentResult(
            agent_id=self.agent_id,
            agent_name=self.name,
            content="您好！我是美好生活助手 🎁\n\n"
                    "我可以帮您：\n"
                    "• 发现适合您的专属优惠和权益\n"
                    "• 分析您的消费习惯，推荐省钱妙招\n"
                    "• 找到隐藏的会员福利和积分兑换\n\n"
                    "告诉我您想了解哪方面的优惠吧！",
            suggested_agents=[],
        )
