"""AI 产品推荐路由 — 手机银行"为你推荐"接口"""
from fastapi import APIRouter, Query, Header
from urllib.parse import unquote
from pmb.api.schemas.common import ApiResponse
from pmb.ai_manage.services import product_matching_service as pms

router = APIRouter()


def _decode_user_name(user_name: str) -> str:
    """HTTP Header 中的中文 URL 编码解码"""
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
    except (UnicodeDecodeError, UnicodeEncodeError):
        return user_name


@router.get("/recommendations/ai-products", summary="AI产品推荐（手机银行）")
async def get_ai_products(
    x_user_name: str = Header("", alias="x-user-name"),
    refresh: bool = Query(False, description="是否强制刷新匹配"),
):
    user_name = _decode_user_name(x_user_name)
    if not user_name:
        return ApiResponse(code=400, message="缺少用户身份信息")

    # 强制刷新：清除缓存 + 清除进度
    if refresh:
        pms.delete_result(user_name)
        # 也清除进度状态
        from pmb.ai_manage.services.product_matching_service import _matching_status
        _matching_status.pop(user_name, None)

    # 查缓存
    cached = pms.get_cached_result(user_name)

    if cached is not None and not refresh:
        # 已有缓存，返回 top 3
        products = cached.get("matched_products", [])
        top3 = products[:3]
        return ApiResponse(
            data={
                "status": "ok",
                "products": top3,
                "tags_used": cached.get("tags_used", []),
            },
            total=len(products),
        )

    # 无缓存：启动异步匹配，立即返回 generating 状态
    # 先检查是否已经在匹配中
    status = pms.get_matching_status(user_name)
    if status is None or status.get("status") == "done":
        pms.start_matching_async(user_name)

    return ApiResponse(
        data={
            "status": "generating",
            "products": [],
            "message": "AI 匹配已启动，请轮询进度",
        },
    )


@router.get("/recommendations/ai-products/status", summary="AI产品匹配进度")
async def get_ai_products_status(
    x_user_name: str = Header("", alias="x-user-name"),
):
    user_name = _decode_user_name(x_user_name)
    if not user_name:
        return ApiResponse(code=400, message="缺少用户身份信息")

    raw = pms.get_matching_status(user_name)
    if raw is None:
        return ApiResponse(data={"status": "idle", "steps": [], "message": "暂无匹配任务"})

    # 计算每步状态
    current_step = raw.get("step", 0)
    raw_steps = raw.get("steps", [])
    steps = []
    for i, s in enumerate(raw_steps):
        if i < current_step:
            step_status = "completed"
        elif i == current_step and raw.get("status") != "done":
            step_status = "running"
        else:
            step_status = "pending"
        steps.append({
            "id": s["id"],
            "label": s["label"],
            "icon": s["icon"],
            "status": step_status,
            "detail": s.get("detail"),
        })

    overall_status = raw.get("status", "running")
    if overall_status == "done":
        steps = [{**s, "status": "completed"} for s in steps]

    resp = {
        "status": "done" if overall_status == "done" else "running",
        "message": raw.get("message", ""),
        "steps": steps,
    }

    # 如果已完成，附上结果
    if overall_status == "done":
        cached = pms.get_cached_result(user_name)
        if cached:
            products = cached.get("matched_products", [])
            resp["result"] = products[:3]
            resp["tags_used"] = cached.get("tags_used", [])

    return ApiResponse(data=resp)
