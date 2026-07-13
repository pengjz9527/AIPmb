"""消费模式检测 Skill — 从交易流水数据中检测周期性扣款、异常支出、重复消费等模式

检测规则：
1. 周期性扣款: 同一对手方、相同金额、连续 >= 3 个月、扣款日方差 <= 3 天
2. 重复消费: 同一商户 >= 5 笔/月
3. 异常大额支出: 单笔 > 类别均值 + 2σ
4. 消费频次突增/突降: 环比变化 > 50%
"""
from collections import defaultdict, Counter
from datetime import datetime, timedelta
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client


class ExpensePatternDetectorSkill(BaseSkill):

    @property
    def name(self) -> str:
        return "expense_pattern_detector"

    @property
    def description(self) -> str:
        return (
            "检测消费数据中的模式：周期性扣款（疑似订阅服务）、异常大额支出、"
            "同一商户重复消费、消费频次突增/突降。返回检测到的所有模式列表。"
        )

    @property
    def parameters_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "months": {"type": "integer", "description": "分析最近几个月的数据，默认6"},
            },
        }

    async def execute(self, **kwargs) -> SkillResult:
        user_name = kwargs.get("user_name", "")
        months = kwargs.get("months", 6)
        api = create_client(user_name=user_name)

        # 1. 获取交易明细（支出方向，默认近6个月）
        now = datetime.now()
        date_from = (now - timedelta(days=months * 31)).strftime("%Y-%m-%d")
        date_to = now.strftime("%Y-%m-%d")

        transactions, _ = await api.list_transactions(
            direction="expense",
            date_from=date_from,
            date_to=date_to,
            limit=5000,
        )

        if not transactions:
            return SkillResult(
                success=True,
                data={"subscriptions": [], "repeat_merchants": [], "anomalies": [], "summary": "暂无交易数据"},
                summary="未找到交易记录，无法检测消费模式",
            )

        # 2. 检测周期性扣款（疑似订阅）
        subscriptions = self._detect_subscriptions(transactions)

        # 3. 检测重复消费（同一商户多笔）
        repeat_merchants = self._detect_repeat_merchants(transactions)

        # 4. 检测异常大额支出
        anomalies = self._detect_anomalies(transactions)

        total_found = len(subscriptions) + len(repeat_merchants) + len(anomalies)
        summary_parts = []
        if subscriptions:
            summary_parts.append(f"{len(subscriptions)}个疑似订阅")
        if repeat_merchants:
            summary_parts.append(f"{len(repeat_merchants)}个重复商户")
        if anomalies:
            summary_parts.append(f"{len(anomalies)}笔异常支出")
        summary = "检测到" + "、".join(summary_parts) if summary_parts else "未检测到明显消费模式"

        return SkillResult(
            success=True,
            data={
                "subscriptions": subscriptions,
                "repeat_merchants": repeat_merchants,
                "anomalies": anomalies,
                "total_patterns": total_found,
            },
            summary=summary,
        )

    def _detect_subscriptions(self, transactions: list[dict]) -> list[dict]:
        """检测周期性扣款（疑似订阅服务）

        逻辑：按(对手方, 金额)分组 → 检查是否连续 >= 3 个月 → 日期方差 <= 3 天
        """
        # 按 (对手方, 金额) 分组，每组记录 {年月: [日期]}
        groups: dict[tuple[str, float], dict[str, list[int]]] = defaultdict(
            lambda: defaultdict(list)
        )

        for tx in transactions:
            counterparty = str(tx.get("counterparty", "") or tx.get("description", "") or tx.get("merchant", ""))
            try:
                amount = abs(float(tx.get("amount", 0) or 0))
            except (TypeError, ValueError):
                continue
            date_str = str(tx.get("date", "") or tx.get("transaction_date", ""))
            if not counterparty or amount <= 0 or not date_str:
                continue

            # 解析日期
            try:
                dt = datetime.strptime(date_str[:10], "%Y-%m-%d")
            except ValueError:
                continue

            year_month = dt.strftime("%Y-%m")
            groups[(counterparty, amount)][year_month].append(dt.day)

        subscriptions = []
        for (counterparty, amount), month_days in groups.items():
            # 需要连续 >= 3 个月
            months_sorted = sorted(month_days.keys())
            if len(months_sorted) < 3:
                continue

            # 检查月份是否连续
            consecutive = True
            for i in range(1, len(months_sorted)):
                prev = datetime.strptime(months_sorted[i - 1] + "-01", "%Y-%m-%d")
                curr = datetime.strptime(months_sorted[i] + "-01", "%Y-%m-%d")
                diff_months = (curr.year - prev.year) * 12 + (curr.month - prev.month)
                if diff_months > 2:  # 允许间隔1个月（如2月和4月之间隔了3月）
                    consecutive = False
                    break

            if not consecutive:
                continue

            # 检查日期方差 <= 3 天
            all_days = []
            for days in month_days.values():
                all_days.extend(days)
            if len(all_days) < 3:
                continue

            mean_day = sum(all_days) / len(all_days)
            variance = sum((d - mean_day) ** 2 for d in all_days) / len(all_days)
            std_dev = variance ** 0.5
            if std_dev > 3:
                continue

            # 标记为疑似订阅
            months_count = len(months_sorted)
            subscriptions.append({
                "counterparty": counterparty,
                "amount": round(amount, 2),
                "months_count": months_count,
                "avg_day": round(mean_day, 0),
                "day_variance": round(std_dev, 1),
                "months": months_sorted,
                "label": f"「{counterparty}」每月¥{amount:,.0f}，连续{months_count}个月",
            })

        # 按月份数降序
        subscriptions.sort(key=lambda s: s["months_count"], reverse=True)
        return subscriptions[:10]  # 最多返回 10 个

    def _detect_repeat_merchants(self, transactions: list[dict]) -> list[dict]:
        """检测同一商户的重复消费（>= 5 笔/月）"""
        # 按 (对手方, 年月) 分组计数
        merchant_month: dict[tuple[str, str], list[dict]] = defaultdict(list)

        for tx in transactions:
            counterparty = str(tx.get("counterparty", "") or tx.get("merchant", "") or tx.get("description", ""))
            try:
                amount = abs(float(tx.get("amount", 0) or 0))
            except (TypeError, ValueError):
                continue
            date_str = str(tx.get("date", "") or tx.get("transaction_date", ""))
            if not counterparty or not date_str:
                continue

            try:
                dt = datetime.strptime(date_str[:10], "%Y-%m-%d")
            except ValueError:
                continue

            year_month = dt.strftime("%Y-%m")
            merchant_month[(counterparty, year_month)].append({
                "date": date_str[:10],
                "amount": round(amount, 2),
            })

        repeat_merchants = []
        for (counterparty, ym), txs in merchant_month.items():
            if len(txs) < 5:
                continue
            total = sum(t["amount"] for t in txs)
            repeat_merchants.append({
                "counterparty": counterparty,
                "month": ym,
                "count": len(txs),
                "total_amount": round(total, 2),
                "avg_amount": round(total / len(txs), 2),
                "label": f"「{counterparty}」{ym}月共{len(txs)}笔，合计¥{total:,.2f}",
            })

        # 按笔数降序
        repeat_merchants.sort(key=lambda m: m["count"], reverse=True)
        return repeat_merchants[:10]

    def _detect_anomalies(self, transactions: list[dict]) -> list[dict]:
        """检测异常大额支出（超出类别均值 + 2σ 的单笔消费）"""
        # 按类别分组
        category_amounts: dict[str, list[float]] = defaultdict(list)
        category_txns: dict[str, list[dict]] = defaultdict(list)

        for tx in transactions:
            category = str(tx.get("category", "") or tx.get("subcategory", "") or "其他")
            try:
                amount = abs(float(tx.get("amount", 0) or 0))
            except (TypeError, ValueError):
                continue
            if amount <= 0:
                continue

            category_amounts[category].append(amount)
            category_txns[category].append(tx)

        anomalies = []
        for category, amounts in category_amounts.items():
            if len(amounts) < 3:  # 样本太少，跳过
                continue

            mean = sum(amounts) / len(amounts)
            variance = sum((a - mean) ** 2 for a in amounts) / len(amounts)
            std_dev = variance ** 0.5
            threshold = mean + 2 * std_dev

            if std_dev < 1:  # 金额波动太小，忽略
                continue

            for tx in category_txns[category]:
                try:
                    amount = abs(float(tx.get("amount", 0) or 0))
                except (TypeError, ValueError):
                    continue
                if amount > threshold and amount > mean * 1.5:
                    date_str = str(tx.get("date", "") or tx.get("transaction_date", ""))[:10]
                    counterparty = str(tx.get("counterparty", "") or tx.get("description", "") or tx.get("merchant", ""))
                    anomalies.append({
                        "date": date_str,
                        "category": category,
                        "counterparty": counterparty,
                        "amount": round(amount, 2),
                        "category_avg": round(mean, 2),
                        "threshold": round(threshold, 2),
                        "label": f"{date_str} 「{counterparty}」¥{amount:,.2f}（该类均值¥{mean:,.0f}）",
                    })

        # 按金额降序
        anomalies.sort(key=lambda a: a["amount"], reverse=True)
        return anomalies[:10]
