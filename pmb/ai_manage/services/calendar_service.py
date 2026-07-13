"""AI 纪念日历生成服务"""
import json
import asyncio
from datetime import datetime
from pmb.ai_manage.store import read_json, write_json
from pmb.ai_manage.models.calendar_event import MemorialCalendar, MemorialEvent
from pmb.ai_manage.services.user_service import get_user_transactions, get_user_detail

STORE_FILE = "memorial_calendars.json"

# 发送给 LLM 的最大交易记录数（避免 prompt 过大）
MAX_TX_FOR_LLM = 200

# ---------- 异步生成进度跟踪 ----------
# 内存中的进度状态，key=user_name, value={"status": str, "step": int, "message": str, "result": dict|None}
_generation_status: dict[str, dict] = {}

# 生成步骤定义 (供前端展示)
GENERATION_STEPS = [
    {"id": "collecting", "label": "收集交易数据", "icon": "database"},
    {"id": "sampling", "label": "分析消费模式", "icon": "analytics"},
    {"id": "reasoning", "label": "AI 正在识别关键事件", "icon": "psychology", "detail": "正在分析人生里程碑、生活变迁、重要消费..."},
    {"id": "generating", "label": "AI 正在生成纪念文案", "icon": "auto_awesome", "detail": "为每个事件撰写温暖文案..."},
    {"id": "building", "label": "整理日历数据", "icon": "calendar_month"},
    {"id": "done", "label": "生成完成", "icon": "check_circle"},
]

CALENDAR_SYSTEM_PROMPT = """你是一位温暖贴心的"用户人生记录官"。你的任务是根据用户的银行交易和消费记录，识别出与用户成长、生活紧密相关的关键事件，生成一份纪念日历。

请分析交易数据，找出以下类型的关键事件：
1. **人生里程碑**: 第一笔工资入账、第一张信用卡激活、第一笔投资理财、第一个大额存款
2. **生活变迁**: 搬家（大额家居/装修消费）、换工作（工资卡信息变更）、结婚（婚庆相关消费）、生子（母婴用品消费）
3. **重要消费**: 第一次出国旅行、第一辆车、第一套房（大额贷款/消费）
4. **情感记忆**: 每年固定日期的特殊消费（生日、纪念日相关的餐饮/礼物消费）
5. **成长轨迹**: 收入增长节点、消费升级节点、理财意识觉醒、储蓄里程碑

对每个事件，请生成：
- 事件日期（从交易记录中提取，格式 YYYY-MM-DD）
- 事件类型（milestone/life_change/major_purchase/emotion/growth）
- 事件标题（简短有力，如"第一次工资到账"）
- 温馨文案（50-100字，温暖感人，有共鸣，帮用户回忆起那一天的珍贵记忆）
- 关联交易记录序号列表
- 重要性评分（1-10）

输出格式（严格JSON）：
{"events": [{"date": "YYYY-MM-DD", "event_type": "milestone", "title": "事件标题", "description": "温馨文案...", "related_tx_seqs": [1,2,3], "importance": 8}, ...]}

注意：
- 只输出有明确数据支撑的事件，不要编造
- 温馨文案用第二人称"你"，营造亲切感
- 每个事件3-6个
- 日期必须来自交易记录中的实际日期"""


def _get_llm():
    """获取活跃配置的 LLM 实例"""
    from pmb.ai_manage.services.model_config_service import get_active_config
    from pmb.llm.qwen import QwenLLM
    config = get_active_config()
    if config is None:
        return QwenLLM()
    return QwenLLM(
        model=config.model_name,
        api_key=config.api_key,
        base_url=config.base_url,
    )


def _set_progress(user_name: str, step_id: str, message: str = "", result: dict = None):
    """更新生成进度"""
    step_idx = 0
    for i, s in enumerate(GENERATION_STEPS):
        if s["id"] == step_id:
            step_idx = i
            break
    _generation_status[user_name] = {
        "status": step_id,
        "step": step_idx,
        "total_steps": len(GENERATION_STEPS),
        "message": message or GENERATION_STEPS[step_idx]["label"],
        "result": result,
        "steps": GENERATION_STEPS,
    }


