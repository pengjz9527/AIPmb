from fastapi import APIRouter, Query, Header
from pmb.api.schemas.common import ApiResponse
from urllib.parse import unquote

router = APIRouter()


def _decode_user_name(user_name: str) -> str:
    """HTTP Header 中的中文可能以 latin1 或 URL 编码形式传输，统一解码为 utf-8"""
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
    except (UnicodeEncodeError, UnicodeDecodeError):
        return user_name


@router.get("/skills/domain", summary="Agent 能力入口列表")
async def get_domain_skills():
    """获取所有 Agent 的能力入口信息，用于前端快捷卡片。
    已从 Skill 入口迁移为 Agent 入口 — Skill 不再对客直接暴露。"""
    from pmb.agents.registry import agent_registry
    agents = agent_registry.list_agents()
    # 转换为前端 SkillCard 兼容格式（保留 label/description/name 字段）
    return ApiResponse(data=[
        {
            "name": a.agent_id,
            "label": a.name,
            "description": a.description,
            "avatar": a.avatar,
        }
        for a in agents
    ])


@router.get("/skills/history-today", summary="历史上的今天")
async def get_history_today(user_name: str = Header("", alias="x-user-name")):
    """检索用户往年同日交易，挖掘纪念意义，提供优惠权益"""
    user_name = _decode_user_name(user_name)
    from pmb.skills.domain.history_today import HistoryTodaySkill
    skill = HistoryTodaySkill()
    result = await skill.execute(user_name=user_name)
    return ApiResponse(data=result.data)


@router.get("/skills/neighborhood", summary="生活圈分析")
async def get_neighborhood(user_name: str = Header("", alias="x-user-name")):
    """分析用户的居住区域、工作地、常去商户和通勤方式"""
    user_name = _decode_user_name(user_name)
    from pmb.skills.domain.neighborhood import NeighborhoodProfilerSkill
    skill = NeighborhoodProfilerSkill()
    result = await skill.execute(user_name=user_name)
    return ApiResponse(data=result.data)


@router.get("/recommendations/todos", summary="待办推荐")
async def get_todos(user_name: str = Header("", alias="x-user-name")):
    """基于用户账户数据生成待办推荐"""
    user_name = _decode_user_name(user_name)
    from pmb.core import account_service, consumption_service

    todos = []
    # 获取账户汇总
    all_accounts, _ = account_service.list_accounts(user_name=user_name, limit=1000)
    for acc in all_accounts:
        at = str(acc.get("账户类型", ""))
        if "信用" in at:
            due = str(acc.get("本期应还金额(元)", "") or "")
            due_day = str(acc.get("到期还款日", "") or "")
            if due and due != "0" and due != "0.00":
                card = str(acc.get("卡种/产品", ""))
                todos.append({
                    "todo_type": "credit_repayment",
                    "title": f"{card}还款提醒",
                    "description": f"本期应还 ¥{due}，还款日：{due_day}",
                    "priority": 10,
                    "action_label": "立即还款",
                })

    # 消费异常提醒
    stats = consumption_service.get_consumption_stats(group_by="month", top=3, user_name=user_name)
    if len(stats) >= 2:
        latest = stats[0]["total"]
        avg = sum(s["total"] for s in stats[1:]) / len(stats[1:])
        if avg > 0 and latest > avg * 1.5:
            todos.append({
                "todo_type": "spending_alert",
                "title": "消费异常提醒",
                "description": f"近期消费 ¥{latest:.0f}，高于月均 ¥{avg:.0f}",
                "priority": 5,
                "action_label": "查看明细",
            })

    # 待缴费提醒（基于历史规律预测）
    try:
        from pmb.core import payment_service
        pending = payment_service.predict_pending_payments(user_name=user_name)
        for p in pending[:3]:  # 最多3条
            urgency = "已逾期" if p.get("is_overdue") else "即将到期"
            todos.append({
                "todo_type": "payment_due",
                "title": f"{p.get('payment_type', '缴费')}提醒",
                "description": (
                    f"{urgency}，预估 ¥{p.get('estimated_amount', 0):.0f}，"
                    f"预计{p.get('estimated_next_date', '')}"
                ),
                "priority": 8 if p.get("is_overdue") else 6,
                "action_label": "去缴费",
                "payment_no": p.get("payment_no", ""),
                "payment_type": p.get("payment_type", ""),
            })
    except Exception:
        pass  # 缴费数据不可用时不阻塞其他待办

    # 按 priority 降序排列
    todos.sort(key=lambda t: t.get("priority", 0), reverse=True)
    return ApiResponse(data=todos)


