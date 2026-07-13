"""模型配置数据模型"""
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class ModelConfig:
    id: str
    name: str
    provider: str
    api_key: str
    base_url: str
    model_name: str
    is_active: bool = False
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now().isoformat())

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "provider": self.provider,
            "api_key": self.api_key,
            "base_url": self.base_url,
            "model_name": self.model_name,
            "is_active": self.is_active,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "ModelConfig":
        return cls(
            id=d.get("id", ""),
            name=d.get("name", ""),
            provider=d.get("provider", ""),
            api_key=d.get("api_key", ""),
            base_url=d.get("base_url", ""),
            model_name=d.get("model_name", ""),
            is_active=d.get("is_active", False),
            created_at=d.get("created_at", ""),
            updated_at=d.get("updated_at", ""),
        )