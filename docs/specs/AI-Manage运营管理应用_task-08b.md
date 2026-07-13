# AI-Manage 运营管理应用

## Context

银行运营人员需要一套工具来管理 AI 手机银行背后的大模型配置、分析用户数据、通过 AI 生成用户标签，并将标签与银行产品进行匹配，挖掘推荐机会。该能力需集成到现有 AI 手机银行中，在客户需要产品推荐时自动使用。

## 架构概览

- **后端**: `pmb/ai_manage/` 模块，集成到现有 `pmb` FastAPI 项目
- **前端**: `aipmb_manage/` Flutter Web 项目
- **数据存储**: JSON 文件持久化（模型配置、用户标签、推荐结果、纪念日历）

## Task 1: 创建 ai_manage 基础模块

### Task 1.1: 创建模块结构和工具类
- 创建 `pmb/ai_manage/__init__.py`
- 创建 `pmb/ai_manage/config.py` — 数据目录路径、默认配置
- 创建 `pmb/ai_manage/store.py` — JSON 文件读写工具（线程安全）

### Task 1.2: 创建数据模型
- `pmb/ai_manage/models/__init__.py`
- `pmb/ai_manage/models/model_config.py` — ModelConfig dataclass
- `pmb/ai_manage/models/user_tag.py` — UserTag dataclass
- `pmb/ai_manage/models/match_result.py` — ProductMatch、RecommendationRecord dataclass
- `pmb/ai_manage/models/calendar_event.py` — MemorialEvent、MemorialCalendar dataclass

### Task 1.3: 创建 Pydantic Schema
- `pmb/api/schemas/ai_manage.py` — ModelConfigCreate、ModelConfigUpdate、BatchTagRequest、MatchRequest、CalendarGenerateRequest 等

## Task 2: 大模型配置管理

### Task 2.1: 模型配置服务
- `pmb/ai_manage/services/model_config_service.py` — CRUD 操作，默认从 .env 初始化配置
- 支持列出、创建、更新、删除、激活（切换）模型配置
- 激活时自动将其他配置设为非活跃

### Task 2.2: 模型配置路由
- `pmb/ai_manage/routers/model_config_router.py` — 6 个 REST 端点
- `GET /manage/model-configs` — 列出所有配置
- `POST /manage/model-configs` — 创建配置
- `PUT /manage/model-configs/{id}` — 更新配置
- `DELETE /manage/model-configs/{id}` — 删除配置
- `POST /manage/model-configs/{id}/activate` — 激活配置
- `GET /manage/model-configs/active` — 获取活跃配置

## Task 3: 用户管理

### Task 3.1: 用户服务
- `pmb/ai_manage/services/user_service.py` — 从账户数据中提取用户列表
- 支持按姓名搜索、分页
- 获取用户详情（账户、交易、消费统计）
- 按用户姓名过滤信用卡交易和借记卡交易

### Task 3.2: 用户路由
- `pmb/ai_manage/routers/user_router.py` — 6 个 REST 端点
- `GET /manage/users` — 用户列表（支持搜索）
- `GET /manage/users/{name}` — 用户详情
- `GET /manage/users/{name}/accounts` — 用户账户
- `GET /manage/users/{name}/transactions` — 用户交易
- `GET /manage/users/{name}/consumption-stats` — 消费统计
- `GET /manage/users/{name}/summary` — 汇总信息

## Task 4: AI 用户标签生成

### Task 4.1: 标签服务
- `pmb/ai_manage/services/tagging_service.py` — 核心 AI 标签引擎
- 收集用户消费数据（分类、商户、金额、时段分布）
- 构造 LLM prompt 要求生成有趣、有创意的标签（如"深夜食堂爱好者"、"咖啡续命达人"）
- 解析 LLM 返回的 JSON 结果
- 持久化到 `user_tags.json`
- 支持单个用户和批量生成

### Task 4.2: 标签路由
- `pmb/ai_manage/routers/tagging_router.py` — 4 个 REST 端点
- `GET /manage/tags/{user_name}` — 获取用户标签
- `POST /manage/tags/{user_name}/generate` — 生成标签
- `POST /manage/tags/batch-generate` — 批量生成
- `GET /manage/tags` — 列出所有已标记用户

## Task 5: 用户纪念日历（AI 生成）

### Task 5.1: 纪念日历服务
- `pmb/ai_manage/services/calendar_service.py` — 核心 AI 纪念日历引擎
- 收集用户全部交易和消费记录，按时间线排列
- 通过 LLM 分析交易记录，识别与用户成长、生活紧密相关的关键事件
- 识别的事件类型包括但不限于：
  - **人生里程碑**: 第一笔工资入账、第一张信用卡激活、第一笔投资理财
  - **生活变迁**: 搬家（大额家居消费）、换工作（工资卡变更）、结婚（大额婚庆消费）
  - **重要消费**: 第一次出国旅行、第一辆车、第一套房（大额贷款/消费）
  - **情感记忆**: 每年固定日期的特殊消费（如生日、纪念日相关的餐饮/礼物消费）
  - **成长轨迹**: 收入增长节点、消费升级节点、理财意识觉醒
- 为每个事件生成纪念日期、事件标题、温馨文案、关联交易记录
- 持久化到 `memorial_calendars.json`
- 支持单个用户和批量生成

