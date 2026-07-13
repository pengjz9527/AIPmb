"""贷款产品推荐 Skill — 根据用户资金与消费情况推荐合适贷款，已持有贷款则引导至成本优化"""
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client


# ---------- 消费场景与贷款用途的映射 ----------
# 每个消费子类别对应最适合的贷款类型关键词
CONSUMPTION_LOAN_MAP = [
    (["餐饮美食", "超市便利店", "网购", "日用百货"], "消费贷"),
    (["网约车", "加油", "汽车", "铁路 出行", "航空 出行"], "汽车消费贷款"),
    (["房租", "物业", "装修", "家居", "房产"], "住房贷款"),
    (["通讯软件数码", "家用电器", "电子设备"], "消费贷"),
    (["生活缴费"], "消费贷"),
    (["医疗健康"], "消费贷"),
    (["旅游", "酒店", "休闲娱乐"], "消费贷"),
    (["教育", "培训"], "消费贷"),
]

# 贷款产品类别与消费场景的映射
LOAN_PURPOSE_MATCH = {
    "住房贷款": ["一手住房贷款", "二手住房贷款", "个人住房按揭贷款"],
    "消费贷款": ["闪电贷", "个人综合消费贷款", "个人循环授信", "消费贷"],
    "汽车贷款": ["个人汽车消费贷款"],
    "经营贷款": ["小微贷", "生意贷", "商业用房贷款"],
}


