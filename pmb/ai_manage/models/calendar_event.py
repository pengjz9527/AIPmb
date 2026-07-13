"""纪念日历数据模型"""
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class MemorialEvent:
    date: str                # 纪念日期 "YYYY-MM-DD"
    event_type: str          # 事件类型: milestone/life_change/major_purchase/emotion/growth
    title: str               # 事件标题
    description: str         # 温馨文案
    related_transactions: list[dict] = field(default_factory=list)  # 关联交易记录
    importance: int = 5      # 重要性评分 1-10

    def to_dict(self) -> dict:
        return {
            "date": self.date,
            "event_type": self.event_type,
            "title": self.title,
            "description": self.description,
            "related_transactions": self.related_transactions,
            "importance": self.importance,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "MemorialEvent":
        return cls(
            date=d.get("date", ""),
            event_type=d.get("event_type", ""),
            title=d.get("title", ""),
            description=d.get("description", ""),
            related_transactions=d.get("related_transactions", []),
            importance=d.get("importance", 5),
        )


@dataclass
class MemorialCalendar:
    user_name: str
    events: list[MemorialEvent] = field(default_factory=list)
    generated_at: str = field(default_factory=lambda: datetime.now().isoformat())
    model_used: str = ""

    def to_dict(self) -> dict:
        return {
            "user_name": self.user_name,
            "events": [e.to_dict() for e in self.events],
            "generated_at": self.generated_at,
            "model_used": self.model_used,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "MemorialCalendar":
        return cls(
            user_name=d.get("user_name", ""),
            events=[MemorialEvent.from_dict(e) for e in d.get("events", [])],
            generated_at=d.get("generated_at", ""),
            model_used=d.get("model_used", ""),
        )