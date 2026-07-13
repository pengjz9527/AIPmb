"""对话记录管理路由 — 运营人员查询用户AI对话历史"""
import json
from datetime import datetime, timezone

from fastapi import APIRouter, Query
from fastapi.responses import StreamingResponse

from pmb.api.schemas.common import ApiResponse
from pmb.ai_manage.services import conversation_service
from pmb.ai_manage.store import read_json, write_json
from pmb.skills.orchestrator import skill_orchestrator

router = APIRouter()

MARKETING_LEADS_FILE = "marketing_leads.json"


@router.get("/manage/users/{user_name}/conversations", summary="获取用户对话记录列表")
async def list_user_conversations(
    user_name: str,
    keyword: str = Query("", description="搜索关键词（内容/业务维度）"),
    business_type: str = Query("", description="业务维度过滤: 理财/贷款/保险/基金/外汇/存款/黄金/信用卡/通用"),
    time_range: str = Query("", description="时间区隔过滤: today/week/month/older"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    """聚合内存实时对话 + JSON 历史数据，返回统一分页格式"""
    items, total = conversation_service.list_conversations(
        user_name=user_name,
        keyword=keyword,
        business_type=business_type,
        time_range=time_range,
        limit=limit,
        offset=offset,
    )
    return ApiResponse(data=items, total=total)


@router.get("/manage/users/{user_name}/conversations/{session_id}", summary="获取单次会话详情")
async def get_conversation_detail(user_name: str, session_id: str):
    detail = conversation_service.get_session_detail(user_name, session_id)
    if detail is None:
        return ApiResponse(code=404, message="会话不存在")
    return ApiResponse(data=detail)


@router.post("/manage/users/{user_name}/conversations/analyze", summary="AI分析标注业务维度")
async def analyze_conversation_business(
    user_name: str,
    session_id: str = Query(..., description="要分析的会话ID"),
):
    """对指定会话进行AI业务维度标注"""
    try:
        result = await conversation_service.analyze_business_type(user_name, session_id)
        return ApiResponse(data=result)
    except ValueError as e:
        return ApiResponse(code=404, message=str(e))
    except Exception as e:
        return ApiResponse(code=500, message=f"分析失败: {str(e)}")


@router.get("/manage/users/{user_name}/conversation-summary", summary="用户对话汇总统计")
async def get_conversation_summary(user_name: str):
    summary = conversation_service.get_conversation_summary(user_name)
    return ApiResponse(data=summary)


@router.post("/manage/users/{user_name}/marketing-leads", summary="营销线索分析")
async def analyze_marketing_leads(user_name: str):
    """基于近一周对话内容和用户标签，AI 分析生成营销线索（非流式，兼容旧版）"""
    try:
        result, summary = await skill_orchestrator.execute_skill(
            name="marketing_lead_analyzer",
            arguments={},
            user_name=user_name,
        )
        if not result.success:
            return ApiResponse(code=500, message=result.error or "分析失败")
        # 持久化存储（补充生成时间）
        save_data = dict(result.data)
        save_data["generated_at"] = datetime.now(timezone.utc).isoformat()
        _save_leads(user_name, save_data)
        return ApiResponse(data=save_data, message=summary)
    except Exception as e:
        return ApiResponse(code=500, message=f"营销线索分析失败: {str(e)}")


@router.get("/manage/users/{user_name}/marketing-leads", summary="获取营销线索")
async def get_marketing_leads(user_name: str):
    """获取已缓存的营销线索，包含生成时间"""
    leads = _load_leads(user_name)
    if leads:
        return ApiResponse(data=leads)
    return ApiResponse(data={"user_name": user_name, "leads": [], "generated_at": None})


@router.get("/manage/users/{user_name}/marketing-leads/stream", summary="流式营销线索分析")
async def analyze_marketing_leads_stream(user_name: str):
    """流式分析：逐步返回 AI 推理过程和最终线索"""
    from pmb.skills.domain.marketing_lead_analyzer import MARKETING_LEAD_PROMPT
    from pmb.ai_manage.services import tagging_service
    from pmb.ai_manage.services.conversation_service import (
        list_conversations, get_session_detail, _flatten_messages_to_text, _safe_iso_to_dt,
    )
    from pmb.llm.qwen import QwenLLM
    from datetime import timedelta

    async def generate():
        try:
            # 阶段1：收集数据
            yield _sse({"type": "status", "message": "正在收集用户标签..."})

            tags_data = tagging_service.get_tags_for_user(user_name)
            tags = []
            if tags_data is not None:
                for t in tags_data.tags:
                    if isinstance(t, dict):
                        name = t.get("name", "")
                        if name:
                            tags.append(name)

            yield _sse({"type": "status", "message": f"已获取 {len(tags)} 个标签，正在拉取对话记录..."})

            now = datetime.now(timezone.utc)
            one_week_ago = now - timedelta(days=7)
            all_items, _ = list_conversations(user_name=user_name, limit=100, offset=0)

            recent_sessions = []
            for item in all_items:
                started_at = item.get("started_at", "")
                dt = _safe_iso_to_dt(started_at)
                if dt and dt >= one_week_ago:
                    recent_sessions.append(item)
            if not recent_sessions:
                recent_sessions = all_items[:3]

            if not recent_sessions:
                yield _sse({"type": "done", "result": {
                    "user_name": user_name, "user_insight": "暂无对话记录",
                    "leads": [], "conversation_count": 0, "tags_used": tags,
                    "generated_at": now.isoformat(),
                }})
                return

            yield _sse({"type": "status", "message": f"已拉取 {len(recent_sessions)} 次近一周对话，正在提取内容..."})

            conversation_texts = []
            for session in recent_sessions:
                session_id = session.get("session_id", "")
                detail = get_session_detail(user_name, session_id)
                if detail:
                    messages = detail.get("messages", [])
                    text = _flatten_messages_to_text(messages)
                    if len(text) > 1500:
                        text = text[:1500] + "..."
                    conversation_texts.append(
                        f"--- 会话 ({session.get('started_at', '')[:10]}) ---\n{text}"
                    )

            combined_text = "\n\n".join(conversation_texts)
            if len(combined_text) > 6000:
                combined_text = combined_text[:6000] + "..."

            llm_input = f"""用户标签：{'、'.join(tags) if tags else '暂无标签'}

近期对话（共{len(recent_sessions)}次）：
{combined_text}"""

            yield _sse({"type": "status", "message": "数据已就绪，正在调用 AI 分析..."})

            # 阶段2：流式调用 LLM
            llm = QwenLLM()
            full_content = ""
            reasoning_parts: list[str] = []

            async for chunk in llm.chat_stream(
                messages=[
                    {"role": "system", "content": MARKETING_LEAD_PROMPT},
                    {"role": "user", "content": llm_input},
                ],
                temperature=0.5,
            ):
                if chunk.reasoning_content:
                    reasoning_parts.append(chunk.reasoning_content)
                    yield _sse({"type": "reasoning", "content": chunk.reasoning_content})
                if chunk.content:
                    full_content += chunk.content
                    yield _sse({"type": "content", "content": chunk.content})

            full_reasoning = "".join(reasoning_parts)

            # 阶段3：解析结果
            yield _sse({"type": "status", "message": "AI 分析完成，正在解析结果..."})

            content = full_content.strip()
            try:
                if "```json" in content:
                    content = content.split("```json")[1].split("```")[0].strip()
                elif "```" in content:
                    content = content.split("```")[1].split("```")[0].strip()
                parsed = json.loads(content)
            except (json.JSONDecodeError, IndexError):
                parsed = {"user_insight": "分析生成中遇到格式问题", "leads": []}

            generated_at = datetime.now(timezone.utc).isoformat()
            result = {
                "user_name": user_name,
                "user_insight": parsed.get("user_insight", ""),
                "leads": parsed.get("leads", []),
                "conversation_count": len(recent_sessions),
                "tags_used": tags,
                "generated_at": generated_at,
                "ai_reasoning": full_reasoning,
            }

            # 持久化存储
            _save_leads(user_name, {
                "user_name": user_name,
                "user_insight": result["user_insight"],
                "leads": result["leads"],
                "conversation_count": result["conversation_count"],
                "tags_used": result["tags_used"],
                "generated_at": generated_at,
            })

            yield _sse({"type": "done", "result": result})

        except Exception as e:
            yield _sse({"type": "error", "message": str(e)})

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


def _sse(data: dict) -> str:
    """格式化为 SSE 事件"""
    return f"data: {json.dumps(data, ensure_ascii=False)}\n\n"


def _load_leads(user_name: str) -> dict | None:
    """加载用户的营销线索缓存"""
    store = read_json(MARKETING_LEADS_FILE)
    if isinstance(store, list):
        store = {}
    return store.get(user_name)


def _save_leads(user_name: str, data: dict):
    """保存营销线索缓存"""
    store = read_json(MARKETING_LEADS_FILE)
    if isinstance(store, list):
        store = {}
    store[user_name] = data
    write_json(MARKETING_LEADS_FILE, store)
