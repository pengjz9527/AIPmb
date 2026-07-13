"""风险测评路由"""
from fastapi import APIRouter, Query, Header
from pydantic import BaseModel
from pmb.api.schemas.common import ApiResponse
from pmb.ai_manage.services import risk_assessment_service

router = APIRouter()


class RiskAssessmentRequest(BaseModel):
    user_name: str
    risk_level: str  # C1/C2/C3/C4/C5
    expiry_date: str  # YYYY/MM/DD


def _get_user_name(user_name: str, x_user_name: str) -> str:
    """优先使用 query 参数，否则从 header 获取并 URL 解码"""
    if user_name:
        return user_name
    if x_user_name:
        import urllib.parse
        return urllib.parse.unquote(x_user_name)
    return ""


@router.get("/risk-assessment", summary="查询用户风险测评结果")
async def get_risk_assessment(
    user_name: str = Query("", description="用户姓名"),
    x_user_name: str = Header("", alias="x-user-name"),
):
    name = _get_user_name(user_name, x_user_name)
    if not name:
        return ApiResponse(code=400, message="缺少用户姓名参数")
    result = risk_assessment_service.get_assessment(name)
    if result is None:
        return ApiResponse(data={"risk_level": "", "assessed": False})
    result["assessed"] = True
    return ApiResponse(data=result)


@router.post("/risk-assessment", summary="保存风险测评结果")
async def save_risk_assessment(body: RiskAssessmentRequest):
    valid_levels = {"C1", "C2", "C3", "C4", "C5"}
    if body.risk_level not in valid_levels:
        return ApiResponse(code=400, message=f"无效的风险等级: {body.risk_level}")
    record = risk_assessment_service.save_assessment(
        body.user_name, body.risk_level, body.expiry_date
    )
    return ApiResponse(data=record, message="测评结果已保存")
