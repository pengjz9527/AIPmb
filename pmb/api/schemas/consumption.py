from pydantic import BaseModel


class ConsumptionResponse(BaseModel):
    seq: int
    date: str
    direction: str
    amount: float
    subcategory: str
    category: str
    merchant: str
    channel: str
    card_number: str
    summary: str


class ConsumptionStatsItem(BaseModel):
    name: str
    count: int
    total: float
    avg: float
