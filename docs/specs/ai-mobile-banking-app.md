# AI手机银行APP — Spec驱动实现计划

## Context

现有项目 AIPmb 是一个基于 Python 的银行个人业务 CLI 系统，包含完整的账户、交易、产品、消费四大服务模块和 Excel 数据源。用户需要将其升级为 **AI原生的手机银行APP**，核心体验以对话方式提供服务，支持多模态输入（文字/图片/语音），界面极简（只有"此刻"和"我的"两个频道）。

**本项目的核心创新在于多智能体架构**：通过植入多个专业化的AI智能体（理财专家、消费分析师、生活管家、画像分析师），实现深度业务分析能力，而非简单的问答交互。每个智能体拥有独立人设、专属System Prompt、差异化工具集和数据分析逻辑，能产出结构化的深度分析报告。架构支持可插拔扩展，新增智能体只需实现基类接口并注册。

**技术决策：**
- 跨平台框架：Flutter（iOS + Android）
- 后端：复用现有 Python 后端，包装为 FastAPI REST API + WebSocket
- LLM：国内大模型API（通义千问为首选，支持多厂商切换）
- 核心架构：多智能体（Multi-Agent）意图路由 + 深度分析
- 交付目标：MVP 最小可用产品

---

## 1. 整体架构

```
┌──────────────────────────────────────────────────────┐
│                Flutter 前端 (APP)                      │
│  ┌─────────┐  ┌────────┐  ┌──────────────────────┐  │
│  │ 此刻频道 │  │ 我的频道│  │  AI对话 (多智能体)   │  │
│  └────┬────┘  └───┬────┘  └──────────┬───────────┘  │
│       └──────┬────┘──────────────────┘               │
│       Riverpod 状态管理                                │
│       HTTP REST / WebSocket                           │
└──────────────┬───────────────────────────────────────┘
               │
┌──────────────┼───────────────────────────────────────┐
│     Python FastAPI 后端                                │
│  ┌───────┐ ┌──────────┐ ┌──────────────────────────┐ │
│  │REST API│ │WebSocket │ │   Agent 智能体调度层      │ │
│  └───┬───┘ └────┬─────┘ │ ┌──────┐┌──────┐┌──────┐ │ │
│      │           │       │ │理财  ││消费  ││生活  │ │ │
│      │           │       │ │专家  ││分析  ││便利  │ │ │
│      │           │       │ └──────┘└──────┘└──────┘ │ │
│      │           │       │ ┌──────┐┌──────┐          │ │
│      │           │       │ │用户  ││通用  │  ...可扩展│ │
│      │           │       │ │画像  ││助手  │          │ │
│      │           │       │ └──────┘└──────┘          │ │
│      └─────┬─────┴───────┴──────────┬───────────────┘ │
│             └──────────┬─────────────┘                 │
│       LLM集成层 + Function Calling                      │
│       pmb 服务层（不修改）                               │
│       DataLoader + Excel 数据源                         │
└───────────────────────────────────────────────────────┘
               │
       国内大模型 API
   通义千问 / 文心一言 / DeepSeek
```

**通信协议：**
- REST API：数据查询（账户/交易/产品/消费），统一响应 `{"code":0, "message":"ok", "data":{...}, "total":N}`
- WebSocket `ws://host/api/v1/chat/ws/{session_id}`：AI 对话流式输出

---

## 2. Python 后端实现

### 2.1 新增目录结构

```
pmb/
├── api/                        # [新增] API层
│   ├── __init__.py
│   ├── app.py                  # FastAPI实例、CORS、生命周期
│   ├── deps.py                 # 依赖注入
│   ├── schemas/                # Pydantic响应模型
│   │   ├── common.py           #   ApiResponse, PaginationParams
│   │   ├── account.py          #   AccountResponse, AccountSummaryResponse
│   │   ├── transaction.py      #   TransactionResponse, TransactionSummaryResponse
│   │   ├── product.py          #   ProductResponse, ProductCategoryResponse
│   │   ├── consumption.py      #   ConsumptionResponse, ConsumptionStatsResponse
│   │   ├── chat.py             #   ChatMessageSchema, ChatChunkSchema
│   │   └── recommendation.py   #   TodoItem, ProductRecommendation, PromoItem
│   ├── mappers/                # 中文key→英文key映射
│   │   ├── account_mapper.py
│   │   ├── transaction_mapper.py
│   │   ├── product_mapper.py
│   │   └── consumption_mapper.py
│   └── routers/                # API路由
│       ├── account_router.py
│       ├── transaction_router.py
│       ├── product_router.py
│       ├── consumption_router.py
│       ├── chat_router.py       # WebSocket + 对话历史REST
│       ├── upload_router.py     # 图片/语音上传
│       └── recommendation_router.py
├── agents/                      # [新增] 多智能体层
│   ├── __init__.py
│   ├── base.py                  # Agent基类（接口定义、公共逻辑）
│   ├── registry.py              # Agent注册表 + 意图路由分发器
│   ├── financial_planner.py     # 理财专家智能体
│   ├── consumption_analyst.py   # 消费分析智能体
│   ├── life_assistant.py        # 生活便利智能体
│   ├── user_profiler.py         # 用户画像智能体
│   └── general_assistant.py     # 通用助手智能体（兜底）
├── llm/                        # [新增] 大模型集成层
│   ├── __init__.py
│   ├── base.py                 # LLM抽象基类
│   ├── qwen.py                 # 通义千问适配
│   ├── wenxin.py               # 文心一言适配
│   ├── deepseek.py             # DeepSeek适配
│   ├── tool_registry.py        # Function Calling工具定义+执行分发
│   ├── context_manager.py      # 对话上下文管理
│   └── stream_handler.py       # 流式响应处理
├── profile/                    # [新增] 用户画像
│   ├── __init__.py
│   ├── tag_engine.py           # 标签计算引擎
│   └── recommendation_engine.py # 推荐引擎
└── (现有文件不变)
```

