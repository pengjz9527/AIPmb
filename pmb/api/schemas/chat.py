from pydantic import BaseModel
from typing import Any


class ChatMessageSend(BaseModel):
    """客户端发送的消息"""
    type: str = "user_message"
    content: str
    content_type: str = "text"
    media_url: str = ""
    agent_id: str | None = None


class ChatChunk(BaseModel):
    """服务端流式返回的chunk"""
    type: str = "ai_chunk"
    content: str = ""
    agent: dict | None = None
    cards: list[dict] = []
    is_final: bool = False


class ChatSession(BaseModel):
    session_id: str
    created_at: str
    agent_id: str | None = None
