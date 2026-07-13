from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Account:
    seq: int
    name: str
    account_type: str
    card_product: str
    account_number: str
    branch: str
    currency: str
    expiry_date: str
    balance: str
    credit_limit: str
    billing_day: str
    due_day: str
    amount_due: str
    min_payment: str
    last_tx_date: str
    source: str
    notes: str
    raw_data: dict = field(default_factory=dict)

    @classmethod
    def from_row(cls, row: dict) -> "Account":
        return cls(
            seq=_int(row.get("序号", 0)),
            name=str(row.get("用户姓名", "")),
            account_type=str(row.get("账户类型", "")),
            card_product=str(row.get("卡种/产品", "")),
            account_number=str(row.get("账号/卡号", "")),
            branch=str(row.get("开户行/发卡行", "")),
            currency=str(row.get("币种", "")),
            expiry_date=str(row.get("到期日", "") or ""),
            balance=str(row.get("最新余额(元)", "") or ""),
            credit_limit=str(row.get("信用额度(元)", "") or ""),
            billing_day=str(row.get("账单日", "") or ""),
            due_day=str(row.get("到期还款日", "") or ""),
            amount_due=str(row.get("本期应还金额(元)", "") or ""),
            min_payment=str(row.get("最低还款额(元)", "") or ""),
            last_tx_date=str(row.get("最近交易日期", "") or ""),
            source=str(row.get("数据来源", "") or ""),
            notes=str(row.get("备注", "") or ""),
            raw_data=row,
        )


@dataclass
class CreditTransaction:
    seq: int
    bill_month: str
    year: int
    month: int
    cardholder: str
    card_number: str
    transaction_date: str
    posting_date: str
    trans_year: int
    trans_month: int
    category: str
    direction: str
    summary: str
    payment_channel: str
    merchant_name: str
    subcategory: str
    amount: float
    original_amount: float
    currency: str
    raw_data: dict = field(default_factory=dict)

    @classmethod
    def from_row(cls, row: dict) -> "CreditTransaction":
        return cls(
            seq=_int(row.get("序号", 0)),
            bill_month=str(row.get("账单月份", "")),
            year=_int(row.get("年份", 0)),
            month=_int(row.get("月份", 0)),
            cardholder=str(row.get("持卡人姓名", "")),
            card_number=str(row.get("卡号", "")),
            transaction_date=str(row.get("交易日期", "")),
            posting_date=str(row.get("记账日期", "")),
            trans_year=_int(row.get("交易年份", 0)),
            trans_month=_int(row.get("交易月份", 0)),
            category=str(row.get("交易分类", "")),
            direction=str(row.get("收支方向", "")),
            summary=str(row.get("交易摘要", "")),
            payment_channel=str(row.get("支付渠道", "")),
            merchant_name=str(row.get("商户名称", "")),
            subcategory=str(row.get("消费细分子类", "")),
            amount=_float(row.get("交易金额", 0)),
            original_amount=_float(row.get("交易地金额", 0)),
            currency=str(row.get("币种", "")),
            raw_data=row,
        )


@dataclass
class DebitTransaction:
    seq: int
    posting_date: str
    year: int
    month: int
    currency: str
    direction: str
    amount: float
    running_balance: float
    trans_category: str
    trans_method: str
    counterparty_name: str
    counterparty_account: str
    source_account: str
    branch: str
    raw_data: dict = field(default_factory=dict)

    @classmethod
    def from_row(cls, row: dict) -> "DebitTransaction":
        return cls(
            seq=_int(row.get("序号", 0)),
            posting_date=str(row.get("记账日期", "")),
            year=_int(row.get("年份", 0)),
            month=_int(row.get("月份", 0)),
            currency=str(row.get("币种", "")),
            direction=str(row.get("收支方向", "")),
            amount=_float(row.get("交易金额(元)", 0)),
            running_balance=_float(row.get("联机余额(元)", 0)),
            trans_category=str(row.get("交易大类", "")),
            trans_method=str(row.get("交易方式/渠道", "")),
            counterparty_name=str(row.get("对手方名称", "")),
            counterparty_account=str(row.get("对手方账号/卡号", "") or ""),
            source_account=str(row.get("来源账号", "")),
            branch=str(row.get("开户行", "")),
            raw_data=row,
        )