根目录新增 `run_api.py` 作为API服务启动入口。

### 2.2 REST API 路由

| 方法 | 路径 | 对应服务函数 |
|------|------|-------------|
| GET | `/api/v1/accounts` | `account_service.list_accounts` |
| GET | `/api/v1/accounts/{account_id}` | `account_service.get_account` |
| GET | `/api/v1/accounts/summary` | `account_service.get_account_summary` |
| GET | `/api/v1/transactions` | `transaction_service.list_transactions` |
| GET | `/api/v1/transactions/{seq_no}` | `transaction_service.get_transaction` |
| GET | `/api/v1/transactions/summary` | `transaction_service.get_transaction_summary` |
| GET | `/api/v1/products` | `product_service.list_products` |
| GET | `/api/v1/products/{product_name}` | `product_service.get_product` |
| GET | `/api/v1/products/summary` | `product_service.get_product_summary` |
| GET | `/api/v1/products/categories` | `product_service.get_categories` |
| GET | `/api/v1/consumptions` | `consumption_service.list_consumption` |
| GET | `/api/v1/consumptions/{seq_no}` | `consumption_service.get_consumption` |
| GET | `/api/v1/consumptions/stats` | `consumption_service.get_consumption_stats` |
| GET | `/api/v1/wealth/overview` | 新增：财富总览计算 |
| GET | `/api/v1/recommendations/todos` | 推荐引擎：待办 |
| GET | `/api/v1/recommendations/promos` | 推荐引擎：优惠 |
| GET | `/api/v1/recommendations/products` | 推荐引擎：产品推荐 |
| GET | `/api/v1/profile/tags` | 标签引擎：用户画像标签 |
| POST | `/api/v1/upload/image` | 图片上传 |
| POST | `/api/v1/upload/voice` | 语音上传 |

### 2.3 AI 对话 WebSocket 协议

**客户端发送：**
```json
{
  "type": "user_message",
  "content": "我这个月消费了多少",
  "content_type": "text",
  "media_url": "",
  "timestamp": "2026-06-05T10:00:00Z"
}
```

**服务端流式返回：**
```json
{"type": "ai_chunk", "content": "根据查询结果", "cards": [], "is_final": false}
{"type": "ai_chunk", "content": "，您本月消费了", "cards": [], "is_final": false}
{"type": "ai_chunk", "content": "", "cards": [{"card_type":"consumption_stats","data":[...]}], "is_final": false}
{"type": "ai_done", "content": "", "is_final": true}
```

### 2.4 LLM 集成 — Function Calling

将 pmb 服务暴露为 LLM 可调用的工具：

| 工具名 | 描述 | 调用的服务函数 |
|--------|------|--------------|
| `query_accounts` | 查询银行账户信息 | `account_service.list_accounts` |
| `query_transactions` | 查询交易明细 | `transaction_service.list_transactions` |
| `query_consumption_stats` | 查询消费统计 | `consumption_service.get_consumption_stats` |
| `query_products` | 查询银行产品 | `product_service.list_products` |
| `get_account_summary` | 获取账户汇总 | `account_service.get_account_summary` |

**对话流程：** 用户消息 → LLM → tool_call → 执行pmb服务 → 结果回传LLM → 流式生成回复

### 2.5 用户画像标签体系

| 标签类别 | 标签示例 | 提取逻辑 |
|---------|---------|---------|
| 资产等级 | 高净值/中产/基础 | 借记卡总余额阈值 |
| 消费偏好 | 餐饮达人/网购达人/出行达人 | 消费统计Top1子类 |
| 消费水平 | 高/中/低 | 月均消费金额阈值 |
| 风险偏好 | 保守/稳健/进取 | 产品风险等级分布 |
| 渠道偏好 | 支付宝/微信/刷卡 | 支付渠道统计Top1 |

### 2.6 认证方案（MVP简化）

固定Token认证：后端启动时生成Token，前端登录页输入测试手机号，验证通过返回Token，后续请求 `Authorization: Bearer <token>`。

### 2.7 需修改的现有文件

| 文件 | 修改内容 |
|------|---------|
| `pyproject.toml` | 添加 fastapi, uvicorn, dashscope, python-multipart, websockets 依赖 |
| `pmb/core/config.py` | 可选：添加API配置项 |

**核心原则：现有 pmb 服务层代码完全不修改。**

### 2.8 新增文件完整清单

**Python 后端新增文件（约35个）：**

