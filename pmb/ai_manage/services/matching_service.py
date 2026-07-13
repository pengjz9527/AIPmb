"""产品-标签匹配引擎服务"""
import json
from datetime import datetime
from pmb.ai_manage.store import read_json, write_json
from pmb.ai_manage.models.match_result import ProductMatch, RecommendationRecord
from pmb.ai_manage.models.user_tag import UserTag
from pmb.ai_manage.services.tagging_service import get_tags_for_user
from pmb.core import product_service

STORE_FILE = "recommendations.json"

MATCH_SYSTEM_PROMPT = """你是一位银行产品推荐专家。根据用户标签，判断哪些银行产品最适合推荐给该用户。

请分析每个产品与该标签的关联度，给出匹配分数(0-1，1=完美匹配)和推荐理由。

输出格式（严格JSON）：
{"matches": [{"product_name": "产品名称", "product_category": "产品类别", "match_score": 0.85, "reasoning": "推荐理由，结合标签和产品特点"}, ...]}
只输出分数 >= 0.5 的匹配项，按分数从高到低排序。"""


def _get_llm():
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


def _load_store() -> dict:
    data = read_json(STORE_FILE)
    if isinstance(data, list):
        return {}
    return data or {}


def _save_store(data: dict):
    write_json(STORE_FILE, data)


def get_cached_recommendations(user_name: str) -> RecommendationRecord | None:
    """获取缓存的推荐结果"""
    store = _load_store()
    if user_name in store:
        return RecommendationRecord.from_dict(store[user_name])
    return None


async def match_tags_to_products(
    user_name: str,
    tag_names: list[str] | None = None,
    force: bool = False,
) -> RecommendationRecord:
    """标签→产品匹配"""
    if not force:
        cached = get_cached_recommendations(user_name)
        if cached is not None:
            return cached

    # 获取用户标签
    user_tag = get_tags_for_user(user_name)
    if user_tag is None:
        raise ValueError(f"用户 {user_name} 暂无标签，请先生成标签")

    if tag_names:
        tags = [t for t in user_tag.tags if t.get("name") in tag_names]
    else:
        tags = user_tag.tags

    if not tags:
        raise ValueError("没有可用的标签")

    # 加载所有产品
    all_products = []
    from pmb.core.config import PRODUCT_FILES, PRODUCT_CATEGORY_NAMES
    for cat, filepath in PRODUCT_FILES.items():
        cat_name = PRODUCT_CATEGORY_NAMES.get(cat, cat)
        products, _ = product_service.list_products(category=cat, limit=100)
        for p in products:
            all_products.append({
                "name": p.get("产品名称", p.get("产品名称/类别", p.get("基金类别", p.get("产品名称/业务", "")))),
                "category": cat_name,
                "category_key": cat,
                "type": p.get("产品大类", p.get("产品类型", p.get("基金类型", p.get("业务类型", p.get("产品类别", ""))))),
                "description": p.get("产品描述", ""),
                "risk_level": p.get("风险等级", ""),
                "detail": p,
            })

    # 分组匹配（每批 20 个产品，减少 LLM 上下文压力）
    llm = _get_llm()
    all_matches: list[ProductMatch] = []

    for tag in tags:
        tag_name = tag.get("name", "")
        tag_reasoning = tag.get("reasoning", "")

        # 分批处理产品
        batch_size = 20
        for i in range(0, len(all_products), batch_size):
            batch = all_products[i:i + batch_size]
            product_list = json.dumps([
                {"name": p["name"], "category": p["category"], "type": p["type"], "description": p["description"]}
                for p in batch
            ], ensure_ascii=False)

            user_prompt = f"""用户标签: {tag_name}
标签推理: {tag_reasoning}

可选产品列表:
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
                matches = result.get("matches", [])

                for m in matches:
                    # 找到对应的产品详情
                    product_detail = {}
                    for p in batch:
                        if p["name"] == m.get("product_name"):
                            product_detail = p["detail"]
                            break
                    all_matches.append(ProductMatch(
                        tag_name=tag_name,
                        product_name=m.get("product_name", ""),
                        product_category=m.get("product_category", ""),
                        match_score=m.get("match_score", 0.0),
                        reasoning=m.get("reasoning", ""),
                        product_detail=product_detail,
                    ))
            except Exception:
                continue

    # 按分数排序
    all_matches.sort(key=lambda m: m.match_score, reverse=True)

    record = RecommendationRecord(
        user_name=user_name,
        matches=all_matches,
        model_used=_get_model_name(),
    )

    store = _load_store()
    store[user_name] = record.to_dict()
    _save_store(store)

    return record


def get_matched_products(user_name: str, top: int = 20) -> list[dict]:
    """获取匹配的产品列表（手机银行调用）"""
    record = get_cached_recommendations(user_name)
    if record is None:
        return []
    # 去重，按最高分保留
    seen = set()
    result = []
    for m in record.matches[:top * 2]:
        key = m.product_name
        if key not in seen:
            seen.add(key)
            result.append(m.to_dict())
            if len(result) >= top:
                break
    return result


def delete_matches(user_name: str) -> bool:
    """清除匹配缓存"""
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