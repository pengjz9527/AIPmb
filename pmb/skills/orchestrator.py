"""Skill 编排器 — 注册所有 Skill，生成 LLM 工具列表，执行技能"""
import asyncio
import json
import time
import uuid
from datetime import datetime, timezone
from pmb.skills.base import BaseSkill, SkillResult


class SkillOrchestrator:
    """技能编排器：注册/工具生成/执行"""

    # Agent 管理的 Skill 名称集合（不在前端独立展示）
    AGENT_MANAGED_SKILLS = {'consumption_analysis', 'income_forecast'}

    def __init__(self):
        self._skills: dict[str, BaseSkill] = {}

    def register(self, skill: BaseSkill):
        """注册 Skill"""
        self._skills[skill.name] = skill

    def to_openai_tools(self) -> list[dict]:
        """生成 OpenAI function calling 工具定义列表"""
        return [s.tool_definition for s in self._skills.values()]

    def get_skill_names(self) -> list[str]:
        """获取所有已注册 Skill 名称"""
        return list(self._skills.keys())

    def get_skill_labels(self) -> list[dict]:
        """获取所有 Skill 的中文标签，返回 [{name, label}]。

        label 从 description 的第一句提取，截断至 30 字。
        """
        results = []
        for skill in self._skills.values():
            desc = skill.description
            label = desc.split("。")[0].strip()
            if len(label) > 30:
                label = label[:28] + "..."
            results.append({
                "name": skill.name,
                "label": label,
            })
        return results

    def get_domain_skills(self) -> list[dict]:
        """获取所有领域层 Skill 的展示信息（用于前端快捷卡片）

        返回列表，每项包含：
        - name: Skill 名称（function name）
        - description: Skill 能力描述
        - label: 用户友好的中文标签（从 description 提取第一句）
        """
        domain_prefixes = ("collect_", "compute_", "calculate_")
        results = []
        for skill in self._skills.values():
            # 过滤掉数据收集层 Skill，只保留领域层
            if any(skill.name.startswith(p) for p in domain_prefixes):
                continue
            # 过滤掉已由 Agent 统一管理的 Skill
            if skill.name in self.AGENT_MANAGED_SKILLS:
                continue
            desc = skill.description
            # 从 description 提取第一句作为 label
            label = desc.split("。")[0].strip()
            if len(label) > 20:
                label = label[:18] + "..."
            results.append({
                "name": skill.name,
                "description": desc,
                "label": label,
            })
        return results

    async def execute_skill(self, name: str, arguments: dict, user_name: str = "", session_id: str = "") -> tuple[SkillResult, str]:
        """
        执行技能，返回 (SkillResult, summary_text)。
        summary_text 用于前端 thinking 面板展示。
        session_id 用于技能监控日志关联。
        """
        start_time = time.perf_counter()
        skill = self._skills.get(name)
        log_id = str(uuid.uuid4())[:8]

        if skill is None:
            duration_ms = int((time.perf_counter() - start_time) * 1000)
            asyncio.create_task(self._write_skill_log(
                log_id=log_id, skill_name=name, user_name=user_name,
                session_id=session_id, duration_ms=duration_ms,
                success=False, error_message=f"未知技能: {name}",
                arguments=arguments, result_summary="", api_traces=[],
            ))
            return (
                SkillResult(success=False, error=f"未知技能: {name}"),
                f"未知技能: {name}",
            )

        try:
            from pmb.ai_manage.services.skill_monitor_service import start_trace, stop_trace
            start_trace()
            result = await skill.execute(user_name=user_name, **arguments)
            api_traces = stop_trace()
            summary = result.summary if result.summary else f"技能 {name} 执行完成"
            duration_ms = int((time.perf_counter() - start_time) * 1000)
            asyncio.create_task(self._write_skill_log(
                log_id=log_id, skill_name=name, user_name=user_name,
                session_id=session_id, duration_ms=duration_ms,
                success=True, error_message="",
                arguments=arguments, result_summary=summary,
                api_traces=api_traces,
            ))
            return result, summary
        except Exception as e:
            api_traces = []
            try:
                from pmb.ai_manage.services.skill_monitor_service import stop_trace
                api_traces = stop_trace()
            except Exception:
                pass
            duration_ms = int((time.perf_counter() - start_time) * 1000)
            asyncio.create_task(self._write_skill_log(
                log_id=log_id, skill_name=name, user_name=user_name,
                session_id=session_id, duration_ms=duration_ms,
                success=False, error_message=str(e),
                arguments=arguments, result_summary="",
                api_traces=api_traces,
            ))
            return (
                SkillResult(success=False, error=str(e)),
                f"技能 {name} 执行出错: {str(e)}",
            )

    @staticmethod
    async def _write_skill_log(log_id: str, skill_name: str, user_name: str,
                         session_id: str, duration_ms: int, success: bool,
                         error_message: str, arguments: dict,
                         result_summary: str, api_traces: list):
        """异步写入技能日志 — 卸载到线程池，不阻塞 skill 执行"""
        from pmb.ai_manage.store import read_json, write_json

        STORE_FILE = "skill_logs.json"
        log_entry = {
            "id": log_id,
            "skill_name": skill_name,
            "user_name": user_name,
            "session_id": session_id,
            "invoked_at": datetime.now(timezone.utc).isoformat(),
            "duration_ms": duration_ms,
            "success": success,
            "error_message": error_message,
            "arguments": {
                k: str(v)[:200] if isinstance(v, (dict, list)) else v
                for k, v in arguments.items()
            },
            "result_summary": result_summary[:200] if result_summary else "",
            "api_traces": api_traces,
        }

        def _do_write():
            logs = read_json(STORE_FILE)
            if isinstance(logs, dict):
                logs = []
            logs.append(log_entry)
            if len(logs) > 10000:
                logs = logs[-10000:]
            write_json(STORE_FILE, logs)

        try:
            await asyncio.to_thread(_do_write)
        except Exception:
            pass  # 日志写入失败不应影响 Skill 执行


