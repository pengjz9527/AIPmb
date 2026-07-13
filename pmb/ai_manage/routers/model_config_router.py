"""模型配置路由"""
from fastapi import APIRouter
from pmb.api.schemas.common import ApiResponse
from pmb.api.schemas.ai_manage import ModelConfigCreate, ModelConfigUpdate
from pmb.ai_manage.services import model_config_service

router = APIRouter()


@router.get("/manage/model-configs", summary="列出所有模型配置")
async def list_model_configs():
    configs = model_config_service.list_configs()
    return ApiResponse(data=[c.to_dict() for c in configs])


@router.get("/manage/model-configs/active", summary="获取活跃配置")
async def get_active_config():
    config = model_config_service.get_active_config()
    if config is None:
        return ApiResponse(code=404, message="无活跃配置")
    return ApiResponse(data=config.to_dict())


@router.get("/manage/model-configs/{config_id}", summary="获取模型配置详情")
async def get_model_config(config_id: str):
    config = model_config_service.get_config(config_id)
    if config is None:
        return ApiResponse(code=404, message="配置不存在")
    return ApiResponse(data=config.to_dict())


@router.post("/manage/model-configs", summary="创建模型配置")
async def create_model_config(body: ModelConfigCreate):
    config = model_config_service.create_config(body.model_dump())
    return ApiResponse(data=config.to_dict())


@router.put("/manage/model-configs/{config_id}", summary="更新模型配置")
async def update_model_config(config_id: str, body: ModelConfigUpdate):
    config = model_config_service.update_config(config_id, body.model_dump(exclude_none=True))
    if config is None:
        return ApiResponse(code=404, message="配置不存在")
    return ApiResponse(data=config.to_dict())


@router.delete("/manage/model-configs/{config_id}", summary="删除模型配置")
async def delete_model_config(config_id: str):
    ok = model_config_service.delete_config(config_id)
    if not ok:
        return ApiResponse(code=400, message="无法删除活跃配置或配置不存在")
    return ApiResponse(message="删除成功")


@router.post("/manage/model-configs/{config_id}/activate", summary="激活模型配置")
async def activate_model_config(config_id: str):
    config = model_config_service.activate_config(config_id)
    if config is None:
        return ApiResponse(code=404, message="配置不存在")
    return ApiResponse(data=config.to_dict())