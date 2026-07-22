"""Agent 智能体模块

导出所有 Agent 类、基类和注册表。

Agent 清单（4个）:
- GeneralAssistantAgent (小易)：入口+兜底，全部 Skill 可用
- IncomeExpenseAnalystAgent (收支分析专家)：收支分析、消费续航、生活推荐
- FinancialPlannerAgent (理财专家)：资产配置、理财产品推荐
- UserProfilerAgent (画像分析师)：用户画像、邻里画像
"""
from pmb.agents.base import BaseAgent, AgentContext, AgentResult, AgentCard
from pmb.agents.general_assistant import GeneralAssistantAgent
from pmb.agents.income_expense_analyst import IncomeExpenseAnalystAgent
from pmb.agents.financial_planner import FinancialPlannerAgent
from pmb.agents.user_profiler import UserProfilerAgent
from pmb.agents.registry import AgentRegistry, agent_registry

__all__ = [
    "BaseAgent",
    "AgentContext",
    "AgentResult",
    "AgentCard",
    "GeneralAssistantAgent",
    "IncomeExpenseAnalystAgent",
    "FinancialPlannerAgent",
    "UserProfilerAgent",
    "AgentRegistry",
    "agent_registry",
]