def _register_all_skills():
    """注册所有 Skill（细粒度 + 粗粒度）"""
    from pmb.skills.data.account import CollectAccountDataSkill
    from pmb.skills.data.consumption import CollectConsumptionDataSkill
    from pmb.skills.data.product import CollectProductDataSkill
    from pmb.skills.data.transaction import CollectTransactionDataSkill
    from pmb.skills.data.survival import CalculateSurvivalSkill
    from pmb.skills.data.tags import ComputeUserTagsSkill
    from pmb.skills.domain.financial_planning import FinancialPlanningSkill
    from pmb.skills.domain.consumption_analysis import ConsumptionAnalysisSkill
    from pmb.skills.domain.life_recommendation import LifeRecommendationSkill
    from pmb.skills.domain.user_profiling import UserProfilingSkill
    from pmb.skills.domain.neighborhood import NeighborhoodProfilerSkill
    from pmb.skills.domain.income_forecast import IncomeForecastSkill
    from pmb.skills.domain.loan_cost_optimizer import LoanCostOptimizerSkill
    from pmb.skills.domain.loan_product_recommendation import LoanProductRecommendationSkill
    from pmb.skills.domain.history_today import HistoryTodaySkill
    from pmb.skills.domain.hidden_habits_explorer import HiddenHabitsExplorerSkill
    from pmb.skills.domain.payment_reminder import PaymentReminderSkill
    from pmb.skills.domain.marketing_lead_analyzer import MarketingLeadAnalyzerSkill
    from pmb.skills.domain.expense_pattern_detector import ExpensePatternDetectorSkill
    from pmb.skills.domain.reimbursement_organizer import ReimbursementOrganizerSkill
    from pmb.skills.domain.knowledge_search import KnowledgeSearchSkill

    orchestrator = SkillOrchestrator()
    orchestrator.register(CollectAccountDataSkill())
    orchestrator.register(CollectConsumptionDataSkill())
    orchestrator.register(CollectProductDataSkill())
    orchestrator.register(CollectTransactionDataSkill())
    orchestrator.register(CalculateSurvivalSkill())
    orchestrator.register(ComputeUserTagsSkill())
    orchestrator.register(FinancialPlanningSkill())
    orchestrator.register(ConsumptionAnalysisSkill())
    orchestrator.register(LifeRecommendationSkill())
    orchestrator.register(UserProfilingSkill())
    orchestrator.register(NeighborhoodProfilerSkill())
    orchestrator.register(IncomeForecastSkill())
    orchestrator.register(LoanCostOptimizerSkill())
    orchestrator.register(LoanProductRecommendationSkill())
    orchestrator.register(HistoryTodaySkill())
    orchestrator.register(HiddenHabitsExplorerSkill())
    orchestrator.register(PaymentReminderSkill())
    orchestrator.register(MarketingLeadAnalyzerSkill())
    orchestrator.register(ExpensePatternDetectorSkill())
    orchestrator.register(ReimbursementOrganizerSkill())
    orchestrator.register(KnowledgeSearchSkill())
    return orchestrator


# 全局单例
skill_orchestrator = _register_all_skills()