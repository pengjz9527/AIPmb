"""纪念日历路由"""
from fastapi import APIRouter, Query
from pmb.api.schemas.common import ApiResponse
from pmb.api.schemas.ai_manage import CalendarGenerateRequest
from pmb.ai_manage.services import calendar_service

router = APIRouter()


@router.get("/manage/calendar/{user_name}", summary="获取用户纪念日历")
async def get_calendar(user_name: str):
    calendar = calendar_service.get_calendar_for_user(user_name)
    if calendar is None:
        return ApiResponse(code=404, message=f"用户 {user_name} 暂无纪念日历，请先生成")
    return ApiResponse(data=calendar.to_dict())


@router.post("/manage/calendar/{user_name}/generate", summary="生成用户纪念日历（同步）")
async def generate_calendar(user_name: str):
    try:
        calendar = await calendar_service.generate_calendar_for_user(user_name, force=True)
        return ApiResponse(data=calendar.to_dict())
    except ValueError as e:
        return ApiResponse(code=404, message=str(e))
    except Exception as e:
        return ApiResponse(code=500, message=f"生成纪念日历失败: {str(e)}")


@router.post("/manage/calendar/{user_name}/generate-async", summary="异步生成纪念日历")
async def generate_calendar_async(user_name: str):
    """启动异步日历生成，立即返回，前端通过 /status 轮询进度"""
    calendar_service.start_generation_async(user_name)
    return ApiResponse(message="日历生成已启动", data={"status": "started"})


@router.get("/manage/calendar/{user_name}/status", summary="查询日历生成进度")
async def get_generation_status(user_name: str):
    """查询异步日历生成的实时进度"""
    status = calendar_service.get_generation_status(user_name)
    if status is None:
        return ApiResponse(code=404, message="暂无生成任务")
    return ApiResponse(data=status)


@router.post("/manage/calendar/batch-generate", summary="批量生成纪念日历")
async def batch_generate_calendars(body: CalendarGenerateRequest):
    results = await calendar_service.batch_generate_calendars(body.user_names, force=body.force_regenerate)
    return ApiResponse(data=results)


@router.get("/manage/calendar/{user_name}/events", summary="按月份查询纪念事件")
async def get_events_by_month(
    user_name: str,
    year: int = Query(..., description="年份"),
    month: int = Query(..., ge=1, le=12, description="月份"),
):
    events = calendar_service.get_events_by_month(user_name, year, month)
    return ApiResponse(data=[e.to_dict() for e in events])


@router.delete("/manage/calendar/{user_name}", summary="清除纪念日历缓存")
async def delete_calendar(user_name: str):
    ok = calendar_service.delete_calendar(user_name)
    if not ok:
        return ApiResponse(code=404, message="纪念日历不存在")
    return ApiResponse(message="删除成功")