"""缴费记录 API 路由"""
from fastapi import APIRouter, Query, Header
from pmb.api.schemas.common import ApiResponse
from urllib.parse import unquote

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
    except (UnicodeEncodeError, UnicodeDecodeError):
        return user_name


@router.get("/payments", summary="查询缴费记录")
async def get_payments(
    user_name: str = Header("", alias="x-user-name"),
    payment_type: str = Query("", description="缴费类型过滤（模糊匹配）"),
    date_from: str = Query("", description="起始日期 YYYY-MM-DD"),
    date_to: str = Query("", description="截止日期 YYYY-MM-DD"),
    limit: int = Query(20, description="每页记录数"),
    offset: int = Query(0, description="偏移量"),
):
    """查询缴费记录，支持按类型、日期范围过滤和分页"""
    from pmb.core import payment_service

    user_name = _decode_user_name(user_name)
    rows, total = payment_service.list_payments(
        user_name=user_name,
        payment_type=payment_type,
        date_from=date_from,
        date_to=date_to,
        limit=limit,
        offset=offset,
    )
    return ApiResponse(data=rows, total=total)


@router.get("/payments/summary", summary="缴费汇总统计")
async def get_payment_summary(user_name: str = Header("", alias="x-user-name")):
    """
    缴费汇总统计。
    返回 total_count、total_amount、by_type（按类型）、by_month（按月）、recent_payments（最近5笔）
    """
    from pmb.core import payment_service

    user_name = _decode_user_name(user_name)
    summary = payment_service.get_payment_summary(user_name=user_name)
    return ApiResponse(data=summary)


@router.get("/payments/forecast", summary="待缴费预测")
async def get_payment_forecast(user_name: str = Header("", alias="x-user-name")):
    """
    基于历史缴费规律预测待缴费任务。
    返回列表，每项包含 payment_no、payment_type、last_date、estimated_next_date、
    estimated_amount、is_overdue、days_overdue、confidence 等字段。
    """
    from pmb.core import payment_service

    user_name = _decode_user_name(user_name)
    pending = payment_service.predict_pending_payments(user_name=user_name)
    return ApiResponse(data=pending)
