"""购买申请 Service — JSON 文件持久化"""
import uuid
from datetime import datetime
from pmb.ai_manage.store import read_json, write_json

PURCHASE_FILE = "purchases.json"


def create_purchase(user_name: str, product_name: str, amount: float) -> dict:
    """创建购买申请记录"""
    purchases = read_json(PURCHASE_FILE)
    if not isinstance(purchases, list):
        purchases = []

    purchase = {
        "id": str(uuid.uuid4()),
        "user_name": user_name,
        "product_name": product_name,
        "amount": amount,
        "status": "pending",
        "created_at": datetime.now().isoformat(),
    }

    purchases.append(purchase)
    write_json(PURCHASE_FILE, purchases)
    return purchase
