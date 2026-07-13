"""知识库搜索 Skill — 语义检索产品知识库"""
from pmb.skills.base import BaseSkill, SkillResult
from pmb.rag.vector_store import ProductVectorStore


class KnowledgeSearchSkill(BaseSkill):
    """语义搜索产品知识库。

    当用户询问产品推荐、产品对比、产品特性、利率查询等需要从
    银行产品库中获取详细知识的问题时，LLM 应调用此技能。
    与 query_products 的结构化查询互补，本技能提供语义级别的模糊检索。
    """

    @property
    def name(self) -> str:
        return "knowledge_search"

    @property
    def description(self) -> str:
        return (
            "搜索银行产品知识库和通用知识文档，获取相关产品和政策的详细知识。"
            "适用于产品推荐、产品对比、产品特性查询、利率查询、银行政策咨询等。"
            "输入自然语言查询描述文本，返回语义最匹配的知识片段。"
            "适用场景：'推荐低风险理财产品'、'有什么存款'、"
            "'哪个贷款利率低'、'提前还贷违约金怎么算'、"
            "'R2风险的理财有哪些'、'外汇额度限制'等。"
        )

    @property
    def parameters_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "用户关于产品的自然语言查询，如'低风险理财产品'、'招商银行的贷款'",
                },
                "category": {
                    "type": "string",
                    "enum": ["deposit", "loan", "wealth", "fund", "insurance", "forex", "gold", "knowledge", ""],
                    "description": "类别过滤：deposit存款/loan贷款/wealth理财/fund基金/insurance保险/forex外汇/gold黄金/knowledge通用知识文档，空不限制",
                },
                "top_k": {
                    "type": "integer",
                    "description": "返回结果数量，默认5条",
                },
            },
            "required": ["query"],
        }

    async def execute(self, **kwargs) -> SkillResult:
        user_name = kwargs.get("user_name", "")
        query = kwargs.get("query", "")
        category = kwargs.get("category", "")
        top_k = kwargs.get("top_k", 5)

        if not query:
            return SkillResult(
                success=False,
                error="缺少查询参数 query",
                summary="知识搜索失败：缺少查询内容",
            )

        # 确保 top_k 在合理范围
        try:
            top_k = int(top_k)
        except (TypeError, ValueError):
            top_k = 5
        top_k = max(1, min(top_k, 20))

        try:
            # 初始化向量库并检索
            vector_store = ProductVectorStore()

            # 检查索引是否存在
            status = vector_store.get_status()
            if status["document_count"] == 0:
                return SkillResult(
                    success=False,
                    error="产品知识库索引尚未构建，请先执行 'pmb rag build' 命令构建索引",
                    data={"query": query, "results": []},
                    summary="知识搜索失败：索引未构建",
                )

            category_filter = category if category else None
            results = vector_store.search(
                query=query,
                top_k=top_k,
                category_filter=category_filter,
            )

            if not results:
                return SkillResult(
                    success=True,
                    data={
                        "query": query,
                        "category": category,
                        "results": [],
                    },
                    summary=f"未找到与'{query}'相关的产品知识",
                )

            # 格式化结果
            formatted_results = []
            for i, r in enumerate(results):
                formatted_results.append({
                    "rank": i + 1,
                    "text": r["text"],
                    "score": round(1.0 - r["distance"], 4) if r["distance"] <= 1.0 else round(1.0 / (1.0 + r["distance"]), 4),
                    "metadata": r["metadata"],
                })

            categories_found = list(set(r["metadata"].get("category_label", "") for r in results))
            summary = f"找到 {len(results)} 条相关产品知识，涉及 {', '.join(categories_found)} 等类别"

            return SkillResult(
                success=True,
                data={
                    "query": query,
                    "category": category,
                    "results": formatted_results,
                },
                summary=summary,
            )

        except Exception as e:
            return SkillResult(
                success=False,
                error=str(e),
                data={"query": query},
                summary=f"知识搜索出错: {str(e)}",
            )
