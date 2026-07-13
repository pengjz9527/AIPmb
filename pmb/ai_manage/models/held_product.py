"""用户持有产品数据模型"""
from dataclasses import dataclass, field


@dataclass
class HeldWealthProduct:
    """持有理财产品"""
    id: str
    holder_name: str
    product_name: str
    category: str
    term: str
    card_tail: str
    holding_amount: float
    holding_profit: float
    principal: float
    shares: float
    yield_rate: float
    redeem_date: str
    redeem_amount: float
    redeem_status: str

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "holder_name": self.holder_name,
            "product_name": self.product_name,
            "category": self.category,
            "term": self.term,
            "card_tail": self.card_tail,
            "holding_amount": self.holding_amount,
            "holding_profit": self.holding_profit,
            "principal": self.principal,
            "shares": self.shares,
            "yield_rate": self.yield_rate,
            "redeem_date": self.redeem_date,
            "redeem_amount": self.redeem_amount,
            "redeem_status": self.redeem_status,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "HeldWealthProduct":
        return cls(
            id=str(d.get("id", "")),
            holder_name=str(d.get("holder_name", "")),
            product_name=str(d.get("product_name", "")),
            category=str(d.get("category", "")),
            term=str(d.get("term", "")),
            card_tail=str(d.get("card_tail", "")),
            holding_amount=float(d.get("holding_amount", 0) or 0),
            holding_profit=float(d.get("holding_profit", 0) or 0),
            principal=float(d.get("principal", 0) or 0),
            shares=float(d.get("shares", 0) or 0),
            yield_rate=float(d.get("yield_rate", 0) or 0),
            redeem_date=str(d.get("redeem_date", "")),
            redeem_amount=float(d.get("redeem_amount", 0) or 0),
            redeem_status=str(d.get("redeem_status", "")),
        )


@dataclass
class HeldLoan:
    """持有贷款"""
    id: str
    holder_name: str
    loan_type: str
    loan_no: str
    purpose: str
    bank_branch: str
    issue_date: str
    principal: float
    remaining_principal: float
    repaid_principal: float
    rate_type: str
    annual_rate: str
    lpr_adjust: str
    next_repricing_date: str
    repayment_method: str
    repayment_card: str
    notify_phone: str

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "holder_name": self.holder_name,
            "loan_type": self.loan_type,
            "loan_no": self.loan_no,
            "purpose": self.purpose,
            "bank_branch": self.bank_branch,
            "issue_date": self.issue_date,
            "principal": self.principal,
            "remaining_principal": self.remaining_principal,
            "repaid_principal": self.repaid_principal,
            "rate_type": self.rate_type,
            "annual_rate": self.annual_rate,
            "lpr_adjust": self.lpr_adjust,
            "next_repricing_date": self.next_repricing_date,
            "repayment_method": self.repayment_method,
            "repayment_card": self.repayment_card,
            "notify_phone": self.notify_phone,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "HeldLoan":
        return cls(
            id=str(d.get("id", "")),
            holder_name=str(d.get("holder_name", "")),
            loan_type=str(d.get("loan_type", "")),
            loan_no=str(d.get("loan_no", "")),
            purpose=str(d.get("purpose", "")),
            bank_branch=str(d.get("bank_branch", "")),
            issue_date=str(d.get("issue_date", "")),
            principal=float(d.get("principal", 0) or 0),
            remaining_principal=float(d.get("remaining_principal", 0) or 0),
            repaid_principal=float(d.get("repaid_principal", 0) or 0),
            rate_type=str(d.get("rate_type", "")),
            annual_rate=str(d.get("annual_rate", "")),
            lpr_adjust=str(d.get("lpr_adjust", "")),
            next_repricing_date=str(d.get("next_repricing_date", "")),
            repayment_method=str(d.get("repayment_method", "")),
            repayment_card=str(d.get("repayment_card", "")),
            notify_phone=str(d.get("notify_phone", "")),
        )


@dataclass
class HeldPension:
    """养老金账户"""
    id: str
    holder_name: str
    account_type: str
    total_amount: float
    idle_amount: float
    annual_deposit_limit: float
    remaining_deposit_quota: float
    deposited_amount: float
    tax_benefit: str
    auto_deposit_status: str
    recommended_plan: str
    reference_yield: str
    yield_calculation: str
    remark: str

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "holder_name": self.holder_name,
            "account_type": self.account_type,
            "total_amount": self.total_amount,
            "idle_amount": self.idle_amount,
            "annual_deposit_limit": self.annual_deposit_limit,
            "remaining_deposit_quota": self.remaining_deposit_quota,
            "deposited_amount": self.deposited_amount,
            "tax_benefit": self.tax_benefit,
            "auto_deposit_status": self.auto_deposit_status,
            "recommended_plan": self.recommended_plan,
            "reference_yield": self.reference_yield,
            "yield_calculation": self.yield_calculation,
            "remark": self.remark,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "HeldPension":
        return cls(
            id=str(d.get("id", "")),
            holder_name=str(d.get("holder_name", "")),
            account_type=str(d.get("account_type", "")),
            total_amount=float(d.get("total_amount", 0) or 0),
            idle_amount=float(d.get("idle_amount", 0) or 0),
            annual_deposit_limit=float(d.get("annual_deposit_limit", 0) or 0),
            remaining_deposit_quota=float(d.get("remaining_deposit_quota", 0) or 0),
            deposited_amount=float(d.get("deposited_amount", 0) or 0),
            tax_benefit=str(d.get("tax_benefit", "")),
            auto_deposit_status=str(d.get("auto_deposit_status", "")),
            recommended_plan=str(d.get("recommended_plan", "")),
            reference_yield=str(d.get("reference_yield", "")),
            yield_calculation=str(d.get("yield_calculation", "")),
            remark=str(d.get("remark", "")),
        )
