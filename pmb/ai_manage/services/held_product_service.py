"""用户持有产品服务"""
from datetime import datetime
from pmb.core.loader import loader
from pmb.utils.search import apply_pagination


def _safe_float(v) -> float:
    try:
        return float(v) if v is not None else 0.0
    except (TypeError, ValueError):
        return 0.0


def _safe_str(v) -> str:
    return str(v) if v is not None else ""


def _format_date(v):
    """统一日期格式为字符串"""
    if v is None:
        return ""
    if isinstance(v, datetime):
        return v.strftime("%Y-%m-%d")
    return str(v)


# ---------- 理财 ----------
def list_wealth_products(user_name: str, limit: int = 20, offset: int = 0) -> tuple[list[dict], int]:
    rows = loader.load_held_wealth()
    items = [_row_to_wealth(r) for r in rows if _safe_str(r.get("持有人姓名")) == user_name]
    paginated, total = apply_pagination(items, offset, limit)
    return paginated, total


def get_wealth_detail(product_id: str) -> dict | None:
    rows = loader.load_held_wealth()
    for r in rows:
        if str(r.get("序号", "")) == product_id:
            return _row_to_wealth(r)
    return None


def redeem_wealth_product(product_id: str, amount: float | None = None) -> dict:
    """模拟赎回操作，返回操作结果"""
    detail = get_wealth_detail(product_id)
    if detail is None:
        raise ValueError(f"理财产品 {product_id} 不存在")
    return {
        "product_id": product_id,
        "action": "redeem",
        "amount": amount or detail.get("redeem_amount"),
        "status": "submitted",
        "message": "赎回申请已提交，预计T+1到账",
    }


# ---------- 贷款 ----------
def list_loans(user_name: str, limit: int = 20, offset: int = 0) -> tuple[list[dict], int]:
    rows = loader.load_held_loans()
    items = [_row_to_loan(r) for r in rows if _safe_str(r.get("持有人姓名")) == user_name]
    paginated, total = apply_pagination(items, offset, limit)
    return paginated, total


def get_loan_detail(loan_id: str) -> dict | None:
    rows = loader.load_held_loans()
    for r in rows:
        if str(r.get("序号", "")) == loan_id:
            return _row_to_loan(r)
    return None


def get_repayment_plan(loan_id: str) -> list[dict]:
    """生成等额本息/等额本金还款计划"""
    detail = get_loan_detail(loan_id)
    if detail is None:
        raise ValueError(f"贷款 {loan_id} 不存在")

    remaining = detail.get("remaining_principal", 0)
    annual_rate_str = detail.get("annual_rate", "0%")
    repayment_method = detail.get("repayment_method", "")

    # 解析年利率
    rate = 0.0
    try:
        rate = float(annual_rate_str.replace("%", "")) / 100
    except (ValueError, TypeError):
        rate = 0.0286  # 默认 2.86%

    monthly_rate = rate / 12
    plan = []

    if "等额本息" in repayment_method:
        # 等额本息：每月还款额固定
        months = 120  # 默认剩余10年
        if remaining > 0 and monthly_rate > 0:
            monthly_payment = remaining * monthly_rate * (1 + monthly_rate) ** months / ((1 + monthly_rate) ** months - 1)
        else:
            monthly_payment = remaining / months if months > 0 else 0

        current_remaining = remaining
        for i in range(1, min(months + 1, 13)):  # 生成12期
            interest = current_remaining * monthly_rate
            principal_payment = monthly_payment - interest
            current_remaining -= principal_payment
            plan.append({
                "period": i,
                "payment_date": _next_month_date(i),
                "principal": round(principal_payment, 2),
                "interest": round(interest, 2),
                "total_payment": round(monthly_payment, 2),
                "remaining_principal": round(max(current_remaining, 0), 2),
            })
    else:
        # 等额本金：每月本金固定
        months = 120
        monthly_principal = remaining / months if months > 0 else 0
        current_remaining = remaining
        for i in range(1, min(months + 1, 13)):
            interest = current_remaining * monthly_rate
            total = monthly_principal + interest
            current_remaining -= monthly_principal
            plan.append({
                "period": i,
                "payment_date": _next_month_date(i),
                "principal": round(monthly_principal, 2),
                "interest": round(interest, 2),
                "total_payment": round(total, 2),
                "remaining_principal": round(max(current_remaining, 0), 2),
            })

    return plan


def prepay_loan(loan_id: str, amount: float) -> dict:
    """模拟提前还款"""
    detail = get_loan_detail(loan_id)
    if detail is None:
        raise ValueError(f"贷款 {loan_id} 不存在")
    return {
        "loan_id": loan_id,
        "action": "prepay",
        "amount": amount,
        "status": "submitted",
        "message": "提前还款申请已提交，预计下一个扣款日执行",
    }


