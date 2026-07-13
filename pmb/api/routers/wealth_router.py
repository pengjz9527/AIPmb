from fastapi import APIRouter, Header
from pmb.core import account_service
from pmb.ai_manage.services import held_product_service
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


@router.get("/wealth/overview", summary="财富总览")
async def get_wealth_overview(user_name: str = Header("", alias="x-user-name")):
    user_name = _decode_user_name(user_name)
    """计算总资产、总负债、净资产"""
    rows = account_service.get_account_summary(user_name=user_name)
    summary_dict = {item[0]: item[1] for item in rows}

    # 从账户汇总中提取数值
    total_assets = 0.0
    total_liabilities = 0.0

    # 获取所有账户进行计算
    all_accounts, _ = account_service.list_accounts(user_name=user_name, limit=1000)
    for acc in all_accounts:
        at = str(acc.get("账户类型", ""))
        if "借记" in at:
            try:
                bal = float(acc.get("最新余额(元)", 0) or 0)
                total_assets += bal
            except (TypeError, ValueError):
                pass
        elif "信用" in at:
            try:
                due = float(acc.get("本期应还金额(元)", 0) or 0)
                total_liabilities += due
            except (TypeError, ValueError):
                pass

    # 资产构成
    asset_breakdown = []
    debit_count = 0
    credit_count = 0
    total_credit_limit = 0.0
    for acc in all_accounts:
        at = str(acc.get("账户类型", ""))
        if "借记" in at:
            debit_count += 1
        elif "信用" in at:
            credit_count += 1
            try:
                lim = float(acc.get("信用额度(元)", 0) or 0)
                total_credit_limit += lim
            except (TypeError, ValueError):
                pass

    if total_assets > 0:
        asset_breakdown.append({"type": "借记卡余额", "amount": total_assets, "count": debit_count})
    if total_credit_limit > 0:
        asset_breakdown.append({"type": "信用卡额度", "amount": total_credit_limit, "count": credit_count})

    # 理财产品持仓
    try:
        wealth_items, _ = held_product_service.list_wealth_products(user_name, limit=1000, offset=0)
        total_wealth_holding = sum(float(w.get("holding_amount", 0) or 0) for w in wealth_items)
        if total_wealth_holding > 0:
            asset_breakdown.append({"type": "理财产品", "amount": total_wealth_holding, "count": len(wealth_items)})
            total_assets += total_wealth_holding
    except Exception:
        pass

    # 养老金/保障资产
    try:
        pension_items, _ = held_product_service.list_pensions(user_name, limit=1000, offset=0)
        total_pension = sum(float(p.get("total_amount", 0) or 0) for p in pension_items)
        if total_pension > 0:
            asset_breakdown.append({"type": "养老金保障", "amount": total_pension, "count": len(pension_items)})
            total_assets += total_pension
    except Exception:
        pass

    net_worth = total_assets - total_liabilities

    return ApiResponse(data={
        "total_assets": round(total_assets, 2),
        "total_liabilities": round(total_liabilities, 2),
        "net_worth": round(total_assets - total_liabilities, 2),
        "asset_breakdown": asset_breakdown,
        "currency": "CNY",
    })
