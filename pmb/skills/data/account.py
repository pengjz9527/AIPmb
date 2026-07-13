"""收集账户数据 Skill"""
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client


class CollectAccountDataSkill(BaseSkill):

    @property
    def name(self) -> str:
        return "collect_account_data"

    @property
    def description(self) -> str:
        return "查询用户所有银行账户信息，包括借记卡余额、信用卡额度、应还金额等。当用户询问账户余额、资产状况时调用。"

    @property
    def parameters_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "account_type": {
                    "type": "string",
                    "enum": ["credit", "debit", ""],
                    "description": "账户类型筛选：credit信用卡/debit借记卡/空全部",
                },
                "limit": {"type": "integer", "description": "返回条数，默认100"},
                "user_name": {"type": "string", "description": "用户姓名，用于数据隔离"},
            },
        }

    async def execute(self, **kwargs) -> SkillResult:
        account_type = kwargs.get("account_type", "")
        limit = kwargs.get("limit", 100)
        user_name = kwargs.get("user_name", "")

        api = create_client(user_name=user_name)
        accounts, total = await api.list_accounts(
            account_type=account_type, limit=limit
        )
        summary_data, _ = await api.get_account_summary()

        simplified = []
        for a in accounts:
            simplified.append({
                "账户类型": a.get("account_type", ""),
                "卡种产品": a.get("card_product", ""),
                "账号": a.get("account_number", ""),
                "余额": a.get("balance", "0"),
                "信用额度": a.get("credit_limit", ""),
                "本期应还": a.get("amount_due", ""),
            })

        # API 返回 [{"label":..., "value":...}]，转换为 dict
        summary_dict = {item["label"]: item["value"] for item in summary_data} if summary_data else {}

        return SkillResult(
            success=True,
            data={
                "accounts": simplified,
                "total": total,
                "summary": summary_dict,
            },
            summary=f"已获取{total}个账户信息，总资产¥{summary_dict.get('total_balance', 0)}",
        )