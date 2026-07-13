"""贷款成本优化方案 Skill — 检查持有贷款，给出提前还款与转贷降息两种优化建议"""
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client


class LoanCostOptimizerSkill(BaseSkill):
    """贷款成本优化方案：
    1. 检查用户是否持有贷款产品
    2. 持有多笔贷款时列出供用户选择
    3. 收集用户资金余额和消费习惯
    4. 给出两种优化方案：
       a. 提前还款（基于可用资金和消费预留）
       b. 申请转贷下调利率（匹配银行低息贷款产品）
    5. 每种方案附带操作按钮
    """

    @property
    def name(self) -> str:
        return "loan_cost_optimizer"

    @property
    def description(self) -> str:
        return (
            "为我制定贷款成本优化方案。检查我持有的银行贷款，结合账户余额和消费习惯，"
            "给出'提前还款'和'申请转贷下调利率'两种优化路径的具体建议和预估节省金额。"
            "如果我持有多笔贷款，会先列出所有贷款供我选择。适用场景："
            "'贷款优化'、'提前还款'、'转贷降息'、'降低月供'、'节省利息'等场景。"
        )

    @property
    def parameters_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "loan_id": {
                    "type": "string",
                    "description": "用户选择的贷款ID（序号），如果用户已指定则传入，否则留空让用户选择",
                },
                "sentiment": {
                    "type": "string",
                    "description": "用户表达的情绪倾向，如'想省钱'、'月供压力大'、'想尽快还清'等，用于调整建议侧重",
                },
            },
        }

    async def execute(self, **kwargs) -> SkillResult:
        user_name = kwargs.get("user_name", "")
        loan_id = kwargs.get("loan_id", "")
        sentiment = kwargs.get("sentiment", "")
        api = create_client(user_name=user_name)

        # ------ 1. 查询用户持有的贷款 ------
        loans, _ = await api.list_loans(limit=100)

        if not loans:
            return SkillResult(
                success=True,
                data={
                    "has_loans": False,
                    "message": f"用户 {user_name} 当前没有持有贷款产品，无需优化。",
                    "action_buttons": [],
                },
                summary="用户暂无持有贷款，无需优化",
            )

        # ------ 2. 多笔贷款：列出供用户选择 ------
        if not loan_id and len(loans) > 1:
            return SkillResult(
                success=True,
                data={
                    "has_loans": True,
                    "need_selection": True,
                    "loan_count": len(loans),
                    "loan_options": [
                        {
                            "id": l["id"],
                            "loan_type": l["loan_type"],
                            "loan_no": l["loan_no"],
                            "purpose": l["purpose"],
                            "bank_branch": l["bank_branch"],
                            "remaining_principal": l["remaining_principal"],
                            "annual_rate": l["annual_rate"],
                            "repayment_method": l["repayment_method"],
                            "issue_date": l["issue_date"],
                        }
                        for l in loans
                    ],
                    "action_buttons": [],
                },
                summary=f"用户持有多笔贷款({len(loans)}笔)，需选择贷款后再进行优化分析",
            )

        # ------ 3. 确定目标贷款 ------
        target_loan = None
        if loan_id:
            target_loan = await api.get_loan_detail(loan_id)
            if target_loan is None:
                return SkillResult(
                    success=False,
                    error=f"贷款 {loan_id} 不存在",
                )

        if target_loan is None:
            target_loan = loans[0]

        # ------ 4. 收集用户资金与消费数据 ------
        # 账户余额
        all_accounts, _ = await api.list_accounts(limit=100)
        total_balance = 0.0
        for a in all_accounts:
            at = str(a.get("account_type", ""))
            if "借记" in at:
                try:
                    total_balance += float(a.get("balance", 0) or 0)
                except (TypeError, ValueError):
                    pass

        # 月均消费
        monthly_stats, _ = await api.get_consumption_stats(
            group_by="month", top=12
        )
        avg_monthly = (
            sum(s["total"] for s in monthly_stats) / max(len(monthly_stats), 1)
            if monthly_stats
            else 0
        )

        # 消费子类分布
        subcategory_stats, _ = await api.get_consumption_stats(
            group_by="subcategory", top=8
        )

        # 最近6个月消费趋势
        recent_6m = sorted(
            monthly_stats, key=lambda x: x["name"], reverse=True
        )[:6]
        recent_trend = [{"month": m["name"], "amount": m["total"]} for m in recent_6m]

        # ------ 5. 计算提前还款建议 ------
        prepay_analysis = self._analyze_prepay(target_loan, total_balance, avg_monthly)

        # ------ 6. 搜索可转贷的低息产品 ------
        refi_analysis = await self._analyze_refinance(target_loan, api)

        # ------ 7. 汇总操作按钮 ------
        action_buttons = [
            {
                "label": "提前还款",
                "type": "primary",
                "action": "navigate",
                "route": "/held-products/loans",
                "params": {"loan_id": target_loan["id"], "tab": "prepay"},
                "description": "前往贷款详情页办理提前还款",
            },
            {
                "label": "申请转贷",
                "type": "secondary",
                "action": "navigate",
                "route": "/held-products/loans",
                "params": {"loan_id": target_loan["id"], "tab": "refinance"},
                "description": "前往贷款详情页申请转贷降息",
            },
        ]

        return SkillResult(
            success=True,
            data={
                "has_loans": True,
                "need_selection": False,
                "loan": {
                    "id": target_loan["id"],
                    "loan_type": target_loan["loan_type"],
                    "loan_no": target_loan["loan_no"],
                    "purpose": target_loan["purpose"],
                    "bank_branch": target_loan["bank_branch"],
                    "principal": target_loan["principal"],
                    "remaining_principal": target_loan["remaining_principal"],
                    "repaid_principal": target_loan["repaid_principal"],
                    "annual_rate": target_loan["annual_rate"],
                    "rate_type": target_loan["rate_type"],
                    "lpr_adjust": target_loan["lpr_adjust"],
                    "next_repricing_date": target_loan["next_repricing_date"],
                    "repayment_method": target_loan["repayment_method"],
                    "issue_date": target_loan["issue_date"],
                    "repayment_progress_pct": round(
                        target_loan["repaid_principal"]
                        / max(target_loan["principal"], 1)
                        * 100,
                        1,
                    ),
                },
                "user_financial_snapshot": {
                    "total_balance": round(total_balance, 2),
                    "avg_monthly_expense": round(avg_monthly, 2),
                    "subcategory_stats": subcategory_stats,
                    "recent_6m_trend": recent_trend,
                },
                "prepay_plan": prepay_analysis,
                "refinance_plan": refi_analysis,
                "user_sentiment": sentiment,
                "action_buttons": action_buttons,
            },
            summary=(
                f"已分析贷款「{target_loan['loan_type']}」优化方案："
                f"剩余本金¥{target_loan['remaining_principal']:,.0f}，年利率{target_loan['annual_rate']}。"
                f"提前还款建议金额¥{prepay_analysis.get('recommended_prepay_amount', 0):,.0f}，"
                f"匹配{len(refi_analysis.get('matched_products', []))}款低息转贷产品。"
            ),
        )

    # ========== 提前还款分析 ==========
    def _analyze_prepay(self, loan: dict, total_balance: float, avg_monthly: float) -> dict:
        """分析提前还款方案"""
        remaining = loan["remaining_principal"]

        # 解析年利率
        annual_rate_str = loan.get("annual_rate", "0%")
        rate = 0.0
        try:
            rate = float(annual_rate_str.replace("%", "")) / 100
        except (ValueError, TypeError):
            rate = 0.0286

        # 预留 6 个月生活支出的安全垫
        safety_cushion = round(avg_monthly * 6, 2)
        available_for_prepay = max(0, total_balance - safety_cushion)

        # 推荐提前还款金额：可用资金与剩余本金的最小值
        recommended_prepay = min(available_for_prepay, remaining)

        # 估算节省利息（简化：剩余本金 * 年利率 = 年度利息，还款后节省对应比例）
        if remaining > 0:
            annual_interest = remaining * rate
            prepay_ratio = recommended_prepay / remaining
            annual_savings = round(annual_interest * prepay_ratio, 2)
            # 假设剩余10年
            total_savings = round(annual_savings * 10, 2)
        else:
            annual_interest = 0
            annual_savings = 0
            total_savings = 0

        # 还款方式分析
        repayment_method = loan.get("repayment_method", "")
        monthly_payment_estimate = 0
        if remaining > 0 and rate > 0:
            months = 120  # 默认剩余10年
            monthly_rate = rate / 12
            if "等额本息" in repayment_method:
                if monthly_rate > 0:
                    monthly_payment_estimate = (
                        remaining
                        * monthly_rate
                        * (1 + monthly_rate) ** months
                        / ((1 + monthly_rate) ** months - 1)
                    )
                else:
                    monthly_payment_estimate = remaining / months
            else:  # 等额本金
                monthly_principal = remaining / months
                monthly_payment_estimate = monthly_principal + remaining * monthly_rate

        # 还款后新月供估算
        new_remaining = remaining - recommended_prepay
        new_monthly_payment = 0
        if new_remaining > 0 and rate > 0:
            months = 120
            monthly_rate = rate / 12
            if "等额本息" in repayment_method:
                if monthly_rate > 0:
                    new_monthly_payment = (
                        new_remaining
                        * monthly_rate
                        * (1 + monthly_rate) ** months
                        / ((1 + monthly_rate) ** months - 1)
                    )
                else:
                    new_monthly_payment = new_remaining / months
            else:
                monthly_principal = new_remaining / months
                new_monthly_payment = monthly_principal + new_remaining * monthly_rate

        return {
            "remaining_principal": remaining,
            "annual_rate": annual_rate_str,
            "annual_interest_estimate": round(annual_interest, 2),
            "monthly_payment_estimate": round(monthly_payment_estimate, 2),
            "safety_cushion_6m": safety_cushion,
            "available_for_prepay": round(available_for_prepay, 2),
            "recommended_prepay_amount": round(recommended_prepay, 2),
            "annual_interest_saved": annual_savings,
            "total_interest_saved_10yr": total_savings,
            "new_remaining_after_prepay": round(new_remaining, 2),
            "new_monthly_payment": round(new_monthly_payment, 2),
            "monthly_payment_reduction": round(
                max(0, monthly_payment_estimate - new_monthly_payment), 2
            ),
            "prepay_ratio_pct": round(
                recommended_prepay / max(remaining, 1) * 100, 1
            ),
            "suggestion_summary": (
                f"您当前可用资金为 ¥{total_balance:,.2f}，预留6个月生活支出 "
                f"¥{safety_cushion:,.2f} 后，可用于提前还款的金额为 "
                f"¥{available_for_prepay:,.2f}。建议提前还款 "
                f"¥{recommended_prepay:,.2f}（占剩余本金 {recommended_prepay / max(remaining, 1) * 100:.0f}%），"
                f"可节省年利息约 ¥{annual_savings:,.2f}，月供从 "
                f"¥{monthly_payment_estimate:,.2f} 降至 ¥{new_monthly_payment:,.2f}。"
            )
            if available_for_prepay > 0
            else (
                f"您当前可用资金为 ¥{total_balance:,.2f}，预留6个月生活支出 "
                f"¥{safety_cushion:,.2f} 后，暂无富余资金可用于提前还款。"
                f"建议先通过消费优化积累资金，再考虑提前还款。"
            ),
        }

    # ========== 转贷降息分析 ==========
    async def _analyze_refinance(self, loan: dict, api) -> dict:
        """分析转贷降息方案"""
        current_rate_str = loan.get("annual_rate", "0%")
        current_rate = 0.0
        try:
            current_rate = float(current_rate_str.replace("%", "")) / 100
        except (ValueError, TypeError):
            current_rate = 0.0286

        remaining = loan["remaining_principal"]

        # 搜索银行自有低息贷款产品
        all_loan_products, _ = await api.list_products(category="loan", limit=50)

        matched = []
        for p in all_loan_products:
            p_rate_str = str(p.get("年化利率/参考利率", p.get("利率范围", "0%")))
            # 解析产品利率（可能有范围 3.0%-4.5%）
            p_rate = self._parse_rate(p_rate_str)
            # 只保留利率更低的产品
            if p_rate > 0 and p_rate < current_rate:
                savings_per_year = round(remaining * (current_rate - p_rate), 2)
                matched.append({
                    "name": p.get("name", ""),
                    "category": p.get("type_label", p.get("category", "")),
                    "current_rate": current_rate_str,
                    "new_rate": p_rate_str,
                    "new_rate_value": round(p_rate * 100, 2),
                    "rate_reduction": f"{round((current_rate - p_rate) * 100, 2)}%",
                    "annual_interest_saved": savings_per_year,
                    "total_saved_10yr": round(savings_per_year * 10, 2),
                    "min_amount": _safe_float(p.get("起存/起购金额(元)", p.get("起存金额", 0))),
                    "max_amount": _safe_float(p.get("贷款金额上限(元)", p.get("最高额度", 0))),
                    "term": str(p.get("产品期限/贷款期限", p.get("存期/期限", ""))),
                    "risk_level": str(p.get("risk_level", "")),
                    "features": str(p.get("产品特点", p.get("产品特点/适用人群", ""))),
                    "apply_condition": str(p.get("申请条件", p.get("准入条件", ""))),
                })

        # 按年节省利息降序排列
        matched.sort(key=lambda x: x["annual_interest_saved"], reverse=True)

        # 当前利息估算
        current_annual_interest = round(remaining * current_rate, 2)
        repayment_method = loan.get("repayment_method", "")

        return {
            "current_loan_rate": current_rate_str,
            "current_annual_interest": current_annual_interest,
            "repayment_method": repayment_method,
            "matched_products_count": len(matched),
            "matched_products": matched[:5],  # 最多展示5款
            "suggestion_summary": (
                f"当前贷款年利率为 {current_rate_str}，年利息约 ¥{current_annual_interest:,.2f}。"
                f"我们为您匹配了 {len(matched)} 款利率更低的转贷产品，"
                f"最优可节省年利息 ¥{matched[0]['annual_interest_saved']:,.2f}。"
            )
            if matched
            else (
                f"当前贷款年利率为 {current_rate_str}，年利息约 ¥{current_annual_interest:,.2f}。"
                f"暂未找到利率更低的转贷产品，建议关注 LPR 重定价日 "
                f"({loan.get('next_repricing_date', '无')}) 后的利率变化。"
                f"或优先考虑提前还款方案。"
            ),
        }

    def _parse_rate(self, rate_str: str) -> float:
        """解析利率字符串，支持 '3.5%'、'3.5%-4.5%' 等格式，返回最低值"""
        try:
            clean = rate_str.replace("%", "").strip()
            if "-" in clean:
                parts = clean.split("-")
                return float(parts[0].strip()) / 100
            return float(clean) / 100
        except (ValueError, TypeError):
            return 0


def _safe_float(v) -> float:
    try:
        return float(v) if v is not None else 0.0
    except (TypeError, ValueError):
        return 0.0
