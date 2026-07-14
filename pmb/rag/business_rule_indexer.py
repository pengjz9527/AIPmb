"""业务规则索引器 — 解析 Markdown 规则文件并分块入 ChromaDB"""
import re
import logging
from pathlib import Path

from pmb.core.config import BUSINESS_RULES_DIR
from pmb.rag.business_rule_store import BusinessRuleStore
from pmb.llm.embedding import EmbeddingAdapter

logger = logging.getLogger(__name__)


class BusinessRuleIndexer:
    """业务规则索引管理器

    编排完整的规则索引构建/重建流程：
    1. 解析 rag_docs/业务规则约束/*.md 文件
    2. 按规则编号分块
    3. 批量调用 Embedding API 向量化
    4. 存入 ChromaDB `business_rules` Collection
    """

    def __init__(self):
        self.store = BusinessRuleStore()
        self.embedding = EmbeddingAdapter()

    # ---- 规则解析 ----

    @staticmethod
    def parse_rules(rules_dir: str | Path | None = None) -> list[dict]:
        """解析所有业务规则 .md 文件，按规则编号分块

        Args:
            rules_dir: 规则文件目录，默认 BUSINESS_RULES_DIR

        Returns:
            [{id, text, metadata: {rule_id, scenario, tags, source_file}}, ...]
        """
        rules_dir = Path(rules_dir or BUSINESS_RULES_DIR)
        if not rules_dir.exists():
            logger.warning("业务规则目录不存在: %s", rules_dir)
            return []

        rules: list[dict] = []
        for filepath in sorted(rules_dir.glob("*.md")):
            if not filepath.is_file():
                continue
            content = filepath.read_text(encoding="utf-8")
            parsed = BusinessRuleIndexer._parse_single_file(content, filepath.name)
            rules.extend(parsed)

        logger.info("从 %d 个文件中解析出 %d 条业务规则",
                     len(set(r["metadata"]["source_file"] for r in rules)),
                     len(rules))
        return rules

    @staticmethod
    def _parse_single_file(content: str, filename: str) -> list[dict]:
        """解析单个 Markdown 文件，提取每条规则

        每条规则的格式:
            **规则编号：** R00001
            **适用场景：** [xxx] — ...
            **规则话术：** ...
            **规则标签：** tag1, tag2, ...

        Returns:
            [{id, text, metadata: {rule_id, scenario, tags, source_file}}, ...]
        """
        rules = []

        # 按规则编号分块：以 "**规则编号：**" 作为每个规则的开始标记
        blocks = re.split(r"\*\*规则编号：\*\*\s*", content)

        for block in blocks[1:]:  # 第一个块是文件标题/前言，跳过
            block = block.strip()
            if not block:
                continue

            rule_id = ""
            scenario = ""
            rule_text = ""
            tags_str = ""

            # 提取各个字段
            m = re.match(r"(R\d+)", block)
            if m:
                rule_id = m.group(1)

            m = re.search(r"\*\*适用场景：\*\*\s*(.+?)(?:\n|$)", block)
            if m:
                scenario = m.group(1).strip()

            # 提取规则话术（在 "**规则话术：**" 和 "**规则标签：**" 或 "---" 之间）
            m = re.search(
                r"\*\*规则话术：\*\*\s*(.+?)(?=\n\*\*规则标签：\*\*|\n---|\n\*\*规则)",
                block, re.DOTALL
            )
            if m:
                rule_text = m.group(1).strip()

            # 提取规则标签
            m = re.search(r"\*\*规则标签：\*\*\s*(.+?)(?:\n|$)", block)
            if m:
                tags_str = m.group(1).strip()

            if not rule_id:
                continue

            # 构建检索用的 text（语义搜索用于匹配用户 query）
            search_text = f"适用场景：{scenario} 规则话术：{rule_text}"

            rules.append({
                "id": f"rule_{filename.replace('.md', '')}_{rule_id}",
                "text": search_text,
                "metadata": {
                    "rule_id": rule_id,
                    "scenario": scenario,
                    "tags": tags_str,
                    "source_file": filename,
                    "category": "business_rule",
                },
            })

        return rules

    # ---- 索引构建 ----

    def build_index(self, force: bool = False) -> dict:
        """构建业务规则索引

        Args:
            force: 是否强制重建

        Returns:
            构建统计 dict
        """
        status = self.store.get_status()
        if status["rule_count"] > 0 and not force:
            logger.info(
                "业务规则索引已存在（%d 条），跳过构建。使用 force=True 强制重建。",
                status["rule_count"],
            )
            return {"status": "skipped", "reason": "索引已存在", **status}

        if force and status["rule_count"] > 0:
            logger.info("强制重建：删除旧索引...")
            self.store.delete_collection()

        # Step 1: 解析规则
        logger.info("正在解析业务规则文件...")
        rules = self.parse_rules()
        if not rules:
            logger.warning("未找到任何业务规则，索引构建终止")
            return {"status": "empty", "reason": "未找到业务规则文件", "rule_count": 0}

        texts = [rule["text"] for rule in rules]
        logger.info("共解析出 %d 条业务规则", len(texts))

        # Step 2: 批量向量化
        logger.info("正在调用 Embedding API 批量向量化...")
        embeddings = self.embedding.embed_batch(texts)
        valid_count = sum(1 for e in embeddings if e is not None and len(e) > 0)
        logger.info("向量化完成：%d/%d 条成功", valid_count, len(texts))

        # Step 3: 存入 ChromaDB
        logger.info("正在写入 ChromaDB 向量库...")
        self.store.add_rules(rules, embeddings)

        final_status = self.store.get_status()
        logger.info(
            "业务规则索引构建完成！共 %d 条规则，覆盖 %d 个规则文件",
            final_status["rule_count"],
            len(final_status["sources"]),
        )
        return {"status": "built", **final_status}

    def rebuild_index(self) -> dict:
        """重建索引"""
        return self.build_index(force=True)

    def get_status(self) -> dict:
        """查询索引状态"""
        return self.store.get_status()
