"""标签管理路由"""
from fastapi import APIRouter
from pmb.api.schemas.common import ApiResponse
from pmb.api.schemas.ai_manage import BatchTagRequest
from pmb.ai_manage.services import tagging_service

router = APIRouter()


@router.get("/manage/tags", summary="列出所有已标记用户")
async def list_tagged_users():
    users = tagging_service.list_tagged_users()
    return ApiResponse(data=users)


@router.get("/manage/tags/{user_name}", summary="获取用户标签")
async def get_user_tags(user_name: str):
    tag = tagging_service.get_tags_for_user(user_name)
    if tag is None:
        return ApiResponse(code=404, message=f"用户 {user_name} 暂无标签，请先生成")
    return ApiResponse(data=tag.to_dict())


@router.post("/manage/tags/{user_name}/generate", summary="生成用户标签")
async def generate_user_tags(user_name: str):
    try:
        tag = await tagging_service.generate_tags_for_user(user_name, force=True)
        return ApiResponse(data=tag.to_dict())
    except ValueError as e:
        return ApiResponse(code=404, message=str(e))
    except Exception as e:
        return ApiResponse(code=500, message=f"生成标签失败: {str(e)}")


@router.post("/manage/tags/batch-generate", summary="批量生成标签")
async def batch_generate_tags(body: BatchTagRequest):
    results = await tagging_service.batch_generate_tags(body.user_names, force=body.force_regenerate)
    return ApiResponse(data=results)