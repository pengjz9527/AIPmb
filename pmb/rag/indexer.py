"""索引管理器 — 编排产品知识库索引的构建与重建"""
import logging

from pmb.rag.builder import build_all_documents
from pmb.rag.vector_store import ProductVectorStore
from pmb.llm.embedding import EmbeddingAdapter

logger = logging.getLogger(__name__)


class ProductIndexer:
    """产品知识索引管理器

    编排完整的索引构建 / 重建流程：
    1. 从 Excel 生成文本文档
    2. 批量调用 Embedding API 向量化
    3. 存入 ChromaDB 向量库
    """

    def __init__(self):
        self.vector_store = ProductVectorStore()
        self.embedding = EmbeddingAdapter()

    def build_index(self, force: bool = False) -> dict:
        """构建产品知识库索引

        Args:
            force: 是否强制重建（即使索引已存在）

        Returns:
            构建统计 dict
        """
        # Step 1: 检查现有状态
        status = self.vector_store.get_status()
        if status["document_count"] > 0 and not force:
            logger.info(
                "索引已存在（%d 条文档），跳过构建。使用 force=True 强制重建。",
                status["document_count"],
            )
            return {"status": "skipped", "reason": "索引已存在，使用 --force 强制重建", **status}

        # Step 2: 如果 force，删除旧 Collection
        if force and status["document_count"] > 0:
            logger.info("强制重建：删除旧索引...")
            self.vector_store.delete_collection()

        # Step 3: 从 Excel 构建文本文档
        logger.info("正在从 Excel 构建产品文本文档...")
        documents = build_all_documents()
        if not documents:
            logger.warning("没有找到任何产品数据，索引构建终止")
            return {"status": "empty", "reason": "未找到产品数据", "document_count": 0}

        texts = [doc["text"] for doc in documents]
        logger.info("共生成 %d 条产品文档", len(texts))

        # Step 4: 批量向量化
        logger.info("正在调用 Embedding API 批量向量化...")
        embeddings = self.embedding.embed_batch(texts)
        valid_count = sum(1 for e in embeddings if e is not None and len(e) > 0)
        logger.info("向量化完成：%d/%d 条成功", valid_count, len(texts))

        # Step 5: 存入 ChromaDB
        logger.info("正在写入 ChromaDB 向量库...")
        self.vector_store.add_documents(documents, embeddings)

        # Step 6: 返回统计
        final_status = self.vector_store.get_status()
        logger.info(
            "索引构建完成！共 %d 条文档，覆盖 %d 个类别",
            final_status["document_count"],
            len(final_status["categories"]),
        )
        return {"status": "built", **final_status}

    def rebuild_index(self) -> dict:
        """重建索引（删除旧数据后重新构建）"""
        return self.build_index(force=True)

    def get_status(self) -> dict:
        """查询索引状态"""
        return self.vector_store.get_status()
