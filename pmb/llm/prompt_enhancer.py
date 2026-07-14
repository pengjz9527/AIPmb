"""Prompt 增强器 — 将业务规则约束注入 Agent system prompt"""
import logging
from pathlib import Path

from pmb.core.config import CONSTRAINT_TEMPLATE_FILE
from pmb.rag.business_rule_retriever import BusinessRuleRetriever, RuleEntry

logger = logging.getLogger(__name__)


class PromptEnhancer:
    """Prompt 增强器

    负责：
    1. 加载 AI对话约束规则.md 模板
    2. 检索用户 query 匹配的业务规则
    3. 按模板格式组装增强后的 system prompt
    """

    # 系统硬性指令模板（从约束规则模板文件加载）
    _system_instruction: str | None = None

    # 单例检索器
    _retriever: BusinessRuleRetriever | None = None

    @classmethod
    def _load_template(cls) -> str:
        """加载 AI对话约束规则.md 模板并提取系统指令和输出要求部分"""
        if cls._system_instruction is not None:
            return cls._system_instruction

        template_path = CONSTRAINT_TEMPLATE_FILE
        if not template_path.exists():
            logger.warning("约束规则模板不存在: %s，使用默认指令", template_path)
            cls._system_instruction = cls._default_instruction()
            return cls._system_instruction

        content = template_path.read_text(encoding="utf-8")

        # 移除占位符行（如 "{规则编号...}"、"{用户当前提问}" 等），
        # 保留 #系统硬性指令 和 #输出要求 部分
        lines = content.split("\n")
        instruction_lines = []
        output_lines = []
        in_output = False
        skip_placeholder = False

        for line in lines:
            stripped = line.strip()

            # 跳过占位符行和纯变量行
            if stripped.startswith("{") and stripped.endswith("}"):
                continue
            if stripped in ("{规则编号、场景、规则话术、规则标签}", "{当前轮次之前对话记录}",
                           "{用户query}"):
                continue
            if stripped.startswith("#本次匹配RAG") or stripped.startswith("#用户历史对话") or stripped.startswith("#用户当前提问"):
                continue

            if stripped.startswith("#输出要求"):
                in_output = True
                output_lines.append(line)
                continue

            if in_output:
                output_lines.append(line)
            else:
                instruction_lines.append(line)

        cls._system_instruction = "\n".join(instruction_lines).strip()
        # 保存输出要求部分
        cls._output_template = "\n".join(output_lines).strip() if output_lines else ""
        return cls._system_instruction

    @classmethod
    def _default_instruction(cls) -> str:
        """默认系统指令（当模板文件不存在时使用）"""
        return (
            "你是银行零售业务专家级顾问，负责回答客户提问咨询，"
            "所有回答必须严格遵循业务规则文件中定义的业务规则，不得超出规则范围。\n"
            "若用户需求违反任意一条约束规则，拒绝执行，并按照规则内标准话术回复。\n"
            "回答必须引用对应规则编号作为依据，不可编造规则、放宽门槛。\n"
            "未在规则中允许的操作一律视为禁止。"
        )

    @classmethod
    def _get_retriever(cls):
        """懒加载检索器单例"""
        if cls._retriever is None:
            cls._retriever = BusinessRuleRetriever()
            cls._retriever.ensure_loaded()
        return cls._retriever

    @classmethod
    def build(
        cls,
        agent_system_prompt: str,
        user_query: str,
        conversation_history: str = "",
    ) -> str:
        """构建增强后的 system prompt

        Args:
            agent_system_prompt: Agent 原始 system_prompt（如 GeneralAssistantAgent.system_prompt）
            user_query: 用户当前提问
            conversation_history: 历史对话上下文（可选）

        Returns:
            增强后的完整 system prompt，格式如下：
            # 系统硬性指令 + 业务约束规则 + Agent 能力描述 + 历史对话 + 当前提问
        """
        # 加载约束模板
        system_instruction = cls._load_template()

        # 检索匹配规则
        entries = cls._get_retriever().search_with_cache(user_query)
        rule_text = cls._get_retriever().format_for_prompt(entries)

        # 组装完整 prompt
        parts = []

        # Part 1: Agent 自身的能力描述
        parts.append(agent_system_prompt)

        # Part 2: 系统硬性指令（业务规则约束的总体要求）
        parts.append(f"\n\n## 业务规则约束\n{system_instruction}")

        # Part 3: 本次匹配的具体业务规则
        parts.append(f"\n\n## 本次匹配的业务约束规则\n{rule_text}")

        # Part 4: 输出格式要求
        output_req = getattr(cls, '_output_template', "")
        if output_req:
            parts.append(f"\n\n{output_req}")
        else:
            parts.append(
                "\n\n#输出要求\n"
                "1. 先判断用户请求是否违反上方任意约束规则；\n"
                "2. 违规：直接按规则标准话术拦截，标注违规规则ID；\n"
                "3. 合规：基于规则给出业务解答，关键办理条件引用规则原文；\n"
                "4. 禁止出现规则未提及的承诺、简化门槛、放宽限制。"
            )

        enhanced = "\n".join(parts)
        logger.info(
            "Prompt 增强完成：匹配到 %d 条业务规则，prompt 总长度 %d 字符",
            len(entries), len(enhanced)
        )
        return enhanced