```
# API层
pmb/api/__init__.py
pmb/api/app.py                              # FastAPI实例
pmb/api/deps.py                             # 依赖注入
pmb/api/schemas/__init__.py
pmb/api/schemas/common.py                   # 统一响应格式
pmb/api/schemas/account.py
pmb/api/schemas/transaction.py
pmb/api/schemas/product.py
pmb/api/schemas/consumption.py
pmb/api/schemas/chat.py
pmb/api/schemas/recommendation.py
pmb/api/schemas/agent.py                    # Agent相关Schema
pmb/api/mappers/__init__.py
pmb/api/mappers/account_mapper.py
pmb/api/mappers/transaction_mapper.py
pmb/api/mappers/product_mapper.py
pmb/api/mappers/consumption_mapper.py
pmb/api/routers/__init__.py
pmb/api/routers/account_router.py
pmb/api/routers/transaction_router.py
pmb/api/routers/product_router.py
pmb/api/routers/consumption_router.py
pmb/api/routers/chat_router.py
pmb/api/routers/upload_router.py
pmb/api/routers/recommendation_router.py
pmb/api/routers/agent_router.py             # 智能体API路由

# 智能体层
pmb/agents/__init__.py
pmb/agents/base.py                          # Agent基类
pmb/agents/registry.py                      # 注册表+意图路由
pmb/agents/financial_planner.py             # 理财专家智能体
pmb/agents/consumption_analyst.py           # 消费分析智能体
pmb/agents/life_assistant.py               # 生活便利智能体
pmb/agents/user_profiler.py                # 用户画像智能体
pmb/agents/general_assistant.py            # 通用助手（兜底）

# LLM层
pmb/llm/__init__.py
pmb/llm/base.py
pmb/llm/qwen.py
pmb/llm/wenxin.py
pmb/llm/deepseek.py
pmb/llm/tool_registry.py
pmb/llm/context_manager.py
pmb/llm/stream_handler.py

# 用户画像+推荐
pmb/profile/__init__.py
pmb/profile/tag_engine.py
pmb/profile/recommendation_engine.py

# 启动入口
run_api.py
```

---

## 3. Flutter 前端实现

### 3.1 项目目录结构

```
aipmb_app/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── config/
│   │   ├── theme.dart
│   │   ├── routes.dart
│   │   └── api_config.dart
│   ├── models/
│   │   ├── account.dart
│   │   ├── transaction.dart
│   │   ├── product.dart
│   │   ├── chat_message.dart
│   │   ├── recommendation.dart
│   │   ├── user_profile.dart
│   │   └── agent.dart                  # 智能体模型
│   ├── providers/
│   │   ├── account_provider.dart
│   │   ├── chat_provider.dart
│   │   ├── recommendation_provider.dart
│   │   ├── user_profile_provider.dart
│   │   └── agent_provider.dart         # 智能体状态管理
│   ├── services/
│   │   ├── api_client.dart
│   │   ├── websocket_service.dart
│   │   ├── speech_service.dart
│   │   └── image_service.dart
│   ├── pages/
│   │   ├── main_shell.dart          # 底部Tab导航
│   │   ├── moment/
│   │   │   ├── moment_page.dart     # 此刻频道主页
│   │   │   ├── ai_chat_section.dart # AI对话区域
│   │   │   ├── agent_entry_section.dart # 智能体入口区
│   │   │   └── recommendation_section.dart # 推荐卡片流
│   │   ├── mine/
│   │   │   ├── mine_page.dart       # 我的频道主页
│   │   │   ├── wealth_overview.dart # 财富总览
│   │   │   ├── account_list.dart    # 账户列表
│   │   │   └── settings_page.dart   # 设置
│   │   ├── agent/                      # [新增] 智能体页面
│   │   │   ├── agent_chat_page.dart    # 智能体专属对话页
│   │   │   └── agent_report_page.dart  # 分析报告页
│   │   └── chat/
│   │       └── full_chat_page.dart  # 全屏对话
│   ├── widgets/
│   │   ├── chat/
│   │   │   ├── message_bubble.dart
│   │   │   ├── chat_input_bar.dart
│   │   │   └── streaming_text.dart
│   │   ├── cards/
│   │   │   ├── product_card.dart
│   │   │   ├── transaction_card.dart
│   │   │   ├── todo_card.dart
│   │   │   ├── promo_card.dart
│   │   │   ├── agent_card.dart          # 智能体图标卡片
│   │   │   ├── wealth_plan_card.dart    # 理财方案卡片
│   │   │   ├── survival_card.dart       # 续航测算卡片
│   │   │   ├── profile_card.dart        # 画像标签卡片
│   │   │   └── recommendation_with_reason_card.dart  # 含原因的推荐卡片
│   │   ├── charts/
│   │   │   ├── consumption_bar_chart.dart
│   │   │   └── wealth_pie_chart.dart
│   │   └── common/
│   │       └── amount_text.dart
│   └── utils/
│       └── formatters.dart
├── pubspec.yaml
└── assets/
```

### 3.2 核心依赖

```yaml
dependencies:
  flutter_riverpod: ^2.4.0    # 状态管理
  go_router: ^13.0.0          # 路由
  dio: ^5.4.0                 # HTTP客户端
  web_socket_channel: ^2.4.0  # WebSocket
  fl_chart: ^0.66.0           # 图表
  speech_to_text: ^6.6.0      # 语音识别
  image_picker: ^1.0.0        # 图片选择
  markdown_widget: ^2.3.0     # Markdown渲染
```

### 3.3 路由结构

```
/ (MainShell, 底部双Tab)
├── /moment        此刻频道（默认Tab）
└── /mine          我的频道
    /moment/chat   全屏AI对话（从此刻频道展开）
```

### 3.4 "此刻"频道 UI 布局

自上而下：
1. **顶部问候区**：时段问候 + 用户姓名 + 日期
2. **AI 对话区**（页面中部60%）：半屏对话卡片，展示最近AI交互或预设话术，可展开全屏
3. **推荐卡片流**（下方可滚动）：
   - 待办卡片组（信用卡还款提醒、账单查询等）
   - 产品推荐卡片（基于用户画像）
   - 优惠推荐卡片（基于消费偏好）
4. **底部固定输入栏**：文字输入 + 语音按钮 + 图片按钮 + 发送按钮

### 3.5 "我的"频道 UI 布局

