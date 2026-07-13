from pydantic import BaseModel
from typing import Any


class ApiResponse(BaseModel):
    """统一API响应格式"""
    code: int = 0
    message: str = "ok"
    data: Any = None
    total: int | None = None


class PaginationParams(BaseModel):
    """分页参数"""
    limit: int = 20
    offset: int = 0
