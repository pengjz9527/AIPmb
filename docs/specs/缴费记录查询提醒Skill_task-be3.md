# 收支分析智能体（IncomeExpenseAnalystAgent）实现方案

## 上下文

当前 AIPmb 系统只有一个注册的 Agent（`GeneralAssistantAgent`/小易），所有用户请求都通过 WebSocket 硬编码路由给它。用户需要新增一个**收支分析智能体**，提供多轮对话能力，每轮分析后能主动预测并提示下一轮对话建议。

本方案基于用户确认的 6 个关键决策点设计：
- **关键点1**：方案A — 独立 Agent（注册到 AgentRegistry，通过关键词路由）
- **关键点2**：方案A — 规则引擎 + LLM 增强（非纯 LLM 驱动）
- **关键点3**：退出策略 — 意图匹配度 < 0.3 且用户消息不涉及收支 → 回退到 GeneralAssistant
- **关键点4**：新增 2 个 Skill（`expense_pattern_detector`、`reimbursement_organizer`），不在 Agent 内部实现
- **关键点5**：前端新增"建议" UI 组件（SuggestionChips）
- **关键点6**：Agent 共存策略 — can_handle() 评分路由 + 低于阈值回退 + 显式 @切换
- **关键点7**：前端入口整合 — 将 `consumption_analysis`/`income_forecast` 的独立 Skill 入口从前端移除，能力融入收支分析 Agent；新增 Agent 快捷入口

### 预期效果

- 用户发送"分析我的收支" → 自动路由到收支分析师，AppBar 显示 Agent 名称
- Agent 基于消费数据检测模式（周期扣款/异常支出/重复消费等），生成分析报告
- 分析报告下方展示 2-3 条"下一步建议" chip，用户点击自动发送对应问题
- 用户持续追问收支相关问题 → 保持在同一 Agent 多轮对话
- 用户切换话题（如"推荐理财产品"）→ 自动回退到小易
- 前端"此刻"页面和对话页面的快捷入口不再显示独立的"消费分析"、"收入预测" Skill，替换为"收支分析" Agent 统一入口

---

## Task 1：新增 Pattern Detector Skill

**文件**: `pmb/skills/domain/expense_pattern_detector.py`（新建）

参考 `income_forecast.py` 的 Skill 模式：

```python
class ExpensePatternDetectorSkill(BaseSkill):
    name = "expense_pattern_detector"
    description = "检测消费数据模式：周期性扣款（订阅服务）、异常大额支出、同一商户重复消费、消费频次变化"
    parameters_schema = {"type": "object", "properties": {"months": {"type": "integer", "description": "分析月份数，默认6"}}}

    async def execute(self, **kwargs) -> SkillResult:
        # 1. 获取交易明细
        # 2. 检测周期性扣款（同一商户、相同金额、连续>=3月、日期方差<=3天）
        # 3. 检测重复商户消费（同一商户 >= 5笔/月）
        # 4. 检测异常大额支出（超出均值 2σ 的单笔消费）
        # 5. 返回 {subscriptions, repeat_merchants, anomalies, summary}
```

核心检测算法：
- **周期性扣款**: 按月分组 → 同一对手方金额相同 → 连续 >= 3 月 → 扣款日方差 ≤ 3 天
- **异常支出**: 按类别计算均值+标准差 → 单笔 > μ+2σ → 标记异常
- **重复消费**: 按商户分组计数 → >= 5 笔/月 → 标记

---

## Task 2：新增 Reimbursement Organizer Skill

**文件**: `pmb/skills/domain/reimbursement_organizer.py`（新建）

```python
class ReimbursementOrganizerSkill(BaseSkill):
    name = "reimbursement_organizer"
    description = "识别差旅消费（交通/住宿），整理为结构化报销清单"
    parameters_schema = {"type": "object", "properties": {"month": {"type": "string", "description": "YYYY-MM，默认当前月"}}}

    async def execute(self, **kwargs) -> SkillResult:
        # 1. 获取指定月份交易明细
        # 2. 匹配差旅关键词：机票/火车票/酒店/宾馆/打车
        # 3. 按类别分组整理
        # 4. 返回 {month, total_amount, categories: {交通:[], 住宿:[], ...}}
```

---

## Task 3：注册新 Skill 到 SkillOrchestrator

