"""对话记录查询服务 — 聚合内存实时数据与JSON持久化历史"""
import json
from datetime import datetime, timedelta, timezone
from typing import Optional

from pmb.core.memory_service import memory_service
from pmb.api.routers.chat_router import _chat_sessions, _session_user_map
from pmb.utils.search import apply_pagination, fuzzy_match


# 业务维度关键词映射（用于快速预标注）
_BUSINESS_KEYWORDS = {
    "理财": ["理财", "基金", "投资", "收益", "净值", "申购", "赎回", "定投", "资产配置"],
    "贷款": ["贷款", "借款", "房贷", "车贷", "利率", "还款", "月供", "额度", "抵押", "信用贷"],
    "保险": ["保险", "保单", "保费", "重疾", "医疗险", "寿险", "意外险", "理赔", "投保"],
    "基金": ["基金", "股票基金", "债券基金", "货币基金", "ETF", "指数基金", "基金经理"],
    "外汇": ["外汇", "汇率", "美元", "欧元", "日元", "结汇", "购汇", "外币", "跨境"],
    "存款": ["存款", "定期", "活期", "大额存单", "利率", "保本", "储蓄", "存单"],
    "黄金": ["黄金", "金条", "纸黄金", "贵金属", "金价", "积存金", "黄金ETF"],
    "信用卡": ["信用卡", "账单", "额度", "分期", "积分", "还款日", "免息期", "刷卡"],
    "通用": [],
}

# LLM 业务分析提示词
_BUSINESS_ANALYSIS_PROMPT = """你是一位银行业务分类专家。请分析以下用户与AI助手的对话，判断主要涉及的业务维度。

可选业务维度：理财、贷款、保险、基金、外汇、存款、黄金、信用卡、通用（无明显业务倾向）

要求：
1. 返回最相关的1-3个业务维度
2. 给出简要理由（20字以内）
3. 如果涉及多个业务，按相关度排序

输出格式（严格JSON）：
{"business_types": [{"type": "业务维度", "confidence": 0.95, "reason": "理由"}], "summary": "对话核心意图摘要（30字以内）"}"""


def _safe_iso_to_dt(iso_str: str) -> Optional[datetime]:
    """安全解析 ISO 时间字符串"""
    if not iso_str:
        return None
    try:
        s = iso_str.replace("Z", "+00:00")
        return datetime.fromisoformat(s)
    except (ValueError, TypeError):
        return None


def _determine_time_range(dt: datetime) -> str:
    """将时间归类为时间段标签"""
    now = datetime.now(timezone.utc)
    delta = now - dt.astimezone(timezone.utc)
    if delta <= timedelta(hours=24):
        return "today"
    elif delta <= timedelta(days=7):
        return "week"
    elif delta <= timedelta(days=30):
        return "month"
    else:
        return "older"


def _keyword_match_business(text: str) -> list[str]:
    """基于关键词快速匹配业务维度"""
    if not text:
        return ["通用"]
    text_lower = text.lower()
    matched = []
    for biz, keywords in _BUSINESS_KEYWORDS.items():
        if biz == "通用":
            continue
        if any(kw in text_lower for kw in keywords):
            matched.append(biz)
    return matched if matched else ["通用"]


def _flatten_messages_to_text(messages: list[dict]) -> str:
    """将消息列表拼接为可搜索文本"""
    parts = []
    for m in messages:
        role = m.get("role", "")
        content = str(m.get("content", ""))
        if content.strip():
            parts.append(f"{role}:{content}")
    return "\n".join(parts)


def _entry_to_conversation_item(entry: dict, source: str, user_name: str) -> dict:
    """将 MemoryEntry 或内存会话转换为统一对话项格式"""
    session_id = entry.get("session_id", "")
    started_at = entry.get("started_at", "")
    ended_at = entry.get("ended_at", "")
    messages = entry.get("raw_messages", [])
    summary = entry.get("summary", "")
    compressed = entry.get("compressed", False)

    # 时间解析
    start_dt = _safe_iso_to_dt(started_at)
    time_range = _determine_time_range(start_dt) if start_dt else "older"

    # 业务维度预标注
    searchable_text = summary if compressed else _flatten_messages_to_text(messages)
    business_types = entry.get("business_types") or _keyword_match_business(searchable_text)

    # 首条消息预览
    preview = ""
    if messages:
        first_user = next((m["content"] for m in messages if m.get("role") == "user"), "")
        preview = first_user[:80] + "..." if len(first_user) > 80 else first_user
    elif summary:
        preview = summary[:80] + "..." if len(summary) > 80 else summary

    return {
        "session_id": session_id,
        "user_name": user_name,
        "started_at": started_at,
        "ended_at": ended_at,
        "message_count": len(messages) if not compressed else 0,
        "preview": preview,
        "business_types": business_types,
        "time_range": time_range,
        "source": source,
        "compressed": compressed,
        "has_summary": bool(summary),
    }