def get_generation_status(user_name: str) -> dict | None:
    """查询生成进度"""
    return _generation_status.get(user_name)


def start_generation_async(user_name: str):
    """启动异步日历生成（非阻塞），进度写入 _generation_status"""
    if user_name in _generation_status:
        current = _generation_status[user_name]
        if current["status"] not in ("done", "error"):
            return  # 正在生成中

    _set_progress(user_name, "collecting", "正在收集交易数据...")
    asyncio.create_task(_run_generation(user_name))


async def _run_generation(user_name: str):
    """后台执行日历生成"""
    try:
        # Step 1: 收集数据
        _set_progress(user_name, "collecting", "正在从账户和交易记录中收集数据...")

        detail = get_user_detail(user_name)
        if detail is None:
            _set_progress(user_name, "error", f"用户 {user_name} 不存在", result={"error": f"用户 {user_name} 不存在"})
            return

        all_txs, _ = get_user_transactions(user_name, limit=2000)
        if not all_txs:
            all_txs = _get_debit_transactions(user_name)
        if not all_txs:
            _set_progress(user_name, "error", "没有交易记录", result={"error": f"用户 {user_name} 没有交易记录"})
            return

        await asyncio.sleep(0.3)

        # Step 2: 采样分析
        _set_progress(user_name, "sampling",
                      f"已收集 {len(all_txs)} 条交易记录，正在按月份均匀采样...")
        sampled_txs = _sample_transactions(all_txs, MAX_TX_FOR_LLM)

        timeline = []
        for tx in sampled_txs:
            timeline.append({
                "序号": tx.get("序号"),
                "日期": tx.get("交易日期"),
                "金额": tx.get("交易金额"),
                "方向": tx.get("收支方向"),
                "分类": tx.get("交易分类"),
                "子类": tx.get("消费细分子类"),
                "商户": tx.get("商户名称"),
                "摘要": tx.get("交易摘要"),
            })
        timeline.sort(key=lambda x: str(x.get("日期", "")))

        user_prompt = f"""请根据以下用户"{user_name}"的交易记录，生成纪念日历。

用户信息：账户数 {detail['account_count']}，总资产 ¥{detail['total_balance']:,.2f}

交易记录（按时间排序）：
{json.dumps(timeline, ensure_ascii=False, indent=2)}"""

        await asyncio.sleep(0.2)

        # Step 3: LLM 推理
        _set_progress(user_name, "reasoning",
                      f"已将 {len(timeline)} 条关键交易发送给 AI，AI 正在分析您的人生轨迹...")

        try:
            llm = _get_llm()
            response = await llm.chat(messages=[
                {"role": "system", "content": CALENDAR_SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ])
        except Exception as llm_err:
            _set_progress(user_name, "error",
                          f"LLM 调用失败: {str(llm_err)[:100]}",
                          result={"error": f"LLM 调用失败: {str(llm_err)[:100]}"})
            return

        # Step 4: 解析生成
        _set_progress(user_name, "generating", "AI 已完成分析，正在生成纪念文案...")

        try:
            content = response.content.strip()
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0].strip()
            elif "```" in content:
                content = content.split("```")[1].split("```")[0].strip()
            result = json.loads(content)
            events_data = result.get("events", [])
        except (json.JSONDecodeError, IndexError):
            events_data = []

        # Step 5: 构建日历
        _set_progress(user_name, "building", f"AI 识别了 {len(events_data)} 个纪念事件，正在整理日历...")

        tx_map = {str(tx.get("序号", "")): tx for tx in all_txs}
        events = []
        for ed in events_data:
            related_txs = []
            for seq in ed.get("related_tx_seqs", []):
                key = str(seq)
                if key in tx_map:
                    related_txs.append(tx_map[key])
            importance = ed.get("importance", 5)
            try:
                importance = int(importance)
            except (TypeError, ValueError):
                importance = 5
            events.append(MemorialEvent(
                date=ed.get("date", ""),
                event_type=ed.get("event_type", ""),
                title=ed.get("title", ""),
                description=ed.get("description", ""),
                related_transactions=related_txs,
                importance=importance,
            ))

        events.sort(key=lambda e: e.date)

        calendar = MemorialCalendar(
            user_name=user_name,
            events=events,
            model_used=_get_model_name(),
        )

        store = _load_store()
        store[user_name] = calendar.to_dict()
        _save_store(store)

        # Step 6: 完成
        _set_progress(user_name, "done", f"日历生成完成！共发现 {len(events)} 个珍贵的人生时刻",
                      result={"calendar": calendar.to_dict(), "event_count": len(events)})

    except Exception as e:
        _set_progress(user_name, "error", f"生成失败: {str(e)[:200]}",
                      result={"error": str(e)[:200]})


