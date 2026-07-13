"""LLM抽象基类"""
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import AsyncIterator


@dataclass
class ChatMessage:
    role: str  # system / user / assistant / tool
    content: str
    tool_call_id: str | None = None
    tool_name: str | None = None


@dataclass
class ToolCall:
    id: str
    name: str
    arguments: dict


@dataclass
class ChatResponse:
    content: str
    tool_calls: list[ToolCall] = field(default_factory=list)
    finish_reason: str = "stop"
    reasoning_content: str | None = None  # Kimi 等推理模型的思维链


@dataclass
class ChatChunk:
    content: str = ""
    tool_calls: list[ToolCall] = field(default_factory=list)
    finish_reason: str | None = None
    reasoning_content: str | None = None  # Kimi 等推理模型的思维链


class BaseLLM(ABC):
    """LLM抽象基类，所有LLM适配器必须继承"""

    @abstractmethod
    async def chat(
        self,
        messages: list[dict],
        tools: list[dict] | None = None,
        temperature: float = 0.7,
    ) -> ChatResponse:
        """非流式对话"""

    @abstractmethod
    async def chat_stream(
        self,
        messages: list[dict],
        tools: list[dict] | None = None,
        temperature: float = 0.7,
    ) -> AsyncIterator[ChatChunk]:
        """流式对话"""

    @abstractmethod
    async def vision(
        self,
        messages: list[dict],
        image_url: str,
    ) -> ChatResponse:
        """多模态（图片理解）"""
