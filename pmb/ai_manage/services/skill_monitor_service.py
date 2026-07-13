"""技能监控服务 — 日志查询、周报生成、API链路追踪"""
import contextvars
import time
from datetime import datetime, timedelta, timezone
from collections import defaultdict

from pmb.ai_manage.store import read_json

STORE_FILE = "skill_logs.json"

# ===== API 链路追踪上下文 =====
_trace_stack: contextvars.ContextVar[list] = contextvars.ContextVar(
    "skill_trace_stack", default=[]
)
_trace_active: contextvars.ContextVar[bool] = contextvars.ContextVar(
    "skill_trace_active", default=False
)


class TraceContext:
    """API 链路追踪上下文管理器

    使用方式:
        with TraceContext("account_loader", "load_accounts") as trace:
            result = loader.load_accounts()
            trace.set_row_count(len(result))
    """

    def __init__(self, service_name: str, function_name: str):
        self.service_name = service_name
        self.function_name = function_name
        self.start_time = 0.0
        self.row_count = 0

    def __enter__(self):
        self.start_time = time.perf_counter()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if _trace_active.get():
            duration_ms = int((time.perf_counter() - self.start_time) * 1000)
            traces = list(_trace_stack.get())
            traces.append({
                "service_name": self.service_name,
                "function_name": self.function_name,
                "duration_ms": duration_ms,
                "row_count": self.row_count,
            })
            _trace_stack.set(traces)
        return False

    def set_row_count(self, count: int):
        self.row_count = count


def start_trace():
    """开始追踪 — 在 execute_skill 开始时调用"""
    _trace_active.set(True)
    _trace_stack.set([])


def stop_trace() -> list:
    """停止追踪，返回收集到的调用链路"""
    traces = list(_trace_stack.get())
    _trace_stack.set([])
    _trace_active.set(False)
    return traces


def is_tracing() -> bool:
    """检查当前是否在追踪上下文中"""
    return _trace_active.get()


# ===== 日志查询 =====

def query_logs(
    skill_names: list | None = None,
    status: str | None = None,
    start_time: str | None = None,
    end_time: str | None = None,
    user_name: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> tuple[list, int]:
    """查询技能调用日志，支持多条件筛选和分页"""
    logs = read_json(STORE_FILE)
    if isinstance(logs, dict):
        logs = []

    # 按时间倒序
    logs = sorted(logs, key=lambda l: l.get("invoked_at", ""), reverse=True)

    # 过滤
    filtered = logs
    if skill_names:
        filtered = [l for l in filtered if l.get("skill_name") in skill_names]
    if status == "success":
        filtered = [l for l in filtered if l.get("success")]
    elif status == "failure":
        filtered = [l for l in filtered if not l.get("success")]
    if start_time:
        filtered = [l for l in filtered if l.get("invoked_at", "") >= start_time]
    if end_time:
        filtered = [l for l in filtered if l.get("invoked_at", "") <= end_time]
    if user_name:
        filtered = [l for l in filtered if l.get("user_name") == user_name]

    total = len(filtered)
    paginated = filtered[offset:offset + limit]
    return paginated, total


def get_log_detail(log_id: str) -> dict | None:
    """获取单条日志详情"""
    logs = read_json(STORE_FILE)
    if isinstance(logs, dict):
        return None
    for log in logs:
        if log.get("id") == log_id:
            return log
    return None


# ===== 周报生成 =====

def get_weekly_report() -> dict:
    """生成最近7天的技能调用分析周报"""
    logs = read_json(STORE_FILE)
    if isinstance(logs, dict):
        logs = []

    now = datetime.now(timezone.utc)
    week_ago = (now - timedelta(days=7)).isoformat()

    # 筛选本周日志
    week_logs = [l for l in logs if l.get("invoked_at", "") >= week_ago]

    if not week_logs:
        return {
            "period": {"start": week_ago, "end": now.isoformat()},
            "total_calls": 0,
            "success_count": 0,
            "failure_count": 0,
            "success_rate": 0.0,
            "avg_duration_ms": 0.0,
            "max_duration_ms": 0,
            "min_duration_ms": 0,
            "skill_stats": [],
            "hot_ranking": [],
            "failure_reasons": [],
        }

    # 总览
    total = len(week_logs)
    success_count = sum(1 for l in week_logs if l.get("success"))
    durations = [l.get("duration_ms", 0) for l in week_logs]
    avg_duration = sum(durations) / len(durations) if durations else 0
    max_duration = max(durations) if durations else 0
    min_duration = min(durations) if durations else 0

    # 每个 Skill 统计
    skill_groups: dict[str, list] = defaultdict(list)
    for l in week_logs:
        skill_groups[l.get("skill_name", "unknown")].append(l)

    skill_stats = []
    for name, items in skill_groups.items():
        item_durations = [i.get("duration_ms", 0) for i in items]
        item_success = sum(1 for i in items if i.get("success"))
        skill_stats.append({
            "skill_name": name,
            "call_count": len(items),
            "success_count": item_success,
            "failure_count": len(items) - item_success,
            "success_rate": round(item_success / len(items), 4) if items else 0,
            "avg_duration_ms": round(sum(item_durations) / len(item_durations), 1) if item_durations else 0,
            "max_duration_ms": max(item_durations) if item_durations else 0,
            "min_duration_ms": min(item_durations) if item_durations else 0,
        })

    # 热度排名 (按调用次数降序)
    skill_stats.sort(key=lambda s: s["call_count"], reverse=True)
    hot_ranking = [
        {"rank": i + 1, "skill_name": s["skill_name"], "call_count": s["call_count"]}
        for i, s in enumerate(skill_stats)
    ]

    # 失败原因分类
    failure_reasons: dict[str, int] = defaultdict(int)
    for l in week_logs:
        if not l.get("success"):
            reason = l.get("error_message", "未知错误")
            reason_key = reason[:60] if reason else "未知错误"
            failure_reasons[reason_key] += 1
    failure_summary = sorted(
        [{"reason": k, "count": v} for k, v in failure_reasons.items()],
        key=lambda x: x["count"], reverse=True,
    )[:10]

    return {
        "period": {"start": week_ago, "end": now.isoformat()},
        "total_calls": total,
        "success_count": success_count,
        "failure_count": total - success_count,
        "success_rate": round(success_count / total, 4) if total else 0,
        "avg_duration_ms": round(avg_duration, 1),
        "max_duration_ms": max_duration,
        "min_duration_ms": min_duration,
        "skill_stats": skill_stats,
        "hot_ranking": hot_ranking,
        "failure_reasons": failure_summary,
    }


def get_skill_labels() -> list[dict]:
    """获取所有已注册 Skill 名称及中文标签（用于筛选下拉），返回 [{name, label}]"""
    from pmb.skills.orchestrator import skill_orchestrator
    return skill_orchestrator.get_skill_labels()