def _load_store() -> dict:
    """加载日历存储"""
    data = read_json(STORE_FILE)
    if isinstance(data, list):
        return {}
    return data or {}


def _save_store(data: dict):
    write_json(STORE_FILE, data)


def get_calendar_for_user(user_name: str) -> MemorialCalendar | None:
    """获取用户纪念日历"""
    store = _load_store()
    if user_name in store:
        try:
            return MemorialCalendar.from_dict(store[user_name])
        except Exception:
            # 存储数据损坏，删除并返回 None
            del store[user_name]
            _save_store(store)
            return None
    return None


def get_events_by_month(user_name: str, year: int, month: int) -> list[MemorialEvent]:
    """按月份查询纪念事件"""
    calendar = get_calendar_for_user(user_name)
    if calendar is None:
        return []
    target = f"{year:04d}-{month:02d}"
    return [e for e in calendar.events if e.date[:7] == target]


async def generate_calendar_for_user(user_name: str, force: bool = False) -> MemorialCalendar:
    """为用户生成纪念日历"""
    if not force:
        existing = get_calendar_for_user(user_name)
        if existing is not None:
            return existing

    detail = get_user_detail(user_name)
    if detail is None:
        raise ValueError(f"用户 {user_name} 不存在，请检查用户名是否正确")

    # 获取所有交易记录（包含借记卡 + 信用卡）
    all_txs, _ = get_user_transactions(user_name, limit=2000)

    # 如果信用卡交易不足，尝试拉取借记卡交易记录补充
    if not all_txs:
        all_txs = _get_debit_transactions(user_name)

    if not all_txs:
        raise ValueError(f"用户 {user_name} 没有交易记录，无法生成纪念日历")

    # 采样交易记录以控制 prompt 大小
    sampled_txs = _sample_transactions(all_txs, MAX_TX_FOR_LLM)

    # 构建交易时间线数据（使用采样后的数据）
    timeline = []
    for tx in sampled_txs:
        timeline.append({
            "序号": tx.get("序号"),
            "日期": tx.get("交易日期"),
            "金额": tx.get("交易金额"),
            "方向": tx.get("收支方向"),
            "分类": tx.get("交易分类"),
            "子类": tx.get("消费细分子类"),
            "商户": tx.get("商户名称"),
            "摘要": tx.get("交易摘要"),
        })

    # 按日期排序
    timeline.sort(key=lambda x: str(x.get("日期", "")))

    user_prompt = f"""请根据以下用户"{user_name}"的交易记录，生成纪念日历。

用户信息：账户数 {detail['account_count']}，总资产 ¥{detail['total_balance']:,.2f}

交易记录（按时间排序）：
{json.dumps(timeline, ensure_ascii=False, indent=2)}"""

    try:
        llm = _get_llm()
        response = await llm.chat(messages=[
            {"role": "system", "content": CALENDAR_SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ])
    except Exception as llm_err:
        raise RuntimeError(
            f"LLM 调用失败: {str(llm_err)}。"
            f"请检查模型配置（API Key、Base URL）是否正确且可访问。"
        ) from llm_err

    try:
        content = response.content.strip()
        if "```json" in content:
            content = content.split("```json")[1].split("```")[0].strip()
        elif "```" in content:
            content = content.split("```")[1].split("```")[0].strip()
        result = json.loads(content)
        events_data = result.get("events", [])
    except (json.JSONDecodeError, IndexError):
        events_data = []

    # 补充关联交易详情（从原始 all_txs 中查找，包含采样掉的记录）
    tx_map = {str(tx.get("序号", "")): tx for tx in all_txs}
    events = []
    for ed in events_data:
        related_txs = []
        for seq in ed.get("related_tx_seqs", []):
            key = str(seq)
            if key in tx_map:
                related_txs.append(tx_map[key])
        # 确保 importance 是整数
        importance = ed.get("importance", 5)
        try:
            importance = int(importance)
        except (TypeError, ValueError):
            importance = 5
        events.append(MemorialEvent(
            date=ed.get("date", ""),
            event_type=ed.get("event_type", ""),
            title=ed.get("title", ""),
            description=ed.get("description", ""),
            related_transactions=related_txs,
            importance=importance,
        ))

    events.sort(key=lambda e: e.date)

    calendar = MemorialCalendar(
        user_name=user_name,
        events=events,
        model_used=_get_model_name(),
    )

    store = _load_store()
    store[user_name] = calendar.to_dict()
    _save_store(store)

    return calendar


async def batch_generate_calendars(user_names: list[str], force: bool = False) -> dict[str, dict]:
    """批量生成纪念日历"""
    results = {}
    for name in user_names:
        try:
            calendar = await generate_calendar_for_user(name, force)
            results[name] = {"success": True, "event_count": len(calendar.events)}
        except Exception as e:
            results[name] = {"success": False, "error": str(e)}
    return results


def delete_calendar(user_name: str) -> bool:
    """删除用户纪念日历缓存"""
    store = _load_store()
    if user_name in store:
        del store[user_name]
        _save_store(store)
        return True
    return False


def _get_model_name() -> str:
    from pmb.ai_manage.services.model_config_service import get_active_config
    config = get_active_config()
    if config:
        return config.model_name
    from pmb.core.config import LLM_MODEL
    return LLM_MODEL


def _get_debit_transactions(user_name: str) -> list[dict]:
    """获取用户借记卡交易记录作为信用卡交易的补充"""
    from pmb.core.loader import loader
    rows = loader.load_debit_transactions()
    txs = []
    for row in rows:
        name = str(row.get("用户姓名", "")).strip()
        if name == user_name:
            txs.append({
                "序号": row.get("序号"),
                "交易日期": row.get("记账日期"),
                "交易金额": row.get("交易金额(元)"),
                "收支方向": row.get("收支方向"),
                "交易分类": row.get("交易大类", ""),
                "消费细分子类": "",
                "商户名称": row.get("对手方名称", ""),
                "交易摘要": row.get("交易方式/渠道", ""),
            })
    txs.sort(key=lambda x: str(x.get("交易日期", "")), reverse=True)
    return txs


def _sample_transactions(txs: list[dict], max_count: int) -> list[dict]:
    """按月份均匀采样交易记录，控制 prompt 大小"""
    if len(txs) <= max_count:
        return txs

    # 按月份分组
    from collections import defaultdict
    month_groups = defaultdict(list)
    for tx in txs:
        date_str = str(tx.get("交易日期", ""))
        month_key = date_str[:7] if len(date_str) >= 7 else "unknown"
        month_groups[month_key].append(tx)

    # 按月份数均匀分配名额
    num_months = max(len(month_groups), 1)
    per_month = max(max_count // num_months, 1)

    sampled = []
    for month_key in sorted(month_groups.keys()):
        group = month_groups[month_key]
        # 每个月取 per_month 条，均匀间隔采样
        if len(group) <= per_month:
            sampled.extend(group)
        else:
            step = len(group) / per_month
            for i in range(per_month):
                idx = int(i * step)
                if idx < len(group):
                    sampled.append(group[idx])

    # 按日期排序后返回
    sampled.sort(key=lambda x: str(x.get("交易日期", "")))
    return sampled[:max_count]