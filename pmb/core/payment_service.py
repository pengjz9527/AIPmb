"""缴费记录 Service — 查询、汇总、待缴费预测"""
from datetime import datetime, date, timedelta
from collections import defaultdict
from pmb.core.loader import loader
from pmb.utils.search import apply_pagination


# ========== 1. 查询缴费记录 ==========

def list_payments(
    user_name: str = "",
    payment_type: str = "",
    date_from: str = "",
    date_to: str = "",
    limit: int = 20,
    offset: int = 0,
) -> tuple[list[dict], int]:
    """返回过滤+分页后的缴费记录列表"""
    rows = loader.load_payments()

    if user_name:
        rows = [r for r in rows if str(r.get("用户名", "")).strip() == user_name]
    if payment_type:
        rows = [r for r in rows if payment_type in str(r.get("缴费类型", ""))]
    if date_from:
        rows = [r for r in rows if str(r.get("缴费日期", "")) >= date_from]
    if date_to:
        rows = [r for r in rows if str(r.get("缴费日期", "")) <= date_to]

    # 按缴费日期降序排列
    rows.sort(key=lambda r: str(r.get("缴费日期", "")), reverse=True)

    # 补充 abs_amount 便于展示
    for r in rows:
        try:
            r["abs_amount"] = abs(float(r.get("金额(元)", 0)))
        except (ValueError, TypeError):
            r["abs_amount"] = 0.0

    return apply_pagination(rows, offset, limit)


# ========== 2. 汇总统计 ==========

def get_payment_summary(user_name: str = "") -> dict:
    """汇总缴费记录：按类型、按月统计"""
    rows = loader.load_payments()
    if user_name:
        rows = [r for r in rows if str(r.get("用户名", "")).strip() == user_name]

    total_amount = 0.0
    by_type: dict[str, dict] = defaultdict(lambda: {"payment_type": "", "count": 0, "total": 0.0})
    by_month: dict[str, dict] = defaultdict(lambda: {"month": "", "count": 0, "total": 0.0})

    for r in rows:
        try:
            amount = abs(float(r.get("金额(元)", 0)))
        except (ValueError, TypeError):
            amount = 0.0
        total_amount += amount

        ptype = str(r.get("缴费类型", ""))
        if ptype:
            by_type[ptype]["payment_type"] = ptype
            by_type[ptype]["count"] += 1
            by_type[ptype]["total"] += amount

        d = str(r.get("缴费日期", ""))
        if d and len(d) >= 7:
            month_key = d[:7]  # YYYY-MM
            by_month[month_key]["month"] = month_key
            by_month[month_key]["count"] += 1
            by_month[month_key]["total"] += amount

    # 按月排序
    by_month_list = sorted(by_month.values(), key=lambda x: x["month"])
    by_type_list = sorted(by_type.values(), key=lambda x: x["total"], reverse=True)

    # 最近5笔
    sorted_rows = sorted(rows, key=lambda r: str(r.get("缴费日期", "")), reverse=True)
    recent = sorted_rows[:5]
    for r in recent:
        try:
            r["abs_amount"] = abs(float(r.get("金额(元)", 0)))
        except (ValueError, TypeError):
            r["abs_amount"] = 0.0

    return {
        "total_count": len(rows),
        "total_amount": round(total_amount, 2),
        "by_type": by_type_list,
        "by_month": by_month_list,
        "recent_payments": recent,
    }


# ========== 3. 待缴费预测 ==========

def predict_pending_payments(user_name: str = "") -> list[dict]:
    """
    基于每个缴费编号的历史规律，预测最近一期应缴费但尚未缴费的任务。
    
    算法（纯规则引擎）：
    1. 按 payment_no 分组，每组内按日期排序
    2. 计算平均缴费间隔天数 和 平均缴费日（几号）
    3. 判断周期类型：间隔<40天=monthly，>=40天=quarterly
    4. last_date + interval_days = expected_next_date
    5. expected_next_date <= today → 标记为待缴费/已逾期
    """
    rows = loader.load_payments()
    if user_name:
        rows = [r for r in rows if str(r.get("用户名", "")).strip() == user_name]

    if not rows:
        return []

    # 按缴费编号分组
    groups: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        pno = str(r.get("缴费编号", "")).strip()
        if pno:
            groups[pno].append(r)

    # current_date = "2026-06-15"  # 从 plan 中的系统时间推断
    today = date.today()

    pending = []
    for pno, records in groups.items():
        if len(records) < 2:
            continue  # 只有一次记录，无法推断规律

        # 按日期升序
        records.sort(key=lambda r: str(r.get("缴费日期", "")))

        # 计算间隔天数
        intervals = []
        for i in range(1, len(records)):
            d1 = _parse_date(str(records[i - 1].get("缴费日期", "")))
            d2 = _parse_date(str(records[i].get("缴费日期", "")))
            if d1 and d2:
                intervals.append((d2 - d1).days)

        if not intervals:
            continue

        avg_interval = sum(intervals) / len(intervals)

        # 计算平均缴费日
        days_of_month = []
        for r in records:
            d = _parse_date(str(r.get("缴费日期", "")))
            if d:
                days_of_month.append(d.day)
        avg_day = sum(days_of_month) / len(days_of_month) if days_of_month else 15

        # 计算金额
        amounts = []
        for r in records:
            try:
                amounts.append(abs(float(r.get("金额(元)", 0))))
            except (ValueError, TypeError):
                pass
        avg_amount = sum(amounts) / len(amounts) if amounts else 0.0

        # 最近一次缴费
        last_record = records[-1]
        last_date = _parse_date(str(last_record.get("缴费日期", "")))
        if not last_date:
            continue

        # 推算下次缴费日
        expected_next = last_date + timedelta(days=int(round(avg_interval)))

        # 如果推算的下次日期已在今天之前（或之后很近），则为待缴费
        is_overdue = expected_next <= today
        days_overdue = max(0, (today - expected_next).days)

        # 周期类型判断
        if avg_interval >= 40:
            period_type = "quarterly"
        else:
            period_type = "monthly"

        # 置信度
        if len(records) >= 4 and max(intervals) - min(intervals) < 15:
            confidence = "high"
        elif len(records) >= 2:
            confidence = "medium"
        else:
            confidence = "low"

        # 仅返回近期（逾期或60天内即将到期）的待缴费项
        if is_overdue or days_overdue > -60:
            payment_type = str(last_record.get("缴费类型", ""))
            try:
                last_amount = abs(float(last_record.get("金额(元)", 0)))
            except (ValueError, TypeError):
                last_amount = 0.0

            pending.append({
                "payment_no": pno,
                "payment_type": payment_type,
                "last_date": str(last_record.get("缴费日期", "")),
                "last_amount": round(last_amount, 2),
                "estimated_next_date": expected_next.strftime("%Y-%m-%d"),
                "estimated_amount": round(avg_amount, 2),
                "is_overdue": is_overdue,
                "days_overdue": days_overdue if is_overdue else 0,
                "days_until_due": 0 if is_overdue else abs(days_overdue),
                "period_type": period_type,
                "avg_interval_days": round(avg_interval, 1),
                "history_count": len(records),
                "confidence": confidence,
            })

    # 按逾期天数降序（逾期在前），再按下次缴费日升序
    pending.sort(key=lambda x: (-x["is_overdue"], x["estimated_next_date"]))

    return pending


def _parse_date(s: str) -> date | None:
    """解析日期字符串 YYYY-MM-DD"""
    if not s or not s.strip():
        return None
    try:
        return datetime.strptime(s.strip()[:10], "%Y-%m-%d").date()
    except ValueError:
        return None
