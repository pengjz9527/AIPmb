from pydantic import BaseModel
from typing import Optional


class TransactionResponse(BaseModel):
    seq: int
    source: str
    date: str
    direction: str
    amount: float
    category: str
    subcategory: str
    merchant: str
    payment_channel: str
    account_number: str
    currency: str


class TransactionSummaryItem(BaseModel):
    name: str
    count: int
    total: float
    avg: float