@router.get("/recommendations/promos", summary="优惠推荐")
async def get_promos(user_name: str = Header("", alias="x-user-name")):
    """基于消费偏好推荐优惠，至少返回2条确保左右平衡"""
    user_name = _decode_user_name(user_name)
    from pmb.core import consumption_service

    promos = []
    stats = consumption_service.get_consumption_stats(group_by="subcategory", top=8, user_name=user_name)

    # MVP阶段：基于消费偏好硬编码优惠模板
    promo_templates = {
        "餐饮美食": {"title": "美食满减活动", "description": "每周三餐饮消费满100减20", "valid_until": "2026-12-31"},
        "网约车": {"title": "出行立减优惠", "description": "每周五打车立减5元", "valid_until": "2026-12-31"},
        "超市便利店": {"title": "超市满减活动", "description": "周末超市消费满200减30", "valid_until": "2026-12-31"},
        "网购": {"title": "电商返现活动", "description": "指定电商平台消费返现1%", "valid_until": "2026-12-31"},
        "通讯软件数码": {"title": "数码配件折扣", "description": "指定数码配件9折优惠", "valid_until": "2026-12-31"},
        "铁路 出行": {"title": "火车票立减优惠", "description": "12306购票满100减10", "valid_until": "2026-12-31"},
        "生活缴费": {"title": "生活缴费返现", "description": "每月缴费满100元返现5元", "valid_until": "2026-12-31"},
        "医疗健康": {"title": "健康体检优惠", "description": "指定体检套餐享8折优惠", "valid_until": "2026-12-31"},
    }

    # 兜底模板（当消费偏好匹配不足时使用）
    fallback_templates = [
        {"title": "新客专享优惠", "description": "首次使用AI银行服务享专属权益", "valid_until": "2026-12-31", "reason": "新用户专享"},
        {"title": "积分兑换活动", "description": "消费积分可兑换精美礼品", "valid_until": "2026-12-31", "reason": "权益回馈"},
        {"title": "信用卡分期优惠", "description": "信用卡账单分期享利率折扣", "valid_until": "2026-12-31", "reason": "信用卡专属"},
    ]

    for stat in stats[:5]:
        sub = stat.get("name", "")
        for key, template in promo_templates.items():
            if key in sub:
                promos.append({
                    **template,
                    "reason": f"您近期在{sub}消费{stat['count']}笔，共¥{stat['total']:.0f}",
                })
                break

    # 确保至少返回2条
    while len(promos) < 2:
        fallback = fallback_templates[len(promos) % len(fallback_templates)]
        promos.append(fallback)

    return ApiResponse(data=promos[:2])


@router.get("/recommendations/products", summary="产品推荐")
async def get_recommended_products(user_name: str = Header("", alias="x-user-name")):
    """基于用户画像推荐产品"""
    user_name = _decode_user_name(user_name)
    from pmb.core import product_service, consumption_service

    # 简单推荐逻辑：根据消费水平推荐不同风险等级产品
    stats = consumption_service.get_consumption_stats(group_by="month", top=3, user_name=user_name)
    avg_monthly = sum(s["total"] for s in stats) / max(len(stats), 1) if stats else 0

    recommendations = []
    if avg_monthly > 5000:
        # 中高消费：推荐稳健型产品
        products, _ = product_service.list_products(category="wealth", limit=3)
        for p in products:
            recommendations.append({
                "name": p.get("产品名称/类别", p.get("产品名称", "")),
                "category": "wealth",
                "type_label": p.get("产品类型", ""),
                "description": p.get("产品描述", ""),
                "risk_level": p.get("风险等级", ""),
                "reason": "基于您的消费水平，推荐稳健型理财产品",
            })
    else:
        # 低消费：推荐保本型产品
        products, _ = product_service.list_products(category="deposit", limit=3)
        for p in products:
            recommendations.append({
                "name": p.get("产品名称", ""),
                "category": "deposit",
                "type_label": p.get("产品大类", ""),
                "description": p.get("产品描述", ""),
                "risk_level": "",
                "reason": "基于您的消费水平，推荐保本型存款产品",
            })

    return ApiResponse(data=recommendations)


@router.get("/profile/tags", summary="用户画像标签")
async def get_profile_tags(user_name: str = Header("", alias="x-user-name")):
    """获取用户画像标签（优先 AI 标签，回退规则标签）"""
    user_name = _decode_user_name(user_name)

    # 1. Always compute rule-based tags (fast, no LLM dependency)
    from pmb.profile.tag_engine import tag_engine
    tags = tag_engine.compute_tags(user_name=user_name)

    # 2. Try to get AI tags from cache
    ai_tags = []
    try:
        from pmb.ai_manage.services.tagging_service import get_tags_for_user
        cached = get_tags_for_user(user_name)
        if cached is not None and cached.tags:
            ai_tags = [
                {"name": t["name"], "description": t.get("reasoning", t.get("description", ""))}
                for t in cached.tags
            ]
    except Exception:
        pass  # Graceful degradation: no AI tags

    # 3. If no AI tags cached, trigger async generation (non-blocking)
    #    The next request will pick up the cached result.
    if not ai_tags and user_name:
        try:
            from pmb.ai_manage.services.tagging_service import generate_tags_for_user
            import asyncio
            asyncio.create_task(generate_tags_for_user(user_name))
        except Exception:
            pass

    return ApiResponse(data={**tags, "ai_tags": ai_tags})
