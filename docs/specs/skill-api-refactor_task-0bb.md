## Context

**问题**: AI 对话输出的理财推荐包含 `[查看详情](/product?product_name=XXX)` 和 `[马上购买](/buy?product_name=XXX)` Markdown 链接，点击后无响应。

**根因**: `message_bubble.dart` 和 `markdown_table_cards.dart` 使用 `MarkdownConfig.defaultConfig` 未配置 `LinkConfig.onTap` 回调，且缺少产品详情页和购买申请页。

**目标**: 打通 "对话链接 → 产品详情 → 购买申请" 全链路。

---

## 架构总览

```
AI 对话气泡 (MessageBubble)
  → MarkdownBlock/MobileMarkdownRenderer + LinkConfig.onTap
    ├── /product?product_name=xxx → ProductDetailPage → GET /api/v1/products/{name}
    └── /buy?product_name=xxx     → PurchasePage → POST /api/v1/purchases
```

---

## Task 1: 后端 — 新建购买申请 API

**1.1 CREATE `pmb/api/schemas/purchase.py`**
- `PurchaseRequest`: product_name (str) + amount (float)
- `PurchaseResponse`: id, user_name, product_name, amount, status, created_at

**1.2 CREATE `pmb/core/purchase_service.py`**
- `create_purchase(user_name, product_name, amount)` — 生成 UUID，写入 `pmb/ai_manage/data/purchases.json`
- 复用 `pmb/ai_manage/store.py` 的 `read_json`/`write_json` 线程安全存储

**1.3 CREATE `pmb/api/routers/purchase_router.py`**
- `POST /api/v1/purchases` — 从 `x-user-name` Header 获取用户，验证 amount > 0，调用 purchase_service
- 复用 `recommendation_router.py` 的 `_decode_user_name()` 解码

**1.4 MODIFY `pmb/api/app.py`**
- import purchase_router，注册路由 `app.include_router(purchase_router.router, prefix="/api/v1", tags=["购买"])`

---

## Task 2: Flutter — Markdown 链接点击拦截

**2.1 MODIFY `aipmb_app/lib/widgets/chat/message_bubble.dart`**
- 新增 `_buildMarkdownConfig(BuildContext context)` 方法：创建 `MarkdownConfig` 带 `LinkConfig(onTap: ...)`
- 新增 `_handleMarkdownLink(BuildContext context, String url)` 方法：
  - 解析 `uri.path == '/product'` → `context.push('/product/detail?product_name=...')`
  - 解析 `uri.path == '/buy'` → `context.push('/purchase?product_name=...')`
- 修改 `_buildMobileMarkdown` 使用 `_buildMarkdownConfig(context)` 替代 `MarkdownConfig.defaultConfig`

**2.2 MODIFY `aipmb_app/lib/widgets/chat/markdown_table_cards.dart`**
- `buildWidgets` 方法增加可选 `MarkdownConfig? config` 参数，透传至 `_buildTextBlock`
- `_buildTextBlock` 方法增加可选 `MarkdownConfig? config` 参数

---

## Task 3: Flutter — 产品详情页（聊天入口）

**3.1 CREATE `aipmb_app/lib/models/product_detail.dart`**
- `ProductDetail` 类：name, bank, typeLabel, category, categoryLabel, description, riskLevel
- `fromJson` 映射后端 `map_product()` 输出的英文 key

**3.2 CREATE `aipmb_app/lib/pages/product/product_detail_page.dart`**
- `ProductDetailPage(productName: String)` — StatefulWidget
- `initState()`: 调用 `GET /api/v1/products/$productName`
- 展示：银行、产品名称、类型、类别、描述、风险等级
- 底部 "马上购买" Button → `context.push('/purchase?product_name=...')`
- 加载态 CircularProgressIndicator，错误态重试按钮

---

## Task 4: Flutter — 购买申请页

**4.1 CREATE `aipmb_app/lib/pages/purchase/purchase_page.dart`**
- `PurchasePage(productName: String)` — StatefulWidget
- 表单：产品名称(只读显示) + 购买金额(TextFormField，数字键盘，验证 > 0)
- "确认购买" Button：
  - `POST /api/v1/purchases {product_name, amount}`
  - `x-user-name` 由 ApiClient interceptor 自动注入
  - 成功 → AlertDialog 提示"购买申请已提交，请等待审核"
  - 失败 → SnackBar 显示错误信息
  - 提交中显示 loading 状态

---

## Task 5: Flutter — 路由注册 & 配置

**5.1 MODIFY `aipmb_app/lib/config/routes.dart`**
- import ProductDetailPage, PurchasePage
- 新增 `GoRoute('/product/detail')` 和 `GoRoute('/purchase')`

**5.2 MODIFY `aipmb_app/lib/config/api_config.dart`**
- 新增 `static const String purchases = '/api/v1/purchases'`

---

## Task 6: 后端 — LLM Prompt 增强（可选）

**6.1 MODIFY `pmb/agents/general_assistant.py`**
- 产品推荐约束中补充：链接必须使用绝对路径格式，以 / 开头

---

## 文件变更汇总

| # | 操作 | 文件 |
|---|------|------|
| 1 | CREATE | `pmb/api/schemas/purchase.py` |
| 2 | CREATE | `pmb/core/purchase_service.py` |
| 3 | CREATE | `pmb/api/routers/purchase_router.py` |
| 4 | MODIFY | `pmb/api/app.py` |
| 5 | MODIFY | `pmb/agents/general_assistant.py` |
| 6 | CREATE | `aipmb_app/lib/models/product_detail.dart` |
| 7 | CREATE | `aipmb_app/lib/pages/product/product_detail_page.dart` |
| 8 | CREATE | `aipmb_app/lib/pages/purchase/purchase_page.dart` |
| 9 | MODIFY | `aipmb_app/lib/widgets/chat/message_bubble.dart` |
| 10 | MODIFY | `aipmb_app/lib/widgets/chat/markdown_table_cards.dart` |
| 11 | MODIFY | `aipmb_app/lib/config/routes.dart` |
| 12 | MODIFY | `aipmb_app/lib/config/api_config.dart` |

---

## 验证

1. 重启后端 → 模拟器运行 APP
2. 在对话中说"推荐个性化理财方案"
3. 检查 AI 回复中的 **[查看详情]** 和 **[马上购买]** 链接可点击
4. 点击 **[查看详情]** → 跳转到产品详情页，显示完整产品信息（银行、类型、描述、风险等级）
5. 在产品详情页点击 **[马上购买]** → 跳转到购买页
6. 填写购买金额（如 50000）并提交 → 显示"购买申请已提交"提示
7. 检查 `pmb/ai_manage/data/purchases.json` 有新增记录
