"""收支分析专家智能体 — 整合收支分析、消费续航测算、生活推荐能力"""
import asyncio
from pmb.agents.base import BaseAgent, AgentContext


# 规则引擎：检测条件 → 建议
RULES = [
    {
        "id": "travel_freq",
        "category": "差旅",
        "condition_desc": "交通+住宿+机票>=3笔/月",
        "sugg_id": "sugg_travel_reimburse",
        "label": "整理差旅报销清单",
        "prompt_template": "帮我整理最近{months}个月的差旅消费，生成报销清单",
        "priority": "high",
    },
    {
        "id": "repeat_merchant",
        "category": "重复消费",
        "condition_desc": "同一商户>=5笔/月",
        "sugg_id": "sugg_merchant_audit",
        "label": "审查重复消费",
        "prompt_template": "帮我分析在「{merchant}」的重复消费情况",
        "priority": "medium",
    },
    {
        "id": "food_ratio",
        "category": "餐饮",
        "condition_desc": "餐饮占比>30%",
        "sugg_id": "sugg_food_budget",
        "label": "设置餐饮预算",
        "prompt_template": "帮我分析餐饮支出结构，制定合理的餐饮预算",
        "priority": "medium",
    },
    {
        "id": "expense_growth",
        "category": "支出增长",
        "condition_desc": "环比增长>20%",
        "sugg_id": "sugg_expense_review",
        "label": "排查异常支出",
        "prompt_template": "帮我排查本月异常支出，看看哪些消费比平时多",
        "priority": "high",
    },
    {
        "id": "subscription",
        "category": "订阅",
        "condition_desc": "周期扣款>=2个来源",
        "sugg_id": "sugg_subscription_review",
        "label": "审查订阅服务",
        "prompt_template": "帮我检查有哪些自动扣款的订阅服务",
        "priority": "medium",
    },
    {
        "id": "credit_ratio",
        "category": "信用卡",
        "condition_desc": "信用卡还款>月收入50%",
        "sugg_id": "sugg_credit_optimize",
        "label": "优化信用卡还款",
        "prompt_template": "帮我分析信用卡还款压力，看看有没有优化方案",
        "priority": "high",
    },
    {
        "id": "income_volatile",
        "category": "收入波动",
        "condition_desc": "收入CV>0.3",
        "sugg_id": "sugg_income_stability",
        "label": "关注收入稳定性",
        "prompt_template": "帮我评估收入稳定性，看看如何应对收入波动",
        "priority": "low",
    },
]

# 退出关键词
EXIT_KEYWORDS = ["返回", "换个话题", "退出", "回小易", "切换助手"]