**LLM Prompt 设计要点**:
- System prompt 引导 AI 扮演"用户人生记录官"角色
- 输入用户交易时间线数据和统计摘要
- 要求输出结构化 JSON：事件日期、事件类型、标题、温馨文案（50-100字）、关联交易记录列表
- 温馨文案要求温暖、感人、有共鸣，避免商业化用语

### Task 5.2: 纪念日历路由
- `pmb/ai_manage/routers/calendar_router.py` — 5 个 REST 端点
- `GET /manage/calendar/{user_name}` — 获取用户纪念日历
- `POST /manage/calendar/{user_name}/generate` — 为单个用户生成纪念日历
- `POST /manage/calendar/batch-generate` — 批量为多个用户生成
- `GET /manage/calendar/{user_name}/events` — 按月份查询纪念事件
- `DELETE /manage/calendar/{user_name}` — 清除缓存

### Task 5.3: 纪念日历数据模型
- `MemorialEvent`: 日期、事件类型、标题、温馨文案、关联交易列表、重要性评分
- `MemorialCalendar`: 用户名、事件列表（按日期排序）、生成时间、使用模型

## Task 6: 产品-标签匹配引擎

### Task 6.1: 匹配服务
- `pmb/ai_manage/services/matching_service.py` — 标签→产品匹配
- 加载所有类别的银行产品
- 对每个标签，使用 LLM 分析产品描述与标签的关联度
- 计算匹配分数(0-1)，输出推荐理由
- 持久化到 `recommendations.json`

### Task 6.2: 匹配路由
- `pmb/ai_manage/routers/matching_router.py` — 4 个 REST 端点
- `POST /manage/matches` — 生成匹配
- `GET /manage/matches/{user_name}` — 获取缓存匹配
- `GET /manage/matches/{user_name}/products` — 匹配产品列表
- `DELETE /manage/matches/{user_name}` — 清除缓存

### Task 6.3: 手机银行集成接口
- `GET /manage/recommendations/{user_name}` — 提供给 AI 手机银行调用的推荐接口
- 优先返回缓存结果，无缓存则触发完整匹配流程

## Task 7: 注册路由到现有 API

- 修改 `pmb/api/app.py`，注册 5 个新路由（前缀 `/api/v1`，标签 `AI-Manage`）
- 修改 `pmb/api/routers/__init__.py`，导出新路由
- 更新 `pyproject.toml`，添加 `openai` 依赖声明

## Task 8: Flutter Web 前端 aipmb_manage/

### Task 8.1: 项目初始化
- 创建 `aipmb_manage/` 项目骨架
- `pubspec.yaml` — dio、flutter_riverpod、go_router、fl_chart、intl
- `lib/main.dart` — MaterialApp.router 入口
- `lib/config/` — api_config.dart、routes.dart、theme.dart

### Task 8.2: 数据模型
- `lib/models/` — model_config.dart、manage_user.dart、user_tag.dart、match_result.dart、calendar_event.dart

### Task 8.3: API 服务层
- `lib/services/api_client.dart` — Dio 封装
- `lib/providers/` — model_config_provider、user_provider、tagging_provider、matching_provider、calendar_provider

### Task 8.4: 页面实现
- **Dashboard** (`dashboard_page.dart`) — 统计概览：用户数、标签数、活跃模型、匹配数、纪念日历数
- **模型配置** (`model_config_list_page.dart`, `model_config_form_page.dart`) — 列表+表单
- **用户列表** (`user_list_page.dart`) — 搜索+分页
- **用户详情** (`user_detail_page.dart`) — 账户、消费图表、操作入口
- **标签生成** (`tagging_page.dart`) — 一键生成，标签展示，批量操作
- **产品匹配** (`matching_page.dart`) — 选择标签→匹配→结果表格
- **纪念日历** (`calendar_page.dart`) — 日历视图展示纪念事件，按月份浏览，点击事件查看详情和温馨文案

### Task 8.5: 通用组件
- `lib/widgets/` — stats_card.dart、tag_chip.dart、match_product_card.dart、calendar_event_card.dart、timeline_widget.dart

## Task 9: 集成测试与验证

- 启动后端 `python run_api.py`，验证所有 `/api/v1/manage/` 端点
- 启动前端 `cd aipmb_manage && flutter run -d chrome`，验证页面功能
- 验证模型配置 CRUD 和切换功能
- 验证标签生成和产品匹配的 AI 能力
- 验证纪念日历生成功能，检查 AI 识别的事件是否合理、文案是否温馨感人
- 验证手机银行推荐接口 `/manage/recommendations/{user_name}` 可正常调用

## 关键设计决策

1. **JSON 文件持久化**: 模型配置、用户标签、推荐结果、纪念日历均存储在 `pmb/ai_manage/data/` 下，线程安全
2. **默认配置**: 首次运行时从 `.env` 读取 LLM_API_KEY 等创建默认配置
3. **LLM 调用**: tagging_service、calendar_service 和 matching_service 均从活跃配置获取 LLM 实例
4. **用户数据过滤**: 信用卡交易按 `持卡人姓名` 过滤，借记卡交易按账户号关联过滤
5. **结果缓存**: 标签、匹配结果和纪念日历持久化，避免重复 LLM 调用
6. **纪念日历生成**: AI 分析用户全部交易时间线，识别人生里程碑、生活变迁、重要消费等关键事件，生成带温馨文案的纪念日历，运营人员可选择单个用户或批量生成