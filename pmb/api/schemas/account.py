from pydantic import BaseModel
from typing import Optional


class AccountResponse(BaseModel):
    seq: int
    name: str
    account_type: str
    card_product: str
    account_number: str
    branch: str
    currency: str
    expiry_date: str = ""
    balance: str = ""
    credit_limit: str = ""
    billing_day: str = ""
    due_day: str = ""
    amount_due: str = ""
    min_payment: str = ""
    last_tx_date: str = ""
    source: str = ""
    notes: str = ""


class AccountSummaryItem(BaseModel):
    label: str
    value: str


class WealthOverviewResponse(BaseModel):
    total_assets: float
    total_liabilities: float
    net_worth: float
    asset_breakdown: list[dict]
    currency: str = "CNY"
