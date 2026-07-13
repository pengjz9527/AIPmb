from fastapi import APIRouter, Header
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


@router.get("/ai/insight", summary="AI一句话洞察")
async def get_ai_insight(user_name: str = Header("", alias="x-user-name")):
    """基于用户消费/交易数据，调用 LLM 生成一句话洞察摘要"""
    user_name = _decode_user_name(user_name)
    from pmb.core.insight_service import generate_insight
    data = await generate_insight(user_name)
    return ApiResponse(data=data)
