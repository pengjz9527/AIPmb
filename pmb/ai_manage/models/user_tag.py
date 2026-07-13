"""用户标签数据模型"""
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class UserTag:
    user_name: str
    tags: list[dict] = field(default_factory=list)  # [{"name": "...", "reasoning": "..."}]
    generated_at: str = field(default_factory=lambda: datetime.now().isoformat())
    model_used: str = ""

    def to_dict(self) -> dict:
        return {
            "user_name": self.user_name,
            "tags": self.tags,
            "generated_at": self.generated_at,
            "model_used": self.model_used,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "UserTag":
        return cls(
            user_name=d.get("user_name", ""),
            tags=d.get("tags", []),
            generated_at=d.get("generated_at", ""),
            model_used=d.get("model_used", ""),
        )