自上而下：
1. **用户头像+姓名**
2. **财富总览卡片**：总资产/总负债/净资产 + 资产构成饼图
3. **账户关系列表**：借记卡（卡号脱敏+余额）、信用卡（额度+应还+账单日）
4. **消费趋势**：近6月消费柱状图 + Top5消费子类
5. **功能入口**：消费明细、产品浏览、APP设置

### 3.6 对话消息渲染

消息由多个 ContentPart 组成：
- **TextPart**：Markdown 渲染
- **ProductCardPart**：产品推荐卡片
- **TransactionListPart**：交易列表卡片
- **ConsumptionStatsPart**：消费统计卡片
- **ImagePart**：图片缩略图
- **ActionPart**：快捷操作按钮

---

## 4. 多智能体架构（核心创新）

### 4.1 设计理念

AI手机银行的核心智能化通过多智能体（Multi-Agent）架构实现。每个智能体是一个专业化的 AI 角色，拥有独立的 System Prompt、专属工具集和分析逻辑，负责特定领域的深度业务分析。用户对话时，系统通过意图路由自动分发到最合适的智能体；用户也可主动指定智能体进行深度咨询。

**关键原则：**
- 每个智能体有专属人设和专业领域，不是通用助手的简单分流
- 智能体之间可以协作（如用户画像智能体为理财专家提供画像数据）
- 可插拔扩展：新增智能体只需实现基类接口 + 注册，无需改动其他代码
- 每个智能体的输出包含结构化卡片数据，前端差异化渲染

### 4.2 Agent 基类设计

```python
class BaseAgent(ABC):
    """智能体基类，所有Agent必须继承"""

    @property
    @abstractmethod
    def agent_id(self) -> str:
        """智能体唯一标识，如 'financial_planner'"""

    @property
    @abstractmethod
    def name(self) -> str:
        """智能体显示名称，如 '理财专家'"""

    @property
    @abstractmethod
    def description(self) -> str:
        """智能体能力描述，用于意图路由匹配"""

    @property
    @abstractmethod
    def avatar(self) -> str:
        """智能体头像标识，前端渲染用"""

    @property
    @abstractmethod
    def system_prompt(self) -> str:
        """专属System Prompt，定义人设、行为边界、输出格式"""

    @property
    def tools(self) -> list[dict]:
        """该智能体可使用的Function Calling工具定义，默认全部"""
        return ALL_TOOLS

    @abstractmethod
    async def analyze(self, context: AgentContext) -> AgentResult:
        """
        核心分析方法。
        1. 收集所需数据（调用pmb服务）
        2. 构建增强prompt（注入数据分析结果）
        3. 调用LLM生成深度分析
        4. 返回结构化结果（文本+卡片）
        """

    def can_handle(self, user_message: str) -> float:
        """
        意图匹配度评分（0.0~1.0）。
        基类提供关键词匹配默认实现，子类可覆盖。
        返回值越高表示越适合处理该消息。
        """
```

### 4.3 Agent 注册表与意图路由

```python
class AgentRegistry:
    """智能体注册表 + 意图路由分发器"""

    def __init__(self):
        self._agents: dict[str, BaseAgent] = {}

    def register(self, agent: BaseAgent):
        """注册智能体，支持动态扩展"""

    def route(self, user_message: str) -> BaseAgent:
        """
        意图路由：根据用户消息选择最合适的智能体。
        1. 检查是否有明确指定（如 @理财专家）
        2. 各Agent的can_handle评分，取最高分
        3. 若最高分<阈值，路由到通用助手
        """

    def get_agent(self, agent_id: str) -> BaseAgent | None:
        """按ID获取智能体"""

    def list_agents(self) -> list[AgentInfo]:
        """列出所有可用智能体"""
```

**路由策略：**
1. **显式指定**：用户输入 `@理财专家` 前缀，直接路由到指定Agent
2. **智能匹配**：各Agent的 `can_handle()` 对消息打分，最高分Agent胜出
3. **上下文延续**：对话已在某Agent上下文中，后续消息默认继续由该Agent处理
4. **兜底降级**：所有Agent评分低于0.3时，路由到通用助手

### 4.4 四大核心智能体详细设计

---

#### 智能体一：理财专家 (Financial Planner)

**agent_id**: `financial_planner`
**名称**: 理财专家
**人设**: 专业、亲和的资深理财顾问，善于根据客户实际情况量身定制方案

**核心能力**: 根据用户当前财富状况和消费习惯，制定理财方案，且不降低消费品味

**专属System Prompt 核心要点**:
```
你是一位资深理财专家，专注于为银行客户提供个性化的理财规划方案。
你的核心理念是：理财不是节流，而是让钱更聪明地运转。
你需要：
1. 先全面了解客户的资产状况（存款、信用卡、负债）
2. 分析客户的消费习惯和消费水平
3. 在不降低消费品味的前提下，找出资金优化空间
4. 推荐适合客户风险偏好的银行产品组合
5. 给出具体的资金分配建议（每月可投资金额、产品配比、预期收益）
输出格式要求：
- 给出"现状分析"、"优化建议"、"产品推荐"、"预期效果"四个板块
- 金额精确到元，收益率给出合理区间
- 产品推荐必须来自银行实际产品库
```

**专属工具集**:
- `query_accounts` + `get_account_summary`：获取资产全貌
- `query_consumption_stats(group_by="month")`：获取月度消费水平
- `query_consumption_stats(group_by="subcategory")`：获取消费结构
- `query_products(category="wealth")` / `query_products(category="fund")`：推荐理财/基金产品
- `query_products(category="deposit")`：保本型产品兜底