@dataclass
class UnifiedTransaction:
    seq: int
    source: str  # "credit" or "debit"
    date: str
    direction: str
    amount: float
    category: str
    subcategory: str
    merchant: str
    payment_channel: str
    account_number: str
    currency: str
    raw_data: dict = field(default_factory=dict)

    @classmethod
    def from_credit(cls, tx: CreditTransaction) -> "UnifiedTransaction":
        return cls(
            seq=tx.seq,
            source="credit",
            date=tx.transaction_date,
            direction=tx.direction,
            amount=tx.amount,
            category=tx.category,
            subcategory=tx.subcategory,
            merchant=tx.merchant_name,
            payment_channel=tx.payment_channel,
            account_number=tx.card_number,
            currency=tx.currency,
            raw_data=tx.raw_data,
        )

    @classmethod
    def from_debit(cls, tx: DebitTransaction) -> "UnifiedTransaction":
        return cls(
            seq=tx.seq,
            source="debit",
            date=tx.posting_date,
            direction=tx.direction,
            amount=tx.amount,
            category=tx.trans_category,
            subcategory="",
            merchant=tx.counterparty_name,
            payment_channel=tx.trans_method,
            account_number=tx.source_account,
            currency=tx.currency,
            raw_data=tx.raw_data,
        )


@dataclass
class Product:
    bank: str
    name: str
    category: str  # deposit/loan/wealth/fund/insurance/forex/gold
    type_label: str
    description: str
    risk_level: str
    raw_data: dict = field(default_factory=dict)

    @classmethod
    def from_row(cls, row: dict, category: str) -> "Product":
        bank = str(row.get("银行", ""))
        # 不同产品文件列名不同，需要适配
        if category == "deposit":
            name = str(row.get("产品名称", ""))
            type_label = str(row.get("产品大类", ""))
            description = str(row.get("产品描述", ""))
            risk_level = ""
        elif category == "loan":
            name = str(row.get("产品名称", ""))
            type_label = str(row.get("产品大类", ""))
            description = str(row.get("产品描述", ""))
            risk_level = ""
        elif category == "wealth":
            name = str(row.get("产品名称/类别", ""))
            type_label = str(row.get("产品类型", ""))
            description = str(row.get("产品描述", ""))
            risk_level = str(row.get("风险等级", ""))
        elif category == "fund":
            name = str(row.get("基金类别", ""))
            type_label = str(row.get("基金类型", ""))
            description = str(row.get("产品描述", ""))
            risk_level = str(row.get("风险等级", ""))
        elif category == "insurance":
            name = str(row.get("产品名称/类别", ""))
            type_label = str(row.get("保险类型", ""))
            description = str(row.get("产品描述", ""))
            risk_level = ""
        elif category == "forex":
            name = str(row.get("产品名称/业务", ""))
            type_label = str(row.get("业务类型", ""))
            description = str(row.get("产品描述", ""))
            risk_level = ""
        elif category == "gold":
            name = str(row.get("产品名称", ""))
            type_label = str(row.get("产品类别", ""))
            description = str(row.get("产品描述", ""))
            risk_level = ""
        else:
            name = ""
            type_label = ""
            description = ""
            risk_level = ""
        return cls(
            bank=bank,
            name=name,
            category=category,
            type_label=type_label,
            description=description,
            risk_level=risk_level,
            raw_data=row,
        )


@dataclass
class ConsumptionRecord:
    seq: int
    date: str
    merchant: str
    subcategory: str
    amount: float
    channel: str
    category: str
    card_number: str
    summary: str
    direction: str
    raw_data: dict = field(default_factory=dict)

    @classmethod
    def from_credit(cls, tx: CreditTransaction) -> "ConsumptionRecord":
        return cls(
            seq=tx.seq,
            date=tx.transaction_date,
            merchant=tx.merchant_name,
            subcategory=tx.subcategory,
            amount=tx.amount,
            channel=tx.payment_channel,
            category=tx.category,
            card_number=tx.card_number,
            summary=tx.summary,
            direction=tx.direction,
            raw_data=tx.raw_data,
        )


def _int(v) -> int:
    try:
        return int(v)
    except (TypeError, ValueError):
        return 0


def _float(v) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0
