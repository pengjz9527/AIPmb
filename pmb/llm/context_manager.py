"""对话上下文管理器"""
from datetime import datetime


class ConversationContext:
    """单个对话会话的上下文"""

    def __init__(self, session_id: str, max_turns: int = 20):
        self.session_id = session_id
        self.messages: list[dict] = []
        self.system_prompt: str = ""
        self.current_agent_id: str | None = None
        self.created_at: datetime = datetime.now()
        self.max_turns = max_turns  # 保留最近N轮对话

    def add_message(self, role: str, content: str, **kwargs):
        """添加消息到上下文"""
        msg = {"role": role, "content": content}
        msg.update(kwargs)
        self.messages.append(msg)
        self._trim()

    def _trim(self):
        """超出窗口时丢弃最早的用户-助手对话对，system消息始终保留"""
        system_msgs = [m for m in self.messages if m["role"] == "system"]
        other_msgs = [m for m in self.messages if m["role"] != "system"]

        max_messages = self.max_turns * 2  # 每轮2条消息
        if len(other_msgs) > max_messages:
            other_msgs = other_msgs[-max_messages:]

        self.messages = system_msgs + other_msgs

    def get_messages(self) -> list[dict]:
        """获取完整消息列表（含system prompt）"""
        if self.system_prompt and (not self.messages or self.messages[0]["role"] != "system"):
            return [{"role": "system", "content": self.system_prompt}] + self.messages
        return self.messages

    def set_system_prompt(self, prompt: str):
        """设置system prompt"""
        self.system_prompt = prompt
        # 移除旧的system消息
        self.messages = [m for m in self.messages if m["role"] != "system"]


class ContextManager:
    """对话上下文管理器，管理所有会话"""

    def __init__(self):
        self._contexts: dict[str, ConversationContext] = {}

    def get_or_create(self, session_id: str) -> ConversationContext:
        """获取或创建会话上下文"""
        if session_id not in self._contexts:
            self._contexts[session_id] = ConversationContext(session_id)
        return self._contexts[session_id]

    def delete(self, session_id: str):
        """删除会话上下文"""
        self._contexts.pop(session_id, None)

    def list_sessions(self) -> list[str]:
        """列出所有会话ID"""
        return list(self._contexts.keys())


# 全局单例
context_manager = ContextManager()
