"""用户对话记忆服务 — 持久化存储、压缩摘要、注入 system prompt"""
import json
import asyncio
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

from pmb.core.memory_models import UserMemory, MemoryEntry
from pmb.core.config import PROJECT_ROOT

# 存储目录
MEMORIES_DIR = PROJECT_ROOT / "pmb" / "output" / "memories"
# 并发锁：按 user_name 粒度
_LOCKS: dict[str, asyncio.Lock] = {}


def _get_lock(user_name: str) -> asyncio.Lock:
    """获取或创建 user_name 粒度的 asyncio.Lock"""
    if user_name not in _LOCKS:
        _LOCKS[user_name] = asyncio.Lock()
    return _LOCKS[user_name]


class MemoryService:
    """用户对话长期记忆服务"""

    def _file_path(self, user_name: str) -> Path:
        """用户记忆文件的路径"""
        MEMORIES_DIR.mkdir(parents=True, exist_ok=True)
        safe_name = "".join(c for c in user_name if c.isalnum() or c in "._-")
        return MEMORIES_DIR / f"{safe_name}.json"

    def load(self, user_name: str) -> UserMemory:
        """从 JSON 文件加载用户记忆，不存在则返回空记忆"""
        fp = self._file_path(user_name)
        if not fp.exists():
            now = datetime.now(timezone.utc).isoformat()
            return UserMemory(user_name=user_name, created_at=now, updated_at=now)

        try:
            data = json.loads(fp.read_text(encoding="utf-8"))
            return UserMemory(
                user_name=data.get("user_name", user_name),
                created_at=data.get("created_at", ""),
                updated_at=data.get("updated_at", ""),
                entries=data.get("entries", []),
            )
        except (json.JSONDecodeError, KeyError):
            now = datetime.now(timezone.utc).isoformat()
            return UserMemory(user_name=user_name, created_at=now, updated_at=now)

    def save(self, user_name: str, memory: UserMemory) -> None:
        """将用户记忆序列化到 JSON 文件"""
        memory.updated_at = datetime.now(timezone.utc).isoformat()
        data = {
            "user_name": memory.user_name,
            "created_at": memory.created_at,
            "updated_at": memory.updated_at,
            "entries": memory.entries,
        }
        fp = self._file_path(user_name)
        fp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    async def start_session(self, user_name: str, session_id: str) -> None:
        """开始新会话 — 记录开始时间"""
        async with _get_lock(user_name):
            memory = self.load(user_name)
            # 记录会话开始（轻量标记，end_session 时正式写入）
            memory._pending_session_start = datetime.now(timezone.utc).isoformat()
            self.save(user_name, memory)

    async def end_session(
        self, user_name: str, session_id: str, messages: list[dict]
    ) -> None:
        """结束会话 — 将对话消息保存为记忆条目"""
        if not user_name or not messages:
            return

        async with _get_lock(user_name):
            memory = self.load(user_name)
            now = datetime.now(timezone.utc)

            started_at = getattr(memory, "_pending_session_start", None) or now.isoformat()
            # 仅保留 user 和 assistant 消息（过滤 system 消息）
            filtered = [
                {"role": m["role"], "content": m.get("content", "")}
                for m in messages
                if m.get("role") in ("user", "assistant")
            ]
            if not filtered:
                return

            entry = MemoryEntry(
                session_id=session_id,
                started_at=started_at,
                ended_at=now.isoformat(),
                raw_messages=filtered,
            )
            memory.add_entry(entry)
            self.save(user_name, memory)

    def get_memory_summary(self, user_name: str) -> str:
        """构建注入 system prompt 的历史记忆摘要文本，无记忆时返回空字符串"""
        if not user_name:
            return ""
        memory = self.load(user_name)
        summaries = memory.compressed_summaries
        if not summaries:
            return ""

        lines = ["\n## 用户历史对话记忆"]
        for i, s in enumerate(summaries):
            stripped = s.strip()
            if stripped:
                lines.append(f"- {stripped}")
        return "\n".join(lines) if len(lines) > 1 else ""

    async def compress_if_needed(self, user_name: str) -> int:
        """检查并压缩超过 1 天的记忆条目，返回压缩数量"""
        if not user_name:
            return 0

        async with _get_lock(user_name):
            memory = self.load(user_name)
            pending = memory.pending_entries
            if not pending:
                return 0

            now = datetime.now(timezone.utc)
            compressed_count = 0

            for entry_dict in pending:
                try:
                    started = datetime.fromisoformat(entry_dict["started_at"])
                except (ValueError, KeyError):
                    continue

                if (now - started) <= timedelta(days=1):
                    continue  # 未满 1 天，跳过

                raw = entry_dict.get("raw_messages", [])
                if not raw:
                    continue

                summary = await self._generate_summary(raw)
                if not summary:
                    continue

                entry_dict["summary"] = summary
                entry_dict["raw_messages"] = []
                entry_dict["compressed"] = True
                entry_dict["compressed_at"] = now.isoformat()
                compressed_count += 1

            if compressed_count > 0:
                self.save(user_name, memory)

            # 清理超过 30 天的条目
            self._cleanup_old_inplace(memory, max_age_days=30)
            if compressed_count > 0:
                self.save(user_name, memory)

            return compressed_count

    async def _generate_summary(self, messages: list[dict]) -> str:
        """调用 LLM 将对话压缩为一段摘要（≤150 字）"""
        if not messages:
            return ""

        # 构建对话文本
        dialog_lines = []
        for m in messages:
            role = "用户" if m.get("role") == "user" else "助手"
            content = str(m.get("content", ""))[:500]  # 每条截断 500 字
            if content.strip():
                dialog_lines.append(f"{role}: {content}")
        dialog_text = "\n".join(dialog_lines)
        if not dialog_text.strip():
            return ""

        prompt = f"""你是一个对话记忆压缩助手。请将以下用户与银行AI助手的对话压缩为一段简洁的摘要（不超过150字）。

要求：
1. 提取用户的核心意图和需求
2. 记录关键信息（金额、产品偏好、关注点等）
3. 忽略寒暄和无关内容
4. 多个主题用句号分隔

对话：
{dialog_text}

请输出一段摘要："""

        try:
            from pmb.llm.qwen import QwenLLM

            llm = QwenLLM()
            response = await llm.chat(
                messages=[{"role": "user", "content": prompt}],
                tools=None,
                temperature=0.3,
            )
            summary = response.content.strip()
            return summary[:200]  # 限制 200 字
        except Exception as e:
            # 降级：返回对话首条用户消息摘要
            first_user = next(
                (m["content"] for m in messages if m.get("role") == "user"), ""
            )
            return f"[对话摘要] {first_user[:100]}..."

    def _cleanup_old_inplace(self, memory: UserMemory, max_age_days: int = 30) -> None:
        """删除超过 max_age_days 天的压缩记忆条目（原地修改）"""
        if not memory.entries:
            return
        cutoff = datetime.now(timezone.utc) - timedelta(days=max_age_days)
        kept = []
        for e in memory.entries:
            try:
                started = datetime.fromisoformat(e["started_at"])
            except (ValueError, KeyError):
                kept.append(e)
                continue
            if started > cutoff:
                kept.append(e)
        memory.entries = kept


# 全局单例
memory_service = MemoryService()
