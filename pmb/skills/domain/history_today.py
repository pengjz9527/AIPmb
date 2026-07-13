"""历史上的今天 Skill — 检索往年同日交易，挖掘纪念意义，提供优惠权益"""
import json
from datetime import datetime
from collections import defaultdict
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client

# ---------- 纪念类型 → 权益映射 ----------
BENEFIT_TEMPLATES = {
    "major_purchase": {
        "label": "大额消费回馈",
        "description": "感谢您在过去的重要消费时刻选择了我们",
        "benefit_type": "信用卡积分翻倍",
        "benefit_desc": "本月信用卡消费享双倍积分",
        "icon": "shopping_cart",
    },
    "first_income": {
        "label": "成长见证礼",
        "description": "纪念您财富成长的第一步",
        "benefit_type": "存款加息券",
        "benefit_desc": "定期存款享额外0.1%加息",
        "icon": "trending_up",
    },
    "family_care": {
        "label": "家人关爱权益",
        "description": "在此刻，为家人送上一份保障",
        "benefit_type": "家庭保险优惠",
        "benefit_desc": "家庭意外险首月1元体验",
        "icon": "favorite",
    },
    "travel_memory": {
        "label": "旅行回忆礼",
        "description": "重温旅途美好，开启下一段旅程",
        "benefit_type": "出行消费券",
        "benefit_desc": "酒店/机票消费满500减50",
        "icon": "flight",
    },
    "growth_milestone": {
        "label": "成长里程碑礼遇",
        "description": "见证您财富积累的重要节点",
        "benefit_type": "理财体验金",
        "benefit_desc": "专属理财体验金1000元，收益归您",
        "icon": "emoji_events",
    },
    "daily_warmth": {
        "label": "生活小确幸",
        "description": "平凡日子里的温暖记忆",
        "benefit_type": "消费立减券",
        "benefit_desc": "餐饮/便利店消费随机立减1-10元",
        "icon": "spa",
    },
}

# 产品大类 → 权益关键词映射（用于匹配真实产品）
BENEFIT_PRODUCT_MAP = {
    "信用卡积分翻倍": {"category": "loan", "keywords": ["信用卡", "积分"]},
    "存款加息券": {"category": "deposit", "keywords": ["定期", "存款", "大额存单"]},
    "家庭保险优惠": {"category": "insurance", "keywords": ["意外险", "家庭", "保障"]},
    "出行消费券": {"category": "loan", "keywords": ["出行", "旅行", "酒店"]},
    "理财体验金": {"category": "wealth", "keywords": ["理财", "稳健", "现金管理"]},
    "消费立减券": {"category": "loan", "keywords": ["消费", "信用卡", "立减"]},
}

HISTORY_TODAY_PROMPT = """你是一位温暖贴心的"用户人生记录官"。用户提供了往年同一天（月-日）的交易记录。

请分析这些在每年同一日期发生的交易，挖掘其中值得纪念的意义：

1. **识别关键事件类型**：
   - major_purchase: 大额消费（>1000元），如买车、装修、大额购物
   - first_income: 首次收入入账、工资里程碑
   - family_care: 为家人消费（医疗、教育、礼物）
   - travel_memory: 旅行相关消费（机票、酒店、景点）
   - growth_milestone: 理财/投资/存款重要节点
   - daily_warmth: 日常温暖消费（餐饮、礼物、固定习惯）

2. **生成纪念意义**：
   - 温馨标题（简短有力，如"去年今日，你开启了理财之路"）
   - 纪念文案（50-80字，温暖感人）
   - 选择最突出的一个事件类型作为主要纪念

3. **推荐权益方向**：
   - 根据纪念类型，从权益库中选择合适的权益类型
   - 说明为什么这个权益适合用户

输出格式（严格JSON）：
{
  "has_memory": true/false,
  "memory": {
    "event_type": "major_purchase",
    "title": "纪念标题",
    "description": "温馨文案...",
    "year": 2025,
    "benefit_type": "benefit_key_from_list"
  },
  "years_summary": "往年同日交易概况（一句话）"
}

注意：
- 如果确实没有值得纪念的交易，has_memory 设为 false
- year 字段选择最有纪念意义的年份
- benefit_type 从以下选择最合适的: major_purchase, first_income, family_care, travel_memory, growth_milestone, daily_warmth
"""


