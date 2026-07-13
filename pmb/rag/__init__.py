"""RAG 模块 — 产品知识库向量检索"""
from pmb.rag.vector_store import ProductVectorStore
from pmb.rag.builder import build_product_document, build_all_documents, build_rag_documents
from pmb.rag.indexer import ProductIndexer

__all__ = [
    "ProductVectorStore",
    "build_product_document",
    "build_all_documents",
    "build_rag_documents",
    "ProductIndexer",
]
