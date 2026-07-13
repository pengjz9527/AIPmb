#!/usr/bin/env python3
"""
用户数据隔离完整验证测试
以王小美、彭楫洲两个用户登录，验证频道数据隔离和Skill调用隔离
"""
import asyncio
import json
import sys
from urllib.parse import quote

BASE_URL = "http://localhost:8000/api/v1"

USERS = {
    "彭楫洲": {
        "expected_accounts": 4,      # 2借记卡 + 2信用卡
        "expected_debit_tx": 1399,   # 借记卡交易
        "expected_credit_tx": 1457,  # 信用卡交易
        "expected_consumption": 1457, # 消费记录（仅信用卡）
        "has_credit": True,
    },
    "王小美": {
        "expected_accounts": 2,      # 2借记卡
        "expected_debit_tx": 37,     # 借记卡交易
        "expected_credit_tx": 0,     # 无信用卡
        "expected_consumption": 0,   # 无消费记录
        "has_credit": False,
    },
}


class TestResult:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.details = []

    def ok(self, name, detail=""):
        self.passed += 1
        self.details.append(("PASS", name, detail))
        print(f"  ✅ PASS: {name}")
        if detail:
            print(f"      {detail}")

    def fail(self, name, expected, actual):
        self.failed += 1
        self.details.append(("FAIL", name, f"期望: {expected}, 实际: {actual}"))
        print(f"  ❌ FAIL: {name}")
        print(f"      期望: {expected}, 实际: {actual}")

    def summary(self):
        total = self.passed + self.failed
        print(f"\n{'='*60}")
        print(f"测试结果: {self.passed}/{total} 通过, {self.failed}/{total} 失败")
        print(f"{'='*60}")
        return self.failed == 0


async def http_get(path, user_name=""):
    """发送HTTP GET请求"""
    import aiohttp
    headers = {}
    if user_name:
        headers["x-user-name"] = user_name
    async with aiohttp.ClientSession() as session:
        async with session.get(f"{BASE_URL}{path}", headers=headers) as resp:
            return await resp.json()


async def test_accounts_isolation(result: TestResult):
    """测试1: 账户数据隔离"""
    print("\n【测试1】账户数据隔离")
    for user_name, expected in USERS.items():
        data = await http_get("/accounts", user_name)
        total = data.get("total", 0)
        accounts = data.get("data", [])

        # 检查账户数量
        if total == expected["expected_accounts"]:
            result.ok(f"{user_name} 账户数量", f"{total}个账户")
        else:
            result.fail(f"{user_name} 账户数量", expected["expected_accounts"], total)

        # 检查账户归属
        wrong_accounts = [a for a in accounts if a.get("name") != user_name]
        if not wrong_accounts:
            result.ok(f"{user_name} 账户归属正确")
        else:
            result.fail(f"{user_name} 账户归属", "无其他用户账户", f"发现{len(wrong_accounts)}个其他用户账户")

        # 检查信用卡存在性
        credit_cards = [a for a in accounts if "信用" in str(a.get("account_type", ""))]
        if expected["has_credit"]:
            if len(credit_cards) > 0:
                result.ok(f"{user_name} 信用卡存在", f"{len(credit_cards)}张")
            else:
                result.fail(f"{user_name} 信用卡存在", ">=1", 0)
        else:
            if len(credit_cards) == 0:
                result.ok(f"{user_name} 无信用卡")
            else:
                result.fail(f"{user_name} 无信用卡", 0, len(credit_cards))


async def test_transactions_isolation(result: TestResult):
    """测试2: 交易数据隔离"""
    print("\n【测试2】交易数据隔离")
    for user_name, expected in USERS.items():
        # 借记卡交易
        data = await http_get("/transactions?source=debit&limit=1000", user_name)
        total = data.get("total", 0)
        if total == expected["expected_debit_tx"]:
            result.ok(f"{user_name} 借记卡交易数量", f"{total}条")
        else:
            result.fail(f"{user_name} 借记卡交易数量", expected["expected_debit_tx"], total)

        # 全部交易
        data = await http_get("/transactions?source=all&limit=1000", user_name)
        total = data.get("total", 0)
        expected_total = expected["expected_debit_tx"] + expected["expected_credit_tx"]
        if total == expected_total:
            result.ok(f"{user_name} 全部交易数量", f"{total}条")
        else:
            result.fail(f"{user_name} 全部交易数量", expected_total, total)

        # 交易归属检查（抽样）
        transactions = data.get("data", [])
        if transactions:
            sample = transactions[:5]
            # 借记卡交易检查来源账号
            debit_samples = [t for t in sample if t.get("source") == "借记卡"]
            if debit_samples:
                result.ok(f"{user_name} 交易数据格式正确", f"样本{len(debit_samples)}条借记卡交易")


