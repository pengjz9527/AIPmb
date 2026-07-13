"""AI-Manage 配置"""
from pathlib import Path

# 数据存储目录
DATA_DIR = Path(__file__).parent / "data"

# 默认模型配置（从 .env 读取）
from pmb.core.config import LLM_API_KEY, LLM_BASE_URL, LLM_MODEL

DEFAULT_MODEL_CONFIG = {
    "id": "default",
    "name": "Kimi K2.5 (默认)",
    "provider": "moonshot",
    "api_key": LLM_API_KEY,
    "base_url": LLM_BASE_URL,
    "model_name": LLM_MODEL,
    "is_active": True,
}