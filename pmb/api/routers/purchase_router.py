"""购买申请路由"""
from fastapi import APIRouter, Header
from urllib.parse import unquote
from pmb.api.schemas.common import ApiResponse
from pmb.api.schemas.purchase import PurchaseRequest
from pmb.core import purchase_service

router = APIRouter()


def _decode_user_name(user_name: str) -> str:
    """HTTP Header 中的中文可能以 latin1 或 URL 编码形式传输，统一解码为 utf-8"""
    if not user_name:
        return ""
    try:
        decoded = unquote(user_name)
        if decoded != user_name:
            return decoded
    except Exception:
        pass
    try:
        return user_name.encode("latin1").decode("utf-8")
    except (UnicodeDecodeError, UnicodeEncodeError):
        return user_name


@router.post("/purchases", summary="提交购买申请")
async def create_purchase(
    body: PurchaseRequest,
    x_user_name: str = Header("", alias="x-user-name"),
):
    user_name = _decode_user_name(x_user_name)
    if not user_name:
        return ApiResponse(code=400, message="缺少用户身份信息")
    if body.amount <= 0:
        return ApiResponse(code=400, message="购买金额必须大于0")

    result = purchase_service.create_purchase(user_name, body.product_name, body.amount)
    return ApiResponse(data=result, message="购买申请已提交")
