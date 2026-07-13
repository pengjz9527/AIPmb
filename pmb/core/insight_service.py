"""AI 一句话洞察服务 — 基于用户消费/交易数据生成简短智能洞察"""
import asyncio
import time
from datetime import datetime

# 简单内存缓存 {user_name: (timestamp, insight_data)}
_insight_cache: dict[str, tuple[float, dict]] = {}
_CACHE_TTL = 300  # 5分钟


async def generate_insight(user_name: str) -> dict:
    """生成用户 AI 一句话洞察（≤40字），带缓存和降级策略"""

    # 1. 检查缓存
    if user_name in _insight_cache:
        cached_time, cached_data = _insight_cache[user_name]
        if time.time() - cached_time < _CACHE_TTL:
            return cached_data

    # 2. 获取消费统计数据
    from pmb.core import consumption_service, transaction_service

    stats = consumption_service.get_consumption_stats(
        group_by="month", top=3, user_name=user_name
    )
    category_stats = consumption_service.get_consumption_stats(
        group_by="subcategory", top=5, user_name=user_name
    )

    # 3. 尝试调用 LLM 生成洞察
    try:
        insight_text = await _generate_with_llm(stats, category_stats, user_name)
        insight_type = _classify_insight(insight_text)
    except Exception:
        # 降级：使用规则生成静态文案
        insight_text, insight_type = _generate_fallback(stats, category_stats)

    result = {
        "insight": insight_text,
        "insight_type": insight_type,
        "generated_at": datetime.now().isoformat(),
    }

    # 4. 写入缓存
    _insight_cache[user_name] = (time.time(), result)
    return result


async def _generate_with_llm(
    monthly_stats: list[dict],
    category_stats: list[dict],
    user_name: str,
) -> str:
    """调用 LLM 生成一句话洞察"""
    from pmb.llm.qwen import QwenLLM

    # 构造消费摘要
    month_desc = ", ".join(
        f"{s['name']}消费{s['count']}笔共¥{s['total']:.0f}" for s in monthly_stats[:3]
    )
    cat_desc = ", ".join(
        f"{s['name']}¥{s['total']:.0f}" for s in category_stats[:5]
    )

    prompt = (
        f"你是AI银行助手小易。基于以下用户消费数据，生成一句简短洞察（不超过35字），"
        f"要求友好、具体、有数据支撑，给出一个可行动的建议。\n\n"
        f"月度消费: {month_desc}\n"
        f"分类Top5: {cat_desc}\n\n"
        f"直接输出洞察文案，不要任何前缀或解释。"
    )

    llm = QwenLLM()
    resp = await asyncio.wait_for(
        llm.chat(messages=[{"role": "user", "content": prompt}], temperature=0.8),
        timeout=10.0,
    )
    return resp.content.strip().strip('"').strip("'")


def _generate_fallback(
    monthly_stats: list[dict], category_stats: list[dict]
) -> tuple[str, str]:
    """规则降级：基于数据直接拼接文案"""
    if not monthly_stats and not category_stats:
        return "开始记录你的消费，让小易为你提供更精准的建议", "general"

    # 有月度数据：对比趋势
    if len(monthly_stats) >= 2:
        latest = monthly_stats[0]["total"]
        prev = monthly_stats[1]["total"]
        if latest > prev * 1.2:
            pct = int((latest - prev) / prev * 100) if prev > 0 else 0
            return f"本月消费较上月增长{pct}%，建议关注大额支出", "spending_alert"
        elif latest < prev * 0.8:
            return "本月消费控制良好，继续保持理性消费习惯", "positive"

    # 有分类数据：展示 Top1
    if category_stats:
        top = category_stats[0]
        return f"近期{top['name']}消费最多，共{top['count']}笔¥{top['total']:.0f}", "category_insight"

    return "小易正在分析你的消费习惯，稍后为你呈现洞察", "general"


def _classify_insight(text: str) -> str:
    """简单分类洞察类型"""
    if any(w in text for w in ["增长", "偏高", "超过", "注意"]):
        return "spending_alert"
    if any(w in text for w in ["良好", "保持", "不错", "优秀"]):
        return "positive"
    if any(w in text for w in ["建议", "推荐", "试试"]):
        return "suggestion"
    return "general"
