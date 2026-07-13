"""购买申请 Schema"""
from pydantic import BaseModel


class PurchaseRequest(BaseModel):
    product_name: str
    amount: float


class PurchaseResponse(BaseModel):
    id: str
    user_name: str
    product_name: str
    amount: float
    status: str
    created_at: str
