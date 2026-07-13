"""用户管理路由"""
from fastapi import APIRouter, Query
from pmb.api.schemas.common import ApiResponse
from pmb.ai_manage.services import user_service

router = APIRouter()


@router.get("/manage/users", summary="列出所有用户")
async def list_users(
    keyword: str = Query("", description="搜索关键词"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    users, total = user_service.list_users(keyword=keyword, limit=limit, offset=offset)
    return ApiResponse(data=users, total=total)


@router.get("/manage/users/{name}", summary="用户详情")
async def get_user_detail(name: str):
    detail = user_service.get_user_detail(name)
    if detail is None:
        return ApiResponse(code=404, message=f"用户 {name} 不存在")
    return ApiResponse(data=detail)


@router.get("/manage/users/{name}/accounts", summary="用户账户列表")
async def get_user_accounts(name: str):
    accounts = user_service.get_user_accounts(name)
    return ApiResponse(data=accounts)


@router.get("/manage/users/{name}/transactions", summary="用户交易记录")
async def get_user_transactions(
    name: str,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    txs, total = user_service.get_user_transactions(name, limit=limit, offset=offset)
    return ApiResponse(data=txs, total=total)


@router.get("/manage/users/{name}/consumption-stats", summary="用户消费统计")
async def get_user_consumption_stats(
    name: str,
    group_by: str = Query("subcategory", description="分组字段: subcategory/category/merchant/month"),
    top: int = Query(10, ge=1, le=50),
):
    stats = user_service.get_user_consumption_stats(name, group_by=group_by, top=top)
    return ApiResponse(data=stats)


@router.get("/manage/users/{name}/summary", summary="用户汇总信息")
async def get_user_summary(name: str):
    summary = user_service.get_user_summary(name)
    if summary is None:
        return ApiResponse(code=404, message=f"用户 {name} 不存在")
    return ApiResponse(data=summary)