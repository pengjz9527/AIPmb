"""用户认证路由 — 手机号登录"""
import json
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from pmb.api.schemas.common import ApiResponse

router = APIRouter()

# 用户数据文件路径
USERS_FILE = Path(__file__).resolve().parent.parent.parent.parent / "pmb" / "output" / "users.json"


class LoginRequest(BaseModel):
    phone: str


def _load_users() -> list[dict]:
    """加载用户列表，文件不存在时自动创建并写入默认用户"""
    if not USERS_FILE.exists():
        USERS_FILE.parent.mkdir(parents=True, exist_ok=True)
        default_users = {
            "users": [
                {
                    "phone": "18600035919",
                    "name": "彭楫洲",
                    "created_at": "2026-06-07T00:00:00",
                }
            ]
        }
        USERS_FILE.write_text(
            json.dumps(default_users, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        return default_users["users"]
    data = json.loads(USERS_FILE.read_text(encoding="utf-8"))
    return data.get("users", [])


def _save_users(users: list[dict]) -> None:
    """保存用户列表到 JSON 文件"""
    USERS_FILE.parent.mkdir(parents=True, exist_ok=True)
    USERS_FILE.write_text(
        json.dumps({"users": users}, ensure_ascii=False, indent=2), encoding="utf-8"
    )


@router.post("/auth/login", summary="手机号登录")
async def login(req: LoginRequest):
    """手机号登录：查找已有用户，存在则返回用户信息。登录成功后重新计算用户标签。"""
    phone = req.phone.strip()
    if not phone:
        raise HTTPException(status_code=400, detail="手机号不能为空")

    users = _load_users()
    for u in users:
        if u["phone"] == phone:
            # 登录成功，清除标签缓存以触发重新计算
            from pmb.profile.tag_engine import tag_engine
            tag_engine.clear_cache()
            # 重新计算标签
            tags = tag_engine.compute_tags()
            return ApiResponse(
                data={
                    "phone": u["phone"],
                    "name": u["name"],
                    "created_at": u.get("created_at", ""),
                    "tags": tags.get("tags", []),
                }
            )

    raise HTTPException(status_code=404, detail="用户不存在")


@router.get("/auth/users", summary="用户列表")
async def list_users():
    """列出所有注册用户（调试用）"""
    return ApiResponse(data=_load_users())
