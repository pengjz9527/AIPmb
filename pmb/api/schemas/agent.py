from pydantic import BaseModel
from typing import Any


class AgentInfo(BaseModel):
    agent_id: str
    name: str
    description: str
    avatar: str


class NextSuggestion(BaseModel):
    id: str
    label: str
    prompt: str
    priority: str = "medium"
    reason: str = ""
    group: str = "root"  # "continue" | "root"


class AgentResult(BaseModel):
    agent_id: str
    agent_name: str
    content: str
    cards: list[dict] = []
    suggested_agents: list[str] = []
    metadata: dict = {}
    next_suggestions: list[NextSuggestion] = []
