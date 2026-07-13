"""AI 用户标签生成服务"""
import json
from datetime import datetime
from pmb.ai_manage.store import read_json, write_json
from pmb.ai_manage.models.user_tag import UserTag
from pmb.ai_manage.services.user_service import get_user_detail, get_user_consumption_stats

STORE_FILE = "user_tags.json"

TAG_SYSTEM_PROMPT = """你是一位用户画像分析师。根据消费数据生成个性化标签。

规则：
1. 标签名要生动有趣，5-8个字（如"高铁通勤VIP"、"深夜食堂常客"、"数码生态建设者"）
2. description 字段要写成用户能看懂的自然语言解释（如"近3个月铁路出行消费占比38%，月均乘坐12次，是12306的忠实用户"）
3. 每个标签引用具体数据支撑，让用户感到"这确实是我"
4. 输出3-6个标签

输出格式（严格JSON）：
{"tags": [{"name": "标签名", "description": "用数据说话的解释"}, ...]}"""


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


def _load_store() -> dict:
    """加载标签存储"""
    data = read_json(STORE_FILE)
    if isinstance(data, list):
        return {}
    return data or {}


def _save_store(data: dict):
    write_json(STORE_FILE, data)


def get_tags_for_user(user_name: str) -> UserTag | None:
    """获取用户标签"""
    store = _load_store()
    if user_name in store:
        return UserTag.from_dict(store[user_name])
    return None


def list_tagged_users() -> list[str]:
    """列出所有已标记用户"""
    store = _load_store()
    return list(store.keys())


async def generate_tags_for_user(user_name: str, force: bool = False) -> UserTag:
    """为单个用户生成标签"""
    # 检查缓存
    if not force:
        existing = get_tags_for_user(user_name)
        if existing is not None:
            return existing

    # 收集用户数据
    detail = get_user_detail(user_name)
    if detail is None:
        raise ValueError(f"用户 {user_name} 不存在")

    stats = get_user_consumption_stats(user_name, group_by="subcategory", top=10)
    merchant_stats = get_user_consumption_stats(user_name, group_by="merchant", top=10)
    monthly_stats = get_user_consumption_stats(user_name, group_by="month", top=12)

    # 构建 prompt
    user_data = {
        "用户": user_name,
        "账户数": detail["account_count"],
        "总资产": f"¥{detail['total_balance']:,.2f}",
        "总交易笔数": detail["transaction_count"],
        "消费分类Top10": [{"分类": s["name"], "金额": s["total"], "笔数": s["count"]} for s in stats],
        "常去商户Top10": [{"商户": s["name"], "金额": s["total"], "笔数": s["count"]} for s in merchant_stats],
        "月度消费趋势": [{"月份": s["name"], "金额": s["total"], "笔数": s["count"]} for s in monthly_stats],
    }

    user_prompt = f"请根据以下用户数据，生成有趣的个性化标签：\n\n{json.dumps(user_data, ensure_ascii=False, indent=2)}"

    llm = _get_llm()
    response = await llm.chat(messages=[
        {"role": "system", "content": TAG_SYSTEM_PROMPT},
        {"role": "user", "content": user_prompt},
    ])

    # 解析 LLM 响应
    try:
        content = response.content.strip()
        # 处理可能的 markdown 代码块
        if "```json" in content:
            content = content.split("```json")[1].split("```")[0].strip()
        elif "```" in content:
            content = content.split("```")[1].split("```")[0].strip()
        result = json.loads(content)
        tags = result.get("tags", [])
    except (json.JSONDecodeError, IndexError):
        # 尝试直接解析
        tags = [{"name": "消费达人", "description": "基于消费数据分析"}]

    # 保存
    user_tag = UserTag(
        user_name=user_name,
        tags=tags,
        model_used=f"{_get_model_name()}",
    )

    store = _load_store()
    store[user_name] = user_tag.to_dict()
    _save_store(store)

    return user_tag


async def batch_generate_tags(user_names: list[str], force: bool = False) -> dict[str, dict]:
    """批量生成标签"""
    results = {}
    for name in user_names:
        try:
            tag = await generate_tags_for_user(name, force)
            results[name] = {"success": True, "tags": tag.tags}
        except Exception as e:
            results[name] = {"success": False, "error": str(e)}
    return results


def _get_model_name() -> str:
    """获取当前使用的模型名称"""
    from pmb.ai_manage.services.model_config_service import get_active_config
    config = get_active_config()
    if config:
        return config.model_name
    from pmb.core.config import LLM_MODEL
    return LLM_MODEL