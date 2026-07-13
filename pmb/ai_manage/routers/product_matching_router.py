"""AI 产品匹配路由 — 标签→产品智能匹配"""
from fastapi import APIRouter
from pmb.api.schemas.common import ApiResponse
from pmb.ai_manage.services import product_matching_service

router = APIRouter()


@router.post("/manage/products/{user_name}/match-async", summary="异步启动产品匹配")
async def start_match_async(user_name: str):
    """启动异步产品匹配任务，前端通过 /match-status 轮询进度"""
    product_matching_service.start_matching_async(user_name)
    return ApiResponse(message="产品匹配已启动", data={"status": "started"})


@router.get("/manage/products/{user_name}/match-status", summary="查询匹配进度")
async def get_match_status(user_name: str):
    """查询异步产品匹配的实时进度"""
    status = product_matching_service.get_matching_status(user_name)
    if status is None:
        return ApiResponse(code=404, message="暂无匹配任务")
    return ApiResponse(data=status)


@router.get("/manage/products/{user_name}/match-result", summary="获取匹配结果")
async def get_match_result(user_name: str):
    """获取缓存的匹配结果"""
    result = product_matching_service.get_cached_result(user_name)
    if result is None:
        return ApiResponse(code=404, message="暂无匹配结果，请先启动匹配")
    return ApiResponse(data=result)


@router.delete("/manage/products/{user_name}/match-result", summary="清除匹配缓存")
async def delete_match_result(user_name: str):
    """清除缓存"""
    ok = product_matching_service.delete_result(user_name)
    if not ok:
        return ApiResponse(code=404, message="匹配结果不存在")
    return ApiResponse(message="删除成功")
