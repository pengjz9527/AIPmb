"""用户标签计算 Skill"""
from pmb.skills.base import BaseSkill, SkillResult


class ComputeUserTagsSkill(BaseSkill):

    @property
    def name(self) -> str:
        return "compute_user_tags"

    @property
    def description(self) -> str:
        return "基于消费统计和账户数据计算用户画像标签。当用户询问画像、我是谁、消费人格时调用。"

    @property
    def parameters_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "subcategory_stats": {"type": "string", "description": "消费子类统计数据（JSON字符串）"},
                "channel_stats": {"type": "string", "description": "支付渠道统计数据（JSON字符串）"},
                "merchant_stats": {"type": "string", "description": "常去商户统计数据（JSON字符串）"},
                "monthly_stats": {"type": "string", "description": "月度消费统计数据（JSON字符串）"},
            },
        }

    async def execute(self, **kwargs) -> SkillResult:
        import json

        subcategory_stats = self._parse_json(kwargs.get("subcategory_stats", "[]"))
        channel_stats = self._parse_json(kwargs.get("channel_stats", "[]"))
        merchant_stats = self._parse_json(kwargs.get("merchant_stats", "[]"))
        monthly_stats = self._parse_json(kwargs.get("monthly_stats", "[]"))

        tags = []

        # 消费偏好标签
        if subcategory_stats:
            top_cat = subcategory_stats[0].get("name", "")
            if any(k in top_cat for k in ["餐饮", "美食"]):
                tags.append("餐饮达人")
            elif any(k in top_cat for k in ["出行", "交通", "铁路"]):
                tags.append("出行达人")
            elif any(k in top_cat for k in ["网购", "电商", "数码"]):
                tags.append("数码达人")
            else:
                tags.append(f"{top_cat}爱好者")

        # 渠道偏好
        if channel_stats:
            top_channel = channel_stats[0].get("name", "")
            tags.append(f"{top_channel}偏好")

        # 常去商户
        if merchant_stats:
            tags.append(f"常去{merchant_stats[0].get('name', '未知商户')}")

        # 消费稳定性
        if monthly_stats and len(monthly_stats) > 1:
            amounts = [s.get("total", 0) for s in monthly_stats]
            avg = sum(amounts) / len(amounts)
            variance = sum((a - avg) ** 2 for a in amounts) / len(amounts)
            if variance < avg * avg * 0.1:
                tags.append("稳定型消费者")
            else:
                tags.append("波动型消费者")

        return SkillResult(
            success=True,
            data={"tags": tags, "count": len(tags)},
            summary=f"已生成{len(tags)}个用户标签：{', '.join(tags[:3])}",
        )

    @staticmethod
    def _parse_json(raw) -> list:
        import json
        if isinstance(raw, list):
            return raw
        try:
            return json.loads(raw)
        except (json.JSONDecodeError, TypeError):
            return []