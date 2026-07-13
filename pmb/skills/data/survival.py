"""续航计算 Skill — 纯计算，不依赖外部服务"""
from pmb.skills.base import BaseSkill, SkillResult


class CalculateSurvivalSkill(BaseSkill):

    @property
    def name(self) -> str:
        return "calculate_survival"

    @property
    def description(self) -> str:
        return "计算用户在没有收入的情况下能撑多久。需要先调用 collect_account_data 和 collect_consumption_data 获取数据后使用。"

    @property
    def parameters_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "total_assets": {"type": "number", "description": "总可用资金（借记卡余额 - 信用卡应还）"},
                "total_liabilities": {"type": "number", "description": "总负债（信用卡应还）"},
                "monthly_avg_expense": {"type": "number", "description": "月均消费金额"},
                "minimal_monthly_expense": {"type": "number", "description": "最低生存月消费（仅必需类）"},
            },
            "required": ["total_assets", "monthly_avg_expense"],
        }

    async def execute(self, **kwargs) -> SkillResult:
        total_assets = float(kwargs.get("total_assets", 0))
        total_liabilities = float(kwargs.get("total_liabilities", 0))
        monthly_avg = float(kwargs.get("monthly_avg_expense", 0))
        minimal_monthly = float(kwargs.get("minimal_monthly_expense", 0))

        available = total_assets - total_liabilities

        if monthly_avg <= 0:
            return SkillResult(
                success=True,
                data={"available_funds": round(available, 2), "error": "月均消费为0，无法计算"},
                summary="月均消费为0，无法计算续航",
            )

        months_current = available / monthly_avg

        if minimal_monthly > 0:
            months_minimal = available / minimal_monthly
        else:
            months_minimal = available / (monthly_avg * 0.5)  # 假设最低为50%

        return SkillResult(
            success=True,
            data={
                "available_funds": round(available, 2),
                "total_assets": round(total_assets, 2),
                "total_liabilities": round(total_liabilities, 2),
                "monthly_avg_expense": round(monthly_avg, 2),
                "months_current_standard": round(months_current, 1),
                "months_minimal_standard": round(months_minimal, 1),
            },
            summary=f"不降标准续航 {months_current:.1f} 个月，最低生存 {months_minimal:.1f} 个月",
        )