"""差旅报销清单整理 Skill — 识别差旅消费，整理为结构化报销清单

识别规则：
- 交通: 机票/飞机票/火车票/高铁/动车/打车/出租车/滴滴/地铁/公交/大巴
- 住宿: 酒店/宾馆/民宿/旅馆/青旅
- 饮食: 餐饮/饭店/餐厅（仅包含出差期间的）
- 其他: 快递/邮寄/打印/复印
"""
from collections import defaultdict
from datetime import datetime, timedelta
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client

# 差旅关键词分类
TRAVEL_KEYWORDS = {
    "交通": [
        "机票", "飞机票", "航空", "航班", "飞行",
        "火车票", "高铁", "动车", "列车",
        "打车", "出租车", "滴滴", "网约车",
        "地铁", "公交", "巴士", "大巴", "长途",
        "租车", "代驾",
    ],
    "住宿": [
        "酒店", "宾馆", "民宿", "旅馆", "青旅", "客栈",
        "住宿", "入住",
    ],
    "餐饮": [
        "餐饮", "饭店", "餐厅", "外卖", "快餐",
        "小吃", "咖啡", "茶饮",
    ],
    "其他": [
        "快递", "邮寄", "打印", "复印",
        "行李", "寄存",
    ],
}


class ReimbursementOrganizerSkill(BaseSkill):

    @property
    def name(self) -> str:
        return "reimbursement_organizer"

    @property
    def description(self) -> str:
        return (
            "识别用户的差旅相关消费（交通/住宿），整理为结构化报销清单。"
            "适用场景：'整理我的差旅报销'、'这月出差花了多少钱'等。"
        )

    @property
    def parameters_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "month": {
                    "type": "string",
                    "description": "指定月份，格式 YYYY-MM，默认当前月",
                },
            },
        }

    async def execute(self, **kwargs) -> SkillResult:
        user_name = kwargs.get("user_name", "")
        month = kwargs.get("month", "")

        now = datetime.now()
        if not month or len(month) != 7:
            month = now.strftime("%Y-%m")

        date_from = f"{month}-01"
        # 计算月末
        try:
            month_dt = datetime.strptime(month, "%Y-%m")
            if month_dt.month == 12:
                next_month = datetime(month_dt.year + 1, 1, 1)
            else:
                next_month = datetime(month_dt.year, month_dt.month + 1, 1)
            last_day = (next_month - timedelta(days=1)).day
        except Exception:
            last_day = 28
        date_to = f"{month}-{last_day:02d}"

        api = create_client(user_name=user_name)

        # 获取当月所有支出交易
        transactions, _ = await api.list_transactions(
            direction="expense",
            date_from=date_from,
            date_to=date_to,
            limit=5000,
        )

        if not transactions:
            return SkillResult(
                success=True,
                data={
                    "month": month,
                    "total_amount": 0,
                    "categories": {},
                    "unmatched": [],
                },
                summary=f"{month}月暂无消费记录",
            )

        # 按类别分组识别差旅消费
        categorized: dict[str, list[dict]] = defaultdict(list)
        unmatched: list[dict] = []

        for tx in transactions:
            counterparty = str(tx.get("counterparty", "") or tx.get("merchant", "") or tx.get("description", ""))
            description = str(tx.get("description", ""))
            combined = counterparty + " " + description

            try:
                amount = abs(float(tx.get("amount", 0) or 0))
            except (TypeError, ValueError):
                continue

            date_str = str(tx.get("date", "") or tx.get("transaction_date", ""))[:10]

            # 匹配差旅关键词
            matched = False
            for category, keywords in TRAVEL_KEYWORDS.items():
                for kw in keywords:
                    if kw in combined:
                        categorized[category].append({
                            "date": date_str,
                            "counterparty": counterparty or description,
                            "amount": round(amount, 2),
                            "description": description,
                            "matched_keyword": kw,
                        })
                        matched = True
                        break
                if matched:
                    break

            if not matched:
                unmatched.append({
                    "date": date_str,
                    "counterparty": counterparty or description,
                    "amount": round(amount, 2),
                })

        # 计算各类别汇总
        category_summary = {}
        total = 0.0
        for cat, items in categorized.items():
            cat_total = sum(item["amount"] for item in items)
            total += cat_total
            category_summary[cat] = {
                "count": len(items),
                "total": round(cat_total, 2),
                "items": items,
            }

        # 汇总文本
        summary_parts = []
        for cat, info in category_summary.items():
            summary_parts.append(f"{cat} {info['count']}笔 ¥{info['total']:,.2f}")
        summary_text = "；".join(summary_parts)

        return SkillResult(
            success=True,
            data={
                "month": month,
                "total_amount": round(total, 2),
                "categories": category_summary,
                "unmatched_count": len(unmatched),
            },
            summary=f"{month}月差旅消费合计¥{total:,.2f}（{summary_text}）" if total > 0 else f"{month}月未识别到差旅消费",
        )
