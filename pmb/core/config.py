import os
from pathlib import Path

# 项目根目录
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent

# 加载 .env 文件
_env_file = PROJECT_ROOT / ".env"
if _env_file.exists():
    for line in _env_file.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip())

# LLM 配置
LLM_API_KEY = os.environ.get("LLM_API_KEY", "")
LLM_BASE_URL = os.environ.get("LLM_BASE_URL", "https://api.moonshot.cn/v1")
LLM_MODEL = os.environ.get("LLM_MODEL", "kimi-k2.5")

# 数据目录
COREDATAS_DIR = PROJECT_ROOT / "coredatas"

# 数据文件路径
ACCOUNT_FILE = COREDATAS_DIR / "客户账户信息表.xlsx"
CREDIT_TX_FILE = COREDATAS_DIR / "信用卡账单合并明细表.xlsx"
DEBIT_TX_FILE = COREDATAS_DIR / "银行交易流水汇总明细表.xlsx"
PAYMENT_FILE = COREDATAS_DIR / "缴费记录.xlsx"

PRODUCT_FILES = {
    "deposit": COREDATAS_DIR / "个人存款产品.xlsx",
    "loan": COREDATAS_DIR / "个人贷款产品.xlsx",
    "wealth": COREDATAS_DIR / "个人理财产品.xlsx",
    "fund": COREDATAS_DIR / "个人基金产品.xlsx",
    "insurance": COREDATAS_DIR / "个人保险产品.xlsx",
    "forex": COREDATAS_DIR / "个人外汇产品.xlsx",
    "gold": COREDATAS_DIR / "个人黄金产品.xlsx",
}

PRODUCT_CATEGORY_NAMES = {
    "deposit": "存款产品",
    "loan": "贷款产品",
    "wealth": "理财产品",
    "fund": "基金产品",
    "insurance": "保险产品",
    "forex": "外汇产品",
    "gold": "黄金产品",
}

# 默认分页
DEFAULT_LIMIT = 20
DEFAULT_OFFSET = 0

# 持有产品文件路径
HELD_PRODUCT_FILES = {
    "wealth": COREDATAS_DIR / "持有理财信息表.xlsx",
    "loan": COREDATAS_DIR / "持有贷款信息表.xlsx",
    "pension": COREDATAS_DIR / "养老金信息表.xlsx",
}

# 文件表头偏移配置 {文件名key: (header_row_1indexed, data_start_row, footer_skip_count)}
HEADER_CONFIG = {
    "account": (3, 4, 0),
    "credit_tx": (1, 2, 0),
    "debit_tx": (3, 4, 3),  # 末尾3行是合计公式
    "product": (1, 2, 0),
    "held_wealth": (3, 4, 0),
    "held_loan": (3, 4, 0),
    "held_pension": (3, 4, 0),
    "payment": (1, 2, 1),  # header_row=1, data_start=2, footer_skip=1 (合计行)
}

# ========== RAG / Embedding 配置 ==========

# 百炼 DashScope Embedding（text-embedding-v3，1024 维）
DASHSCOPE_API_KEY = os.environ.get("DASHSCOPE_API_KEY", "")
EMBEDDING_MODEL_NAME = "text-embedding-v3"
EMBEDDING_DIMENSION = 1024

# ChromaDB 向量库持久化目录
CHROMA_DB_DIR = PROJECT_ROOT / "pmb" / "rag" / "chroma_db"

# RAG 通用知识文档目录（放 .md / .txt 文件，自动索引）
RAG_DOCS_DIR = PROJECT_ROOT / "rag_docs"

# 向量检索默认参数
RAG_DEFAULT_TOP_K = 5
RAG_COLLECTION_NAME = "product_knowledge"

# ========== 业务规则约束 RAG 配置 ==========

# 业务规则约束文档目录
BUSINESS_RULES_DIR = PROJECT_ROOT / "rag_docs" / "业务规则约束"

# AI 对话约束规则模板
CONSTRAINT_TEMPLATE_FILE = RAG_DOCS_DIR / "AI对话约束规则.md"

# 独立 ChromaDB Collection 名称
BUSINESS_RULES_COLLECTION = "business_rules"

# 业务规则检索返回数
RULES_TOP_K = 5

# 规则检索缓存时间（秒）
RULES_CACHE_TTL = 300
