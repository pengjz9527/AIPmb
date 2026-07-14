"""业务规则检索器 — 关键词匹配 + TF-IDF 加权 + 格式化输出"""
import logging
import time
import re
from collections import Counter
from typing import NamedTuple

from pmb.core.config import RULES_TOP_K, RULES_CACHE_TTL
from pmb.rag.business_rule_indexer import BusinessRuleIndexer

logger = logging.getLogger(__name__)


class RuleEntry(NamedTuple):
    """单条匹配规则的结构化表示"""
    rule_id: str
    scenario: str
    speech: str       # 规则话术
    tags: str
    source_file: str
    score: float      # 匹配得分（越高越匹配）


class BusinessRuleRetriever:
    """业务规则检索器（纯关键词引擎，零外部依赖）

    功能：
    1. 解析业务规则，建立内存关键词索引
    2. 对用户 query 做中文分词 → TF-IDF 权重 → 余弦相似度匹配
    3. 标签关键词加权匹配
    4. 格式化输出为 Prompt 可用的结构化文本
    5. 内置 TTL 缓存
    """

    # 中文标点 regex（用于分词）
    _CN_PUNCT = re.compile(r'[，。！？；：""''（）【】《》、\\s]+')
    # 停用词
    _STOP_WORDS = frozenset({
        '的', '了', '在', '是', '我', '有', '和', '就', '不', '人', '都', '一',
        '一个', '上', '也', '很', '到', '说', '要', '去', '你', '会', '着',
        '没有', '看', '好', '自己', '这', '他', '她', '它', '们', '那', '些',
        '什么', '怎么', '如何', '可以', '这个', '那个', '还是', '只是', '已经',
        '因为', '所以', '但是', '如果', '虽然', '而且', '或者', '还', '把',
        '被', '让', '给', '对', '从', '与', '以', '及', '等', '之', '为',
        '问', '想', '知道', '了解', '告诉', '请问', '一下', '帮我', '需要',
        '关于', '进行', '使用', '通过', '是否', '应该', '能够', '可能',
    })

    # 单例
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self._initialized = True
        self._rules: list[dict] = []          # 原始规则列表
        self._doc_ids: list[str] = []          # 每条规则的唯一ID
        self._doc_texts: list[str] = []        # 每条规则的检索文本
        self._doc_tags: list[str] = []         # 每条规则的标签
        self._term_index: dict[str, list[int]] = {}  # 词 → 文档ID列表（倒排索引）
        self._df: Counter = Counter()          # 文档频率
        self._total_docs: int = 0
        self._idf: dict[str, float] = {}
        self._cache: dict[str, tuple[float, list[RuleEntry]]] = {}
        self._loaded = False

    # ---- 分词 ----

    @classmethod
    def _tokenize(cls, text: str) -> list[str]:
        """简单中文分词：按标点 + 二元组切分"""
        text = text.lower().strip()
        # 去标点，保留中文/英文/数字
        parts = cls._CN_PUNCT.split(text)
        tokens = []
        for part in parts:
            part = part.strip()
            if not part:
                continue
            # 二元组分词（bigram）适用于中文
            if re.match(r'[\u4e00-\u9fff]+', part):
                # 中文字符 → bigram
                chars = re.findall(r'[\u4e00-\u9fff]', part)
                for i in range(len(chars)):
                    tokens.append(chars[i])  # unigram
                for i in range(len(chars) - 1):
                    tokens.append(chars[i] + chars[i + 1])  # bigram
            else:
                # 英文/数字 → 按空格分词
                tokens.extend(part.split())
        # 过滤停用词 + 短词
        return [t for t in tokens if len(t) >= 1 and t not in cls._STOP_WORDS]

    # ---- 索引构建 ----

    def build_index(self) -> int:
        """解析规则文件并构建内存倒排索引"""
        from pmb.rag.business_rule_indexer import BusinessRuleIndexer
        rules = BusinessRuleIndexer.parse_rules()
        if not rules:
            logger.warning("未找到任何业务规则")
            return 0

        self._rules = rules
        self._doc_ids = [r["id"] for r in rules]
        self._doc_texts = [r["text"] for r in rules]
        self._doc_tags = [r["metadata"].get("tags", "") for r in rules]
        self._total_docs = len(rules)

        # 构建倒排索引
        for doc_idx, text in enumerate(self._doc_texts):
            tokens = set(self._tokenize(text))
            for token in tokens:
                if token not in self._term_index:
                    self._term_index[token] = []
                self._term_index[token].append(doc_idx)
                self._df[token] += 1

        # 计算 IDF
        for term, df in self._df.items():
            self._idf[term] = 1.0 / (1.0 + df)  # 简化 IDF

        self._loaded = True
        logger.info(
            "关键词索引构建完成：%d 条规则，%d 个词条，%d 个倒排项",
            self._total_docs, len(self._term_index), sum(len(v) for v in self._term_index.values())
        )
        return self._total_docs

    def ensure_loaded(self) -> bool:
        """确保索引已加载"""
        if not self._loaded:
            self.build_index()
        return self._loaded and self._total_docs > 0

    # ---- 检索 ----

    def search(self, query: str, top_k: int = RULES_TOP_K) -> list[RuleEntry]:
        """关键词检索匹配的业务规则

        算法：TF-IDF 余弦相似度 + 标签加权
        """
        if not self.ensure_loaded():
            return []

        query_tokens = self._tokenize(query)
        if not query_tokens:
            return []

        # 计算 query TF
        query_tf = Counter(query_tokens)
        query_weight: dict[str, float] = {}
        for t in query_tokens:
            query_weight[t] = query_tf[t] * self._idf.get(t, 0.0)

        # 计算每个文档的得分
        scores: dict[int, float] = {}
        candidate_docs = set()
        for token in query_tokens:
            if token in self._term_index:
                candidate_docs.update(self._term_index[token])

        for doc_idx in candidate_docs:
            doc_text = self._doc_texts[doc_idx]
            doc_tokens = self._tokenize(doc_text)
            doc_tf = Counter(doc_tokens)

            # 基础得分：TF-IDF 余弦相似度
            score = 0.0
            for token in set(query_tokens) & set(doc_tokens):
                qw = query_weight.get(token, 0)
                dw = doc_tf[token] * self._idf.get(token, 0)
                score += qw * dw

            # 标签加权：query 中的词命中标签直接加分
            tags = self._doc_tags[doc_idx]
            tag_tokens = set(self._tokenize(tags))
            tag_hits = len(set(query_tokens) & tag_tokens)
            if tag_hits > 0:
                score += tag_hits * 0.5

            if score > 0:
                scores[doc_idx] = score

        # 排序取 Top-K
        ranked = sorted(scores.keys(), key=lambda d: scores[d], reverse=True)
        top_indices = ranked[:top_k]

        # 转换为 RuleEntry
        entries: list[RuleEntry] = []
        for doc_idx in top_indices:
            rule = self._rules[doc_idx]
            meta = rule["metadata"]
            entries.append(RuleEntry(
                rule_id=meta["rule_id"],
                scenario=meta["scenario"],
                speech=self._extract_speech(rule["text"]),
                tags=meta["tags"],
                source_file=meta["source_file"],
                score=round(scores[doc_idx], 4),
            ))

        return entries

    def search_with_cache(self, query: str, top_k: int = RULES_TOP_K) -> list[RuleEntry]:
        """带缓存的规则检索"""
        now = time.time()

        cache_key = query.strip()
        if cache_key in self._cache:
            cached_time, cached_entries = self._cache[cache_key]
            if now - cached_time < RULES_CACHE_TTL:
                logger.debug("命中规则缓存: query='%s', %d条", query[:30], len(cached_entries))
                return cached_entries

        entries = self.search(query, top_k=top_k)
        self._cache[cache_key] = (now, entries)

        if len(self._cache) > 100:
            self._cache.clear()

        return entries

    def format_for_prompt(self, entries: list[RuleEntry]) -> str:
        """将匹配规则格式化为 Prompt 可用的 Markdown 文本"""
        if not entries:
            return "（无匹配的业务约束规则）"

        lines = []
        for i, e in enumerate(entries):
            rule_block = (
                f"**[规则编号：{e.rule_id}]** [场景：{e.scenario}]\n"
                f"规则话术：{e.speech}\n"
                f"规则标签：{e.tags}"
            )
            if i < len(entries) - 1:
                rule_block += "\n"
            lines.append(rule_block)

        return "\n\n".join(lines)

    @staticmethod
    def _extract_speech(text: str) -> str:
        """从检索文本中提取规则话术部分"""
        idx = text.find("规则话术：")
        if idx >= 0:
            return text[idx + len("规则话术："):].strip()
        return text

    def get_status(self) -> dict:
        """查询索引状态"""
        return {
            "rule_count": self._total_docs,
            "loaded": self._loaded,
            "cache_size": len(self._cache),
        }
