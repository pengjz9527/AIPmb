"""AI-Manage API Schema"""
from pydantic import BaseModel
from typing import Any


class ModelConfigCreate(BaseModel):
    name: str
    provider: str
    api_key: str
    base_url: str
    model_name: str


class ModelConfigUpdate(BaseModel):
    name: str | None = None
    provider: str | None = None
    api_key: str | None = None
    base_url: str | None = None
    model_name: str | None = None
    is_active: bool | None = None


class BatchTagRequest(BaseModel):
    user_names: list[str]
    force_regenerate: bool = False


class MatchRequest(BaseModel):
    user_name: str
    tag_names: list[str] | None = None


class CalendarGenerateRequest(BaseModel):
    user_names: list[str]
    force_regenerate: bool = False


class TagRecommendationRequest(BaseModel):
    user_name: str