def list_conversations(
    user_name: str,
    keyword: str = "",
    business_type: str = "",
    time_range: str = "",
    limit: int = 20,
    offset: int = 0,
) -> tuple[list[dict], int]:
    """聚合内存 + JSON 历史数据，支持过滤、搜索、分页"""

    all_items: list[dict] = []

    # 1. 加载 JSON 持久化历史
    memory = memory_service.load(user_name)
    for entry in memory.entries:
        item = _entry_to_conversation_item(entry, source="memory", user_name=user_name)
        all_items.append(item)

    # 2. 加载内存实时对话（通过 _session_user_map 关联用户）
    existing_ids = {e.get("session_id") for e in memory.entries}
    for session_id, mapped_user in _session_user_map.items():
        if mapped_user != user_name:
            continue
        if session_id in existing_ids:
            continue
        messages = _chat_sessions.get(session_id, [])
        if not messages:
            continue

        # 构造伪 entry
        now_iso = datetime.now(timezone.utc).isoformat()
        pseudo_entry = {
            "session_id": session_id,
            "started_at": now_iso,
            "ended_at": now_iso,
            "raw_messages": messages,
            "summary": "",
            "compressed": False,
        }
        item = _entry_to_conversation_item(pseudo_entry, source="realtime", user_name=user_name)
        all_items.append(item)

    # 3. 按时间倒序排序
    def _sort_key(item: dict):
        dt = _safe_iso_to_dt(item.get("started_at", ""))
        return dt or datetime.min.replace(tzinfo=timezone.utc)

    all_items.sort(key=_sort_key, reverse=True)

    # 4. 过滤
    filtered = all_items
    if business_type:
        filtered = [it for it in filtered if business_type in it.get("business_types", [])]
    if time_range:
        filtered = [it for it in filtered if it.get("time_range") == time_range]
    if keyword:
        filtered = [
            it for it in filtered
            if fuzzy_match(it, keyword, ["preview", "business_types", "session_id"])
        ]

    # 5. 分页
    paginated, total = apply_pagination(filtered, offset, limit)
    return paginated, total


def get_session_detail(user_name: str, session_id: str) -> Optional[dict]:
    """获取单次会话的完整消息详情"""

    # 优先查 JSON 历史
    memory = memory_service.load(user_name)
    for entry in memory.entries:
        if entry.get("session_id") == session_id:
            return {
                "session_id": session_id,
                "user_name": user_name,
                "started_at": entry.get("started_at"),
                "ended_at": entry.get("ended_at"),
                "messages": entry.get("raw_messages", []),
                "summary": entry.get("summary", ""),
                "compressed": entry.get("compressed", False),
                "business_types": entry.get("business_types", []),
                "source": "memory",
            }

    # 再查内存实时
    if session_id in _chat_sessions:
        messages = _chat_sessions[session_id]
        now_iso = datetime.now(timezone.utc).isoformat()
        return {
            "session_id": session_id,
            "user_name": user_name,
            "started_at": now_iso,
            "ended_at": now_iso,
            "messages": messages,
            "summary": "",
            "compressed": False,
            "business_types": [],
            "source": "realtime",
        }

    return None


async def analyze_business_type(user_name: str, session_id: str) -> dict:
    """调用 LLM 对指定会话进行业务维度智能标注"""
    detail = get_session_detail(user_name, session_id)
    if detail is None:
        raise ValueError("会话不存在")

    messages = detail.get("messages", [])
    text = _flatten_messages_to_text(messages)
    if not text.strip():
        raise ValueError("会话内容为空")

    from pmb.llm.qwen import QwenLLM

    llm = QwenLLM()
    prompt = f"{_BUSINESS_ANALYSIS_PROMPT}\n\n对话内容：\n{text[:2000]}"

    response = await llm.chat(
        messages=[{"role": "user", "content": prompt}],
        temperature=0.3,
    )

    content = response.content.strip()
    # 解析 markdown 代码块
    if "```json" in content:
        content = content.split("```json")[1].split("```")[0].strip()
    elif "```" in content:
        content = content.split("```")[1].split("```")[0].strip()

    try:
        result = json.loads(content)
    except json.JSONDecodeError:
        # 降级：返回关键词匹配结果
        result = {
            "business_types": [{"type": t, "confidence": 0.7, "reason": "关键词匹配"} for t in _keyword_match_business(text)],
            "summary": text[:30] + "...",
        }

    # 将结果写回 memory（如果是历史记录）
    memory = memory_service.load(user_name)
    for entry in memory.entries:
        if entry.get("session_id") == session_id:
            entry["business_types"] = [b["type"] for b in result.get("business_types", [])]
            entry["ai_summary"] = result.get("summary", "")
            memory_service.save(user_name, memory)
            break

    return result


def get_conversation_summary(user_name: str) -> dict:
    """获取用户对话汇总统计"""
    memory = memory_service.load(user_name)
    total_history = len(memory.entries)

    # 统计内存中的实时会话数
    realtime_count = sum(
        1 for sid, u in _session_user_map.items()
        if u == user_name and sid not in {e.get("session_id") for e in memory.entries}
    )

    # 业务维度分布
    biz_dist: dict[str, int] = {}
    for entry in memory.entries:
        btypes = entry.get("business_types") or _keyword_match_business(
            entry.get("summary", "") or _flatten_messages_to_text(entry.get("raw_messages", []))
        )
        for bt in btypes:
            biz_dist[bt] = biz_dist.get(bt, 0) + 1

    last_at = memory.entries[-1].get("ended_at") if memory.entries else None

    return {
        "user_name": user_name,
        "total_sessions": total_history + realtime_count,
        "history_sessions": total_history,
        "realtime_sessions": realtime_count,
        "business_distribution": biz_dist,
        "last_conversation_at": last_at,
    }
