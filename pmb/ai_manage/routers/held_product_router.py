"""用户持有产品路由"""
from fastapi import APIRouter, Query, Header
from pmb.api.schemas.common import ApiResponse
from pmb.api.schemas.held_product import RedeemRequest, PrepayRequest
from pmb.ai_manage.services import held_product_service

router = APIRouter()


def _get_user_name(user_name: str, x_user_name: str) -> str:
    """优先使用 query 参数，否则从 header 获取并 URL 解码"""
    if user_name:
        return user_name
    if x_user_name:
        import urllib.parse
        return urllib.parse.unquote(x_user_name)
    return ""


# ========== 理财 ==========
@router.get("/held-products/wealth", summary="列出用户持有理财产品")
async def list_wealth(
    user_name: str = Query("", description="用户姓名"),
    x_user_name: str = Header("", alias="x-user-name"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    name = _get_user_name(user_name, x_user_name)
    if not name:
        return ApiResponse(code=400, message="缺少用户姓名参数")
    items, total = held_product_service.list_wealth_products(name, limit=limit, offset=offset)
    return ApiResponse(data=items, total=total)


@router.get("/held-products/wealth/{product_id}", summary="理财产品详情")
async def get_wealth_detail(product_id: str):
    detail = held_product_service.get_wealth_detail(product_id)
    if detail is None:
        return ApiResponse(code=404, message=f"理财产品 {product_id} 不存在")
    return ApiResponse(data=detail)


@router.post("/held-products/wealth/{product_id}/redeem", summary="赎回理财产品")
async def redeem_wealth(product_id: str, body: RedeemRequest):
    try:
        result = held_product_service.redeem_wealth_product(product_id, amount=body.amount)
        return ApiResponse(data=result)
    except ValueError as e:
        return ApiResponse(code=404, message=str(e))


# ========== 贷款 ==========
@router.get("/held-products/loans", summary="列出用户持有贷款")
async def list_loans(
    user_name: str = Query("", description="用户姓名"),
    x_user_name: str = Header("", alias="x-user-name"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    name = _get_user_name(user_name, x_user_name)
    if not name:
        return ApiResponse(code=400, message="缺少用户姓名参数")
    items, total = held_product_service.list_loans(name, limit=limit, offset=offset)
    return ApiResponse(data=items, total=total)


@router.get("/held-products/loans/{loan_id}", summary="贷款详情")
async def get_loan_detail(loan_id: str):
    detail = held_product_service.get_loan_detail(loan_id)
    if detail is None:
        return ApiResponse(code=404, message=f"贷款 {loan_id} 不存在")
    return ApiResponse(data=detail)


@router.get("/held-products/loans/{loan_id}/repayment-plan", summary="还款计划")
async def get_repayment_plan(loan_id: str):
    try:
        plan = held_product_service.get_repayment_plan(loan_id)
        return ApiResponse(data=plan)
    except ValueError as e:
        return ApiResponse(code=404, message=str(e))


@router.post("/held-products/loans/{loan_id}/prepay", summary="提前还款")
async def prepay_loan(loan_id: str, body: PrepayRequest):
    try:
        result = held_product_service.prepay_loan(loan_id, amount=body.amount)
        return ApiResponse(data=result)
    except ValueError as e:
        return ApiResponse(code=404, message=str(e))


# ========== 养老金 ==========
@router.get("/held-products/pensions", summary="列出用户养老金账户")
async def list_pensions(
    user_name: str = Query("", description="用户姓名"),
    x_user_name: str = Header("", alias="x-user-name"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    name = _get_user_name(user_name, x_user_name)
    if not name:
        return ApiResponse(code=400, message="缺少用户姓名参数")
    items, total = held_product_service.list_pensions(name, limit=limit, offset=offset)
    return ApiResponse(data=items, total=total)


@router.get("/held-products/pensions/{pension_id}", summary="养老金账户详情")
async def get_pension_detail(pension_id: str):
    detail = held_product_service.get_pension_detail(pension_id)
    if detail is None:
        return ApiResponse(code=404, message=f"养老金账户 {pension_id} 不存在")
    return ApiResponse(data=detail)


# ========== 汇总 ==========
@router.get("/held-products/summary/{user_name}", summary="用户持有产品汇总")
async def get_held_summary(user_name: str):
    summary = held_product_service.get_user_held_summary(user_name)
    if summary is None:
        return ApiResponse(code=404, message=f"用户 {user_name} 暂无持有产品")
    return ApiResponse(data=summary)
