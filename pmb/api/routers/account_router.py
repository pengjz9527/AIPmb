from fastapi import APIRouter, Query, Header
from pmb.core import account_service
from pmb.api.schemas.common import ApiResponse
from pmb.api.mappers.account_mapper import map_account_list, map_account_summary

router = APIRouter()


from urllib.parse import unquote

def _decode_user_name(user_name: str) -> str:
    """HTTP Header 中的中文可能以 latin1 或 URL 编码形式传输，统一解码为 utf-8"""
    if not user_name:
        return ""
    # 先尝试 URL 解码（前端 Uri.encodeComponent 编码）
    try:
        decoded = unquote(user_name)
        if decoded != user_name:
            return decoded
    except Exception:
        pass
    # 再尝试 latin1 解码（curl 等工具直接发送 UTF-8 时的编码方式）
    try:
        return user_name.encode("latin1").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return user_name


@router.get("/accounts", summary="账户列表")
async def list_accounts(
    keyword: str = Query("", description="搜索关键词"),
    account_type: str = Query("", description="账户类型: credit/debit"),
    limit: int = Query(20, description="每页数量"),
    offset: int = Query(0, description="偏移量"),
    user_name: str = Header("", alias="x-user-name"),
):
    user_name = _decode_user_name(user_name)
    results, total = account_service.list_accounts(
        user_name=user_name, keyword=keyword, account_type=account_type, limit=limit, offset=offset
    )
    return ApiResponse(
        data=map_account_list(results), total=total
    )


@router.get("/accounts/summary", summary="账户汇总")
async def get_account_summary(user_name: str = Header("", alias="x-user-name")):
    user_name = _decode_user_name(user_name)
    summary = account_service.get_account_summary(user_name=user_name)
    return ApiResponse(data=map_account_summary(summary))


@router.get("/accounts/{account_id}", summary="账户详情")
async def get_account(account_id: str):
    result = account_service.get_account(account_id)
    if result is None:
        return ApiResponse(code=404, message="账户不存在")
    from pmb.api.mappers.account_mapper import map_account
    return ApiResponse(data=map_account(result))


