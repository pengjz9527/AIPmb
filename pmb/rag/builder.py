"""产品文档构建器 — 将 Excel 产品行 + rag_docs/ 通用文档转换为自然语言文本"""
import logging
from pathlib import Path

from pmb.core.config import PRODUCT_FILES, PRODUCT_CATEGORY_NAMES, RAG_DOCS_DIR
from pmb.core.loader import loader

logger = logging.getLogger(__name__)


def build_product_document(row: dict, category: str) -> str:
    """将一行产品数据转换为自然语言描述文本

    Args:
        row: Excel 原始行 dict（中文列名）
        category: 产品类别 key（deposit/loan/wealth/fund/insurance/forex/gold）

    Returns:
        自然语言描述的文本，如：
        "招商银行的产品'整存整取'，属于存款产品大类。产品描述：..."
    """
    bank = str(row.get("银行", "") or "未知银行")
    description = str(row.get("产品描述", "") or "暂无描述")

    if category == "deposit":
        name = str(row.get("产品名称", "") or "未知产品")
        type_label = str(row.get("产品大类", "") or "暂无")
        return f"{bank}的存款产品'{name}'，属于{type_label}类。产品描述：{description}"

    elif category == "loan":
        name = str(row.get("产品名称", "") or "未知产品")
        type_label = str(row.get("产品大类", "") or "暂无")
        rate = str(row.get("贷款利率参考", "") or "暂无")
        term = str(row.get("贷款期限", "") or "暂无")
        max_amount = str(row.get("最高贷款金额", "") or "暂无")
        repayment = str(row.get("还款方式", "") or "暂无")
        guarantee = str(row.get("担保方式", "") or "暂无")
        condition = str(row.get("申请条件", "") or "暂无")
        channel = str(row.get("申请渠道", "") or "暂无")
        return (
            f"{bank}的贷款产品'{name}'，属于{type_label}类。"
            f"参考利率{rate}，贷款期限{term}，最高额度{max_amount}，"
            f"还款方式{repayment}，担保方式{guarantee}，"
            f"申请条件{condition}，申请渠道{channel}。"
            f"产品描述：{description}"
        )

    elif category == "wealth":
        name = str(row.get("产品名称/类别", "") or "未知产品")
        type_label = str(row.get("产品类型", "") or "暂无")
        risk = str(row.get("风险等级", "") or "暂无")
        return (
            f"{bank}的理财产品'{name}'，产品类型{type_label}，"
            f"风险等级{risk}。产品描述：{description}"
        )

    elif category == "fund":
        name = str(row.get("基金类别", "") or "未知产品")
        type_label = str(row.get("基金类型", "") or "暂无")
        risk = str(row.get("风险等级", "") or "暂无")
        return (
            f"{bank}的基金产品'{name}'，基金类型{type_label}，"
            f"风险等级{risk}。产品描述：{description}"
        )

    elif category == "insurance":
        name = str(row.get("产品名称/类别", "") or "未知产品")
        type_label = str(row.get("保险类型", "") or "暂无")
        return (
            f"{bank}的保险产品'{name}'，保险类型{type_label}。"
            f"产品描述：{description}"
        )

    elif category == "forex":
        name = str(row.get("产品名称/业务", "") or "未知产品")
        type_label = str(row.get("业务类型", "") or "暂无")
        return (
            f"{bank}的外汇产品'{name}'，业务类型{type_label}。"
            f"产品描述：{description}"
        )

    elif category == "gold":
        name = str(row.get("产品名称", "") or "未知产品")
        type_label = str(row.get("产品类别", "") or "暂无")
        return (
            f"{bank}的黄金产品'{name}'，产品类别{type_label}。"
            f"产品描述：{description}"
        )

    # 兜底
    return f"{bank}的产品。产品描述：{description}"


def _get_product_name(row: dict, category: str) -> str:
    """从产品行中提取产品名称"""
    name_fields = {
        "deposit": "产品名称",
        "loan": "产品名称",
        "wealth": "产品名称/类别",
        "fund": "基金类别",
        "insurance": "产品名称/类别",
        "forex": "产品名称/业务",
        "gold": "产品名称",
    }
    field = name_fields.get(category, "产品名称")
    return str(row.get(field, "") or "未知产品")


