"""通义千问LLM适配器 — 使用 OpenAI 兼容协议接入 Kimi / 百炼"""
import json
from typing import AsyncIterator

from openai import AsyncOpenAI

from pmb.llm.base import BaseLLM, ChatResponse, ChatChunk, ToolCall
from pmb.core.config import LLM_API_KEY, LLM_BASE_URL, LLM_MODEL


class QwenLLM(BaseLLM):
    """LLM 适配，使用 OpenAI 兼容协议"""

    def __init__(
        self,
        model: str | None = None,
        api_key: str | None = None,
        base_url: str | None = None,
    ):
        self.model = model or LLM_MODEL
        self.client = AsyncOpenAI(
            api_key=api_key or LLM_API_KEY or "not-set",
            base_url=base_url or LLM_BASE_URL,
        )

    def _format_tools(self, tools: list[dict] | None) -> list[dict] | None:
        """确保工具定义格式兼容 OpenAI"""
        if not tools:
            return None
        # 工具定义已是标准 OpenAI function calling 格式，直接透传
        return tools

    async def chat(
        self,
        messages: list[dict],
        tools: list[dict] | None = None,
        temperature: float = 0.7,
    ) -> ChatResponse:
        kwargs: dict = {
            "model": self.model,
            "messages": messages,
        }
        # kimi-k2.5 等模型要求 temperature 必须为 1
        if "kimi" not in self.model.lower():
            kwargs["temperature"] = temperature
        formatted_tools = self._format_tools(tools)
        if formatted_tools:
            kwargs["tools"] = formatted_tools

        response = await self.client.chat.completions.create(**kwargs)
        choice = response.choices[0]
        message = choice.message

        tool_calls = []
        if message.tool_calls:
            for tc in message.tool_calls:
                try:
                    arguments = json.loads(tc.function.arguments)
                except (json.JSONDecodeError, TypeError):
                    arguments = {}
                tool_calls.append(ToolCall(
                    id=tc.id,
                    name=tc.function.name,
                    arguments=arguments,
                ))

        return ChatResponse(
            content=message.content or "",
            tool_calls=tool_calls,
            finish_reason=choice.finish_reason or "stop",
            reasoning_content=getattr(message, 'reasoning_content', None),
        )

    async def chat_stream(
        self,
        messages: list[dict],
        tools: list[dict] | None = None,
        temperature: float = 0.7,
    ) -> AsyncIterator[ChatChunk]:
        kwargs: dict = {
            "model": self.model,
            "messages": messages,
            "stream": True,
        }
        if "kimi" not in self.model.lower():
            kwargs["temperature"] = temperature
        formatted_tools = self._format_tools(tools)
        if formatted_tools:
            kwargs["tools"] = formatted_tools

        stream = await self.client.chat.completions.create(**kwargs)
        async for chunk in stream:
            if not chunk.choices:
                continue
            delta = chunk.choices[0].delta
            finish_reason = chunk.choices[0].finish_reason

            tool_calls = []
            if hasattr(delta, "tool_calls") and delta.tool_calls:
                for tc in delta.tool_calls:
                    if tc.function and tc.function.name:
                        try:
                            arguments = json.loads(tc.function.arguments or "{}")
                        except (json.JSONDecodeError, TypeError):
                            arguments = {}
                        tool_calls.append(ToolCall(
                            id=tc.id or "",
                            name=tc.function.name,
                            arguments=arguments,
                        ))

            reasoning_content = getattr(delta, 'reasoning_content', None)
            yield ChatChunk(
                content=delta.content or "",
                tool_calls=tool_calls,
                finish_reason=finish_reason,
                reasoning_content=reasoning_content,
            )

    async def vision(
        self,
        messages: list[dict],
        image_url: str,
    ) -> ChatResponse:
        # 检查当前模型是否支持图片输入
        # Kimi K2.5 等模型不支持 image_url 类型，需要降级为纯文本
        unsupported_models = ["kimi", "qwen-turbo", "qwen-plus"]
        model_lower = self.model.lower()
        is_vision_supported = not any(m in model_lower for m in unsupported_models)

        if not is_vision_supported:
            # 降级为纯文本调用，忽略图片
            return await self.chat(messages=messages)

        # 在消息中添加图片内容
        vision_messages = messages.copy()
        last_msg = vision_messages[-1] if vision_messages else {}
        last_msg["content"] = [
            {"type": "image_url", "image_url": {"url": image_url}},
            {"type": "text", "text": last_msg.get("content", "")},
        ]
        vision_messages[-1] = last_msg

        return await self.chat(messages=vision_messages)
