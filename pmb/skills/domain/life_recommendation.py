"""生活推荐领域 Skill — 基于消费画像匹配产品和优惠"""
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client


class LifeRecommendationSkill(BaseSkill):

    @property
    def name(self) -> str:
        return "life_recommendation"

    @property
    def description(self) -> str:
        return "基于我的消费习惯和画像，推荐最匹配的银行产品和优惠活动。每条推荐附带基于消费数据的推荐原因。先输出消费画像概览，再输出产品和优惠推荐。"

    @property
    def parameters_schema(self) -> dict:
        return {"type": "object", "properties": {}}

    async def execute(self, **kwargs) -> SkillResult:
        user_name = kwargs.get("user_name", "")

        # 收集消费画像数据
        api = create_client(user_name=user_name)
        subcategory_stats, _ = await api.get_consumption_stats(group_by="subcategory", top=8)
        channel_stats, _ = await api.get_consumption_stats(group_by="channel", top=5)
        merchant_stats, _ = await api.get_consumption_stats(group_by="merchant", top=10)

        # 收集账户数据
        summary_data, _ = await api.get_account_summary()
        summary_dict = {item["label"]: item["value"] for item in summary_data} if summary_data else {}

        # 收集产品数据
        products, _ = await api.list_products(limit=8)
        simplified_products = []
        for p in products:
            simplified_products.append({
                "名称": p.get("name", ""),
                "类别": p.get("category_label", p.get("category", "")),
                "类型": p.get("type_label", ""),
            })

        # 生成简单标签
        tags = []
        if subcategory_stats:
            top_cat = subcategory_stats[0]["name"]
            if "餐饮" in top_cat:
                tags.append("餐饮达人")
            elif "出行" in top_cat or "交通" in top_cat:
                tags.append("出行达人")
            elif "网购" in top_cat:
                tags.append("网购达人")
        if channel_stats:
            tags.append(f"{channel_stats[0]['name']}偏好")
        if merchant_stats:
            tags.append(f"常去{merchant_stats[0]['name']}")

        return SkillResult(
            success=True,
            data={
                "tags": tags,
                "account_summary": summary_dict,
                "subcategory_stats": subcategory_stats,
                "channel_stats": channel_stats,
                "merchant_stats": merchant_stats,
                "products": simplified_products,
            },
            summary=f"已构建消费画像（{len(tags)}个标签），匹配{len(simplified_products)}款产品",
        )