from fastapi import APIRouter, Query
from pmb.core import product_service
from pmb.api.schemas.common import ApiResponse
from pmb.api.mappers.product_mapper import map_product_list, map_product_categories

router = APIRouter()


@router.get("/products", summary="产品列表")
async def list_products(
    keyword: str = Query("", description="搜索关键词"),
    category: str = Query("", description="产品类别"),
    bank: str = Query("", description="银行名称"),
    risk_level: str = Query("", description="风险等级"),
    limit: int = Query(20, description="每页数量"),
    offset: int = Query(0, description="偏移量"),
):
    results, total = product_service.list_products(
        keyword=keyword, category=category, bank=bank,
        risk_level=risk_level, limit=limit, offset=offset,
    )
    return ApiResponse(data=map_product_list(results), total=total)


@router.get("/products/summary", summary="产品统计")
async def get_product_summary(
    bank: str = Query("", description="银行名称"),
    category: str = Query("", description="产品类别"),
):
    stats = product_service.get_product_summary(bank=bank, category=category)
    return ApiResponse(data=stats)


@router.get("/products/categories", summary="产品类别列表")
async def get_categories():
    cats = product_service.get_categories()
    return ApiResponse(data=map_product_categories(cats))


@router.get("/products/{product_name}", summary="产品详情")
async def get_product(product_name: str, category: str = Query("")):
    result = product_service.get_product(product_name, category)
    if result is None:
        return ApiResponse(code=404, message="产品不存在")
    from pmb.api.mappers.product_mapper import map_product
    return ApiResponse(data=map_product(result))
