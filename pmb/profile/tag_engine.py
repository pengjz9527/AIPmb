"""用户画像标签引擎"""
from pmb.core import account_service, consumption_service


class TagEngine:
    """标签计算引擎"""

    def __init__(self):
        self._cache: dict[str, dict] = {}

    def clear_cache(self):
        """清除标签缓存，用于用户重新登录时重新计算"""
        self._cache = {}

    def compute_tags(self, user_name: str = "") -> dict:
        """计算用户画像标签"""
        if user_name and user_name in self._cache:
            return self._cache[user_name]

        tags = {}

        # 1. 资产等级
        all_accounts, _ = account_service.list_accounts(user_name=user_name, limit=1000)
        total_balance = 0.0
        for acc in all_accounts:
            at = str(acc.get("账户类型", ""))
            if "借记" in at:
                try:
                    total_balance += float(acc.get("最新余额(元)", 0) or 0)
                except (TypeError, ValueError):
                    pass

        if total_balance > 500000:
            tags["asset_level"] = "高净值"
        elif total_balance > 100000:
            tags["asset_level"] = "中产"
        else:
            tags["asset_level"] = "基础"

        # 2. 消费偏好
        sub_stats = consumption_service.get_consumption_stats(group_by="subcategory", top=3, user_name=user_name)
        if sub_stats:
            top = sub_stats[0]["name"]
            if any(k in top for k in ["餐饮", "美食"]):
                tags["consumption_preference"] = "餐饮达人"
            elif any(k in top for k in ["出行", "交通", "网约车"]):
                tags["consumption_preference"] = "出行达人"
            elif any(k in top for k in ["网购", "电商"]):
                tags["consumption_preference"] = "网购达人"
            else:
                tags["consumption_preference"] = f"{top}偏好"

        # 3. 消费水平
        monthly_stats = consumption_service.get_consumption_stats(group_by="month", top=6, user_name=user_name)
        if monthly_stats:
            avg = sum(s["total"] for s in monthly_stats) / len(monthly_stats)
            if avg > 8000:
                tags["consumption_level"] = "高消费"
            elif avg > 3000:
                tags["consumption_level"] = "中等消费"
            else:
                tags["consumption_level"] = "低消费"

        # 4. 风险偏好
        tags["risk_preference"] = "稳健"  # MVP简化

        # 5. 渠道偏好
        channel_stats = consumption_service.get_consumption_stats(group_by="channel", top=3, user_name=user_name)
        if channel_stats:
            tags["channel_preference"] = channel_stats[0]["name"]

        # 6. Top消费类别
        tags["top_categories"] = [s["name"] for s in sub_stats[:5]] if sub_stats else []

        # 综合标签列表
        tag_list = [v for v in tags.values() if isinstance(v, str)]
        tags["tags"] = tag_list

        if user_name:
            self._cache[user_name] = tags
        else:
            self._cache = {"_default": tags}
        return tags


# 全局单例
tag_engine = TagEngine()
