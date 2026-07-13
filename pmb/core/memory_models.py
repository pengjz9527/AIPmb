"""用户对话记忆数据模型"""
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


@dataclass
class MemoryEntry:
    """单次对话的记忆条目 — 压缩前保留 raw_messages，压缩后仅保留 summary"""
    session_id: str
    started_at: str           # ISO 格式
    ended_at: str
    raw_messages: list[dict]  # [{role, content, ...}, ...]
    summary: str = ""         # LLM 生成的压缩摘要
    compressed: bool = False
    compressed_at: Optional[str] = None


@dataclass
class UserMemory:
    """单个用户的完整长期记忆"""
    user_name: str
    created_at: str
    updated_at: str
    entries: list[dict] = field(default_factory=list)

    @property
    def compressed_summaries(self) -> list[str]:
        """所有已压缩条目的摘要列表"""
        return [
            e.get("summary", "")
            for e in self.entries
            if e.get("compressed") and e.get("summary")
        ]

    @property
    def pending_entries(self) -> list[dict]:
        """所有未压缩的条目"""
        return [e for e in self.entries if not e.get("compressed")]

    @property
    def total_sessions(self) -> int:
        """会话总数"""
        return len(self.entries)

    def add_entry(self, entry: MemoryEntry) -> None:
        """追加记忆条目"""
        self.entries.append({
            "session_id": entry.session_id,
            "started_at": entry.started_at,
            "ended_at": entry.ended_at,
            "raw_messages": entry.raw_messages,
            "summary": entry.summary,
            "compressed": entry.compressed,
            "compressed_at": entry.compressed_at,
        })
        self.updated_at = datetime.now().isoformat()
