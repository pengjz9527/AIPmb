"""AI 性格画像服务 — 调用 user_profiling Skill + LLM 生成人生画像

流程：
1. 调用 user_profiling skill 收集消费/收支数据
2. LLM 生成四板块画像：你的画像/消费人格/有趣发现/灵感建议
3. 隐私屏蔽处理（商户名/金额/位置用 * 替换）
4. 缓存结果供前端查询
"""
import json
import re
import asyncio
from datetime import datetime
from pmb.ai_manage.store import read_json, write_json

STORE_FILE = "profile_portraits.json"

# ---------- 异步生成进度跟踪 ----------
_progress: dict[str, dict] = {}

PORTRAIT_STEPS = [
    {"id": "collecting", "label": "收集消费数据", "icon": "database"},
    {"id": "calling_skill", "label": "调用用户画像 Skill", "icon": "person_search",
     "detail": "Skill 正在从账户、交易流水中提取多维度消费数据..."},
    {"id": "reasoning", "label": "AI 正在生成性格画像", "icon": "psychology",
     "detail": "AI 正在分析消费行为，描绘用户的人生画像与消费人格..."},
    {"id": "masking", "label": "隐私信息屏蔽处理", "icon": "shield",
     "detail": "对商户名称、具体金额、地理位置等敏感信息进行脱敏处理..."},
    {"id": "done", "label": "生成完成", "icon": "check_circle"},
]

PORTRAIT_SYSTEM_PROMPT = """你是一位敏锐的"消费行为分析师"。请根据用户的消费和收支数据，生成一份**简洁明快**的人生画像。

你需要为每个板块同时输出两个版本：
- **content**：标签化摘要（简洁，≤100字），用于快速浏览
- **detail**：详细文字分析（100-200字），用温暖细腻的语言深入解读数据，供用户展开查看

四个板块及各自的 content 要求：

## 画像速写
- content: 用 6-8 个关键词标签概括（标签间 · 分隔），最后 1 句 ≤15 字点睛
- detail: 用 2-3 句话描绘用户的生活状态、消费水平、大致人生阶段

## 消费人格
- content: 1 个人格标签 + 3-4 条关键指标（· 分隔，每条 ≤12 字）
- detail: 解释为什么给出这个人格标签，结合数据展开分析

## 数据洞察
- content: 2-3 条消费发现，每条为"标签: 数字"格式，换行分隔
- detail: 对每个发现展开描述，挖掘消费规律和 hidden patterns

## 灵感推荐
- content: 2-3 条标签式建议（· 分隔，每条 ≤10 字）
- detail: 对每条建议展开，说明为什么推荐、有什么好处

输出格式（严格 JSON）：
{"sections": [
  {"title": "画像速写", "content": "标签摘要...", "detail": "详细分析..."},
  {"title": "消费人格", "content": "标签摘要...", "detail": "详细分析..."},
  {"title": "数据洞察", "content": "标签摘要...", "detail": "详细分析..."},
  {"title": "灵感推荐", "content": "标签摘要...", "detail": "详细分析..."}
]}

严格约束：
- content ≤ 100 字，detail 100-200 字
- content 用标签和数据，不用连接词；detail 用温暖流畅的散文
- 不输出个人信息（姓名、卡号、地址）
- 金额用模糊词："小额"、"千元级"、"万元级"
- detail 中可提及消费类别占比、消费节奏等"""


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


def _get_model_name() -> str:
    from pmb.ai_manage.services.model_config_service import get_active_config
    config = get_active_config()
    if config:
        return config.model_name
    from pmb.core.config import LLM_MODEL
    return LLM_MODEL


def _set_progress(user_name: str, step_id: str, message: str = "", result: dict = None):
    """更新进度"""
    step_idx = 0
    for i, s in enumerate(PORTRAIT_STEPS):
        if s["id"] == step_id:
            step_idx = i
            break
    _progress[user_name] = {
        "status": step_id,
        "step": step_idx,
        "total_steps": len(PORTRAIT_STEPS),
        "message": message or PORTRAIT_STEPS[step_idx]["label"],
        "steps": [
            {"id": s["id"], "label": s["label"], "icon": s["icon"], "detail": s.get("detail")}
            for s in PORTRAIT_STEPS
        ],
    }
    if result is not None:
        _progress[user_name]["result"] = result


def get_progress(user_name: str) -> dict | None:
    """查询生成进度"""
    return _progress.get(user_name)


