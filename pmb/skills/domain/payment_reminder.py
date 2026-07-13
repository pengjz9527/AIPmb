"""待缴费提醒 Skill — 基于历史缴费记录预测近期待缴费任务"""
from datetime import datetime
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client


class PaymentReminderSkill(BaseSkill):
    """待缴费提醒：
    1. 查询用户历史缴费记录
    2. 基于缴费规律预测未来待缴费项（电费、水费、有线电视费等）
    3. 区分已逾期和即将到期的缴费项
    4. 生成自然语言提醒报告
    """

    @property
    def name(self) -> str:
        return "predict_payment_reminders"

    @property
    def description(self) -> str:
        return (
            "预测我近期需要缴纳的账单。基于历史缴费记录分析电费、水费、有线电视费等"
            "周期性缴费规律，预测下一次缴费时间和预估金额，提醒我及时缴费。"
            "当我询问'我要缴费'、'待缴费'、'缴费提醒'、'水电费'、'有什么账单'、"
            "'我的缴费'等问题时调用。"
        )

    @property
    def parameters_schema(self) -> dict:
        return {"type": "object", "properties": {}}

    async def execute(self, **kwargs) -> SkillResult:
        user_name = kwargs.get("user_name", "")
        api = create_client(user_name=user_name)

        # 1. 获取待缴费预测
        forecast, _ = await api.get_payment_forecast()

        # 2. 获取汇总统计（供上下文参考）
        try:
            summary, _ = await api.get_payment_summary()
        except Exception:
            summary = {}

        if not forecast:
            return SkillResult(
                success=True,
                data={
                    "has_pending": False,
                    "message": "当前没有检测到待缴费任务，您的账单清理得很干净！",
                    "summary": summary,
                },
                summary="当前没有预测到的待缴费任务",
            )

        # 3. 按紧急程度分级
        urgent = [f for f in forecast if f.get("is_overdue")]
        upcoming = [f for f in forecast if not f.get("is_overdue")]

        # 4. 生成结构化报告
        total_estimated = sum(f.get("estimated_amount", 0) for f in forecast)
        urgent_amount = sum(f.get("estimated_amount", 0) for f in urgent)

        if urgent:
            urgent_type_names = [f.get("payment_type", "缴费") for f in urgent]
            summary_text = (
                f"您有{len(urgent)}项已逾期待缴费：{'、'.join(urgent_type_names)}，"
                f"合计约 ¥{urgent_amount:.0f}。"
                + (
                    f"另有{len(upcoming)}项即将到期。"
                    if upcoming
                    else ""
                )
                + f"建议尽快缴费。"
            )
        else:
            summary_text = (
                f"您有{len(upcoming)}项即将到期的缴费，预估总金额 ¥{total_estimated:.0f}，"
                f"请提前准备。"
            )

        return SkillResult(
            success=True,
            data={
                "has_pending": True,
                "total_count": len(forecast),
                "urgent_count": len(urgent),
                "upcoming_count": len(upcoming),
                "total_estimated": round(total_estimated, 2),
                "urgent_items": urgent,
                "upcoming_items": upcoming,
                "summary": summary,
                "generated_at": datetime.now().isoformat(),
            },
            summary=summary_text,
        )