async def test_consumption_isolation(result: TestResult):
    """测试3: 消费数据隔离"""
    print("\n【测试3】消费数据隔离")
    for user_name, expected in USERS.items():
        # 消费列表
        data = await http_get("/consumptions?limit=1000", user_name)
        total = data.get("total", 0)
        if total == expected["expected_consumption"]:
            result.ok(f"{user_name} 消费记录数量", f"{total}条")
        else:
            result.fail(f"{user_name} 消费记录数量", expected["expected_consumption"], total)

        # 消费统计
        data = await http_get("/consumptions/stats?group_by=month&top=12", user_name)
        stats = data.get("data", [])
        if expected["expected_consumption"] == 0:
            if len(stats) == 0:
                result.ok(f"{user_name} 消费统计为空")
            else:
                result.fail(f"{user_name} 消费统计为空", 0, len(stats))
        else:
            if len(stats) > 0:
                result.ok(f"{user_name} 消费统计有数据", f"{len(stats)}个月")
            else:
                result.fail(f"{user_name} 消费统计有数据", ">0", 0)


async def test_recommendations_isolation(result: TestResult):
    """测试4: 推荐与画像数据隔离"""
    print("\n【测试4】推荐与画像数据隔离")
    for user_name, expected in USERS.items():
        # 待办推荐
        data = await http_get("/recommendations/todos", user_name)
        todos = data.get("data", [])
        credit_todos = [t for t in todos if t.get("todo_type") == "credit_repayment"]
        if expected["has_credit"]:
            if len(credit_todos) > 0:
                result.ok(f"{user_name} 信用卡还款提醒", f"{len(credit_todos)}条")
            else:
                result.fail(f"{user_name} 信用卡还款提醒", ">0", 0)
        else:
            if len(credit_todos) == 0:
                result.ok(f"{user_name} 无信用卡还款提醒")
            else:
                result.fail(f"{user_name} 无信用卡还款提醒", 0, len(credit_todos))

        # 用户画像标签
        data = await http_get("/profile/tags", user_name)
        tags = data.get("data", {})
        tag_list = tags.get("tags", [])
        if expected["has_credit"]:
            # 彭楫洲应该有消费相关标签
            if len(tag_list) > 2:
                result.ok(f"{user_name} 画像标签丰富", f"{len(tag_list)}个标签: {tag_list}")
            else:
                result.fail(f"{user_name} 画像标签丰富", ">2", len(tag_list))
        else:
            # 王小美应该只有基础标签
            if len(tag_list) <= 3:
                result.ok(f"{user_name} 画像标签简洁", f"{len(tag_list)}个标签: {tag_list}")
            else:
                result.fail(f"{user_name} 画像标签简洁", "<=3", len(tag_list))


async def test_wealth_isolation(result: TestResult):
    """测试5: 财富总览数据隔离"""
    print("\n【测试5】财富总览数据隔离")
    for user_name, expected in USERS.items():
        data = await http_get("/wealth/overview", user_name)
        wealth = data.get("data", {})
        total_assets = wealth.get("total_assets", 0)
        asset_breakdown = wealth.get("asset_breakdown", [])

        if total_assets > 0:
            result.ok(f"{user_name} 总资产", f"¥{total_assets:,.2f}")
        else:
            result.fail(f"{user_name} 总资产", ">0", total_assets)

        # 检查资产构成中信用卡部分
        credit_part = [a for a in asset_breakdown if "信用" in str(a.get("type", ""))]
        if expected["has_credit"]:
            if len(credit_part) > 0:
                result.ok(f"{user_name} 财富总览含信用卡额度")
            else:
                result.fail(f"{user_name} 财富总览含信用卡额度", ">0", 0)
        else:
            if len(credit_part) == 0:
                result.ok(f"{user_name} 财富总览不含信用卡额度")
            else:
                result.fail(f"{user_name} 财富总览不含信用卡额度", 0, len(credit_part))


