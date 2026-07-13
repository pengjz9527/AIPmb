from fastapi import APIRouter, Query, Header
from pmb.core import consumption_service
from pmb.api.schemas.common import ApiResponse
from pmb.api.mappers.consumption_mapper import map_consumption_list, map_consumption_stats
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


@router.get("/consumptions", summary="消费列表")
async def list_consumptions(
    keyword: str = Query("", description="搜索关键词"),
    subcategory: str = Query("", description="消费子类"),
    category: str = Query("", description="交易分类"),
    channel: str = Query("", description="支付渠道"),
    date_from: str = Query("", description="起始日期"),
    date_to: str = Query("", description="结束日期"),
    amount_min: float | None = Query(None, description="最小金额"),
    amount_max: float | None = Query(None, description="最大金额"),
    limit: int = Query(20, description="每页数量"),
    offset: int = Query(0, description="偏移量"),
    user_name: str = Header("", alias="x-user-name"),
):
    user_name = _decode_user_name(user_name)
    results, total = consumption_service.list_consumption(
        keyword=keyword, subcategory=subcategory, category=category,
        channel=channel, date_from=date_from, date_to=date_to,
        amount_min=amount_min, amount_max=amount_max,
        limit=limit, offset=offset,
        user_name=user_name,
    )
    return ApiResponse(data=map_consumption_list(results), total=total)


@router.get("/consumptions/stats", summary="消费统计")
async def get_consumption_stats(
    group_by: str = Query("subcategory", description="分组维度"),
    date_from: str = Query("", description="起始日期"),
    date_to: str = Query("", description="结束日期"),
    top: int = Query(10, description="显示前N条"),
    user_name: str = Header("", alias="x-user-name"),
):
    user_name = _decode_user_name(user_name)
    stats = consumption_service.get_consumption_stats(
        group_by=group_by, date_from=date_from, date_to=date_to, top=top,
        user_name=user_name,
    )
    return ApiResponse(data=map_consumption_stats(stats))


@router.get("/consumptions/{seq_no}", summary="消费详情")
async def get_consumption(
    seq_no: int,
    user_name: str = Header("", alias="x-user-name"),
):
    user_name = _decode_user_name(user_name)
    result = consumption_service.get_consumption(seq_no, user_name=user_name)
    if result is None:
        return ApiResponse(code=404, message="消费记录不存在")
    return ApiResponse(data=result)
