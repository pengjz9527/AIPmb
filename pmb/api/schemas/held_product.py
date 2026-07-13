"""持有产品 API Schema"""
from pydantic import BaseModel


class RedeemRequest(BaseModel):
    amount: float | None = None


class PrepayRequest(BaseModel):
    amount: float


class RepaymentPlanItem(BaseModel):
    period: int
    payment_date: str
    principal: float
    interest: float
    total_payment: float
    remaining_principal: float
