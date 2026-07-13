"""JSON 文件读写工具，线程安全"""
import json
import threading
from pathlib import Path
from pmb.ai_manage.config import DATA_DIR

_lock = threading.Lock()


def read_json(filename: str) -> list | dict:
    """读取 JSON 文件"""
    path = DATA_DIR / filename
    if not path.exists():
        return []
    with _lock:
        return json.loads(path.read_text(encoding="utf-8"))


def write_json(filename: str, data: list | dict):
    """写入 JSON 文件"""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with _lock:
        (DATA_DIR / filename).write_text(
            json.dumps(data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )