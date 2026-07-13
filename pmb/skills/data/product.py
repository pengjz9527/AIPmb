"""收集产品数据 Skill"""
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client


class CollectProductDataSkill(BaseSkill):

    @property
    def name(self) -> str:
        return "collect_product_data"

    @property
    def description(self) -> str:
        return "查询银行产品库，包括存款、理财、基金、保险、外汇、黄金等。当用户询问产品推荐、理财产品、存款利率时调用。"

    @property
    def parameters_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "category": {
                    "type": "string",
                    "enum": ["deposit", "loan", "wealth", "fund", "insurance", "forex", "gold", ""],
                    "description": "产品类别，空表示全部",
                },
                "risk_level": {"type": "string", "description": "风险等级筛选"},
                "limit": {"type": "integer", "description": "返回条数，默认10"},
            },
        }

    async def execute(self, **kwargs) -> SkillResult:
        category = kwargs.get("category", "")
        risk_level = kwargs.get("risk_level", "")
        limit = kwargs.get("limit", 10)

        api = create_client()
        products, total = await api.list_products(
            category=category, risk_level=risk_level, limit=limit
        )

        simplified = []
        for p in products:
            simplified.append({
                "名称": p.get("name", ""),
                "类别": p.get("type_label", ""),
                "风险等级": p.get("risk_level", ""),
                "描述": p.get("description", ""),
            })

        return SkillResult(
            success=True,
            data={"products": simplified, "total": total, "category": category},
            summary=f"已获取{total}款产品（类别：{category or '全部'}）",
        )