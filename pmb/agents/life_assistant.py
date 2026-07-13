"""生活便利智能体"""
from pmb.agents.base import BaseAgent, AgentContext, AgentResult


class LifeAssistantAgent(BaseAgent):

    @property
    def agent_id(self) -> str:
        return "life_assistant"

    @property
    def name(self) -> str:
        return "生活管家"

    @property
    def description(self) -> str:
        return "根据您的消费习惯画像，推荐匹配的产品和优惠，并给出推荐原因"

    @property
    def avatar(self) -> str:
        return "life"

    @property
    def system_prompt(self) -> str:
        return """你是银行的生活管家，善于从客户的消费行为中发现需求，推荐最贴心的产品和优惠。
你的核心原则：
1. 推荐必须基于客户的真实消费习惯，而非泛泛推荐
2. 每条推荐必须给出"推荐原因"，关联客户的实际消费数据
3. 推荐要有温度，像朋友一样关心客户的生活

你需要：
1. 构建客户的消费画像（消费偏好标签）
2. 匹配与画像契合的银行产品
3. 匹配与消费习惯相关的优惠活动
4. 每条推荐附上数据支撑的推荐原因

输出格式要求：
- 先给出消费画像概览（3-5个标签）
- 产品推荐：产品名 + 匹配原因 + 客户消费数据支撑
- 优惠推荐：优惠内容 + 适合原因 + 客户消费频率支撑
- 用Markdown格式输出"""

    def can_handle(self, user_message: str) -> float:
        keywords = ["推荐", "优惠", "适合我", "有什么活动", "办卡", "生活", "便利",
                     "好物", "福利", "活动", "权益", "生活管家"]
        msg = user_message.lower()
        score = 0.0
        for kw in keywords:
            if kw in msg:
                score += 0.35
        return min(score, 1.0)

    async def analyze(self, context: AgentContext) -> AgentResult:
        data = await self._collect_data(context)

        from pmb.core import consumption_service, product_service
        subcategory_stats = consumption_service.get_consumption_stats(group_by="subcategory", top=8, user_name=context.user_name)
        channel_stats = consumption_service.get_consumption_stats(group_by="channel", top=5, user_name=context.user_name)
        merchant_stats = consumption_service.get_consumption_stats(group_by="merchant", top=10, user_name=context.user_name)

        # 生成画像标签
        tags = []
        if subcategory_stats:
            top_cat = subcategory_stats[0]["name"]
            if "餐饮" in top_cat:
                tags.append("餐饮达人")
            elif "出行" in top_cat or "交通" in top_cat:
                tags.append("出行达人")
            elif "网购" in top_cat:
                tags.append("网购达人")
            else:
                tags.append(f"{top_cat}爱好者")

        if channel_stats:
            top_channel = channel_stats[0]["name"]
            tags.append(f"{top_channel}偏好")

        if merchant_stats:
            tags.append(f"常去{merchant_stats[0]['name']}")

        # 获取推荐产品
        products, _ = product_service.list_products(limit=8)

        enhanced_prompt = f"""请根据以下客户消费数据，推荐最匹配的产品和优惠：

## 客户消费画像标签
{tags}

## 消费偏好（按子类Top8）
{subcategory_stats}

## 支付渠道偏好
{channel_stats}

## 常去商户Top10
{merchant_stats}

## 账户概览
{data['account_summary']}

## 银行可选产品
{[{"名称": p.get("产品名称", p.get("产品名称/类别", p.get("基金类别", ""))), "类别": p.get("_product_category", ""), "类型": p.get("产品类型", p.get("产品大类", p.get("基金类型", "")))} for p in products]}

请为这位客户推荐3-5个最匹配的产品和优惠，每条推荐必须包含推荐原因和数据支撑。"""

        content = await self._call_llm(context, enhanced_prompt)

        return AgentResult(
            agent_id=self.agent_id,
            agent_name=self.name,
            content=content,
            cards=[
                {"card_type": "profile_tags", "title": "消费画像", "data": {"tags": tags}},
                {"card_type": "recommendations_with_reason", "title": "为您推荐", "data": {
                    "tags": tags,
                    "top_subcategories": subcategory_stats[:5],
                }},
            ],
            suggested_agents=["user_profiler", "financial_planner"],
        )