**核心分析逻辑** (`analyze` 方法):
1. 调用 `get_account_summary` → 总资产、总负债
2. 调用 `query_consumption_stats(group_by="month")` → 月均消费额
3. 调用 `query_consumption_stats(group_by="subcategory")` → 消费结构，识别"刚性支出"（不可压）和"弹性支出"（可优化）
4. 计算：月可投资额 = 月收入 - 刚性支出 - 弹性支出保留额
5. 调用 `query_products` 获取匹配风险偏好的产品列表
6. 将以上数据注入增强Prompt，让LLM生成理财方案
7. 返回结构化结果：包含理财方案卡片（产品配比饼图 + 月度资金分配表）

**意图关键词**: 理财、投资、规划、存钱、收益、产品推荐、资金分配

---

#### 智能体二：消费分析专家 (Consumption Analyst)

**agent_id**: `consumption_analyst`
**名称**: 消费分析师
**人设**: 理性客观的财务分析师，擅长用数据说话，帮助客户看清消费真相

**核心能力**: 分析"如果失去收入来源"的生存能力，提供不同消费标准下的续航方案

**专属System Prompt 核心要点**:
```
你是一位专业的消费分析师，擅长通过数据洞察帮助客户了解自己的消费真相。
你的核心任务是回答"如果没了收入，我还能撑多久"这个关键问题。
你需要：
1. 计算当前总可用资金（存款余额 - 信用卡应还）
2. 分析月均消费（区分"维持现状"和"最低生存"两个档次）
3. 计算两个场景的续航月数
4. 给出降低消费标准的具体建议（按消费子类逐项分析可压缩空间）
5. 给出最长续航方案
输出格式要求：
- 给出"现状诊断"、"续航测算"、"降级方案"、"极限续航"四个板块
- 续航月数精确到0.1个月
- 降级方案按消费子类逐项给出压缩比例建议
- 用对比表格呈现"当前消费"vs"建议消费"
```

**专属工具集**:
- `get_account_summary`：获取可用资金
- `query_accounts`：获取各账户余额和信用卡应还
- `query_consumption_stats(group_by="month")`：月度消费趋势
- `query_consumption_stats(group_by="subcategory")`：消费结构明细
- `query_consumption_stats(group_by="category")`：大类消费占比

**核心分析逻辑** (`analyze` 方法):
1. 可用资金 = 借记卡总余额 - 信用卡应还金额
2. 月均消费 = 近12个月总支出 / 月份数
3. 场景一（不降标准）：续航月数 = 可用资金 / 月均消费
4. 逐项分析消费子类，识别"必需"（餐饮、交通、物业）vs"可选"（娱乐、购物）
5. 最低生存月消费 = 仅保留必需类消费 + 基本日用
6. 场景二（降低标准）：续航月数 = 可用资金 / 最低生存月消费
7. 将以上数据注入增强Prompt，让LLM生成分析报告
8. 返回结构化结果：包含续航测算卡片（双柱对比图 + 逐项压缩建议表）

**意图关键词**: 消费分析、还能撑多久、收入中断、失业、降消费、节省、预算

---

#### 智能体三：生活便利专家 (Life Assistant)

**agent_id**: `life_assistant`
**名称**: 生活管家
**人设**: 热心周到的银行生活管家，了解客户的消费习惯，推荐最贴心的产品和优惠

**核心能力**: 基于消费习惯画像，推荐匹配的产品和优惠，并给出推荐原因

**专属System Prompt 核心要点**:
```
你是银行的生活管家，善于从客户的消费行为中发现需求，推荐最贴心的产品和优惠。
你的核心原则：
1. 推荐必须基于客户的真实消费习惯，而非泛泛推荐
2. 每条推荐必须给出"推荐原因"，关联客户的实际消费数据
3. 推荐要有温度，像朋友一样关心客户的生活
你需要：
1. 构建客户的消费画像（消费偏好标签）
2. 匹配与画像契合的银行产品
3. 匹配与消费习惯相关的优惠活动
4. 每条推荐附上数据支撑的推荐原因
输出格式要求：
- 先给出消费画像概览（3-5个标签）
- 产品推荐：产品名 + 匹配原因 + 客户消费数据支撑
- 优惠推荐：优惠内容 + 适合原因 + 客户消费频率支撑
```

**专属工具集**:
- `query_consumption_stats(group_by="subcategory")`：消费偏好画像
- `query_consumption_stats(group_by="channel")`：支付渠道偏好
- `query_consumption_stats(group_by="merchant", top=10)`：常去商户
- `query_products`：搜索匹配产品
- `get_account_summary`：账户概览

**核心分析逻辑** (`analyze` 方法):
1. 调用消费统计 → 生成画像标签（如"餐饮达人、支付宝偏好、高频出行"）
2. 根据标签匹配产品（出行达人 → 加油优惠卡、ETC产品；网购达人 → 电商联名卡）
3. 根据常去商户匹配优惠（常去星巴克 → 星巴克满减活动）
4. 每条推荐附带：推荐原因 + 对应消费数据
5. 将数据注入增强Prompt，让LLM生成推荐报告
6. 返回结构化结果：画像标签卡 + 推荐列表（含原因标签）

**意图关键词**: 推荐、优惠、适合我、有什么活动、办卡、生活、便利

---

#### 智能体四：用户画像专家 (User Profiler)

**agent_id**: `user_profiler`
**名称**: 画像分析师
**人设**: 洞察力极强的行为分析师，善于从收支和消费行为中描绘一个人的人生画像

**核心能力**: 通过用户收支和消费行为，生成"你是怎样的一个人"画像，并给出有趣的建议