class LoanProductRecommendationSkill(BaseSkill):
    """贷款产品推荐：
    1. 检查用户是否持有贷款
    2. 若已持贷款 → 建议使用 loan_cost_optimizer 进行成本优化
    3. 若未持贷款 → 基于余额、消费水平和消费场景推荐合适的贷款产品
    """

    @property
    def name(self) -> str:
        return "loan_product_recommendation"

    @property
    def description(self) -> str:
        return (
            "为我推荐合适的贷款产品。如果我尚未持有贷款，结合我的资金余额、"
            "消费习惯和消费场景，从银行现有的贷款产品中匹配最合适的产品推荐给我，"
            "每个推荐产品附带产品详情链接。如果我已经持有贷款，则建议我使用"
            "贷款成本优化方案（loan_cost_optimizer）来降低利息支出。"
            "适用场景：'推荐贷款'、'我要贷款'、'有什么贷款产品'、'贷款推荐'等。"
        )

    @property
    def parameters_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "loan_purpose": {
                    "type": "string",
                    "description": "用户期望的贷款用途，如'买车'、'装修'、'消费'等，留空则自动分析",
                },
                "preferred_bank": {
                    "type": "string",
                    "description": "用户偏好的银行，如'招商银行'，留空则不限制",
                },
            },
        }

    async def execute(self, **kwargs) -> SkillResult:
        user_name = kwargs.get("user_name", "")
        loan_purpose = kwargs.get("loan_purpose", "")
        preferred_bank = kwargs.get("preferred_bank", "")
        api = create_client(user_name=user_name)

        # ------ 1. 检查用户是否持有贷款 ------
        loans, _ = await api.list_loans(limit=100)

        if loans:
            # 用户已有贷款 → 引导至成本优化
            loan_list = [
                {
                    "id": l["id"],
                    "loan_type": l["loan_type"],
                    "remaining_principal": l["remaining_principal"],
                    "annual_rate": l["annual_rate"],
                }
                for l in loans
            ]
            return SkillResult(
                success=True,
                data={
                    "has_loans": True,
                    "loan_count": len(loans),
                    "loans": loan_list,
                    "action_suggestion": {
                        "message": (
                            f"您当前持有 {len(loans)} 笔贷款，不需要新的贷款推荐。"
                            f"建议使用「贷款成本优化方案」分析如何降低贷款成本，"
                            f"包括提前还款和转贷降息两种路径。"
                        ),
                        "skill_name": "loan_cost_optimizer",
                        "skill_label": "贷款成本优化",
                    },
                    "action_buttons": [
                        {
                            "label": "去优化贷款成本",
                            "type": "primary",
                            "action": "navigate",
                            "route": "/held-products",
                            "description": "查看持有贷款详情并优化成本",
                        },
                    ],
                },
                summary=f"用户持有 {len(loans)} 笔贷款，建议使用贷款成本优化方案",
            )

        # ------ 2. 收集用户财务数据 ------
        # 账户余额
        all_accounts, _ = await api.list_accounts(limit=100)
        total_balance = 0.0
        credit_card_count = 0
        for acc in all_accounts:
            at = str(acc.get("account_type", ""))
            if "借记" in at:
                try:
                    total_balance += float(acc.get("balance", 0) or 0)
                except (TypeError, ValueError):
                    pass
            elif "信用" in at:
                credit_card_count += 1

        # 消费分析：子类分布
        subcategory_stats, _ = await api.get_consumption_stats(
            group_by="subcategory", top=10
        )

        # 月均消费
        monthly_stats, _ = await api.get_consumption_stats(
            group_by="month", top=6
        )
        avg_monthly = (
            sum(s["total"] for s in monthly_stats) / max(len(monthly_stats), 1)
            if monthly_stats else 0
        )

        # 最近几月趋势
        sorted_months = sorted(monthly_stats, key=lambda x: str(x["name"]), reverse=True)
        monthly_trend = [
            {"month": str(m["name"]), "amount": m["total"]} for m in sorted_months
        ]

        # ------ 3. 推断用户贷款需求 ------
        needed_categories = self._infer_loan_needs(
            subcategory_stats, loan_purpose, avg_monthly, total_balance
        )

        # ------ 4. 获取可用贷款产品并评分 ------
        all_loan_products, _ = await api.list_products(category="loan", limit=50)

        scored_products = self._score_products(
            all_loan_products, needed_categories, preferred_bank,
            avg_monthly, total_balance, subcategory_stats,
        )

        # ------ 5. 生成推荐 ------
        recommendations = scored_products[:5]  # 最多推荐5款

        return SkillResult(
            success=True,
            data={
                "has_loans": False,
                "user_financial_snapshot": {
                    "total_balance": round(total_balance, 2),
                    "avg_monthly_expense": round(avg_monthly, 2),
                    "credit_card_count": credit_card_count,
                    "monthly_trend": monthly_trend,
                },
                "inferred_needs": [
                    {"category": c, "reason": r} for c, r in needed_categories
                ],
                "recommendations": [
                    {
                        "product_name": p["product_name"],
                        "bank": p["bank"],
                        "category": p["category"],
                        "description": p["description"],
                        "purpose": p["purpose"],
                        "max_amount": p["max_amount"],
                        "term": p["term"],
                        "interest_rate": p["interest_rate"],
                        "repayment_method": p["repayment_method"],
                        "guarantee_method": p["guarantee_method"],
                        "apply_condition": p["apply_condition"],
                        "apply_channel": p["apply_channel"],
                        "reason": p["reason"],
                        "suitability_score": p["score"],
                        "detail_link": f"/recommendations?product={p['product_name']}",
                    }
                    for p in recommendations
                ],
                "action_buttons": [
                    {
                        "label": f"查看{p['product_name']}详情",
                        "type": "primary" if i == 0 else "secondary",
                        "action": "navigate",
                        "route": f"/recommendations?product={p['product_name']}",
                        "description": f"查看{p['bank']}{p['product_name']}产品详情",
                    }
                    for i, p in enumerate(recommendations[:3])
                ],
            },
            summary=(
                f"用户无贷款，月均消费 ¥{avg_monthly:,.0f}，可用余额 ¥{total_balance:,.0f}。"
                f"匹配 {len(recommendations)} 款贷款产品推荐。"
            ),
        )

    # ========== 消费场景 -> 贷款需求推断 ==========
    def _infer_loan_needs(
        self,
        subcategory_stats: list[dict],
        explicit_purpose: str,
        avg_monthly: float,
        total_balance: float,
    ) -> list[tuple[str, str]]:
        """根据消费分布推断用户贷款需求类别"""
        needs = []

        # 用户明确指定用途
        if explicit_purpose:
            for kw, category in [
                ("车", "汽车贷款"), ("房", "住房贷款"), ("装修", "住房贷款"),
                ("消费", "消费贷款"), ("生意", "经营贷款"), ("经营", "经营贷款"),
                ("周转", "消费贷款"), ("旅行", "消费贷款"), ("教育", "消费贷款"),
            ]:
                if kw in explicit_purpose:
                    needs.append((category, f"您表示有{explicit_purpose}需求"))
                    break
            if not needs:
                needs.append(("消费贷款", f"您表示有{explicit_purpose}需求"))
            return needs

        # 自动分析：消费子类匹配
        matched_categories = set()
        for stat in subcategory_stats[:8]:
            sub_name = str(stat.get("name", ""))
            for keywords, category in CONSUMPTION_LOAN_MAP:
                if any(kw in sub_name for kw in keywords):
                    if category not in matched_categories:
                        matched_categories.add(category)
                        total = stat["total"]
                        needs.append((
                            category,
                            f"您在'{sub_name}'消费 ¥{total:,.0f}，可匹配{category}产品",
                        ))

        # 余额偏低 → 补充消费贷
        if total_balance < avg_monthly * 3 and "消费贷" not in matched_categories:
            needs.append((
                "消费贷款",
                f"账户余额 ¥{total_balance:,.0f} 较低（<3倍月支出），建议消费贷补充流动性",
            ))

        # 兜底：至少推荐消费贷
        if not needs:
            needs.append(("消费贷款", "基于您的综合消费情况推荐"))

        return needs

    # ========== 产品评分 ==========
    def _score_products(
        self,
        products: list[dict],
        needed_categories: list[tuple[str, str]],
        preferred_bank: str,
        avg_monthly: float,
        total_balance: float,
        subcategory_stats: list[dict],
    ) -> list[dict]:
        """对贷款产品打分排序"""
        scored = []

        for p in products:
            p_name = str(p.get("name", ""))
            p_category = str(p.get("type_label", p.get("category", "")))
            p_bank = str(p.get("bank", ""))
            p_rate_str = str(p.get("贷款利率参考", ""))

            if not p_name:
                continue

            # 银行过滤
            if preferred_bank and preferred_bank not in p_bank:
                continue

            score = 0.0
            matched_reason = ""

            # 与推断需求的类别匹配度
            for need_cat, reason in needed_categories:
                match_keywords = LOAN_PURPOSE_MATCH.get(need_cat, [need_cat])
                for kw in match_keywords:
                    if kw in p_name or kw in p_category:
                        score += 5 if need_cat == needed_categories[0][0] else 3
                        matched_reason = reason
                        break

            # 未匹配任何需求类别的产品跳过
            if score == 0:
                continue

            # 银行加分：招商银行优先
            if "招商" in p_bank:
                score += 1.5
            elif "汉口" in p_bank:
                score += 1.0

            # 利率加分：利率越低越好
            p_rate = self._parse_rate(p_rate_str)
            if p_rate > 0:
                # 基准 4%，每低 0.25% +0.5 分
                score += max(0, (0.04 - p_rate) / 0.0025 * 0.5)

            # 可用额度与消费能力匹配
            max_amount_str = str(p.get("最高贷款金额", "0"))
            max_amount = self._parse_amount(max_amount_str)
            if max_amount > 0:
                expected_loan = avg_monthly * 12  # 假定需要1年消费额贷款
                if max_amount >= expected_loan:
                    score += 1
                elif max_amount >= expected_loan * 0.5:
                    score += 0.5

            scored.append({
                "product_name": p_name,
                "bank": p_bank,
                "category": p_category,
                "description": str(p.get("description", "")),
                "purpose": str(p.get("贷款用途", "")),
                "max_amount": max_amount_str,
                "term": str(p.get("贷款期限", "")),
                "interest_rate": p_rate_str,
                "repayment_method": str(p.get("还款方式", "")),
                "guarantee_method": str(p.get("担保方式", "")),
                "apply_condition": str(p.get("申请条件", "")),
                "apply_channel": str(p.get("申请渠道", "")),
                "reason": matched_reason,
                "score": round(score, 1),
            })

        # 按评分降序
        scored.sort(key=lambda x: x["score"], reverse=True)
        return scored

    @staticmethod
    def _parse_rate(rate_str: str) -> float:
        """解析利率字符串，支持 '3.5%'、'LPR+0.5%' 等"""
        import re
        clean = rate_str.strip().replace(" ", "")
        # 提取第一个百分比数字
        match = re.search(r"(\d+\.?\d*)\s*%", clean)
        if match:
            return float(match.group(1)) / 100
        return 0.0

    @staticmethod
    def _parse_amount(amount_str: str) -> float:
        """解析金额字符串，支持 '100万'、'500000' 等"""
        import re
        clean = str(amount_str).strip().replace(",", "").replace("，", "")
        if "万" in clean:
            match = re.search(r"(\d+\.?\d*)", clean)
            if match:
                return float(match.group(1)) * 10000
        match = re.search(r"(\d+\.?\d*)", clean)
        if match:
            return float(match.group(1))
        return 0.0
