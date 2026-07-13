# 用户投资风险测评功能实现计划

## Context

为用户新增投资风险等级评估功能，包括：JSON 数据表存储、FastAPI 查询/写入接口、"我的"页面风险等级展示、完整的 10 题测评问卷（C1-C5 评级，有效期 1 年）。已有用户彭楫洲预置 C3 等级，王小美未评级。

## 实现任务

### Task 1: 创建种子数据文件

**文件**: `pmb/ai_manage/data/risk_assessments.json` (新建)

写入初始数据：彭楫洲 `risk_level="C3"`, `expiry_date="2026/07/18"`。王小美无记录（表示未评级）。

```json
[
  {
    "id": 1,
    "user_name": "彭楫洲",
    "risk_level": "C3",
    "expiry_date": "2026/07/18",
    "created_at": "2026-06-11T00:00:00"
  }
]
```

### Task 2: 创建后端服务层

**文件**: `pmb/ai_manage/services/risk_assessment_service.py` (新建)

- `get_assessment(user_name)` → 查询用户最新测评记录，含有效期判断（当前日期 > expiry_date → 标记 expired=true）
- `save_assessment(user_name, risk_level, expiry_date)` → 追加新记录（id 自增），不覆盖历史
- 使用 `read_json`/`write_json` 工具，遵循与 `profile_portrait_service.py` 相同的 JSON 存储模式

### Task 3: 创建后端路由

**文件**: `pmb/ai_manage/routers/risk_assessment_router.py` (新建)

- `GET /api/v1/risk-assessment?user_name=xxx` → 查询测评结果。`x-user-name` header 作为备选。未评级返回 `{"risk_level": "", "assessed": false}`
- `POST /api/v1/risk-assessment` → 保存测评结果，校验 risk_level 必须是 C1-C5
- 使用内联 Pydantic `BaseModel` 做请求体验证
- 复用 `held_product_router.py` 的 `_get_user_name()` 模式

### Task 4: 注册路由

**文件**: `pmb/api/app.py` (修改)

- 在 import 区域添加 `risk_assessment_router`
- 在路由注册区域添加 `app.include_router(risk_assessment_router.router, prefix="/api/v1", tags=["风险测评"])`

### Task 5: 前端数据模型

**文件**: `aipmb_app/lib/models/risk_assessment.dart` (新建)

- `RiskAssessment` 类：id, userName, riskLevel, expiryDate, createdAt, expired
- `isAssessed` getter: riskLevel 非空且未过期
- `displayLevel` getter: 返回等级或"未评级"
- `fromJson` 工厂方法，所有字段有默认值容错

### Task 6: API 常量与 Provider

**文件**: `aipmb_app/lib/config/api_config.dart` (修改)

- 添加 `static const String riskAssessment = '/api/v1/risk-assessment';`

**文件**: `aipmb_app/lib/providers/risk_assessment_provider.dart` (新建)

- `riskAssessmentProvider` (FutureProvider) — 通过 ApiClient.get 获取当前用户测评数据
- `submitRiskAssessment()` 函数 — 调用 ApiClient.post 提交测评结果
- 提交后调用方需 `ref.invalidate(riskAssessmentProvider)` 刷新

### Task 7: 风险测评问卷页面

**文件**: `aipmb_app/lib/pages/risk_assessment/risk_assessment_page.dart` (新建)

10 道题，每题 5 个选项 (A-E, 分值 1-5)，覆盖以下维度：

| 题号 | 维度 | 分值逻辑 |
|------|------|----------|
| 1 | 年龄 | 年龄越大分越低（保守） |
| 2 | 投资经验 | 经验越多分越高 |
| 3 | 金融知识 | 了解越多分越高 |
| 4 | 收入稳定性 | 越稳定分越高 |
| 5 | 投资占比 | 占比越高分越高 |
| 6 | 风险偏好 | 越激进分越高 |
| 7 | 投资目标 | 从保本到最大回报 |
| 8 | 亏损反应 | 从全部卖出到大幅追加 |
| 9 | 投资期限 | 越长分越高 |
| 10 | 流动性需求 | 需求越低分越高 |

**计分映射**: 总分 10-50 → C1(≤20), C2(21-30), C3(31-38), C4(39-45), C5(46-50)

**有效期**: 提交日 + 365 天，格式 `YYYY/MM/DD`

**UI**: PageView 逐题展示，底部进度圆点，第 10 题显示"提交测评"按钮。提交后 invalidate provider → pop 返回。

### Task 8: MinePage 改造与路由注册

**文件**: `aipmb_app/lib/pages/mine/mine_page.dart` (修改)

- 在"我的"页面用户信息卡片下方、财富总览卡片上方，新增风险测评卡片
- 卡片显示当前风险等级和到期时间（已评级）或"尚未进行风险测评"（未评级）
- 未评级时显示"马上评级"按钮，已评级时显示"重新测评"按钮
- 点击按钮导航至 `/risk-assessment` 路由

**文件**: `aipmb_app/lib/config/routes.dart` (修改)

- 添加 `RiskAssessmentPage` 和 `riskAssessmentProvider` import
- 新增 GoRoute `/risk-assessment`，通过 query 参数传递用户名

### Task 9: AuthProvider 刷新集成

**文件**: `aipmb_app/lib/providers/auth_provider.dart` (修改)

- 在 `_invalidateAllDataProviders()` 中增加 `_ref.invalidate(riskAssessmentProvider)`
- 确保退出登录/切换用户时清除旧测评数据缓存

## 验证方式

1. 启动 FastAPI 后端：`python run_api.py`
2. 验证 API：`curl http://localhost:8000/api/v1/risk-assessment?user_name=彭楫洲` → 应返回 C3 数据
3. 验证 API：`curl http://localhost:8000/api/v1/risk-assessment?user_name=王小美` → 应返回 `assessed: false`
4. 验证 API：`curl -X POST http://localhost:8000/api/v1/risk-assessment -H "Content-Type: application/json" -d '{"user_name":"王小美","risk_level":"C2","expiry_date":"2027/06/11"}'` → 保存成功
5. 在模拟器中启动 Flutter App，进入"我的"页面 → 彭楫洲应显示 C3 风险等级卡片；王小美应显示"马上评级"按钮
6. 点击"马上评级" → 进入测评问卷页面 → 完成 10 题 → 提交 → 返回"我的"页面 → 卡片更新为新等级
7. `flutter analyze` 零错误
