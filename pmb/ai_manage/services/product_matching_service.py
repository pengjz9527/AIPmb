"""AI 产品匹配服务 — 根据用户标签智能匹配银行产品

流程：
1. 检查用户是否有 AI 标签 → 无则先生成
2. 检查用户风险评估等级
3. 加载银行产品库
4. LLM 智能匹配标签→产品（最多5个）
5. 风评校验与警告
"""
import json
import asyncio
from datetime import datetime
from pmb.ai_manage.store import read_json, write_json
from pmb.ai_manage.services.tagging_service import get_tags_for_user, generate_tags_for_user

STORE_FILE = "product_matches.json"

# ---------- 异步生成进度跟踪 ----------
_matching_status: dict[str, dict] = {}

MATCHING_STEPS = [
    {"id": "checking_tags", "label": "检查用户标签", "icon": "label"},
    {"id": "generating_tags", "label": "AI 正在生成用户标签", "icon": "auto_awesome",
     "detail": "分析消费数据，提取用户画像标签..."},
    {"id": "checking_risk", "label": "检查风险评估等级", "icon": "security"},
    {"id": "loading_products", "label": "加载银行产品库", "icon": "inventory_2"},
    {"id": "matching", "label": "AI 正在智能匹配产品", "icon": "psychology",
     "detail": "根据用户标签和风评，从银行产品库中匹配最合适的产品..."},
    {"id": "ranking", "label": "排序推荐结果", "icon": "format_list_numbered"},
    {"id": "done", "label": "匹配完成", "icon": "check_circle"},
]

MATCH_SYSTEM_PROMPT = """你是一位银行产品推荐专家。请根据用户的标签画像，从银行产品库中推荐最符合用户气质和需求的产品。

要求：
1. 仔细分析每个标签的含义，推断用户的消费习惯、风险偏好、生活方式
2. 将标签与产品特点（产品名称、类型、描述）进行深度关联
3. 对每个匹配给出 0-1 的匹配分数（1=完美匹配）和具体的推荐理由
4. 推荐理由要结合用户标签来说明为什么这个产品适合该用户
5. 最多推荐 5 个产品，只推荐匹配分数 >= 0.5 的

输出格式（严格 JSON）：
{"matches": [{"product_name": "产品名称", "product_category": "产品类别", "match_score": 0.85, "reasoning": "结合「标签名」说明推荐理由"}, ...]}

按匹配分数从高到低排序。"""


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
    """更新匹配进度"""
    step_idx = 0
    for i, s in enumerate(MATCHING_STEPS):
        if s["id"] == step_id:
            step_idx = i
            break
    _matching_status[user_name] = {
        "status": step_id,
        "step": step_idx,
        "total_steps": len(MATCHING_STEPS),
        "message": message or MATCHING_STEPS[step_idx]["label"],
        "steps": [
            {"id": s["id"], "label": s["label"], "icon": s["icon"], "detail": s.get("detail")}
            for s in MATCHING_STEPS
        ],
    }
    if result is not None:
        _matching_status[user_name]["result"] = result


def get_matching_status(user_name: str) -> dict | None:
    """查询匹配进度"""
    return _matching_status.get(user_name)


def _load_store() -> dict:
    data = read_json(STORE_FILE)
    if isinstance(data, list):
        return {}
    return data or {}


def _save_store(data: dict):
    write_json(STORE_FILE, data)


def get_cached_result(user_name: str) -> dict | None:
    """获取缓存的匹配结果"""
    store = _load_store()
    return store.get(user_name)


def delete_result(user_name: str) -> bool:
    """清除匹配缓存"""
    store = _load_store()
    if user_name in store:
        del store[user_name]
        _save_store(store)
        return True
    return False


def start_matching_async(user_name: str):
    """启动异步产品匹配（后台任务）"""
    asyncio.create_task(_run_matching(user_name))