**文件**: `pmb/skills/orchestrator.py`（修改）

在 `_register_all_skills()` 中加入两个新 Skill：

```python
from pmb.skills.domain.expense_pattern_detector import ExpensePatternDetectorSkill
from pmb.skills.domain.reimbursement_organizer import ReimbursementOrganizerSkill
# ... 现有注册 ...
orchestrator.register(ExpensePatternDetectorSkill())
orchestrator.register(ReimbursementOrganizerSkill())
```

同步在 `GeneralAssistantAgent._skill_display_name()` 增加中文映射：
- `"expense_pattern_detector": "消费模式检测"`
- `"reimbursement_organizer": "报销清单整理"`

---

## Task 4：新增收支分析 Agent

**文件**: `pmb/agents/income_expense_analyst.py`（新建）

### 4.1 元数据

```python
class IncomeExpenseAnalystAgent(BaseAgent):
    agent_id = "income_expense_analyst"
    name = "收支分析师"
    description = "专业分析您的收入支出状况，发现消费模式，提供省钱建议"
    avatar = "income_expense"
```

### 4.2 can_handle() 关键词评分

```python
def can_handle(self, user_message: str) -> float:
    strong = ["收支", "收入分析", "支出分析", "收支分析", "省钱"]
    medium = ["消费", "花费", "开销", "钱花在哪", "花了多少"]
    weak = ["收入", "工资", "账单", "预算", "省钱计划"]
    score = 0.0
    for kw in strong: 
        if kw in msg: score += 0.35
    for kw in medium: 
        if kw in msg: score += 0.20
    for kw in weak: 
        if kw in msg: score += 0.10
    return min(score, 1.0)
```

### 4.3 system_prompt

核心功能描述 + 可用工具列表（income_forecast / consumption_analysis / expense_pattern_detector / reimbursement_organizer）+ 输出格式要求 + 建议生成规则。

### 4.4 analyze_stream() — 五阶段流式处理

参照 `GeneralAssistantAgent._analyze_stream_impl()` 的四阶段 + 新增"建议生成"阶段：

| 阶段 | phase_order | 功能 |
|------|:---:|------|
| 意图识别 | 1 | 通过 thinking_step 事件通知前端 |
| Skill编排 | 2 | LLM 决定调用哪些 Skill |
| 数据收集 | 3 | 执行 Skill，捕获 data 到 `collected_skill_data` |
| 分析生成 | 4 | LLM 流式生成分析报告 |
| **建议生成** | **5** | 规则引擎检测模式 → LLM 生成建议文案 |

### 4.5 退出策略

在每轮 `analyze_stream` 开始时检查：
1. 用户说 "返回"/"换个话题"/"退出" → 发送 `agent_changed` 事件，切换到 GeneralAssistant
2. `can_handle()` < 0.15 且非第一轮 → 同样切换
3. 切换时通过 event_queue 发送 `{"type": "agent_changed", "agent_id": "general_assistant", "agent_name": "小易"}`

### 4.6 规则引擎

```python
RULES = [
    {"id": "travel_freq",       "condition": "交通+住宿+机票>=3笔/月",  "sugg_id": "sugg_travel_reimburse", "label": "整理差旅报销清单"},
    {"id": "repeat_merchant",   "condition": "同一商户>=5笔/月",        "sugg_id": "sugg_merchant_audit",   "label": "审查重复消费"},
    {"id": "food_ratio",        "condition": "餐饮占比>30%",            "sugg_id": "sugg_food_budget",      "label": "设置餐饮预算"},
    {"id": "expense_growth",    "condition": "环比增长>20%",            "sugg_id": "sugg_expense_review",   "label": "排查异常支出"},
    {"id": "subscription",      "condition": "周期扣款>=2个来源",       "sugg_id": "sugg_subscription_review","label": "审查订阅服务"},
    {"id": "credit_ratio",      "condition": "信用卡还款>月收入50%",     "sugg_id": "sugg_credit_optimize",  "label": "优化信用卡还款"},
    {"id": "income_volatile",   "condition": "收入CV>0.3",              "sugg_id": "sugg_income_stability", "label": "关注收入稳定性"},
]
```

### 4.7 建议数据结构

