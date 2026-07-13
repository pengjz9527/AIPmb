from pydantic import BaseModel


class TodoItem(BaseModel):
    todo_type: str
    title: str
    description: str
    priority: int = 0
    action_label: str = ""


class ProductRecommendation(BaseModel):
    name: str
    category: str
    type_label: str
    description: str
    risk_level: str = ""
    reason: str = ""


class PromoItem(BaseModel):
    title: str
    description: str
    valid_until: str = ""
    reason: str = ""


class AITagItem(BaseModel):
    """AI 生成的用户标签项"""
    name: str           # e.g., "高铁通勤VIP"
    description: str    # e.g., "近3个月铁路出行消费占比38%..."


class UserProfileTags(BaseModel):
    asset_level: str
    consumption_preference: str
    consumption_level: str
    risk_preference: str
    channel_preference: str
    top_categories: list[str]
    tags: list[str]
    ai_tags: list[AITagItem] = []  # AI 生成的富文本标签（可选，回退时为空）