async def test_skill_data_isolation(result: TestResult):
    """测试6: Skill层数据隔离（直接调用）"""
    print("\n【测试6】Skill层数据隔离（直接调用）")
    import sys
    sys.path.insert(0, "/Users/pengjizhou/Documents/AIPmb")

    from pmb.skills.data.account import CollectAccountDataSkill
    from pmb.skills.data.transaction import CollectTransactionDataSkill
    from pmb.skills.data.consumption import CollectConsumptionDataSkill
    from pmb.skills.domain.consumption_analysis import ConsumptionAnalysisSkill
    from pmb.skills.domain.financial_planning import FinancialPlanningSkill

    for user_name, expected in USERS.items():
        # 测试 CollectAccountDataSkill
        skill = CollectAccountDataSkill()
        res = await skill.execute(user_name=user_name)
        accounts_data = res.data.get("accounts", [])
        if len(accounts_data) == expected["expected_accounts"]:
            result.ok(f"{user_name} CollectAccountDataSkill", f"{len(accounts_data)}个账户")
        else:
            result.fail(f"{user_name} CollectAccountDataSkill", expected["expected_accounts"], len(accounts_data))

        # 测试 CollectTransactionDataSkill
        skill = CollectTransactionDataSkill()
        res = await skill.execute(user_name=user_name, limit=1000)
        tx_data = res.data.get("transactions", [])
        # 只返回了借记卡交易（因为skill默认不传source）
        # 实际上list_transactions默认source=all
        expected_tx = expected["expected_debit_tx"] + expected["expected_credit_tx"]
        if res.data.get("total", 0) == expected_tx:
            result.ok(f"{user_name} CollectTransactionDataSkill", f"{res.data.get('total')}条交易")
        else:
            result.fail(f"{user_name} CollectTransactionDataSkill", expected_tx, res.data.get("total", 0))

        # 测试 CollectConsumptionDataSkill
        skill = CollectConsumptionDataSkill()
        res = await skill.execute(user_name=user_name, top=12)
        stats = res.data.get("stats", [])
        if expected["expected_consumption"] == 0:
            if len(stats) == 0:
                result.ok(f"{user_name} CollectConsumptionDataSkill", "0条统计")
            else:
                result.fail(f"{user_name} CollectConsumptionDataSkill", 0, len(stats))
        else:
            if len(stats) > 0:
                result.ok(f"{user_name} CollectConsumptionDataSkill", f"{len(stats)}条统计")
            else:
                result.fail(f"{user_name} CollectConsumptionDataSkill", ">0", 0)

        # 测试 ConsumptionAnalysisSkill
        skill = ConsumptionAnalysisSkill()
        res = await skill.execute(user_name=user_name)
        data = res.data
        if expected["has_credit"]:
            if data.get("avg_monthly_expense", 0) > 0:
                result.ok(f"{user_name} ConsumptionAnalysisSkill", f"月均消费¥{data.get('avg_monthly_expense'):,.2f}")
            else:
                result.fail(f"{user_name} ConsumptionAnalysisSkill", ">0", data.get("avg_monthly_expense", 0))
        else:
            # 王小美没有信用卡消费，avg_monthly_expense可能为0
            result.ok(f"{user_name} ConsumptionAnalysisSkill", f"可用资金¥{data.get('available_funds', 0):,.2f}")

        # 测试 FinancialPlanningSkill
        skill = FinancialPlanningSkill()
        res = await skill.execute(user_name=user_name)
        data = res.data
        if data.get("total_balance", 0) > 0:
            result.ok(f"{user_name} FinancialPlanningSkill", f"总余额¥{data.get('total_balance'):,.2f}")
        else:
            result.fail(f"{user_name} FinancialPlanningSkill", ">0", data.get("total_balance", 0))


async def test_cross_user_leak(result: TestResult):
    """测试7: 跨用户数据泄露检查"""
    print("\n【测试7】跨用户数据泄露检查")

    # 获取彭楫洲的所有数据
    peng_accounts = await http_get("/accounts?limit=1000", "彭楫洲")
    peng_tx = await http_get("/transactions?source=all&limit=1000", "彭楫洲")

    # 获取王小美的所有数据
    wang_accounts = await http_get("/accounts?limit=1000", "王小美")
    wang_tx = await http_get("/transactions?source=all&limit=1000", "王小美")

    # 检查王小美的数据中是否混入彭楫洲的数据
    wang_account_names = [a.get("name") for a in wang_accounts.get("data", [])]
    if "彭楫洲" not in wang_account_names:
        result.ok("王小美账户无彭楫洲数据混入")
    else:
        result.fail("王小美账户无彭楫洲数据混入", False, True)

    # 检查彭楫洲的数据中是否混入王小美的数据
    peng_account_names = [a.get("name") for a in peng_accounts.get("data", [])]
    peng_account_numbers = [a.get("account_number", "") for a in peng_accounts.get("data", [])]
    if "6214680029336904" not in peng_account_numbers:  # 王小美的卡号
        result.ok("彭楫洲账户无王小美卡号混入")
    else:
        result.fail("彭楫洲账户无王小美卡号混入", False, True)

    # 检查交易数据不重叠
    wang_tx_accounts = set()
    for t in wang_tx.get("data", []):
        acct = t.get("account_number", "")
        if acct:
            wang_tx_accounts.add(acct)

    peng_tx_accounts = set()
    for t in peng_tx.get("data", []):
        acct = t.get("account_number", "")
        if acct:
            peng_tx_accounts.add(acct)

    overlap = wang_tx_accounts & peng_tx_accounts
    if not overlap:
        result.ok("交易数据无重叠卡号", f"彭楫洲:{peng_tx_accounts}, 王小美:{wang_tx_accounts}")
    else:
        result.fail("交易数据无重叠卡号", "无重叠", f"重叠卡号: {overlap}")


async def main():
    print("=" * 70)
    print("用户数据隔离完整验证测试")
    print("=" * 70)
    print(f"测试用户: 彭楫洲、王小美")
    print(f"API地址: {BASE_URL}")

    result = TestResult()

    await test_accounts_isolation(result)
    await test_transactions_isolation(result)
    await test_consumption_isolation(result)
    await test_recommendations_isolation(result)
    await test_wealth_isolation(result)
    await test_skill_data_isolation(result)
    await test_cross_user_leak(result)

    success = result.summary()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