```python
# AgentResult 中新增字段
next_suggestions: list[dict] = [{
    "id": "sugg_travel_reimburse",
    "label": "整理差旅报销清单",
    "prompt": "帮我整理最近3个月的差旅消费，生成报销清单",
    "priority": "high",  # high/medium/low
    "reason": "近3月有12笔交通/住宿消费",
}]
```

---

## Task 5：注册 Agent + 扩展数据模型

### 5.1 AgentRegistry 注册

**文件**: `pmb/agents/registry.py`（修改 `_register_all_agents`）

```python
from pmb.agents.income_expense_analyst import IncomeExpenseAnalystAgent
agent_registry.register(IncomeExpenseAnalystAgent())
```

### 5.2 AgentResult 扩展

**文件**: `pmb/agents/base.py`（修改 `AgentResult` dataclass）

```python
next_suggestions: list[dict] = field(default_factory=list)
```

**文件**: `pmb/api/schemas/agent.py`（修改 `AgentResult` pydantic model）

```python
class NextSuggestion(BaseModel):
    id: str
    label: str
    prompt: str
    priority: str = "medium"
    reason: str = ""

class AgentResult(BaseModel):
    # ... 现有字段 ...
    next_suggestions: list[NextSuggestion] = []
```

---

## Task 6：改造 chat_router — Agent 路由 + 会话状态

**文件**: `pmb/api/routers/chat_router.py`（关键改造）

### 6.1 新增会话级 Agent 状态管理

```python
# 模块级状态
_session_active_agent: dict[str, str] = {}  # session_id → agent_id
```

### 6.2 替换硬编码路由（第 67-68 行）

**旧代码**:
```python
agent = agent_registry.get_agent("general_assistant")
```

**新代码**:
```python
# 获取当前会话的活跃 Agent，或重新路由
current_agent_id = _session_active_agent.get(session_id)
agent = None

if current_agent_id:
    agent = agent_registry.get_agent(current_agent_id)
    if agent and agent.can_handle(content) < 0.15:
        agent = None  # 意图不匹配，重新路由
        _session_active_agent.pop(session_id, None)

if agent is None:
    agent = agent_registry.route(content)
    _session_active_agent[session_id] = agent.agent_id
```

### 6.3 处理 agent_changed 事件

在事件分发的循环中，识别 `type == "agent_changed"` 事件：
- 更新 `_session_active_agent[session_id]`
- 转发给前端（前端用此事件更新 AppBar 标题和头像）

### 6.4 透传 next_suggestions

`ai_done` 事件中增加 `next_suggestions` 字段透传给前端：

```python
await websocket.send_json({
    "type": "ai_done",
    "content": event.get("content", ""),
    "is_final": True,
    "next_suggestions": event.get("next_suggestions", []),
})
```

### 6.5 断开清理

```python
except WebSocketDisconnect:
    _session_active_agent.pop(session_id, None)
```

---

## Task 7：前端 — 新增建议模型

**文件**: `aipmb_app/lib/models/suggestion.dart`（新建）

```dart
class NextSuggestion {
  final String id;
  final String label;
  final String prompt;
  final String priority;
  final String reason;
  // + fromJson / toJson
}
```

---

## Task 8：前端 — 新增 SuggestionChips 组件

**文件**: `aipmb_app/lib/widgets/chat/suggestion_chips.dart`（新建）

```dart
class SuggestionChips extends StatelessWidget {
  final List<NextSuggestion> suggestions;
  final void Function(NextSuggestion) onTap;
  // 渲染: "下一步建议" 标题 + Wrap[ActionChip]
  // 优先级颜色: high=orange, medium=primary, low=grey
}
```

---

## Task 9：前端 — 改造 WebSocket 服务

**文件**: `aipmb_app/lib/services/websocket_service.dart`（修改）

### WsEvent 扩展

```dart
class WsEvent {
  // ... 现有字段 ...
  final List<dynamic> nextSuggestions;  // 新增
  final String? changedAgentId;         // 新增
  final String? changedAgentName;       // 新增
}
```

在 `_channel!.stream.listen` 中解析 `decoded['next_suggestions']`、`decoded['agent_id']`（配合 `type == 'agent_changed'`）。

---

## Task 10：前端 — 改造 ChatProvider

**文件**: `aipmb_app/lib/providers/chat_provider.dart`（修改）

