# 产品知识库 RAG 实施计划

## Context

AIPmb 当前通过 Agent + Skill + LLM (Function Calling) 架构处理用户请求。Skill 从 Excel 返回结构化产品数据（利率、期限等），但 LLM 无法"理解"产品说明书级别的详细描述。本项目为用户引入 RAG（检索增强生成）能力，以产品知识库为第一个落地场景，让 LLM 能基于产品文档的语义检索结果回答用户关于产品推荐、对比、特性等细粒度问题。

## 技术选型

| 组件 | 选择 | 理由 |
|------|------|------|
| 向量数据库 | ChromaDB（嵌入式 PersistentClient） | 纯 Python，无需独立服务，持久化本地 |
| Embedding 模型 | 百炼 text-embedding-v3（1024维） | 项目已依赖 `dashscope>=1.14.0`，中文效果好 |
| 文档构建 | 自定义 builder（Excel行 → 自然语言文本） | 产品字段格式不统一，需按类别定制模板 |
| 检索接口 | knowledge_search Skill（Function Calling） | 复用现有 Skill 架构，LLM 自主调用 |

---

## 新建/修改文件清单

### Phase 1: 配置与依赖

**Task 1.1** — 修改 `pmb/core/config.py`，追加 RAG/Embedding 配置：
```python
# ========== RAG / Embedding 配置 ==========
DASHSCOPE_API_KEY = os.environ.get("DASHSCOPE_API_KEY", "")
CHROMA_DB_DIR = PROJECT_ROOT / "pmb" / "rag" / "chroma_db"
RAG_DEFAULT_TOP_K = 5
RAG_COLLECTION_NAME = "product_knowledge"
```

**Task 1.2** — 修改 `pyproject.toml`，`dependencies` 追加 `"chromadb>=0.5.0"`。

**Task 1.3** — 修改 `.env`，追加 `DASHSCOPE_API_KEY=sk-xxx`（需用户手动填写真实 Key）。

### Phase 2: Embedding 适配器

**Task 2.1** — 新建 `pmb/llm/embedding.py`：
- 类 `EmbeddingAdapter`
  - `__init__(self, api_key, model)`：默认 `DASHSCOPE_API_KEY` + `text-embedding-v3`
  - `embed(text: str) -> list[float]`：单文本嵌入
  - `embed_batch(texts: list[str]) -> list[list[float]]`：批量嵌入，自动分片（25条/批）
  - `_call_api(texts) -> list[list[float]]`：调用 `dashscope.TextEmbedding.call()`
- 错误处理：API 失败打印警告并返回空列表

### Phase 3: RAG 核心模块（`pmb/rag/`）

**Task 3.1** — 新建 `pmb/rag/__init__.py`：导出 `ProductVectorStore`, `build_all_documents`, `ProductIndexer`。

**Task 3.2** — 新建 `pmb/rag/builder.py`：
- `build_product_document(row: dict, category: str) -> str`：单行Excel → 自然语言文本
  - 按类别使用不同模板（deposit/loan/wealth/fund/insurance/forex/gold）
  - 缺字段用 `"暂无"` 占位
- `build_all_documents() -> list[dict]`：遍历7类产品，返回 `[{id, text, metadata}, ...]`
  - ID格式：`"{category}_{index}"`
  - metadata：`{category, category_label, bank, product_name, doc_id}`

**Task 3.3** — 新建 `pmb/rag/vector_store.py`：
- 类 `ProductVectorStore`
  - `__init__(persist_dir)`：初始化 `chromadb.PersistentClient`，get_or_create Collection
  - `add_documents(documents, embeddings)`：批量写入（id + text + metadata + embedding）
  - `search(query, top_k, category_filter) -> list[dict]`：
    1. 实例化 `EmbeddingAdapter`，调用 `embed(query)` 得到查询向量
    2. `collection.query(query_embeddings=[vec], n_results=top_k, where={...})`
    3. 返回 `[{id, text, metadata, distance}]`
  - `delete_collection()`：删除并重建
  - `get_status() -> dict`：文档总数、各类别数量

**Task 3.4** — 新建 `pmb/rag/indexer.py`：
- 类 `ProductIndexer`
  - `build_index(force=False) -> dict`：
    1. 检查现有状态，已存在则跳过（除非 force=True）
    2. force 时先 `delete_collection()`
    3. `build_all_documents()` → 文本列表
    4. `embed_batch()` 分25条/批向量化，打印进度
    5. `add_documents()` 写入 ChromaDB
    6. 返回统计信息
  - `rebuild_index()`：`build_index(force=True)`
  - `get_status()`：代理到 `vector_store.get_status()`

### Phase 4: knowledge_search Skill

**Task 4.1** — 新建 `pmb/skills/domain/knowledge_search.py`：
- 类 `KnowledgeSearchSkill(BaseSkill)`
  - `name = "knowledge_search"`
  - `description`：描述语义搜索产品知识库的用途和适用场景
  - `parameters_schema`：`query`（必填，string）、`category`（可选，enum 7类+空）、`top_k`（可选，int，默认5）
  - `async execute(**kwargs) -> SkillResult`：
    1. 提取 query/category/top_k
    2. 实例化 `EmbeddingAdapter` + `ProductVectorStore`
    3. 调用 `vector_store.search(query, top_k, category)`
    4. 格式化返回 `{query, results: [{rank, text, score, metadata}]}`
    5. 无索引时返回明确错误

**Task 4.2** — 修改 `pmb/skills/orchestrator.py`：
- 在 `_register_all_skills()` 中 `import KnowledgeSearchSkill` 并 `register()`

### Phase 5: CLI 索引管理命令

**Task 5.1** — 新建 `pmb/commands/rag_commands.py`：
- `app = typer.Typer(help="RAG知识库索引管理")`
- `build` 命令：`ProductIndexer().build_index(force=...)`
- `status` 命令：`ProductIndexer().get_status()`
- `rebuild` 命令：`ProductIndexer().rebuild_index()`

**Task 5.2** — 修改 `pmb/cli.py`：
- `import pmb.commands.rag_commands`
- `app.add_typer(rag_commands.app, name="rag")`

### Phase 6: 验证与 .gitignore

**Task 6.1** — 修改 `.gitignore`，追加 `pmb/rag/chroma_db/`（向量库数据不入库）。

---

## 依赖关系与实施顺序

```
Task 1.1-1.3 (配置+依赖) ──→ Task 2.1 (Embedding) ──→ Task 3.1-3.4 (RAG模块)
                                                            │
                                                            ├──→ Task 4.1-4.2 (Skill)
                                                            └──→ Task 5.1-5.2 (CLI)
```

---

## 验证方案

1. **依赖安装**：`pip install chromadb` 确认无版本冲突
2. **Embedding 测试**：Python 中实例化 `EmbeddingAdapter`，调用 `embed("测试文本")`，验证返回 1024 维向量
3. **索引构建**：执行 `pmb rag build`，确认：
   - 7 类产品全部被索引
   - 日志输出进度和统计信息
   - `pmb/rag/chroma_db/` 目录生成持久化文件
4. **检索测试**：Python 中调用 `ProductVectorStore().search("低风险理财", top_k=3)`，验证返回相关结果
5. **Skill 注册**：启动 API 服务，确认 `GET /api/v1/skills` 返回列表中包含 `knowledge_search`
6. **端到端测试**：向 `/api/v1/chat` 发送"推荐低风险理财产品"，验证 LLM 调用了 `knowledge_search` Skill 并基于检索结果回答
