"""技能监控路由 — 日志查询与周报"""
from fastapi import APIRouter, Query
from pmb.api.schemas.common import ApiResponse
from pmb.ai_manage.services import skill_monitor_service as svc

router = APIRouter()


@router.get("/manage/skill-logs", summary="查询技能调用日志")
async def list_skill_logs(
    skill_name: str = Query("", description="Skill 名称筛选，多个用逗号分隔"),
    status: str = Query("", description="状态筛选: success / failure / 空=全部"),
    user_name: str = Query("", description="按用户筛选"),
    start_time: str = Query("", description="起始时间 ISO 格式"),
    end_time: str = Query("", description="结束时间 ISO 格式"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    """获取技能调用日志列表，默认按调用时间倒序"""
    skill_names = [s.strip() for s in skill_name.split(",") if s.strip()] if skill_name else None
    status_filter = status if status in ("success", "failure") else None
    items, total = svc.query_logs(
        skill_names=skill_names,
        status=status_filter,
        start_time=start_time or None,
        end_time=end_time or None,
        user_name=user_name or None,
        limit=limit,
        offset=offset,
    )
    return ApiResponse(data=items, total=total)


@router.get("/manage/skill-logs/{log_id}", summary="获取日志详情")
async def get_skill_log_detail(log_id: str):
    """获取单条日志完整详情（含 API 链路、参数、错误信息）"""
    detail = svc.get_log_detail(log_id)
    if detail is None:
        return ApiResponse(code=404, message="日志不存在")
    return ApiResponse(data=detail)


@router.get("/manage/skill-logs/report/weekly", summary="技能调用周报")
async def get_weekly_report():
    """获取最近7天的技能调用分析周报"""
    report = svc.get_weekly_report()
    return ApiResponse(data=report)


@router.get("/manage/skill-names", summary="获取Skill名称列表")
async def get_skill_names():
    """获取所有 Skill 名称及中文标签，供前端筛选下拉使用，返回 [{name, label}]"""
    labels = svc.get_skill_labels()
    return ApiResponse(data=labels)