### 新增状态字段

```dart
class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  // 存储每条 AI 消息的建议（以消息 ID 为 key）
  final Map<String, List<NextSuggestion>> _suggestionsMap = {};
  
  // 当前活跃 Agent
  String? _activeAgentId;
  String get activeAgentId => _activeAgentId ?? 'general_assistant';
  String? _activeAgentName;
  String get activeAgentName => _activeAgentName ?? '小易';
```

### 事件处理新增

```dart
case 'agent_changed':
  _activeAgentId = event.changedAgentId;
  _activeAgentName = event.changedAgentName;
  break;

case 'ai_done':
  // 存储 next_suggestions
  if (_currentMsgId != null && event.nextSuggestions.isNotEmpty) {
    _suggestionsMap[_currentMsgId!] = event.nextSuggestions
        .map((s) => NextSuggestion.fromJson(s))
        .toList();
  }
  // ... 现有 finish 逻辑 ...
```

### 暴露 getter

```dart
List<NextSuggestion> getSuggestionsFor(String messageId) =>
    _suggestionsMap[messageId] ?? [];
```

---

## Task 11：前端 — 改造 MessageBubble

**文件**: `aipmb_app/lib/widgets/chat/message_bubble.dart`（修改）

- 构造函数增加 `nextSuggestions`、`onSuggestionTap` 参数
- AI 消息渲染中，Markdown 内容下方追加 `SuggestionChips`

---

## Task 12：前端 — 改造 full_chat_page 和 agent_chat_page

### full_chat_page.dart

**文件**: `aipmb_app/lib/pages/chat/full_chat_page.dart`（修改）

- AppBar 标题改为动态: `ref.watch(chatMessagesProvider.notifier).activeAgentName`
- 消息列表中传递 `nextSuggestions` 和 `onSuggestionTap`
- 点击建议 chip → 自动调用 `_sendMessage(suggestion.prompt)`

### agent_chat_page.dart

**文件**: `aipmb_app/lib/pages/agent/agent_chat_page.dart`（修改）

- 同 full_chat_page 的修改模式
- 快捷操作扩展: `income_expense_analyst` → `['分析收支状况', '消费结构分析', '省钱建议', '整理差旅报销']`

---

## Task 13：前端清理收支/消费相关 Skill 入口

**需求**：新增 Agent 后，将原来独立的 `consumption_analysis`、`income_forecast` 等 Skill 入口从前端页面移除，这些能力已融入新的收支分析 Agent。同时增加 Agent 入口，保持页面清爽。

### 13.1 moment_page.dart — 过滤动态 Skill 列表

**文件**: `aipmb_app/lib/pages/moment/moment_page.dart`（修改）

在 `_buildAiAssistantSection()` 方法（约第 403 行）中，过滤掉已被 Agent 收编的 Skill：

```dart
// 新增：已被 Agent 收编的 Skill，不在前端单独展示入口
static const _agentManagedSkills = {'consumption_analysis', 'income_forecast'};

Widget _buildAiAssistantSection({required List<SkillCard> skills}) {
  // 过滤：排除已由 Agent 管理的 Skill
  final filteredSkills = skills
      .where((s) => !_agentManagedSkills.contains(s.name))
      .toList();
  final displayItems = filteredSkills.isNotEmpty
      ? filteredSkills.map((s) => _QuickQ(
          icon: _iconForSkill(s.name),
          label: s.label,
          msg: s.description,
        )).toList()
      : _fallbackQuestions;
  // ... 其余不变 ...
}
```

### 13.2 moment_page.dart — 更新兜底列表 + 新增 Agent 入口

**文件**: `aipmb_app/lib/pages/moment/moment_page.dart`（修改 `_fallbackQuestions`，约第 39 行）

移除收支/消费相关条目，**新增"收支分析"Agent 入口**：

```dart
static const _fallbackQuestions = [
  _QuickQ(icon: Icons.account_balance_wallet, label: '我的财务状况', msg: '帮我分析一下我的财务状况'),
  _QuickQ(icon: Icons.trending_up, label: '制定理财方案', msg: '帮我制定一份理财方案'),
  _QuickQ(icon: Icons.recommend, label: '推荐产品', msg: '根据我的情况推荐一些理财产品'),
  _QuickQ(icon: Icons.analytics_outlined, label: '收支分析', msg: '@收支分析师 帮我分析收支'),  // 新增 Agent 入口
  _QuickQ(icon: Icons.psychology_outlined, label: '我的消费画像', msg: '给我画一个消费画像'),
];
```

