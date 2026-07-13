"""百炼 DashScope Embedding 适配器 — text-embedding-v3，1024 维，OpenAI 兼容"""
import logging
import time
from openai import OpenAI

from pmb.core.config import DASHSCOPE_API_KEY, EMBEDDING_MODEL_NAME

logger = logging.getLogger(__name__)

EMBEDDING_DIMENSION = 1024

_client: OpenAI | None = None


def _get_client() -> OpenAI:
    global _client
    if _client is None:
        _client = OpenAI(
            api_key=DASHSCOPE_API_KEY,
            base_url="https://dashscope.aliyuncs.com/compatible-mode/v1",
        )
    return _client


class EmbeddingAdapter:
    """百炼 text-embedding-v3（OpenAI 兼容协议）

    无需本地模型，通过网络 API 调用。
    批量请求单次最多 10 条文本（百炼限制），自动拆分。
    """

    _BATCH_SIZE = 10

    def embed(self, text: str) -> list[float]:
        client = _get_client()
        resp = client.embeddings.create(
            model=EMBEDDING_MODEL_NAME,
            input=text,
        )
        return resp.data[0].embedding

    def embed_batch(self, texts: list[str]) -> list[list[float]]:
        if not texts:
            return []

        all_embeddings: list[list[float]] = []
        client = _get_client()

        for i in range(0, len(texts), self._BATCH_SIZE):
            batch = texts[i : i + self._BATCH_SIZE]
            logger.info(
                "Embedding batch %d/%d (%d texts) ...",
                i // self._BATCH_SIZE + 1,
                (len(texts) + self._BATCH_SIZE - 1) // self._BATCH_SIZE,
                len(batch),
            )
            try:
                resp = client.embeddings.create(
                    model=EMBEDDING_MODEL_NAME,
                    input=batch,
                )
                batch_embs = [d.embedding for d in sorted(resp.data, key=lambda x: x.index)]
                all_embeddings.extend(batch_embs)
            except Exception as e:
                logger.error("Embedding batch failed at offset %d: %s", i, e)
                raise

            if i + self._BATCH_SIZE < len(texts):
                time.sleep(0.3)  # 限流

        return all_embeddings
