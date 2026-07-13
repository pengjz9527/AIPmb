"""风险测评服务 — 读写 risk_assessments.json"""
from datetime import datetime
from pmb.ai_manage.store import read_json, write_json

STORE_FILE = "risk_assessments.json"


def _load_all() -> list[dict]:
    """加载全部测评记录"""
    data = read_json(STORE_FILE)
    if isinstance(data, dict):
        return []
    return data or []


def _save_all(data: list[dict]):
    """保存全部测评记录"""
    write_json(STORE_FILE, data)


def get_assessment(user_name: str) -> dict | None:
    """查询用户最新测评记录（含有效期判断）"""
    records = _load_all()
    # 按 id 降序，取最新一条该用户的记录
    user_records = [r for r in records if r.get("user_name") == user_name]
    if not user_records:
        return None

    latest = max(user_records, key=lambda r: r.get("id", 0))
    # 判断是否过期
    expiry_str = latest.get("expiry_date", "")
    expired = False
    if expiry_str:
        try:
            expiry = datetime.strptime(expiry_str, "%Y/%m/%d")
            if datetime.now() > expiry:
                expired = True
        except ValueError:
            pass

    return {
        "id": latest.get("id"),
        "user_name": latest.get("user_name"),
        "risk_level": latest.get("risk_level", ""),
        "expiry_date": latest.get("expiry_date", ""),
        "created_at": latest.get("created_at", ""),
        "expired": expired,
    }


def save_assessment(user_name: str, risk_level: str, expiry_date: str) -> dict:
    """保存测评结果（追加新记录，不覆盖历史）"""
    records = _load_all()
    max_id = max((r.get("id", 0) for r in records), default=0)
    new_record = {
        "id": max_id + 1,
        "user_name": user_name,
        "risk_level": risk_level,
        "expiry_date": expiry_date,
        "created_at": datetime.now().isoformat(),
    }
    records.append(new_record)
    _save_all(records)
    return new_record