> **移除的条目**：`消费分析`（原 consumption_analysis）、`失业能撑多久`（原 income_forecast）。
> **新增条目**：`收支分析`，点击后发送 `@收支分析师 帮我分析收支`，触发 Agent 路由。

### 13.3 full_chat_page.dart — 更新快捷提问

**文件**: `aipmb_app/lib/pages/chat/full_chat_page.dart`（修改 `_buildQuickPrompts`，约第 158 行）

```dart
const prompts = [
  '我的账户余额',
  '收支分析',               // 替换 "最近消费分析"，走 Agent 路由
  '帮我制定理财方案',
  '推荐适合我的产品',
  '我的消费画像',
  // 移除 '没有收入能撑多久' → 融入收支分析 Agent
];
```

### 13.4 后端 — SkillOrchestrator 过滤领域 Skill 列表

**文件**: `pmb/skills/orchestrator.py`（修改 `get_domain_skills` 方法，约第 45 行）

前端通过 `/api/v1/skills/domain` 获取 Skill 列表渲染快捷卡片。在后端也过滤掉被 Agent 收编的 Skill，从源头控制：

```python
# Agent 管理的 Skill 名称集合（不在前端独立展示）
AGENT_MANAGED_SKILLS = {'consumption_analysis', 'income_forecast'}

def get_domain_skills(self) -> list[dict]:
    domain_prefixes = ("collect_", "compute_", "calculate_")
    results = []
    for skill in self._skills.values():
        if any(skill.name.startswith(p) for p in domain_prefixes):
            continue
        if skill.name in AGENT_MANAGED_SKILLS:  # 新增过滤
            continue
        desc = skill.description
        label = desc.split("。")[0].strip()
        if len(label) > 20:
            label = label[:18] + "..."
        results.append({
            "name": skill.name,
            "description": desc,
            "label": label,
        })
    return results
```

---

## 实施顺序

1. Task 1 + Task 2（两个新 Skill，无依赖，可并行）
2. Task 3（注册 Skill，依赖 Task 1+2）
3. Task 4（新增 Agent，依赖 Task 3 的 Skill 可用）
4. Task 5（注册 Agent + 扩展模型，依赖 Task 4）
5. Task 6（改造 chat_router，依赖 Task 4+5）
6. Task 7 + Task 8（前端模型 + 组件，无依赖，可并行）
7. Task 9 + Task 10（前端服务 + 状态，依赖 Task 7）
8. Task 11 + Task 12 + Task 13（前端页面改造 + Skill入口清理，依赖 Task 8+9+10）

---

## 验证

1. `python -c "from pmb.agents.income_expense_analyst import IncomeExpenseAnalystAgent; a=IncomeExpenseAnalystAgent(); print(a.agent_id, a.can_handle('分析我的收支'))"` → 输出 > 0.5
2. `python -c "from pmb.skills.domain.expense_pattern_detector import ExpensePatternDetectorSkill; print(ExpensePatternDetectorSkill().name)"` → `expense_pattern_detector`
3. `python -c "from pmb.skills.orchestrator import skill_orchestrator; print('expense_pattern_detector' in skill_orchestrator.get_skill_names())"` → `True`
4. `python -c "from pmb.agents.registry import agent_registry; print('income_expense_analyst' in [a.agent_id for a in agent_registry._agents.values()])"` → `True`
5. 启动后端，发送 WebSocket 消息 "分析我的收支" → 验证路由到收支分析师 + thinking_panel 五阶段展示
6. 验证前端 `next_suggestions` chip 渲染 → 点击建议自动发送
7. 发送 "推荐理财产品" → 验证自动回退到小易
8. 验证 `/api/v1/skills/domain` 返回列表中不包含 `consumption_analysis` 和 `income_forecast`
9. 验证"此刻"页面 Skill 快捷卡片中不显示"消费分析"和"收入预测"，但显示"收支分析"Agent 入口
10. 验证对话页快捷提问中"收支分析"可正确路由到 Agent