def _load_store() -> dict:
    data = read_json(STORE_FILE)
    if isinstance(data, list):
        return {}
    return data or {}


def _save_store(data: dict):
    write_json(STORE_FILE, data)


def get_cached_result(user_name: str) -> dict | None:
    """获取缓存的画像结果"""
    store = _load_store()
    return store.get(user_name)


def delete_result(user_name: str) -> bool:
    """清除画像缓存"""
    store = _load_store()
    if user_name in store:
        del store[user_name]
        _save_store(store)
        return True
    return False


def start_async(user_name: str):
    """启动异步画像生成（后台任务）"""
    asyncio.create_task(_run(user_name))


async def _run(user_name: str):
    """后台执行画像生成"""
    try:
        # Step 1: 收集数据
        _set_progress(user_name, "collecting", "正在收集用户的消费与收支数据...")

        # Step 2: 调用 user_profiling skill
        _set_progress(user_name, "calling_skill", "Skill 正在提取多维度消费画像数据...")

        from pmb.skills.orchestrator import skill_orchestrator
        skill_result, summary = await skill_orchestrator.execute_skill(
            name="user_profiling",
            arguments={},
            user_name=user_name,
        )

        if not skill_result.success:
            _set_progress(user_name, "done",
                          f"Skill 执行失败: {skill_result.error}",
                          result={"error": skill_result.error or "画像 Skill 执行失败"})
            return

        raw_data = skill_result.data or {}
        await asyncio.sleep(0.3)

        # Step 3: LLM 生成画像
        _set_progress(user_name, "reasoning",
                      "AI 正在分析消费行为，描绘人生画像...")

        # 准备 LLM 输入（脱敏前）
        llm_input = _prepare_llm_input(raw_data)

        try:
            llm = _get_llm()
            response = await llm.chat(messages=[
                {"role": "system", "content": PORTRAIT_SYSTEM_PROMPT},
                {"role": "user", "content": llm_input},
            ])
        except Exception as llm_err:
            _set_progress(user_name, "done",
                          f"LLM 调用失败: {str(llm_err)[:100]}",
                          result={"error": f"LLM 调用失败: {str(llm_err)[:100]}"})
            return

        # 解析 LLM 输出
        content = response.content.strip()
        try:
            # 尝试多种方式提取 JSON
            parsed = None
            if content.startswith("{"):
                # 纯 JSON 响应，直接解析
                parsed = json.loads(content)
            elif "```json" in content:
                json_str = content.split("```json")[1].split("```")[0].strip()
                parsed = json.loads(json_str)
            elif "```" in content:
                json_str = content.split("```")[1].split("```")[0].strip()
                parsed = json.loads(json_str)
            else:
                # 尝试用正则从内容中提取 JSON 对象
                import re
                match = re.search(r'\{[^{}]*"sections"[^{}]*\[.*?\][^{}]*\}', content, re.DOTALL)
                if match:
                    parsed = json.loads(match.group())
                else:
                    parsed = json.loads(content)
            sections = parsed.get("sections", []) if parsed else []
        except (json.JSONDecodeError, IndexError, KeyError):
            # 回退：直接用原始文本作为画像内容
            sections = [{
                "title": "用户性格画像",
                "content": content[:500],
                "detail": content[:2000],
            }]

        # Step 4: 隐私屏蔽
        _set_progress(user_name, "masking", "正在对敏感信息进行脱敏处理...")
        sections = _mask_sections(sections)

        await asyncio.sleep(0.3)

        # Step 5: 保存结果
        result = {
            "user_name": user_name,
            "sections": sections,
            "model_used": _get_model_name(),
            "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "privacy_masked": True,
            "skill_summary": summary,
        }

        store = _load_store()
        store[user_name] = result
        _save_store(store)

        _set_progress(user_name, "done", f"画像生成完成，共 {len(sections)} 个板块", result=result)

    except Exception as e:
        _set_progress(user_name, "done",
                      f"生成失败: {str(e)[:100]}",
                      result={"error": str(e)[:200]})