def build_all_documents() -> list[dict]:
    """构建全部文档列表：产品 Excel + rag_docs/ 通用知识文档

    Returns:
        list[dict]，每个 dict 包含：
          - id: 唯一标识
          - text: 自然语言描述文本
          - metadata: {category, category_label, ...}
    """
    documents = []

    # ---- 产品 Excel 文档 ----
    for category, filepath in PRODUCT_FILES.items():
        if not filepath.exists():
            continue

        rows = loader.load_products(category)
        category_label = PRODUCT_CATEGORY_NAMES.get(category, category)

        for idx, row in enumerate(rows):
            text = build_product_document(row, category)
            bank = str(row.get("银行", "") or "未知银行")
            product_name = _get_product_name(row, category)
            doc_id = f"{category}_{idx}"

            documents.append({
                "id": doc_id,
                "text": text,
                "metadata": {
                    "category": category,
                    "category_label": category_label,
                    "bank": bank,
                    "product_name": product_name,
                    "doc_id": doc_id,
                },
            })

    # ---- rag_docs/ 通用知识文档 ----
    documents.extend(build_rag_documents())

    return documents


# ========== 通用知识文档构建 ==========

# 支持的文本文件后缀
_SUPPORTED_SUFFIXES = {".md", ".txt", ".markdown"}
# 文档按标题分块时，每个块的最小字符数（小于此值合并到上一块）
_CHUNK_MIN_CHARS = 80


def build_rag_documents(docs_dir: str | Path | None = None) -> list[dict]:
    """遍历 rag_docs/ 目录，将 .md / .txt 文件按 ## 标题分块后返回

    Args:
        docs_dir: 文档目录，默认 RAG_DOCS_DIR

    Returns:
        list[dict]，每个 dict 包含：
          - id: "{filename}_{chunk_idx}"
          - text: 文档块内容
          - metadata: {category: "knowledge", source_file, title, chunk_idx, ...}
    """
    docs_dir = Path(docs_dir or RAG_DOCS_DIR)
    if not docs_dir.exists():
        logger.info("rag_docs/ 目录不存在，跳过通用文档索引")
        return []

    documents: list[dict] = []
    for filepath in sorted(docs_dir.rglob("*")):
        if not filepath.is_file():
            continue
        suffix = filepath.suffix.lower()
        if suffix not in _SUPPORTED_SUFFIXES:
            continue

        content = filepath.read_text(encoding="utf-8")
        if not content.strip():
            continue

        # 用相对路径 stem 生成唯一 ID 前缀，避免同名文件冲突
        rel_path = filepath.relative_to(docs_dir)
        id_prefix = str(rel_path.with_suffix("")).replace("/", "__")
        chunks = _split_by_headings(content, id_prefix)
        for c in chunks:
            documents.append({
                "id": c["id"],
                "text": c["text"],
                "metadata": {
                    "category": "knowledge",
                    "category_label": "知识文档",
                    "source_file": filepath.name,
                    "title": c["title"],
                    "chunk_idx": c["chunk_idx"],
                    "doc_id": c["id"],
                },
            })

    logger.info("从 rag_docs/ 加载了 %d 个文档块（%d 个文件）", len(documents),
                len(set(d["metadata"]["source_file"] for d in documents)))
    return documents


def _split_by_headings(content: str, filename: str) -> list[dict]:
    """按 ## 标题分块，小段落合并到上一块"""
    import re

    # 用 ## 分割（保留分隔符）
    parts = re.split(r"(?=^## )", content, flags=re.MULTILINE)

    chunks: list[dict] = []
    pending: list[str] = []  # 待合并的小段落
    pending_title = ""
    chunk_idx = 0

    for part in parts:
        part = part.strip()
        if not part:
            continue

        # 提取标题
        title_match = re.match(r"^## (.+)$", part, re.MULTILINE)
        title = title_match.group(1).strip() if title_match else ""
        body = re.sub(r"^## .+\n?", "", part, flags=re.MULTILINE).strip()

        if len(body) < _CHUNK_MIN_CHARS and pending:
            # 小块合并到上一块
            pending.append(body)
            continue

        # 提交上一个 pending 块
        if pending:
            merged = "\n\n".join(pending)
            if len(merged) >= _CHUNK_MIN_CHARS:
                chunks.append({
                    "id": f"{filename}_{chunk_idx}",
                    "title": pending_title or filename,
                    "text": merged,
                    "chunk_idx": chunk_idx,
                })
                chunk_idx += 1
            pending = []

        if body:
            pending = [body]
            pending_title = title

    # 最后一块
    if pending:
        merged = "\n\n".join(pending)
        if merged.strip():
            chunks.append({
                "id": f"{filename}_{chunk_idx}",
                "title": pending_title or filename,
                "text": merged,
                "chunk_idx": chunk_idx,
            })
            chunk_idx += 1

    # 如果没有 ## 标题，整文件作为一个块
    if not chunks:
        chunks.append({
            "id": f"{filename}_0",
            "title": filename,
            "text": content.strip(),
            "chunk_idx": 0,
        })

    return chunks
