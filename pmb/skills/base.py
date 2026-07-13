"""Skill 基类定义"""
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any


@dataclass
class SkillResult:
    """Skill 执行返回"""
    success: bool
    data: Any = None
    summary: str = ""
    error: str = ""


class BaseSkill(ABC):
    """所有 Skill 的抽象基类 — 无状态、纯函数式"""

    @property
    @abstractmethod
    def name(self) -> str:
        """Skill 唯一名称，也是 LLM tool 的 function name"""

    @property
    @abstractmethod
    def description(self) -> str:
        """Skill 能力描述，成为 LLM tool 的 description"""

    @property
    def tool_definition(self) -> dict:
        """生成 OpenAI function calling 工具定义"""
        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": self.description,
                "parameters": self.parameters_schema,
            },
        }

    @property
    @abstractmethod
    def parameters_schema(self) -> dict:
        """工具参数 JSON Schema（空对象表示无参数）"""

    @abstractmethod
    async def execute(self, **kwargs) -> SkillResult:
        """执行技能，参数由 LLM 通过 function calling 传入"""