import asyncio
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pmb.api.schemas.common import ApiResponse

router = APIRouter()

# 内存中存储对话历史
_chat_sessions: dict[str, list[dict]] = {}

# 会话ID到用户名的映射（用于运营端查询实时对话）
_session_user_map: dict[str, str] = {}

# 会话级别：当前活跃的 Agent ID
_session_active_agent: dict[str, str] = {}


@router.get("/chat/sessions", summary="对话会话列表")
async def list_sessions():
    sessions = [
        {"session_id": sid, "message_count": len(msgs)}
        for sid, msgs in _chat_sessions.items()
    ]
    return ApiResponse(data=sessions)


@router.post("/chat/sessions", summary="创建对话会话")
async def create_session():
    import uuid
    session_id = str(uuid.uuid4())[:8]
    _chat_sessions[session_id] = []
    return ApiResponse(data={"session_id": session_id})


@router.get("/chat/sessions/{session_id}/messages", summary="获取对话历史")
async def get_messages(session_id: str):
    messages = _chat_sessions.get(session_id, [])
    return ApiResponse(data=messages)


@router.websocket("/chat/ws/{session_id}")
async def websocket_chat(websocket: WebSocket, session_id: str):
    """WebSocket 对话端点，支持真流式输出 + thinking 过程展示"""
    # 从 query string 获取用户标识（用于长期记忆关联）
    user_name = websocket.query_params.get("user_name", "")

    await websocket.accept()

    if session_id not in _chat_sessions:
        _chat_sessions[session_id] = []

    # 加载用户长期记忆摘要
    from pmb.core.memory_service import memory_service
    memory_summary = ""
    if user_name:
        await memory_service.start_session(user_name, session_id)
        memory_summary = memory_service.get_memory_summary(user_name)
        _session_user_map[session_id] = user_name

    try:
        while True:
            data = await websocket.receive_json()
            content = data.get("content", "")
            content_type = data.get("content_type", "text")

            # 存储用户消息
            user_msg = {"role": "user", "content": content, "content_type": content_type}
            _chat_sessions[session_id].append(user_msg)

            # 路由智能体：优先使用会话活跃 Agent，否则按意图路由
            from pmb.agents.registry import agent_registry

            current_agent_id = _session_active_agent.get(session_id)
            agent = None

            if current_agent_id:
                agent = agent_registry.get_agent(current_agent_id)
                # 检查是否应退出当前 Agent
                if agent and agent.can_handle(content) < 0.15:
                    agent = None
                    _session_active_agent.pop(session_id, None)

            if agent is None:
                agent = agent_registry.route(content)
                _session_active_agent[session_id] = agent.agent_id

            # 如果 Agent 变更，通知前端
            if current_agent_id and current_agent_id != agent.agent_id:
                await websocket.send_json({
                    "type": "agent_changed",
                    "agent_id": agent.agent_id,
                    "agent_name": agent.name,
                })

            if agent is None:
                await websocket.send_json({
                    "type": "error",
                    "content": "智能体服务暂不可用",
                    "is_final": True,
                })
                continue

            # 构建上下文（含用户标识和历史记忆）
            from pmb.agents.base import AgentContext
            context = AgentContext(
                session_id=session_id,
                user_message=content,
                user_name=user_name,
                memory_summary=memory_summary,
                conversation_history=_chat_sessions[session_id],
            )

            # 使用事件队列实现真流式
            event_queue: asyncio.Queue = asyncio.Queue()
            analysis_task = asyncio.create_task(
                agent.analyze_stream(context, event_queue)
            )

            final_content = ""
            try:
                while True:
                    try:
                        event = await asyncio.wait_for(event_queue.get(), timeout=120)
                    except asyncio.TimeoutError:
                        await websocket.send_json({
                            "type": "error",
                            "content": "请求超时，请重试",
                            "is_final": True,
                        })
                        break

                    event_type = event.get("type", "")

                    # 处理 agent_changed 事件（Agent 内部触发了切换）
                    if event_type == "agent_changed":
                        new_agent_id = event.get("agent_id", "")
                        if new_agent_id:
                            _session_active_agent[session_id] = new_agent_id
                        await websocket.send_json(event)
                        continue

                    if event_type == "ai_done":
                        final_content = event.get("content", "")
                        await websocket.send_json({
                            "type": "ai_done",
                            "content": "",
                            "is_final": True,
                            "next_suggestions": event.get("next_suggestions", []),
                        })
                        break

                    await websocket.send_json(event)

            except Exception as e:
                await websocket.send_json({
                    "type": "error",
                    "content": f"智能体处理出错: {str(e)}",
                    "is_final": True,
                })
            finally:
                if not analysis_task.done():
                    analysis_task.cancel()

            # 存储助手消息
            if final_content:
                _chat_sessions[session_id].append({
                    "role": "assistant",
                    "content": final_content,
                    "agent_id": agent.agent_id,
                })

    except WebSocketDisconnect:
        # 清理会话 Agent 状态
        _session_active_agent.pop(session_id, None)
        # 断开时保存本次对话并后台压缩历史记忆
        if user_name:
            session_msgs = _chat_sessions.get(session_id, [])
            if session_msgs:
                # 同步保存记忆（确保在 handler 返回前完成）
                await memory_service.end_session(user_name, session_id, session_msgs)
                # 压缩在后台执行
                asyncio.ensure_future(memory_service.compress_if_needed(user_name))