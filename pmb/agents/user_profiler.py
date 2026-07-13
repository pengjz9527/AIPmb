"""用户画像智能体"""
from pmb.agents.base import BaseAgent, AgentContext, AgentResult


class UserProfilerAgent(BaseAgent):

    @property
    def agent_id(self) -> str:
        return "user_profiler"

    @property
    def name(self) -> str:
        return "画像分析师"

    @property
    def description(self) -> str:
        return "通过您的收支和消费行为，生成您的人生画像，并给出有趣的建议"

    @property
    def avatar(self) -> str:
        return "profile"

    @property
    def system_prompt(self) -> str:
        return """你是一位洞察力极强的用户画像分析师。你的独特之处在于：不仅给出标签，更要用生动、有趣的语言描绘出"这是一个怎样的人"。
你的核心任务：
1. 从消费数据中提炼用户的消费人格（如"品质生活追求者"、"精打细算的实用派"）
2. 用一段生动的描述勾勒用户画像，让人读起来觉得"这就是我"
3. 基于画像，给出有趣的建议（可以是资金规划的，也可以是生活乐趣方面的）
4. 建议要出人意料但有据可循，让用户觉得"原来我还可以这样"

输出格式要求：
- "你的画像"：1-2段生动描述 + 核心标签
- "消费人格"：用比喻描述消费风格
- "有趣发现"：3个从数据中发现的有趣洞察
- "灵感建议"：3-5条有趣建议（资金规划 + 生活乐趣混合）
- 语气要轻松有趣，像朋友聊天一样
- 用Markdown格式输出"""

    def can_handle(self, user_message: str) -> float:
        keywords = ["画像", "我是谁", "我的消费", "分析我", "了解我", "怎样的一个人",
                     "我的风格", "我是怎样的", "人格", "性格", "消费人格"]
        msg = user_message.lower()
        score = 0.0
        for kw in keywords:
            if kw in msg:
                score += 0.4
        return min(score, 1.0)

    async def analyze(self, context: AgentContext) -> AgentResult:
        data = await self._collect_data(context)

        from pmb.core import consumption_service, transaction_service
        subcategory_stats = consumption_service.get_consumption_stats(group_by="subcategory", top=12, user_name=context.user_name)
        monthly_stats = consumption_service.get_consumption_stats(group_by="month", top=12, user_name=context.user_name)
        channel_stats = consumption_service.get_consumption_stats(group_by="channel", top=5, user_name=context.user_name)
        merchant_stats = consumption_service.get_consumption_stats(group_by="merchant", top=15, user_name=context.user_name)

        enhanced_prompt = f"""请根据以下数据，为这位用户画一幅生动有趣的人生画像：

## 账户概况
{data['account_summary']}

## 消费偏好Top12
{subcategory_stats}

## 消费节奏（近12个月月度消费）
{monthly_stats}

## 支付习惯
{channel_stats}

## 生活足迹（常去商户Top15）
{merchant_stats}

请从数据中发现有趣洞察，用生动语言描述这是怎样的一个人，并给出出人意料但有据可循的灵感建议。"""

        content = await self._call_llm(context, enhanced_prompt)

        # 生成画像标签
        tags = []
        if subcategory_stats:
            top = subcategory_stats[0]["name"]
            if any(k in top for k in ["餐饮", "美食"]):
                tags.append("美食家")
            elif any(k in top for k in ["出行", "交通"]):
                tags.append("行者")
            elif any(k in top for k in ["网购", "电商"]):
                tags.append("网购达人")

        if monthly_stats and len(monthly_stats) > 1:
            variance = sum((s["total"] - sum(m["total"] for m in monthly_stats) / len(monthly_stats)) ** 2 for s in monthly_stats) / len(monthly_stats)
            if variance < 100000:
                tags.append("稳定型消费者")
            else:
                tags.append("波动型消费者")

        tags.append("银行用户")

        return AgentResult(
            agent_id=self.agent_id,
            agent_name=self.name,
            content=content,
            cards=[
                {"card_type": "user_profile", "title": "你的画像", "data": {
                    "tags": tags,
                    "top_subcategories": [s["name"] for s in subcategory_stats[:5]],
                    "top_merchants": [s["name"] for s in merchant_stats[:5]],
                }},
            ],
            suggested_agents=["financial_planner", "life_assistant"],
        )
