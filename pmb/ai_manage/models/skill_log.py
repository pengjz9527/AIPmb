"""技能调用日志数据模型"""
from dataclasses import dataclass, field


@dataclass
class SkillLog:
    """单次 Skill 调用日志"""
    id: str                          # UUID 前8位
    skill_name: str                  # Skill 名称
    user_name: str                   # 用户标识
    session_id: str                  # 会话 ID
    invoked_at: str                  # 调用时间 ISO 格式
    duration_ms: int                 # 执行耗时(毫秒)
    success: bool                    # 是否成功
    error_message: str = ""          # 失败原因
    arguments: dict = field(default_factory=dict)     # 调用参数
    result_summary: str = ""         # 返回摘要(截断200字)
    api_traces: list = field(default_factory=list)    # API 调用链路

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "skill_name": self.skill_name,
            "user_name": self.user_name,
            "session_id": self.session_id,
            "invoked_at": self.invoked_at,
            "duration_ms": self.duration_ms,
            "success": self.success,
            "error_message": self.error_message,
            "arguments": self.arguments,
            "result_summary": self.result_summary[:200],
            "api_traces": self.api_traces,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "SkillLog":
        return cls(
            id=d.get("id", ""),
            skill_name=d.get("skill_name", ""),
            user_name=d.get("user_name", ""),
            session_id=d.get("session_id", ""),
            invoked_at=d.get("invoked_at", ""),
            duration_ms=d.get("duration_ms", 0),
            success=d.get("success", True),
            error_message=d.get("error_message", ""),
            arguments=d.get("arguments", {}),
            result_summary=d.get("result_summary", ""),
            api_traces=d.get("api_traces", []),
        )
