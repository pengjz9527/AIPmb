from fastapi import APIRouter, Query, Header
from pmb.core import transaction_service
from pmb.api.schemas.common import ApiResponse
from pmb.api.mappers.transaction_mapper import map_transaction_list, map_transaction_summary
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


@router.get("/transactions", summary="交易列表")
async def list_transactions(
    keyword: str = Query("", description="搜索关键词"),
    source: str = Query("all", description="数据来源: credit/debit/all"),
    direction: str = Query("", description="收支方向: income/expense"),
    category: str = Query("", description="交易分类"),
    date_from: str = Query("", description="起始日期"),
    date_to: str = Query("", description="结束日期"),
    amount_min: float | None = Query(None, description="最小金额"),
    amount_max: float | None = Query(None, description="最大金额"),
    account: str = Query("", description="账号/卡号"),
    limit: int = Query(20, description="每页数量"),
    offset: int = Query(0, description="偏移量"),
    user_name: str = Header("", alias="x-user-name"),
):
    user_name = _decode_user_name(user_name)
    results, total = transaction_service.list_transactions(
        keyword=keyword, source=source, direction=direction,
        category=category, date_from=date_from, date_to=date_to,
        amount_min=amount_min, amount_max=amount_max,
        account=account, limit=limit, offset=offset,
        user_name=user_name,
    )
    return ApiResponse(data=map_transaction_list(results), total=total)


@router.get("/transactions/summary", summary="交易汇总")
async def get_transaction_summary(
    source: str = Query("all", description="数据来源"),
    date_from: str = Query("", description="起始日期"),
    date_to: str = Query("", description="结束日期"),
    group_by: str = Query("month", description="分组维度: month/year/category/subcategory"),
    user_name: str = Header("", alias="x-user-name"),
):
    user_name = _decode_user_name(user_name)
    stats = transaction_service.get_transaction_summary(
        source=source, date_from=date_from, date_to=date_to, group_by=group_by,
        user_name=user_name,
    )
    return ApiResponse(data=map_transaction_summary(stats))


@router.get("/transactions/{seq_no}", summary="交易详情")
async def get_transaction(
    seq_no: int,
    source: str = Query("all"),
    user_name: str = Header("", alias="x-user-name"),
):
    user_name = _decode_user_name(user_name)
    result = transaction_service.get_transaction(seq_no, source, user_name=user_name)
    if result is None:
        return ApiResponse(code=404, message="交易不存在")
    from pmb.api.mappers.transaction_mapper import map_transaction
    return ApiResponse(data=map_transaction(result))
