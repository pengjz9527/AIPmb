"""推荐引擎"""
from pmb.profile.tag_engine import tag_engine


class RecommendationEngine:
    """基于用户画像标签的推荐引擎"""

    def generate_todos(self) -> list[dict]:
        """生成待办推荐"""
        from pmb.core import account_service

        todos = []
        all_accounts, _ = account_service.list_accounts(limit=1000)

        for acc in all_accounts:
            at = str(acc.get("账户类型", ""))
            if "信用" in at:
                due = str(acc.get("本期应还金额(元)", "") or "")
                due_day = str(acc.get("到期还款日", "") or "")
                card = str(acc.get("卡种/产品", ""))
                if due and due not in ("0", "0.00", ""):
                    todos.append({
                        "todo_type": "credit_repayment",
                        "title": f"{card}还款提醒",
                        "description": f"本期应还 ¥{due}，还款日：{due_day}",
                        "priority": 10,
                    })

        return todos

    def generate_promos(self) -> list[dict]:
        """生成优惠推荐"""
        tags = tag_engine.compute_tags()
        pref = tags.get("consumption_preference", "")

        promo_map = {
            "餐饮达人": [
                {"title": "美食满减活动", "description": "每周三餐饮消费满100减20", "reason": "基于您的餐饮消费偏好"},
            ],
            "出行达人": [
                {"title": "出行立减优惠", "description": "每周五打车立减5元", "reason": "基于您的出行消费偏好"},
            ],
            "网购达人": [
                {"title": "电商返现活动", "description": "指定电商平台消费返现1%", "reason": "基于您的网购消费偏好"},
            ],
        }

        return promo_map.get(pref, [
            {"title": "新客专享优惠", "description": "首次使用AI银行服务享专属权益", "reason": "新用户专享"},
        ])

    def generate_product_recommendations(self) -> list[dict]:
        """生成产品推荐"""
        from pmb.core import product_service
        tags = tag_engine.compute_tags()
        risk = tags.get("risk_preference", "稳健")

        category_map = {
            "保守": "deposit",
            "稳健": "wealth",
            "进取": "fund",
        }
        category = category_map.get(risk, "wealth")

        products, total = product_service.list_products(category=category, limit=5)
        recommendations = []
        for p in products:
            recommendations.append({
                "name": p.get("产品名称", p.get("产品名称/类别", "")),
                "category": category,
                "type_label": p.get("产品类型", p.get("产品大类", "")),
                "description": p.get("产品描述", ""),
                "risk_level": p.get("风险等级", ""),
                "reason": f"基于您的{risk}型风险偏好推荐",
            })

        return recommendations


# 全局单例
recommendation_engine = RecommendationEngine()
