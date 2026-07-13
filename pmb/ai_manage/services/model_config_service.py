"""模型配置管理服务"""
import uuid
from datetime import datetime
from pmb.ai_manage.store import read_json, write_json
from pmb.ai_manage.models.model_config import ModelConfig
from pmb.ai_manage.config import DEFAULT_MODEL_CONFIG

STORE_FILE = "model_configs.json"


def _ensure_default():
    """确保至少有一个默认配置"""
    configs = read_json(STORE_FILE)
    if not configs:
        default = DEFAULT_MODEL_CONFIG.copy()
        default["created_at"] = datetime.now().isoformat()
        default["updated_at"] = datetime.now().isoformat()
        write_json(STORE_FILE, [default])
        return [default]
    return configs


def list_configs() -> list[ModelConfig]:
    """列出所有模型配置"""
    configs = _ensure_default()
    return [ModelConfig.from_dict(c) for c in configs]


def get_config(config_id: str) -> ModelConfig | None:
    """按 ID 获取配置"""
    configs = _ensure_default()
    for c in configs:
        if c.get("id") == config_id:
            return ModelConfig.from_dict(c)
    return None


def get_active_config() -> ModelConfig | None:
    """获取当前活跃配置"""
    configs = _ensure_default()
    for c in configs:
        if c.get("is_active"):
            return ModelConfig.from_dict(c)
    return None


def create_config(data: dict) -> ModelConfig:
    """创建新配置"""
    configs = _ensure_default()
    new_id = str(uuid.uuid4())[:8]
    now = datetime.now().isoformat()
    config = {
        "id": new_id,
        "name": data.get("name", ""),
        "provider": data.get("provider", ""),
        "api_key": data.get("api_key", ""),
        "base_url": data.get("base_url", ""),
        "model_name": data.get("model_name", ""),
        "is_active": False,
        "created_at": now,
        "updated_at": now,
    }
    configs.append(config)
    write_json(STORE_FILE, configs)
    return ModelConfig.from_dict(config)


def update_config(config_id: str, data: dict) -> ModelConfig | None:
    """更新配置"""
    configs = _ensure_default()
    for c in configs:
        if c.get("id") == config_id:
            for key in ("name", "provider", "api_key", "base_url", "model_name", "is_active"):
                if key in data and data[key] is not None:
                    c[key] = data[key]
            c["updated_at"] = datetime.now().isoformat()
            write_json(STORE_FILE, configs)
            return ModelConfig.from_dict(c)
    return None


def delete_config(config_id: str) -> bool:
    """删除配置"""
    configs = _ensure_default()
    for i, c in enumerate(configs):
        if c.get("id") == config_id:
            if c.get("is_active"):
                # 不允许删除活跃配置
                return False
            configs.pop(i)
            write_json(STORE_FILE, configs)
            return True
    return False


def activate_config(config_id: str) -> ModelConfig | None:
    """激活配置（自动取消其他配置的活跃状态）"""
    configs = _ensure_default()
    target = None
    for c in configs:
        if c.get("id") == config_id:
            c["is_active"] = True
            c["updated_at"] = datetime.now().isoformat()
            target = c
        else:
            c["is_active"] = False
    if target is None:
        return None
    write_json(STORE_FILE, configs)
    return ModelConfig.from_dict(target)