# ---------- 养老金 ----------
def list_pensions(user_name: str, limit: int = 20, offset: int = 0) -> tuple[list[dict], int]:
    rows = loader.load_held_pensions()
    items = [_row_to_pension(r) for r in rows if _safe_str(r.get("持有人姓名")) == user_name]
    paginated, total = apply_pagination(items, offset, limit)
    return paginated, total


def get_pension_detail(pension_id: str) -> dict | None:
    rows = loader.load_held_pensions()
    for r in rows:
        if str(r.get("序号", "")) == pension_id:
            return _row_to_pension(r)
    return None


# ---------- 汇总 ----------
def get_user_held_summary(user_name: str) -> dict | None:
    wealth, _ = list_wealth_products(user_name, limit=1000, offset=0)
    loans, _ = list_loans(user_name, limit=1000, offset=0)
    pensions, _ = list_pensions(user_name, limit=1000, offset=0)

    if not wealth and not loans and not pensions:
        return None

    total_wealth = sum(_safe_float(w.get("holding_amount")) for w in wealth)
    total_loan = sum(_safe_float(l.get("remaining_principal")) for l in loans)
    total_pension = sum(_safe_float(p.get("total_amount")) for p in pensions)

    return {
        "user_name": user_name,
        "wealth": {
            "count": len(wealth),
            "total_holding_amount": round(total_wealth, 2),
            "products": wealth,
        },
        "loans": {
            "count": len(loans),
            "total_remaining_principal": round(total_loan, 2),
            "items": loans,
        },
        "pensions": {
            "count": len(pensions),
            "total_amount": round(total_pension, 2),
            "items": pensions,
        },
    }


# ---------- 内部转换函数 ----------
def _row_to_wealth(r: dict) -> dict:
    return {
        "id": str(r.get("序号", "")),
        "holder_name": _safe_str(r.get("持有人姓名")),
        "product_name": _safe_str(r.get("产品名称")),
        "category": _safe_str(r.get("产品分类")),
        "term": _safe_str(r.get("产品期限")),
        "card_tail": _safe_str(r.get("关联卡号尾号")),
        "holding_amount": _safe_float(r.get("持仓金额(元)")),
        "holding_profit": _safe_float(r.get("持仓收益(元)")),
        "principal": _safe_float(r.get("投入本金(元)")),
        "shares": _safe_float(r.get("持有份额")),
        "yield_rate": _safe_float(r.get("收益率")),
        "redeem_date": _format_date(r.get("可赎回日期")),
        "redeem_amount": _safe_float(r.get("可赎回金额(元)")),
        "redeem_status": _safe_str(r.get("赎回状态")),
    }


def _row_to_loan(r: dict) -> dict:
    return {
        "id": str(r.get("序号", "")),
        "holder_name": _safe_str(r.get("持有人姓名")),
        "loan_type": _safe_str(r.get("贷款类型")),
        "loan_no": _safe_str(r.get("贷款编号")),
        "purpose": _safe_str(r.get("贷款用途")),
        "bank_branch": _safe_str(r.get("贷款行")),
        "issue_date": _format_date(r.get("发放日")),
        "principal": _safe_float(r.get("贷款本金(元)")),
        "remaining_principal": _safe_float(r.get("未还贷款本金(元)")),
        "repaid_principal": _safe_float(r.get("已还本金(元)")),
        "rate_type": _safe_str(r.get("利率定价方式")),
        "annual_rate": _safe_str(r.get("年利率")),
        "lpr_adjust": _safe_str(r.get("LPR调整")),
        "next_repricing_date": _format_date(r.get("下一个重定价日")),
        "repayment_method": _safe_str(r.get("还款方式")),
        "repayment_card": _safe_str(r.get("还款卡号")),
        "notify_phone": _safe_str(r.get("通知手机号")),
    }


def _row_to_pension(r: dict) -> dict:
    return {
        "id": str(r.get("序号", "")),
        "holder_name": _safe_str(r.get("持有人姓名")),
        "account_type": _safe_str(r.get("账户类型")),
        "total_amount": _safe_float(r.get("总金额(元)")),
        "idle_amount": _safe_float(r.get("闲置金额(元)")),
        "annual_deposit_limit": _safe_float(r.get("年度缴存上限(元)")),
        "remaining_deposit_quota": _safe_float(r.get("剩余缴存额度(元)")),
        "deposited_amount": _safe_float(r.get("已缴存金额(元)")),
        "tax_benefit": _safe_str(r.get("税收优惠")),
        "auto_deposit_status": _safe_str(r.get("自动缴存状态")),
        "recommended_plan": _safe_str(r.get("推荐投资方案")),
        "reference_yield": _safe_str(r.get("参考收益率")),
        "yield_calculation": _safe_str(r.get("收益测算功能")),
        "remark": _safe_str(r.get("备注")),
    }


def _next_month_date(months_ahead: int) -> str:
    """生成未来月份日期"""
    now = datetime.now()
    year = now.year
    month = now.month + months_ahead
    while month > 12:
        month -= 12
        year += 1
    return f"{year}-{month:02d}-01"