async def _run_matching(user_name: str):
    """异步执行产品匹配流程"""
    try:
        # Step 1: 检查用户标签
        _set_progress(user_name, "checking_tags",
                      "正在检查用户 AI 标签...")

        user_tag = get_tags_for_user(user_name)

        # Step 2: 无标签则先生成
        if user_tag is None or not user_tag.tags:
            _set_progress(user_name, "generating_tags",
                          "用户暂无标签，AI 正在生成用户画像标签...")
            await asyncio.to_thread(generate_tags_for_user, user_name)
            user_tag = get_tags_for_user(user_name)

            if user_tag is None or not user_tag.tags:
                _set_progress(user_name, "done",
                              "标签生成失败，无法进行产品匹配",
                              result={"error": "标签生成失败"})
                return

        tag_names = [t.get("name", "") for t in user_tag.tags]

        # Step 3: 检查风险评估
        _set_progress(user_name, "checking_risk",
                      "正在检查用户风险评估等级...")

        risk_info = _check_risk_assessment(user_name)
        has_risk = risk_info["has_risk"]
        risk_level = risk_info["risk_level"]
        risk_warning = risk_info["warning"]

        # Step 4: 加载产品库
        _set_progress(user_name, "loading_products",
                      "正在加载银行产品库...")

        all_products = _load_products(risk_level if has_risk else None)

        if not all_products:
            _set_progress(user_name, "done",
                          "产品库加载失败，请检查数据源",
                          result={"error": "产品库加载失败"})
            return

        # Step 5: LLM 智能匹配
        _set_progress(user_name, "matching",
                      "AI 正在根据标签匹配产品...")

        matched = await _llm_match(tag_names, all_products)

        # Step 6: 排序
        _set_progress(user_name, "ranking",
                      "正在排序推荐结果...")

        matched.sort(key=lambda x: x.get("match_score", 0), reverse=True)
        top5 = matched[:5]

        # 构建最终结果
        result = {
            "user_name": user_name,
            "tags_used": tag_names,
            "has_risk_assessment": has_risk,
            "risk_level": risk_level,
            "risk_warning": risk_warning,
            "matched_products": top5,
            "total_matched": len(matched),
            "model_used": _get_model_name(),
            "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }

        # 缓存结果
        store = _load_store()
        store[user_name] = result
        _save_store(store)

        _set_progress(user_name, "done",
                      f"匹配完成，共推荐 {len(top5)} 款产品",
                      result=result)

    except Exception as e:
        _set_progress(user_name, "done",
                      f"匹配失败: {str(e)}",
                      result={"error": str(e)})


def _check_risk_assessment(user_name: str) -> dict:
    """检查用户是否有风险评估等级"""
    # 尝试从 tagging service/tag_engine 获取
    try:
        from pmb.profile.tag_engine import TagEngine
        engine = TagEngine()
        tags = engine.compute_tags(user_name=user_name)
        risk_pref = tags.get("risk_preference", "")
    except Exception:
        risk_pref = ""

    # 目前系统风险偏好固定为"稳健"（MVP），属于默认值而非真实风评
    # 检查是否有显式的风险评估记录（预留字段）
    has_real_assessment = _has_real_risk_record(user_name)

    if has_real_assessment:
        return {
            "has_risk": True,
            "risk_level": risk_pref,
            "warning": None,
        }
    else:
        return {
            "has_risk": False,
            "risk_level": None,
            "warning": (
                "⚠️ 该用户尚未完成风险等级评估。"
                "以下推荐产品仅供参考内部使用，请在用户完成风评后重新匹配。"
            ),
        }


def _has_real_risk_record(user_name: str) -> bool:
    """检查是否有真实的（非默认）风险评估记录"""
    # 从用户详情或 user_risk.json 中查找
    try:
        from pmb.ai_manage.store import read_json
        risk_data = read_json("user_risk.json")
        if isinstance(risk_data, dict) and user_name in risk_data:
            return True
    except Exception:
        pass

    # 也检查 user_tags 中是否有 risk 字段
    try:
        user_tag = get_tags_for_user(user_name)
        if user_tag and hasattr(user_tag, 'risk_level') and user_tag.risk_level:
            return True
    except Exception:
        pass

    return False


def _load_products(risk_level: str | None) -> list[dict]:
    """加载银行产品库，可选按风险等级过滤"""
    from pmb.core.config import PRODUCT_FILES, PRODUCT_CATEGORY_NAMES
    from pmb.core import product_service

    all_products = []
    for cat, filepath in PRODUCT_FILES.items():
        cat_name = PRODUCT_CATEGORY_NAMES.get(cat, cat)
        try:
            products, _ = product_service.list_products(category=cat, limit=200)
        except Exception:
            continue

        for p in products:
            p_risk = str(p.get("risk_level", p.get("风险等级", "")))
            p_name = str(p.get("name", p.get("产品名称", p.get("产品名称/类别", p.get("基金类别", "")))))

            # 风险等级过滤
            if risk_level and p_risk and risk_level not in p_risk:
                continue

            all_products.append({
                "name": p_name,
                "bank": str(p.get("bank", p.get("银行", ""))),
                "category": cat_name,
                "type_label": str(p.get("type_label", p.get("产品大类", p.get("产品类型", "")))),
                "description": str(p.get("description", p.get("产品描述", "")))[:200],
                "risk_level": p_risk,
                "detail": p,
            })

    return all_products


async def _llm_match(tag_names: list[str], products: list[dict]) -> list[dict]:
    """使用 LLM 匹配标签到产品"""
    llm = _get_llm()

    # 构建标签描述
    tag_desc = "、".join(tag_names)
    user_style = f"用户画像标签: {tag_desc}"

    # 构建产品列表（精简字段，节省 token）
    product_list = json.dumps([
        {
            "name": p["name"],
            "bank": p["bank"],
            "category": p["category"],
            "type": p["type_label"],
            "description": p["description"][:120],
            "risk_level": p["risk_level"],
        }
        for p in products
    ], ensure_ascii=False)

    user_prompt = f"""{user_style}

银行可用产品列表 ({len(products)} 款):
{product_list}"""

    try:
        response = await llm.chat(messages=[
            {"role": "system", "content": MATCH_SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ])

        content = response.content.strip()
        if "```json" in content:
            content = content.split("```json")[1].split("```")[0].strip()
        elif "```" in content:
            content = content.split("```")[1].split("```")[0].strip()

        result = json.loads(content)
        raw_matches = result.get("matches", [])

        # 关联产品详情
        matched = []
        for m in raw_matches:
            p_name = m.get("product_name", "")
            # 查找对应产品
            for p in products:
                if p["name"] == p_name:
                    matched.append({
                        "product_name": p["name"],
                        "bank": p["bank"],
                        "category": p["category"],
                        "type_label": p["type_label"],
                        "description": p["description"],
                        "risk_level": p["risk_level"],
                        "match_score": m.get("match_score", 0.5),
                        "match_reason": m.get("reasoning", ""),
                        "detail_link": f"/recommendations?product={p['name']}",
                    })
                    break
            if len(matched) >= 5:
                break

        return matched

    except Exception as e:
        # LLM 匹配失败时返回空列表
        return []
