"""营销线索分析 Skill — 从最近一周对话中挖掘金融服务需求和营销机会"""
import json
from datetime import datetime, timedelta, timezone
from pmb.skills.base import BaseSkill, SkillResult

MARKETING_LEAD_PROMPT = """你是一位资深的银行营销专家。请根据用户最近一周的AI对话内容和用户标签，分析并预测用户的金融服务需求，生成可执行的营销线索。

## 输入信息
- **用户标签**：反映用户的消费习惯、资产状况、风险偏好等
- **近期对话**：用户与AI助手最近一周的对话记录，包含用户的问题和AI的回复

## 分析维度
1. **需求信号**：从对话中识别用户提到或暗示的金融需求（如"想理财"、"贷款利率高"、"信用卡额度不够"等）
2. **生命周期推断**：根据对话内容和标签推断用户所处的人生阶段和财务状况
3. **产品匹配**：结合银行产品体系，推荐最匹配的金融产品或服务
4. **权益推荐**：推荐符合用户需求的银行权益、优惠活动

## 输出格式（严格 JSON）
{
  "user_insight": "用户整体画像一句话总结（30字以内）",
  "leads": [
    {
      "lead_type": "产品推荐",
      "lead_name": "具体产品名称",
      "category": "理财/贷款/保险/基金/存款/信用卡/外汇/黄金/权益",
      "reason": "为什么推荐（结合对话内容和标签，50字以内）",
      "priority": "高",
      "suggested_action": "建议的话术或行动（30字以内）"
    }
  ]
}

## 要求
- leads 数量 3-5 条
- priority 分"高"/"中"/"低"三档
- 推荐要有数据依据，不要凭空猜测
- 语言简洁专业，适合运营人员直接使用
- 如果用户对话中无明显金融需求，也要根据标签推断潜在需求"""


class MarketingLeadAnalyzerSkill(BaseSkill):

    @property
    def name(self) -> str:
        return "marketing_lead_analyzer"

    @property
    def description(self) -> str:
        return "分析用户近一周的对话记录，结合用户标签预测金融服务需求，生成可营销的线索（产品推荐、权益推荐、服务建议等）"

    @property
    def parameters_schema(self) -> dict:
        return {"type": "object", "properties": {}}

    async def execute(self, **kwargs) -> SkillResult:
        user_name = kwargs.get("user_name", "")

        # 1. 收集用户标签
        from pmb.ai_manage.services import tagging_service
        tags_data = tagging_service.get_tags_for_user(user_name)
        tags = []
        if tags_data is not None:
            for t in tags_data.tags:
                if isinstance(t, dict):
                    name = t.get("name", "")
                    if name:
                        tags.append(name)

        # 2. 收集近一周对话
        from pmb.ai_manage.services.conversation_service import (
            list_conversations, get_session_detail, _flatten_messages_to_text,
        )
        from pmb.ai_manage.services.conversation_service import _safe_iso_to_dt

        now = datetime.now(timezone.utc)
        one_week_ago = now - timedelta(days=7)

        # 获取用户所有对话，按时间倒序
        all_items, _ = list_conversations(
            user_name=user_name,
            limit=100,
            offset=0,
        )

        # 筛选最近一周的对话
        recent_sessions = []
        for item in all_items:
            started_at = item.get("started_at", "")
            dt = _safe_iso_to_dt(started_at)
            if dt and dt >= one_week_ago:
                recent_sessions.append(item)

        # 如果没有一周内的对话，取最近的 3 条
        if not recent_sessions:
            recent_sessions = all_items[:3]

        if not recent_sessions:
            return SkillResult(
                success=True,
                data={
                    "user_name": user_name,
                    "user_insight": "暂无对话记录",
                    "leads": [],
                    "conversation_count": 0,
                },
                summary="无对话记录，无法生成营销线索",
            )

        # 3. 提取对话内容摘要
        conversation_texts = []
        for session in recent_sessions:
            session_id = session.get("session_id", "")
            detail = get_session_detail(user_name, session_id)
            if detail:
                messages = detail.get("messages", [])
                text = _flatten_messages_to_text(messages)
                # 截取前 1500 字，避免输入过长
                if len(text) > 1500:
                    text = text[:1500] + "..."
                conversation_texts.append(f"--- 会话 ({session.get('started_at', '')[:10]}) ---\n{text}")

        combined_text = "\n\n".join(conversation_texts)
        if len(combined_text) > 6000:
            combined_text = combined_text[:6000] + "..."

        # 4. 调用 LLM 分析
        llm_input = f"""用户标签：{'、'.join(tags) if tags else '暂无标签'}

近期对话（共{len(recent_sessions)}次）：
{combined_text}"""

        try:
            from pmb.llm.qwen import QwenLLM
            llm = QwenLLM()
            response = await llm.chat(
                messages=[
                    {"role": "system", "content": MARKETING_LEAD_PROMPT},
                    {"role": "user", "content": llm_input},
                ],
                temperature=0.5,
            )
            content = response.content.strip()
        except Exception as llm_err:
            return SkillResult(
                success=False,
                error=f"LLM 调用失败: {str(llm_err)[:100]}",
            )

        # 5. 解析 LLM 输出
        try:
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0].strip()
            elif "```" in content:
                content = content.split("```")[1].split("```")[0].strip()
            parsed = json.loads(content)
        except (json.JSONDecodeError, IndexError):
            parsed = {
                "user_insight": "分析生成中遇到格式问题",
                "leads": [],
            }

        leads = parsed.get("leads", [])
        user_insight = parsed.get("user_insight", "")

        return SkillResult(
            success=True,
            data={
                "user_name": user_name,
                "user_insight": user_insight,
                "leads": leads,
                "conversation_count": len(recent_sessions),
                "tags_used": tags,
            },
            summary=f"基于近一周 {len(recent_sessions)} 次对话 + {len(tags)} 个标签，生成 {len(leads)} 条营销线索",
        )
