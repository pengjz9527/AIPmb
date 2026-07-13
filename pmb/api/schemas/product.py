from pydantic import BaseModel


class ProductResponse(BaseModel):
    bank: str
    name: str
    category: str
    type_label: str
    description: str
    risk_level: str = ""


class ProductCategoryResponse(BaseModel):
    key: str
    name: str
    count: int
    bank_distribution: str
