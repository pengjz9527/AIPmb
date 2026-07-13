"""产品匹配结果数据模型"""
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class ProductMatch:
    tag_name: str
    product_name: str
    product_category: str
    match_score: float
    reasoning: str
    product_detail: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "tag_name": self.tag_name,
            "product_name": self.product_name,
            "product_category": self.product_category,
            "match_score": self.match_score,
            "reasoning": self.reasoning,
            "product_detail": self.product_detail,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "ProductMatch":
        return cls(
            tag_name=d.get("tag_name", ""),
            product_name=d.get("product_name", ""),
            product_category=d.get("product_category", ""),
            match_score=d.get("match_score", 0.0),
            reasoning=d.get("reasoning", ""),
            product_detail=d.get("product_detail", {}),
        )


@dataclass
class RecommendationRecord:
    user_name: str
    matches: list[ProductMatch] = field(default_factory=list)
    generated_at: str = field(default_factory=lambda: datetime.now().isoformat())
    model_used: str = ""

    def to_dict(self) -> dict:
        return {
            "user_name": self.user_name,
            "matches": [m.to_dict() for m in self.matches],
            "generated_at": self.generated_at,
            "model_used": self.model_used,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "RecommendationRecord":
        return cls(
            user_name=d.get("user_name", ""),
            matches=[ProductMatch.from_dict(m) for m in d.get("matches", [])],
            generated_at=d.get("generated_at", ""),
            model_used=d.get("model_used", ""),
        )