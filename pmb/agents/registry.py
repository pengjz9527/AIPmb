"""Agent注册表和意图路由分发器"""
from pmb.api.schemas.agent import AgentInfo
from pmb.agents.base import BaseAgent


class AgentRegistry:
    """智能体注册表 + 意图路由分发器"""

    ROUTE_THRESHOLD = 0.2  # 低于此分数路由到通用助手

    def __init__(self):
        self._agents: dict[str, BaseAgent] = {}

    def register(self, agent: BaseAgent):
        """注册智能体"""
        self._agents[agent.agent_id] = agent

    def get_agent(self, agent_id: str) -> BaseAgent | None:
        """按ID获取智能体"""
        return self._agents.get(agent_id)

    def route(self, user_message: str) -> BaseAgent:
        """意图路由：根据用户消息选择最合适的智能体"""
        # 1. 检查显式指定（@智能体名）
        if user_message.startswith("@"):
            for agent in self._agents.values():
                if user_message.startswith(f"@{agent.name}") or user_message.startswith(f"@{agent.agent_id}"):
                    return agent

        # 2. 各Agent评分，取最高分
        best_agent = None
        best_score = 0.0
        for agent in self._agents.values():
            score = agent.can_handle(user_message)
            if score > best_score:
                best_score = score
                best_agent = agent

        # 3. 低于阈值路由到通用助手
        if best_score < self.ROUTE_THRESHOLD or best_agent is None:
            return self._agents.get("general_assistant", list(self._agents.values())[0])

        return best_agent

    def list_agents(self) -> list[AgentInfo]:
        """列出所有可用智能体"""
        return [
            AgentInfo(
                agent_id=agent.agent_id,
                name=agent.name,
                description=agent.description,
                avatar=agent.avatar,
            )
            for agent in self._agents.values()
        ]


# 全局单例
agent_registry = AgentRegistry()


def _register_all_agents():
    """注册所有智能体"""
    from pmb.agents.general_assistant import GeneralAssistantAgent
    from pmb.agents.income_expense_analyst import IncomeExpenseAnalystAgent
    from pmb.agents.financial_planner import FinancialPlannerAgent
    from pmb.agents.user_profiler import UserProfilerAgent
    from pmb.agents.lifestyle_agent import LifestyleAgent

    agent_registry.register(GeneralAssistantAgent())
    agent_registry.register(IncomeExpenseAnalystAgent())
    agent_registry.register(FinancialPlannerAgent())
    agent_registry.register(UserProfilerAgent())
    agent_registry.register(LifestyleAgent())


# 自动注册
_register_all_agents()
