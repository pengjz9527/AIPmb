"""ChromaDB 向量库封装 — 产品知识库的存储与检索"""
import logging
from pathlib import Path

import chromadb
from chromadb.config import Settings as ChromaSettings

from pmb.core.config import CHROMA_DB_DIR, RAG_DEFAULT_TOP_K, RAG_COLLECTION_NAME
from pmb.llm.embedding import EmbeddingAdapter

logger = logging.getLogger(__name__)


class ProductVectorStore:
    """产品知识向量库 — 封装 ChromaDB PersistentClient

    使用 ChromaDB 嵌入式模式，数据持久化到本地目录，
    无需独立的向量数据库服务。
    """

    def __init__(self, persist_dir: str | Path | None = None):
        """
        Args:
            persist_dir: ChromaDB 持久化目录，默认 config.CHROMA_DB_DIR
        """
        self._persist_dir = str(persist_dir or CHROMA_DB_DIR)
        self._client = chromadb.PersistentClient(
            path=self._persist_dir,
            settings=ChromaSettings(anonymized_telemetry=False),
        )
        self._collection = self._client.get_or_create_collection(
            name=RAG_COLLECTION_NAME,
        )

    # ---- 写入 ----

    def add_documents(
        self,
        documents: list[dict],
        embeddings: list[list[float]],
    ):
        """批量添加文档到向量库

        Args:
            documents: builder.build_all_documents() 的输出，每项含 id/text/metadata
            embeddings: EmbeddingAdapter.embed_batch() 的输出，需与 documents 一一对应
        """
        if not documents:
            return

        ids = []
        texts = []
        metadatas = []
        valid_embeddings = []

        for doc, emb in zip(documents, embeddings):
            if emb is None or len(emb) == 0:
                logger.warning("Skipping document '%s' due to empty embedding", doc.get("id"))
                continue
            ids.append(doc["id"])
            texts.append(doc["text"])
            metadatas.append(doc["metadata"])
            valid_embeddings.append(emb)

        if not ids:
            logger.warning("No valid documents to add")
            return

        self._collection.add(
            ids=ids,
            documents=texts,
            metadatas=metadatas,
            embeddings=valid_embeddings,
        )
        logger.info("Added %d documents to collection '%s'", len(ids), RAG_COLLECTION_NAME)

    # ---- 检索 ----

    def search(
        self,
        query: str,
        top_k: int = RAG_DEFAULT_TOP_K,
        category_filter: str | None = None,
    ) -> list[dict]:
        """语义检索产品知识库

        Args:
            query: 用户查询文本
            top_k: 返回 Top-K 结果
            category_filter: 可选产品类别过滤（deposit/loan/...）

        Returns:
            [{id, text, metadata, distance}, ...] 按相似度降序
        """
        # Step 1: 查询向量化
        embedding_adapter = EmbeddingAdapter()
        query_embedding = embedding_adapter.embed(query)
        if query_embedding is None or len(query_embedding) == 0:
            logger.error("Failed to embed query: '%s'", query)
            return []

        # Step 2: ChromaDB 检索
        query_kwargs = {
            "query_embeddings": [query_embedding],
            "n_results": min(top_k, self._collection.count()),
        }
        if category_filter:
            query_kwargs["where"] = {"category": category_filter}

        if query_kwargs["n_results"] <= 0:
            return []

        results = self._collection.query(**query_kwargs)

        # Step 3: 格式化返回
        formatted = []
        ids_list = results.get("ids", [[]])[0]
        documents_list = results.get("documents", [[]])[0]
        metadatas_list = results.get("metadatas", [[]])[0]
        distances_list = results.get("distances", [[]])[0]

        for i in range(len(ids_list)):
            formatted.append({
                "id": ids_list[i],
                "text": documents_list[i],
                "metadata": metadatas_list[i],
                "distance": round(distances_list[i], 4),
            })

        return formatted

    # ---- 管理 ----

    def delete_collection(self):
        """删除整个 Collection（用于重建索引）"""
        try:
            self._client.delete_collection(RAG_COLLECTION_NAME)
            logger.info("Deleted collection '%s'", RAG_COLLECTION_NAME)
        except Exception as e:
            logger.warning("Failed to delete collection: %s", e)

        # 重建空 Collection
        self._collection = self._client.get_or_create_collection(
            name=RAG_COLLECTION_NAME,
        )

    def get_status(self) -> dict:
        """查询索引状态

        Returns:
            {document_count, categories: {category: count, ...}}
        """
        total = self._collection.count()
        categories: dict[str, int] = {}

        if total > 0:
            # 获取所有文档的 metadata 来统计类别分布
            all_data = self._collection.get(include=["metadatas"])
            for meta in (all_data.get("metadatas") or []):
                cat = meta.get("category", "unknown")
                categories[cat] = categories.get(cat, 0) + 1

        return {
            "document_count": total,
            "categories": categories,
            "collection_name": RAG_COLLECTION_NAME,
            "persist_dir": self._persist_dir,
        }