**专属System Prompt 核心要点**:
```
你是一位洞察力极强的用户画像分析师。你的独特之处在于：不仅给出标签，
更要用生动、有趣的语言描绘出"这是一个怎样的人"。
你的核心任务：
1. 从消费数据中提炼用户的消费人格（如"品质生活追求者"、"精打细算的实用派"）
2. 用一段生动的描述勾勒用户画像，让人读起来觉得"这就是我"
3. 基于画像，给出有趣的建议（可以是资金规划的，也可以是生活乐趣方面的）
4. 建议要出人意料但有据可循，让用户觉得"原来我还可以这样"
输出格式要求：
- "你的画像"：1-2段生动描述 + 核心标签
- "消费人格"：用比喻描述消费风格
- "有趣发现"：3个从数据中发现的有趣洞察
- "灵感建议"：3-5条有趣建议（资金规划 + 生活乐趣混合）
```

**专属工具集**:
- `get_account_summary`：资产概览
- `query_consumption_stats(group_by="subcategory")`：消费偏好
- `query_consumption_stats(group_by="month")`：消费节奏
- `query_consumption_stats(group_by="channel")`：支付习惯
- `query_consumption_stats(group_by="merchant", top=10)`：生活足迹
- `query_transactions(source="all", direction="expense")`：大额消费
- `query_transactions(source="all", direction="income")`：收入特征
- `query_products`：关联产品

**核心分析逻辑** (`analyze` 方法):
1. 收集全维度数据：资产、消费结构、消费节奏、支付习惯、常去商户、大额消费
2. 从数据中提炼洞察：
   - 消费时段偏好（夜猫子/早鸟）
   - 消费稳定性（稳定型/波动型）
   - 生活品质倾向（品质型/实用型）
   - 社交活跃度（从餐饮/娱乐频次推断）
   - 出行方式（从交通类消费推断）
3. 综合画像：将这些洞察组合成一个有温度的人物描述
4. 生成灵感建议：基于画像跨界联想（如"你是咖啡爱好者，可以考虑..."）
5. 将数据注入增强Prompt，让LLM生成画像报告
6. 返回结构化结果：画像卡片（标签云 + 人格描述 + 洞察气泡 + 建议卡片）

**意图关键词**: 画像、我是谁、我的消费、分析我、了解我、怎样的一个人、我的风格

---

### 4.5 通用助手智能体（兜底）

**agent_id**: `general_assistant`
**名称**: 小招
**人设**: 银行AI助手，处理日常银行查询和简单对话

作为兜底智能体，处理不属于四大专业领域的问题，如查余额、查交易等基础银行服务。System Prompt 即原计划的通用银行助手设定。

### 4.6 智能体协作机制

智能体之间可以协作，通过 `AgentContext` 共享数据：

```python
class AgentContext:
    """智能体上下文，跨Agent共享"""
    session_id: str
    user_message: str
    conversation_history: list[dict]
    user_profile: UserProfile | None       # 用户画像（画像Agent计算后缓存）
    account_summary: dict | None           # 账户汇总（按需加载）
    consumption_stats: dict | None         # 消费统计（按需加载）

class AgentResult:
    """智能体输出结果"""
    agent_id: str
    content: str                           # 文本回复（Markdown）
    cards: list[AgentCard]                 # 结构化卡片
    suggested_agents: list[str]            # 推荐后续可咨询的Agent
    metadata: dict                         # 额外元数据
```

**协作场景：**
- 理财专家需要用户画像数据 → 自动调用 `user_profiler` 的缓存结果
- 消费分析师需要消费结构 → 自动加载 `consumption_stats`
- 用户画像智能体的画像结果被其他智能体引用

### 4.7 新增 REST API（智能体相关）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/agents` | 列出所有可用智能体 |
| POST | `/api/v1/agents/{agent_id}/analyze` | 直接调用指定智能体进行深度分析 |
| GET | `/api/v1/agents/{agent_id}/status` | 获取智能体状态（可用/忙碌） |

**深度分析 API**（同步调用，适合"一键分析"场景）：
```json
POST /api/v1/agents/financial_planner/analyze
Response: {
  "code": 0,
  "data": {
    "agent_id": "financial_planner",
    "agent_name": "理财专家",
    "content": "## 现状分析\n...(Markdown文本)",
    "cards": [
      {"card_type": "wealth_plan", "title": "理财方案", "data": {...}},
      {"card_type": "product_recommendation", "title": "推荐产品", "data": [...]}
    ],
    "suggested_agents": ["consumption_analyst", "user_profiler"]
  }
}
```

### 4.8 前端智能体交互设计

**"此刻"频道增强**：
1. **智能体入口区**：对话区上方显示4个智能体图标卡片，点击即可进入对应智能体对话
2. **对话中智能体标识**：AI回复消息气泡左上角显示当前智能体头像和名称
3. **智能体切换**：对话中可通过 `@智能体名` 切换，或点击推荐的其他智能体标签
4. **一键深度分析**：点击智能体图标后，提供"一键分析"按钮，直接调用深度分析API
5. **分析报告页**：深度分析结果以富文本+卡片的形式展示，支持保存和分享

**新增前端文件**：
- `aipmb_app/lib/models/agent.dart` — 智能体模型
- `aipmb_app/lib/providers/agent_provider.dart` — 智能体状态管理
- `aipmb_app/lib/pages/moment/agent_entry_section.dart` — 智能体入口区
- `aipmb_app/lib/pages/agent/agent_chat_page.dart` — 智能体专属对话页
- `aipmb_app/lib/pages/agent/agent_report_page.dart` — 分析报告页
- `aipmb_app/lib/widgets/cards/agent_card.dart` — 智能体图标卡片
- `aipmb_app/lib/widgets/cards/wealth_plan_card.dart` — 理财方案卡片
- `aipmb_app/lib/widgets/cards/survival_card.dart` — 续航测算卡片
- `aipmb_app/lib/widgets/cards/profile_card.dart` — 画像标签卡片
- `aipmb_app/lib/widgets/cards/recommendation_with_reason_card.dart` — 含原因的推荐卡片