class IncomeExpenseAnalystAgent(BaseAgent):

    managed_skills = [
        "consumption_analysis", "income_forecast",
        "expense_pattern_detector", "calculate_survival",
        "life_recommendation", "reimbursement_organizer",
        "hidden_habits_explorer", "payment_reminder", "history_today",
    ]

    def __init__(self):
        super().__init__()
        self._root_suggestions: list[dict] = []  # 缓存首轮建议，供后续轮次回归

    @property
    def agent_id(self) -> str:
        return "income_expense_analyst"

    @property
    def name(self) -> str:
        return "收支分析专家"

    @property
    def description(self) -> str:
        return "专业分析收支状况，测算消费续航能力，发现消费模式，推荐匹配产品和优惠"

    @property
    def avatar(self) -> str:
        return "income_expense"

    @property
    def system_prompt(self) -> str:
        return """你是招商银行AI收支分析专家，专注帮用户管理财务健康。

核心能力：
1. 收支总览：分析月度/年度收入与支出趋势，识别异常波动
2. 消费结构分析：按分类（餐饮/交通/购物/住房等）拆解支出构成
3. 收入来源分析：工资、投资收益、其他收入的结构和稳定性
4. 消费续航测算：计算"如果没了收入还能撑多久"，区分维持现状和最低生存两个档次，给出逐项降级建议
5. 生活推荐：基于消费习惯画像，推荐匹配的银行产品和优惠活动，每条推荐附带数据支撑的原因
6. 省钱建议：基于消费模式给出可执行的优化建议

可用工具（通过 function calling 调用）：
- income_forecast：收入趋势预测、收支平衡分析、消费规划
- consumption_analysis：消费分析和续航测算
- expense_pattern_detector：检测消费模式（周期性扣款、异常支出、重复消费等）
- calculate_survival：计算无收入情况下的资金续航月数
- life_recommendation：基于消费画像推荐匹配的产品和优惠
- reimbursement_organizer：整理差旅报销清单
- hidden_habits_explorer：从交易中发现有趣生活习惯
- payment_reminder：预测近期待缴费任务
- history_today：检索往年同日交易记忆
- collect_account_data：查询账户信息
- collect_consumption_data：查询消费统计
- collect_transaction_data：查询交易明细

输出规则 — 严格按轮次分层：

【首轮】用户首次询问时：
- 只输出简洁的统计概览（收入/支出/结余 + 主要分类），用简短的表格即可
- 不要展开详细解读、不要给长篇分析、不要主动深入某个维度
- 末尾不要自己输出建议列表，系统会自动在气泡下方附带可点击的建议条目

【后续轮次】用户选择了某条建议后：
- 分析范围严格限定在用户选择的具体主题内
- 不要扩展到其他维度（如用户选了"收入稳定性"，就不要分析消费结构）
- 不要自己补充无关内容或额外建议

与用户互动规则：
- 如果用户说"返回小易"/"换个话题"或问与收支完全无关的问题，礼貌引导回通用助手

分析风格：
- 中文回复，金额格式化为 ¥x,xxx.xx
- 用 Markdown 格式，使用标题、列表、表格使内容清晰
- 续航分析时给出"现状诊断"、"续航测算"、"降级方案"、"极限续航"四个板块
- 生活推荐时每条推荐附带数据支撑的推荐原因
- 友好但专业"""

    def can_handle(self, user_message: str) -> float:
        """意图匹配度评分"""
        strong_keywords = ["收支", "收入分析", "支出分析", "收支分析", "省钱",
                           "撑多久", "收入中断", "失业", "还能撑", "消费分析"]
        medium_keywords = ["消费", "花费", "开销", "钱花在哪", "花了多少",
                           "降消费", "节省", "预算", "断粮", "生活费", "节约"]
        weak_keywords = ["收入", "工资", "账单", "省钱计划", "消费真相", "财务危机",
                         "推荐", "优惠", "适合我", "有什么活动", "办卡", "生活", "便利",
                         "好物", "福利", "活动", "权益"]

        msg = user_message.lower()
        score = 0.0
        for kw in strong_keywords:
            if kw in msg:
                score += 0.35
        for kw in medium_keywords:
            if kw in msg:
                score += 0.20
        for kw in weak_keywords:
            if kw in msg:
                score += 0.10
        return min(score, 1.0)

    async def analyze_stream(
        self, context: AgentContext, event_queue: asyncio.Queue
    ) -> None:
        """流式分析与响应（五阶段）"""
        try:
            await self._analyze_stream_impl(context, event_queue)
        except Exception as e:
            await event_queue.put({
                "type": "error",
                "content": f"收支分析出错: {str(e)}",
                "is_final": True,
            })

    async def _analyze_stream_impl(
        self, context: AgentContext, event_queue: asyncio.Queue
    ) -> None:
        from pmb.llm.context_manager import context_manager
        from pmb.llm.tool_registry import ALL_TOOLS
        from pmb.skills.orchestrator import skill_orchestrator

        conv = context_manager.get_or_create(context.session_id)

        # 退出检查（非首轮）
        round_count = len([m for m in context.conversation_history
                          if m.get("role") == "assistant" and
                          m.get("agent_id") == self.agent_id])

        if round_count > 0:
            if any(kw in context.user_message for kw in EXIT_KEYWORDS):
                await event_queue.put({
                    "type": "agent_changed",
                    "agent_id": "general_assistant",
                    "agent_name": "小易",
                })
                from pmb.agents.registry import agent_registry
                ga = agent_registry.get_agent("general_assistant")
                if ga:
                    await ga.analyze_stream(context, event_queue)
                return

            score = self.can_handle(context.user_message)
            if score < 0.15:
                await event_queue.put({
                    "type": "agent_changed",
                    "agent_id": "general_assistant",
                    "agent_name": "小易",
                })
                from pmb.agents.registry import agent_registry
                ga = agent_registry.get_agent("general_assistant")
                if ga:
                    await ga.analyze_stream(context, event_queue)
                return

        enhanced_prompt = self.system_prompt
        if context.memory_summary:
            enhanced_prompt += "\n" + context.memory_summary
        conv.set_system_prompt(enhanced_prompt)

        messages = conv.get_messages()
        messages.append({"role": "user", "content": context.user_message})

        all_tools = list(ALL_TOOLS) + [
            t for t in skill_orchestrator.to_openai_tools()
            if t["function"]["name"] in {
                "income_forecast", "consumption_analysis",
                "expense_pattern_detector", "reimbursement_organizer",
                "calculate_survival", "life_recommendation",
                "hidden_habits_explorer", "payment_reminder", "history_today",
                "collect_account_data", "collect_consumption_data",
                "collect_transaction_data",
            }
        ]

        content_buffer, collected_skill_data = await self._run_llm_loop(
            context, event_queue, messages, all_tools,
            skill_orchestrator, step_id_prefix="ie",
        )

        # === 阶段5: 建议生成 ===
        await event_queue.put({
            "type": "thinking_step",
            "step_id": "phase_suggest_ie",
            "skill_name": "_suggestion_engine",
            "display_name": "建议生成",
            "status": "invoking",
            "message": "基于消费模式生成下一步建议...",
            "phase": "analyze",
            "phase_order": 5,
        })

        suggestions = self._generate_suggestions(
            collected_skill_data, content_buffer,
            is_first_round=(round_count == 0),
        )

        await event_queue.put({
            "type": "thinking_step",
            "step_id": "phase_suggest_ie",
            "skill_name": "_suggestion_engine",
            "display_name": "建议生成",
            "status": "completed",
            "message": f"生成了{len(suggestions)}条下一步建议",
            "phase": "analyze",
            "phase_order": 5,
        })

        conv.add_message("user", context.user_message)
        conv.add_message("assistant", content_buffer)
        await self._emit_ai_done(event_queue, content_buffer, suggestions)

    # ===== 建议生成辅助方法 =====

    def _generate_suggestions(self, skill_data: dict, analysis_content: str, is_first_round: bool = False) -> list[dict]:
        """基于规则引擎生成建议，首轮缓存为 root，后续分组返回。"""
        suggestions = []

        # 从 expense_pattern_detector 结果中提取模式
        patterns = skill_data.get("expense_pattern_detector", {})
        subscriptions = patterns.get("subscriptions", []) if isinstance(patterns, dict) else []
        repeat_merchants = patterns.get("repeat_merchants", []) if isinstance(patterns, dict) else []
        anomalies = patterns.get("anomalies", []) if isinstance(patterns, dict) else []

        # 规则: 差旅消费频次
        travel_count = 0
        for cat_data in skill_data.values():
            if isinstance(cat_data, dict):
                cat_info = cat_data.get("categories", {})
                if isinstance(cat_info, dict):
                    for cat_name, cat_items in cat_info.items():
                        if cat_name in ("交通", "住宿"):
                            travel_count += cat_items.get("count", 0) if isinstance(cat_items, dict) else 0
        if travel_count >= 3:
            suggestions.append(self._build_suggestion("travel_freq", "root", months=3))

        # 规则: 重复商户消费
        if repeat_merchants:
            top_merchant = repeat_merchants[0] if repeat_merchants else {}
            suggestions.append(self._build_suggestion(
                "repeat_merchant", "root",
                merchant=top_merchant.get("counterparty", "该商户"),
            ))

        # 规则: 餐饮占比 (从 consumption_analysis 数据中提取)
        cons_data = skill_data.get("consumption_analysis", {})
        if isinstance(cons_data, dict):
            category_stats = cons_data.get("category_stats", [])
            total = sum(s.get("total", 0) for s in category_stats)
            food_total = sum(
                s.get("total", 0) for s in category_stats
                if "餐饮" in str(s.get("name", "") or s.get("category", ""))
            )
            if total > 0 and food_total / total > 0.3:
                suggestions.append(self._build_suggestion("food_ratio", "root"))

        # 规则: 月度支出环比增长
        monthly_stats = cons_data.get("monthly_stats", []) if isinstance(cons_data, dict) else []
        if len(monthly_stats) >= 2:
            current = monthly_stats[0].get("total", 0) if monthly_stats else 0
            previous = monthly_stats[1].get("total", 0) if len(monthly_stats) > 1 else 0
            if previous > 0 and (current - previous) / previous > 0.2:
                suggestions.append(self._build_suggestion("expense_growth", "root"))

        # 规则: 周期性扣款（订阅服务）
        if subscriptions:
            suggestions.append(self._build_suggestion("subscription", "root"))

        # 规则: 异常大额支出
        if anomalies:
            if not any(s["id"] == "sugg_expense_review" for s in suggestions):
                suggestions.append(self._build_suggestion("expense_growth", "root"))

        # 兜底：无规则命中时提供默认建议（确保首轮至少有几条可选）
        if not suggestions:
            suggestions = [
                {
                    "id": "sugg_default_overview",
                    "label": "收支总览",
                    "prompt": "帮我生成完整的收支分析报告",
                    "priority": "high",
                    "reason": "全面了解收支状况",
                    "group": "root",
                },
                {
                    "id": "sugg_default_structure",
                    "label": "消费结构",
                    "prompt": "帮我分析消费结构，看看钱都花在哪了",
                    "priority": "medium",
                    "reason": "了解消费构成",
                    "group": "root",
                },
                {
                    "id": "sugg_default_income",
                    "label": "收入稳定性",
                    "prompt": "帮我分析收入是否稳定，有没有风险",
                    "priority": "medium",
                    "reason": "评估收入健康度",
                    "group": "root",
                },
            ]

        # 最多返回 3 条，按优先级排序
        priority_order = {"high": 0, "medium": 1, "low": 2}
        suggestions.sort(key=lambda s: priority_order.get(s.get("priority", "low"), 99))
        root_suggestions = suggestions[:3]

        # 首轮：全部标记为 root 并缓存
        if is_first_round or not self._root_suggestions:
            self._root_suggestions = [dict(s) for s in root_suggestions]
            return root_suggestions

        # 后续轮次：合并 continue + root 两组
        # continue: 从规则引擎产生的额外建议（与当前话题延续），保留 1-2 条不同于 root 的
        continue_suggestions = []
        for s in root_suggestions:
            # 首轮已有这些 root，后续轮次中如果规则又匹配到同样的建议，标记为 continue
            s_copy = dict(s)
            s_copy["group"] = "continue"
            continue_suggestions.append(s_copy)

        # 去重：continue 中排除已存在于 root 的相同 id
        root_ids = {s["id"] for s in self._root_suggestions}
        continue_suggestions = [
            s for s in continue_suggestions
            if s["id"] not in root_ids
        ][:2]

        # 如果 continue 不足，生成 1-2 条基于当前主题的延续建议
        if len(continue_suggestions) < 1:
            continue_suggestions.append(self._build_continue_suggestion(analysis_content))
        continue_suggestions = continue_suggestions[:2]

        # root: 缓存的首轮建议，标记 group="root"
        root_with_group = [dict(s, group="root") for s in self._root_suggestions]

        return continue_suggestions + root_with_group

    def _build_suggestion(self, rule_id: str, group: str = "root", **kwargs) -> dict:
        """根据规则ID构建建议"""
        for rule in RULES:
            if rule["id"] == rule_id:
                prompt = rule["prompt_template"].format(**kwargs, months=3)
                return {
                    "id": rule["sugg_id"],
                    "label": rule["label"],
                    "prompt": prompt,
                    "priority": rule["priority"],
                    "reason": rule["condition_desc"],
                    "group": group,
                }
        return {}

    def _build_continue_suggestion(self, analysis_content: str) -> dict:
        """根据当前分析内容生成延续性建议"""
        if "收入" in analysis_content and "稳定" in analysis_content:
            return {
                "id": "sugg_income_detail",
                "label": "细化收入结构",
                "prompt": "帮我详细拆解收入来源的各项构成",
                "priority": "medium",
                "reason": "深入分析收入",
                "group": "continue",
            }
        if "消费" in analysis_content or "支出" in analysis_content:
            return {
                "id": "sugg_expense_detail",
                "label": "细化消费明细",
                "prompt": "帮我查看消费明细和每个分类的变化趋势",
                "priority": "medium",
                "reason": "深入分析消费",
                "group": "continue",
            }
        return {
            "id": "sugg_deeper_analysis",
            "label": "深入分析",
            "prompt": "帮我针对刚才的分析结果深入展开",
            "priority": "medium",
            "reason": "基于当前话题深入",
            "group": "continue",
        }

    def _build_suggestions_prompt(self, suggestions: list[dict], analysis_content: str) -> str:
        """构建 LLM 润色建议的 prompt"""
        lines = []
        for s in suggestions:
            lines.append(f"[{s['id']}] 优先级:{s['priority']} 原因:{s['reason']}")
        pattern_text = "\n".join(lines)

        return f"""基于以下收支分析结果，为用户生成 2-3 条"下一步行动建议"。

分析摘要：
{analysis_content[:300]}...

检测到的模式：
{pattern_text}

请生成建议，每行一条，格式为：
[suggestion_id]|优先级(high/medium/low)|建议标签(≤8字)|完整提问语句|

建议要自然友好，有吸引力。只输出建议行，不要其他内容。"""

    def _parse_suggestions(self, text: str) -> list[dict]:
        """解析 LLM 返回的建议文本"""
        suggestions = []
        for line in text.strip().split("\n"):
            line = line.strip()
            if "|" not in line or line.startswith("#"):
                continue
            parts = line.split("|")
            if len(parts) >= 4:
                suggestions.append({
                    "id": parts[0].strip(),
                    "priority": parts[1].strip(),
                    "label": parts[2].strip(),
                    "prompt": parts[3].strip(),
                    "reason": "",
                })
        return suggestions[:3]