class HistoryTodaySkill(BaseSkill):
    """历史上的今天：
    检索用户往年同日交易和消费记录，挖掘纪念意义，提供优惠权益。
    权益可针对用户本人或用户家人。
    """

    @property
    def name(self) -> str:
        return "history_today"

    @property
    def description(self) -> str:
        return (
            "查看历史上的今天。检索我在以往年份同一日期（月-日）发生的重要交易和"
            "消费记录，挖掘值得纪念的人生时刻，并结合纪念意义为我或家人提供专属优惠权益。"
            "适用场景：'今天有什么特别的'、'历史上的今天'、'往年今天'等。"
        )

    @property
    def parameters_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {},
        }

    async def execute(self, **kwargs) -> SkillResult:
        user_name = kwargs.get("user_name", "")
        return await self._analyze_history(user_name)

    async def _analyze_history(self, user_name: str) -> SkillResult:
        """执行历史上的今天分析"""
        today = datetime.now()
        today_mmdd = today.strftime("%m-%d")
        api = create_client(user_name=user_name)

        # ------ 1. 收集用户往年同日交易 ------
        all_credit_txs = []
        all_debit_txs = []

        # 信用卡交易
        credit_txs, _ = await api.list_transactions(source="credit", limit=10000)
        for row in credit_txs:
            date_str = str(row.get("date", ""))
            if len(date_str) >= 10 and date_str[5:] == today_mmdd:
                year = int(date_str[:4])
                if year < today.year:
                    all_credit_txs.append({
                        "year": year,
                        "date": date_str,
                        "amount": float(row.get("amount", 0) or 0),
                        "direction": str(row.get("direction", "")),
                        "category": str(row.get("category", "")),
                        "subcategory": str(row.get("subcategory", "")),
                        "merchant": str(row.get("merchant", "")),
                        "summary": str(row.get("summary", "")),
                    })

        # 借记卡交易
        debit_txs, _ = await api.list_transactions(source="debit", limit=10000)
        for row in debit_txs:
            date_str = str(row.get("date", ""))
            if len(date_str) >= 10 and date_str[5:] == today_mmdd:
                year = int(date_str[:4])
                if year < today.year:
                    all_debit_txs.append({
                        "year": year,
                        "date": date_str,
                        "amount": float(row.get("amount", 0) or 0),
                        "direction": str(row.get("direction", "")),
                        "category": str(row.get("category", "")),
                        "subcategory": "",
                        "merchant": str(row.get("merchant", "")),
                        "summary": str(row.get("method", "")),
                    })

        all_txs = all_credit_txs + all_debit_txs

        if not all_txs:
            return SkillResult(
                success=True,
                data={"has_memory": False, "today": today_mmdd},
                summary=f"今天（{today_mmdd}）没有往年同日交易记录",
            )

        # 按年份分组
        year_groups = defaultdict(list)
        for tx in all_txs:
            year_groups[tx["year"]].append(tx)

        # ------ 2. 规则预分析：判断是否有值得纪念的事件 ------
        pre_analysis = self._pre_analyze(all_txs, year_groups)

        if not pre_analysis["has_memorable"]:
            return SkillResult(
                success=True,
                data={"has_memory": False, "today": today_mmdd,
                      "tx_count": len(all_txs), "years": list(year_groups.keys())},
                summary=f"今天（{today_mmdd}）有往年交易但无显著纪念事件",
            )

        # ------ 3. 使用 LLM 深度分析 ------
        try:
            memory_result = await self._llm_analyze(
                user_name, today_mmdd, year_groups, all_txs
            )
        except Exception:
            # LLM 不可用时使用规则分析结果
            memory_result = self._rule_based_memory(
                user_name, today_mmdd, year_groups, pre_analysis
            )

        if not memory_result.get("has_memory"):
            return SkillResult(
                success=True,
                data={"has_memory": False, "today": today_mmdd},
                summary="未发现值得纪念的事件",
            )

        # ------ 4. 匹配权益 ------
        memory = memory_result["memory"]
        benefit = await self._match_benefit(memory, user_name, api)

        return SkillResult(
            success=True,
            data={
                "has_memory": True,
                "today": today_mmdd,
                "today_formatted": f"{today.month}月{today.day}日",
                "memory": memory,
                "benefit": benefit,
                "years_summary": memory_result.get("years_summary", ""),
                "tx_count": len(all_txs),
                "years": sorted(year_groups.keys()),
            },
            summary=f"历史上的今天({today_mmdd})：{memory.get('title','')}",
        )

    def _pre_analyze(self, all_txs: list, year_groups: dict) -> dict:
        """规则预分析：判断是否有值得纪念的事件"""
        has_large = False  # 大额交易 (>1000)
        has_income = False  # 收入类
        has_family = False  # 家庭相关（医疗、教育）
        has_travel = False  # 旅行相关
        has_growth = False  # 理财/投资
        has_repeat = len(year_groups) >= 2  # 多年重复

        for tx in all_txs:
            amt = abs(tx["amount"])
            cat = tx["category"] + tx["subcategory"]
            merchant = tx["merchant"]
            direction = tx["direction"]

            if amt > 1000:
                has_large = True
            if direction == "收入" and amt > 100:
                has_income = True
            if any(kw in cat + merchant for kw in ["医疗", "医院", "教育", "学校", "母婴", "儿童"]):
                has_family = True
            if any(kw in cat + merchant for kw in ["旅游", "酒店", "机票", "火车", "景点"]):
                has_travel = True
            if any(kw in cat + merchant for kw in ["理财", "基金", "存款", "投资", "黄金"]):
                has_growth = True

        # 至少满足一项才是"值得纪念"
        has_memorable = (has_large or has_income or has_family or
                         has_travel or has_growth or has_repeat)

        best_type = "daily_warmth"
        if has_growth:
            best_type = "growth_milestone"
        elif has_travel:
            best_type = "travel_memory"
        elif has_family:
            best_type = "family_care"
        elif has_income:
            best_type = "first_income"
        elif has_large:
            best_type = "major_purchase"

        return {
            "has_memorable": has_memorable,
            "best_type": best_type,
            "flags": {
                "large": has_large, "income": has_income,
                "family": has_family, "travel": has_travel,
                "growth": has_growth, "repeat": has_repeat,
            },
        }

    async def _llm_analyze(self, user_name: str, today_mmdd: str,
                           year_groups: dict, all_txs: list) -> dict:
        """使用 LLM 分析往年同日交易"""
        # 构建精简的输入
        years_info = []
        for year in sorted(year_groups.keys()):
            txs = year_groups[year][:10]  # 每年最多10条
            years_info.append({
                "year": year,
                "count": len(year_groups[year]),
                "transactions": [
                    {
                        "金额": tx["amount"],
                        "方向": tx["direction"],
                        "分类": tx["category"],
                        "商户": tx["merchant"],
                        "摘要": tx["summary"],
                    }
                    for tx in txs
                ],
            })

        user_prompt = f"""用户"{user_name}"在历年 {today_mmdd} 的交易记录：

{json.dumps(years_info, ensure_ascii=False, indent=2)}

请分析这些记录，判断是否有值得纪念的事件。"""

        from pmb.ai_manage.services.calendar_service import _get_llm
        llm = _get_llm()
        response = await llm.chat(messages=[
            {"role": "system", "content": HISTORY_TODAY_PROMPT},
            {"role": "user", "content": user_prompt},
        ])

        content = response.content.strip()
        if "```json" in content:
            content = content.split("```json")[1].split("```")[0].strip()
        elif "```" in content:
            content = content.split("```")[1].split("```")[0].strip()

        return json.loads(content)

    def _rule_based_memory(self, user_name: str, today_mmdd: str,
                           year_groups: dict, pre_analysis: dict) -> dict:
        """规则驱动生成纪念事件（LLM 不可用时的回退）"""
        flags = pre_analysis["flags"]
        best_type = pre_analysis["best_type"]

        # 选择最有代表性的年份
        latest_year = max(year_groups.keys())
        txs_in_year = year_groups[latest_year]
        total_amount = sum(abs(tx["amount"]) for tx in txs_in_year)

        title_map = {
            "major_purchase": f"{latest_year}年今天，你完成了一笔重要消费",
            "first_income": f"{latest_year}年今天，你的财富增值之路",
            "family_care": f"{latest_year}年今天，你为家人付出了关爱",
            "travel_memory": f"{latest_year}年今天，你踏上了一段旅程",
            "growth_milestone": f"{latest_year}年今天，你开启了理财新篇章",
            "daily_warmth": f"{latest_year}年今天，平凡生活里的温暖时刻",
        }

        desc_map = {
            "major_purchase": f"那一天消费了 ¥{total_amount:,.0f}，也许是一份心仪已久的礼物，也许是生活里的一件大事。每一笔大额消费背后，都是你对美好生活的追求。",
            "first_income": f"那一天入账 ¥{total_amount:,.0f}，每一笔收入都是努力的回报。回望过去，你的财富正在稳步增长。",
            "family_care": f"那一天你为家人的健康和成长付出了关爱。亲情是人生最珍贵的财富，你一直在用心守护。",
            "travel_memory": f"那一天的旅途消费，是你探索世界的足迹。生活的意义不仅在于到达，更在于沿途的风景和心情。",
            "growth_milestone": f"那一天的理财决策，是财富觉醒的重要时刻。时光不语，却见证了你每一步的成长。",
            "daily_warmth": f"那一天看起来平平无奇，但正是这些细碎的日常，编织成了你独一无二的人生。",
        }

        return {
            "has_memory": True,
            "memory": {
                "event_type": best_type,
                "title": title_map.get(best_type, title_map["daily_warmth"]),
                "description": desc_map.get(best_type, desc_map["daily_warmth"]),
                "year": latest_year,
                "benefit_type": best_type,
            },
            "years_summary": f"共 {len(year_groups)} 个年份在这一天有交易记录",
        }

    async def _match_benefit(self, memory: dict, user_name: str, api) -> dict:
        """根据纪念类型匹配优惠权益"""
        event_type = memory.get("event_type", "daily_warmth")
        template = BENEFIT_TEMPLATES.get(event_type, BENEFIT_TEMPLATES["daily_warmth"])

        benefit_type = template["benefit_type"]

        # 尝试从真实产品库匹配
        linked_product = await self._find_related_product(benefit_type, user_name, api)

        return {
            "label": template["label"],
            "description": template["description"],
            "benefit_type": benefit_type,
            "benefit_desc": template["benefit_desc"],
            "icon": template["icon"],
            "for_family": event_type == "family_care",
            "linked_product": linked_product,
        }

    async def _find_related_product(self, benefit_type: str, user_name: str, api) -> dict | None:
        """从产品库匹配相关产品"""
        mapping = BENEFIT_PRODUCT_MAP.get(benefit_type)
        if not mapping:
            return None

        products, _ = await api.list_products(
            category=mapping["category"], limit=10
        )

        for p in products:
            p_name = str(p.get("name", ""))
            p_desc = str(p.get("description", ""))
            combined = p_name + p_desc

            for kw in mapping["keywords"]:
                if kw in combined:
                    return {
                        "product_name": p_name,
                        "category": mapping["category"],
                        "bank": str(p.get("bank", "")),
                        "description": p_desc[:100],
                        "detail_link": f"/recommendations?product={p_name}",
                    }

        # 没有匹配到具体产品，返回通用权益
        return None