**WebSocket协议增强**：
```json
// 客户端发送（新增agent_id字段）
{
  "type": "user_message",
  "content": "帮我制定理财方案",
  "content_type": "text",
  "agent_id": "financial_planner"   // 可选，指定智能体
}

// 服务端返回（新增agent字段）
{
  "type": "ai_chunk",
  "content": "...",
  "agent": {
    "agent_id": "financial_planner",
    "name": "理财专家",
    "avatar": "financial"
  },
  "cards": [],
  "is_final": false
}
```

---

## 5. 千人千面推荐逻辑

### 5.1 待办推荐

| 待办类型 | 触发条件 | 推荐内容 |
|---------|---------|---------|
| 信用卡还款 | 有应还金额且距还款日≤5天 | 还款提醒 |
| 账单查询 | 每月账单日后1天 | 账单查看提醒 |
| 大额支出 | 单笔支出>月均50% | 安全提醒 |

### 5.2 产品推荐

| 风险偏好 | 推荐类别 |
|---------|---------|
| 保守型 | 存款、低风险理财、保险 |
| 稳健型 | 理财产品、债基、黄金 |
| 进取型 | 股基、外汇、高收益理财 |

### 5.3 优惠推荐

基于消费偏好标签匹配（餐饮→餐饮优惠，网购→电商返现等）。MVP阶段优惠数据硬编码。

---

## 6. MVP 优先级

### P0 — 必须有

**后端：**
1. FastAPI骨架 + Schema + Mapper（中→英key映射）
2. 5组REST API（账户/交易/产品/消费/财富总览）
3. WebSocket对话端点 + 流式输出
4. 通义千问LLM适配 + Function Calling
5. **多智能体架构：基类 + 注册表 + 意图路由**
6. **四大核心智能体实现（理财专家/消费分析师/生活管家/画像分析师）**
7. 对话上下文内存管理 + AgentContext共享
8. 固定Token认证

**前端：**
1. Flutter骨架 + Riverpod + GoRouter
2. MainShell底部双Tab
3. "我的"频道：财富总览 + 账户列表
4. "此刻"频道：AI对话区 + **智能体入口区** + 推荐卡片位
5. AI对话：文字输入 + 消息气泡（含智能体标识）+ 流式渲染
6. **智能体专属对话页 + 分析报告页**
7. HTTP + WebSocket客户端

### P1 — 应该有

1. 语音输入（speech_to_text）
2. 图片上传+LLM多模态理解
3. 智能体间协作（画像数据自动共享给理财专家等）
4. 用户画像标签引擎 + 千人千面推荐
5. 消费趋势图表
6. **智能体专属卡片组件（理财方案卡/续航测算卡/画像标签卡/推荐含原因卡）**
7. 对话历史本地持久化
8. 文心一言/DeepSeek适配

### P2 — 可以有

1. 深色模式
2. 高级动画
3. 离线缓存
4. 多会话管理

---

## 7. 实施步骤

### Step 1: 后端骨架
- 创建 `pmb/api/` 目录结构和文件
- 实现 `app.py`（FastAPI实例、CORS、生命周期）
- 实现 `schemas/common.py`（统一响应格式）
- 修改 `pyproject.toml` 添加依赖

### Step 2: Schema + Mapper
- 为4个服务模块创建 Pydantic Schema（英文key）
- 创建 mapper 函数（中文key dict → 英文key dict）
- 关键映射：`账号/卡号→account_number`, `最新余额(元)→balance`, `交易金额→amount`, `消费细分子类→subcategory`

### Step 3: REST API路由
- 实现账户/交易/产品/消费/财富总览路由
- 每个路由调用对应service函数 + mapper转换
- 财富总览API新增计算逻辑（总资产=借记卡余额之和，总负债=信用卡应还之和）

### Step 4: LLM集成
- 实现 `base.py` 抽象基类
- 实现 `qwen.py` 通义千问适配（dashscope SDK）
- 实现 `tool_registry.py`（5个工具定义 + 执行分发器）
- 实现 `context_manager.py`（内存中对话上下文，最近20轮）

### Step 5: 多智能体架构
- 实现 `agents/base.py`（Agent基类，定义接口、can_handle默认实现）
- 实现 `agents/registry.py`（注册表 + 意图路由分发器）
- 实现四大核心智能体：
  - `financial_planner.py`：理财专家，收集资产+消费数据，LLM生成理财方案
  - `consumption_analyst.py`：消费分析师，计算续航月数，双场景对比
  - `life_assistant.py`：生活管家，消费画像→产品/优惠匹配+推荐原因
  - `user_profiler.py`：画像分析师，全维度数据→人格画像+灵感建议
- 实现 `general_assistant.py`（通用助手兜底）
- 实现智能体API路由（`/api/v1/agents`）
- 实现AgentContext数据共享和协作机制

### Step 6: WebSocket对话
- 实现 `chat_router.py`（WebSocket端点 + 对话历史REST）
- 实现 `stream_handler.py`（流式响应 → 逐chunk推送给客户端）
- 对话流程集成智能体路由：用户消息 → AgentRegistry.route() → 指定Agent → LLM+Tool → 流式输出
- WebSocket协议增加agent_id字段

