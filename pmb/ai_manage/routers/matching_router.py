"""产品匹配路由"""
from fastapi import APIRouter, Query
from pmb.api.schemas.common import ApiResponse
from pmb.api.schemas.ai_manage import MatchRequest, TagRecommendationRequest
from pmb.ai_manage.services import matching_service

router = APIRouter()


@router.post("/manage/matches", summary="生成产品匹配")
async def generate_matches(body: MatchRequest):
    try:
        record = await matching_service.match_tags_to_products(
            user_name=body.user_name,
            tag_names=body.tag_names,
            force=True,
        )
        return ApiResponse(data=record.to_dict(), total=len(record.matches))
    except ValueError as e:
        return ApiResponse(code=400, message=str(e))
    except Exception as e:
        return ApiResponse(code=500, message=f"生成匹配失败: {str(e)}")


@router.get("/manage/matches/{user_name}", summary="获取缓存匹配结果")
async def get_cached_matches(user_name: str):
    record = matching_service.get_cached_recommendations(user_name)
    if record is None:
        return ApiResponse(code=404, message=f"用户 {user_name} 暂无匹配结果，请先生成")
    return ApiResponse(data=record.to_dict(), total=len(record.matches))


@router.get("/manage/matches/{user_name}/products", summary="获取匹配产品列表")
async def get_matched_products(
    user_name: str,
    top: int = Query(20, ge=1, le=100),
):
    products = matching_service.get_matched_products(user_name, top=top)
    return ApiResponse(data=products, total=len(products))


@router.delete("/manage/matches/{user_name}", summary="清除匹配缓存")
async def delete_matches(user_name: str):
    ok = matching_service.delete_matches(user_name)
    if not ok:
        return ApiResponse(code=404, message="匹配结果不存在")
    return ApiResponse(message="删除成功")


@router.get("/manage/recommendations/{user_name}", summary="手机银行推荐接口")
async def get_tag_recommendations(user_name: str):
    """提供给 AI 手机银行调用，获取基于标签的产品推荐"""
    products = matching_service.get_matched_products(user_name, top=10)
    if not products:
        # 尝试自动生成
        try:
            record = await matching_service.match_tags_to_products(user_name, force=True)
            products = [m.to_dict() for m in record.matches[:10]]
        except Exception:
            return ApiResponse(code=404, message="暂无推荐")
    return ApiResponse(data=products, total=len(products))