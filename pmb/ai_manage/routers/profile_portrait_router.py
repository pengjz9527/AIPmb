"""AI 性格画像路由 — 用户消费画像生成"""
from fastapi import APIRouter
from pmb.api.schemas.common import ApiResponse
from pmb.ai_manage.services import profile_portrait_service

router = APIRouter()


@router.post("/manage/portrait/{user_name}/generate-async", summary="异步生成性格画像")
async def start_portrait(user_name: str):
    """启动异步画像生成，前端通过 /status 轮询进度"""
    profile_portrait_service.start_async(user_name)
    return ApiResponse(message="画像生成已启动", data={"status": "started"})


@router.get("/manage/portrait/{user_name}/status", summary="查询生成进度")
async def get_portrait_status(user_name: str):
    """查询异步画像生成的实时进度"""
    status = profile_portrait_service.get_progress(user_name)
    if status is None:
        return ApiResponse(code=404, message="暂无生成任务")
    return ApiResponse(data=status)


@router.get("/manage/portrait/{user_name}/result", summary="获取画像结果")
async def get_portrait_result(user_name: str):
    """获取缓存的画像结果"""
    result = profile_portrait_service.get_cached_result(user_name)
    if result is None:
        return ApiResponse(code=404, message="暂无画像结果，请先生成")
    return ApiResponse(data=result)


@router.delete("/manage/portrait/{user_name}/result", summary="清除画像缓存")
async def delete_portrait_result(user_name: str):
    """清除缓存"""
    ok = profile_portrait_service.delete_result(user_name)
    if not ok:
        return ApiResponse(code=404, message="画像结果不存在")
    return ApiResponse(message="删除成功")
