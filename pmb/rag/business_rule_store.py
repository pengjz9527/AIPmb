"""业务规则向量库 — 独立的 ChromaDB Collection 存储业务规则约束"""
import logging
from pathlib import Path

import chromadb
from chromadb.config import Settings as ChromaSettings

from pmb.core.config import (
    CHROMA_DB_DIR,
    BUSINESS_RULES_COLLECTION,
    RULES_TOP_K,
)
from pmb.llm.embedding import EmbeddingAdapter

logger = logging.getLogger(__name__)


class BusinessRuleStore:
    """业务规则向量库 — 封装 ChromaDB PersistentClient

    与 ProductVectorStore 使用相同的 ChromaDB 持久化目录，
    但存储在独立的 Collection `business_rules` 中。
    """

    def __init__(self, persist_dir: str | Path | None = None):
        self._persist_dir = str(persist_dir or CHROMA_DB_DIR)
        self._client = chromadb.PersistentClient(
            path=self._persist_dir,
            settings=ChromaSettings(anonymized_telemetry=False),
        )
        self._collection = self._client.get_or_create_collection(
            name=BUSINESS_RULES_COLLECTION,
        )

    # ---- 写入 ----

    def add_rules(
        self,
        rules: list[dict],
        embeddings: list[list[float]],
    ):
        """批量添加规则到向量库

        Args:
            rules: BusinessRuleIndexer.parse_rules() 的输出，
                   每项含 id/text/metadata(rule_id, scenario, tags, source_file)
            embeddings: EmbeddingAdapter.embed_batch() 的输出
        """
        if not rules:
            return

        ids = []
        texts = []
        metadatas = []
        valid_embeddings = []

        for rule, emb in zip(rules, embeddings):
            if emb is None or len(emb) == 0:
                logger.warning("Skipping rule '%s' due to empty embedding", rule.get("id"))
                continue
            ids.append(rule["id"])
            texts.append(rule["text"])
            metadatas.append(rule["metadata"])
            valid_embeddings.append(emb)

        if not ids:
            logger.warning("No valid rules to add")
            return

        self._collection.add(
            ids=ids,
            documents=texts,
            metadatas=metadatas,
            embeddings=valid_embeddings,
        )
        logger.info("Added %d rules to collection '%s'", len(ids), BUSINESS_RULES_COLLECTION)

    # ---- 检索 ----

    def search(
        self,
        query: str,
        top_k: int = RULES_TOP_K,
    ) -> list[dict]:
        """语义检索匹配的业务规则

        Args:
            query: 用户查询文本
            top_k: 返回 Top-K 结果

        Returns:
            [{id, text, metadata: {rule_id, scenario, tags, source_file}, distance}, ...]
        """
        embedding_adapter = EmbeddingAdapter()
        query_embedding = embedding_adapter.embed(query)
        if query_embedding is None or len(query_embedding) == 0:
            logger.error("Failed to embed query: '%s'", query)
            return []

        n_results = min(top_k, self._collection.count())
        if n_results <= 0:
            return []

        results = self._collection.query(
            query_embeddings=[query_embedding],
            n_results=n_results,
        )

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

    @property
    def count(self) -> int:
        return self._collection.count()

    def delete_collection(self):
        """删除整个 Collection（用于重建索引）"""
        try:
            self._client.delete_collection(BUSINESS_RULES_COLLECTION)
            logger.info("Deleted collection '%s'", BUSINESS_RULES_COLLECTION)
        except Exception as e:
            logger.warning("Failed to delete collection: %s", e)

        self._collection = self._client.get_or_create_collection(
            name=BUSINESS_RULES_COLLECTION,
        )

    def get_status(self) -> dict:
        """查询索引状态"""
        total = self._collection.count()
        sources: dict[str, int] = {}

        if total > 0:
            all_data = self._collection.get(include=["metadatas"])
            for meta in (all_data.get("metadatas") or []):
                src = meta.get("source_file", "unknown")
                sources[src] = sources.get(src, 0) + 1

        return {
            "rule_count": total,
            "sources": sources,
            "collection_name": BUSINESS_RULES_COLLECTION,
        }