def _prepare_llm_input(raw_data: dict) -> str:
    """准备 LLM 输入—汇总消费数据为结构化摘要"""
    parts = []

    # 账户汇总：核心指标
    summary = raw_data.get("account_summary", {})
    if summary:
        items = [f"{k}={v}" for k, v in summary.items()]
        parts.append(f"[账户] {'，'.join(items)}")

    # 月度趋势：只给最近6个月
    monthly = raw_data.get("monthly_stats", [])
    if monthly:
        lines = []
        for m in monthly[-6:]:
            label = m.get("label", "")
            total = m.get("total", 0)
            count = m.get("count", 0)
            level = "小额" if total < 3000 else ("千元级" if total < 10000 else "万元级")
            lines.append(f"{label[-2:]}:{level}/{count}笔")
        parts.append(f"[近6月] {' · '.join(lines)}")

    # 消费子类：Top6 + 占比
    subcat = raw_data.get("subcategory_stats", [])
    if subcat:
        lines = []
        for s in subcat[:6]:
            label = s.get("label", "")
            pct = s.get("percentage", 0)
            lines.append(f"{label}{pct}%")
        parts.append(f"[消费Top6] {' · '.join(lines)}")

    # 渠道
    channel = raw_data.get("channel_stats", [])
    if channel:
        lines = [f"{c.get('label', '')}{c.get('total', 0)}笔" for c in channel[:5]]
        parts.append(f"[渠道] {' · '.join(lines)}")

    # 商户：类别化（已脱敏）
    merchants = raw_data.get("merchant_stats", [])
    if merchants:
        lines = []
        for m in merchants[:10]:
            label = m.get("label", "")
            masked_label = _mask_merchant_name(label)
            count = m.get("count", 0)
            lines.append(f"{masked_label}×{count}")
        parts.append(f"[商户] {' · '.join(lines)}")

    if not parts:
        parts.append("[数据] 暂无足够消费数据")

    return "\n".join(parts)


def _mask_sections(sections: list) -> list:
    """对画像内容进行隐私屏蔽，同时处理 content 和 detail"""
    masked = []
    for section in sections:
        content = section.get("content", "")
        detail = section.get("detail", "")
        masked.append({
            "title": section.get("title", ""),
            "content": _mask_privacy(content),
            "detail": _mask_privacy(detail),
        })
    return masked


def _mask_privacy(text: str) -> str:
    """屏蔽隐私信息：
    - 商户名 → ***
    - 具体金额数字 → ***
    - 位置/地址 → ***
    - 银行卡号 → ***
    """
    # 屏蔽具体金额（如 ¥1,234.56, 500元, 2000-3000）
    text = re.sub(r'¥[\d,]+(?:\.\d+)?', '***元', text)
    text = re.sub(r'\d+(?:,\d{3})*(?:\.\d+)?元', '***元', text)
    text = re.sub(r'\d+(?:,\d{3})*(?:\.\d+)?万', '***万', text)

    # 屏蔽可能残留的独立数字金额（4位数以上）
    text = re.sub(r'(?<!\d)\d{4,}(?:\.\d+)?(?!\d)', '***', text)

    # 屏蔽银行名称模式（XX银行、XX支行）
    text = re.sub(r'[\u4e00-\u9fff]{2,6}(?:银行|支行|分理处)', '***', text)

    # 屏蔽地址模式（XX路XX号、XX区XX街）
    text = re.sub(r'[\u4e00-\u9fff]{2,4}(?:路|街|道|巷|弄)(?:\d{1,4}(?:号|弄))?', '***', text)
    text = re.sub(r'[\u4e00-\u9fff]{2,4}(?:区|县|市)(?:[\u4e00-\u9fff]+\d*)?', '***', text)

    # 屏蔽真实姓名模式（2-4个汉字后跟先生/女士/同学等）
    text = re.sub(r'(?:先生|女士|同学|老师|经理|主管)的?[\u4e00-\u9fff]{2,4}', '***', text)

    return text


def _mask_merchant_name(name: str) -> str:
    """商户名模糊化——保留类别，隐藏具体名称"""
    # 知名连锁保留品牌，小商户用***
    well_known = ["星巴克", "肯德基", "麦当劳", "海底捞", "盒马", "永辉", "沃尔玛",
                  "家乐福", "物美", "华联", "711", "全家", "罗森", "美团", "饿了么",
                  "滴滴", "携程", "飞猪", "京东", "淘宝", "天猫", "拼多多",
                  "优衣库", "无印良品", "宜家", "迪卡侬", "山姆", "Costco"]
    for wk in well_known:
        if wk in name:
            return wk
    # 其他商户脱敏
    if len(name) <= 2:
        return "**"
    return name[0] + "***"