### Step 7: 用户画像+推荐
- 实现 `tag_engine.py`（从账户/消费/交易数据提取标签）
- 实现 `recommendation_engine.py`（基于标签生成待办/优惠/产品推荐）
- 实现推荐API路由

### Step 8: Flutter项目骨架
- 创建Flutter项目，配置pubspec.yaml
- 实现main.dart + app.dart + 主题配置
- 实现MainShell底部双Tab导航
- 配置GoRouter路由

### Step 9: Flutter "我的"频道
- 实现财富总览页面（总资产/负债/净资产 + 饼图）
- 实现账户列表页面（借记卡/信用卡分组）
- 实现settings页面

### Step 10: Flutter "此刻"频道 + 智能体入口
- 实现AI对话区（半屏卡片 + 可展开全屏）
- 实现智能体入口区（4个智能体图标卡片）
- 实现智能体专属对话页（agent_chat_page）
- 实现分析报告页（agent_report_page）
- 实现消息气泡组件（含智能体标识头像）
- 实现流式文字渲染组件
- 实现推荐卡片位（待办/产品/优惠三组）

### Step 11: Flutter AI对话 + 智能体集成
- 实现WebSocket客户端
- 实现chat_provider（Riverpod StateNotifier，支持agent_id切换）
- 实现agent_provider（智能体列表+状态管理）
- 实现聊天输入栏（文字+语音按钮+图片按钮+@切换智能体）
- 实现智能体分析报告卡片（理财方案/续航测算/画像/推荐含原因）
- 端到端联调

### Step 12: 多模态输入
- 实现语音录制+识别（speech_to_text）
- 实现图片选择+上传
- 图片URL通过WebSocket发送给后端LLM多模态接口

---

## 8. 验证方案

### 后端验证
```bash
# 启动API服务
cd /Users/pengjizhou/Documents/AIPmb && python run_api.py

# 测试REST API
curl http://localhost:8000/api/v1/accounts
curl http://localhost:8000/api/v1/accounts/summary
curl http://localhost:8000/api/v1/transactions?source=all&limit=5
curl http://localhost:8000/api/v1/consumptions/stats?group_by=subcategory&top=5
curl http://localhost:8000/api/v1/wealth/overview
curl http://localhost:8000/api/v1/profile/tags

# 测试智能体API
curl http://localhost:8000/api/v1/agents                              # 列出所有智能体
curl -X POST http://localhost:8000/api/v1/agents/financial_planner/analyze  # 理财专家深度分析
curl -X POST http://localhost:8000/api/v1/agents/consumption_analyst/analyze # 消费分析深度分析
curl -X POST http://localhost:8000/api/v1/agents/life_assistant/analyze      # 生活管家深度分析
curl -X POST http://localhost:8000/api/v1/agents/user_profiler/analyze       # 用户画像深度分析

# 测试WebSocket对话（使用wscat或Postman）
wscat -c ws://localhost:8000/api/v1/chat/ws/test-session
# 发送: {"type":"user_message","content":"我账户里有多少钱","content_type":"text"}
# 预期: 流式返回AI回复，调用query_accounts工具

# 测试智能体路由
# 发送: {"type":"user_message","content":"帮我制定理财方案","content_type":"text"}
# 预期: 路由到理财专家Agent，返回含理财方案卡片的分析结果
# 发送: {"type":"user_message","content":"如果我失业了还能撑多久","content_type":"text"}
# 预期: 路由到消费分析师Agent，返回含续航测算卡片的分析结果
# 发送: {"type":"user_message","content":"推荐一些适合我的优惠","content_type":"text"}
# 预期: 路由到生活管家Agent，返回含推荐原因的分析结果
# 发送: {"type":"user_message","content":"给我画个像，我是怎样的一个人","content_type":"text"}
# 预期: 路由到画像分析师Agent，返回含人格画像和灵感建议的分析结果
# 发送: {"type":"user_message","content":"帮我制定理财方案","content_type":"text","agent_id":"financial_planner"}
# 预期: 显式指定理财专家Agent
```

### 前端验证
```bash
# 启动Flutter应用
cd /Users/pengjizhou/Documents/AIPmb/aipmb_app && flutter run

# 验证项：
# 1. 底部Tab切换正常（此刻/我的）
# 2. "我的"频道显示财富总览和账户列表
# 3. "此刻"频道显示4个智能体入口卡片
# 4. 点击智能体图标 → 进入智能体专属对话页
# 5. AI对话区可输入文字，消息气泡显示智能体头像
# 6. AI回复流式显示
# 7. 智能体"一键分析" → 展示分析报告页（含卡片）
# 8. 推荐卡片位显示待办/产品/优惠
# 9. 语音按钮可录音识别
# 10. 图片按钮可选择上传
```

### 集成验证（智能体场景）
- **理财专家**：输入"帮我制定理财方案" → 预期路由到理财专家 → 调用账户+消费数据 → 返回理财方案（现状分析+产品推荐+预期效果）
- **消费分析师**：输入"如果我失业了能撑多久" → 预期路由到消费分析师 → 调用账户余额+消费统计 → 返回续航测算（不降标准x个月 + 降级方案y个月）
- **生活管家**：输入"推荐一些适合我的产品" → 预期路由到生活管家 → 调用消费偏好+产品库 → 返回推荐列表（含推荐原因）
- **画像分析师**：输入"分析一下我是怎样的人" → 预期路由到画像分析师 → 调用全维度数据 → 返回人格画像+灵感建议
- **跨Agent协作**：先问画像分析师 → 再问理财专家 → 预期理财专家可引用画像数据
- **通用兜底**：输入"查一下余额" → 预期路由到通用助手 → 简单查询回复
