import typer
from typing import Optional

from pmb.core import account_service
from pmb.core.state import should_json
from pmb.output.formatter import output_list, output_detail, output_summary

app = typer.Typer(help="账户信息查询")


@app.command("list")
def list_accounts(
    keyword: Optional[str] = typer.Option(None, "--keyword", "-k", help="模糊搜索关键词（姓名、账号、卡种、开户行）"),
    account_type: Optional[str] = typer.Option(None, "--type", "-t", help="账户类型: credit(信用卡) 或 debit(借记卡)"),
    limit: int = typer.Option(20, "--limit", help="每页记录数"),
    offset: int = typer.Option(0, "--offset", help="偏移量"),
    output_json: bool = typer.Option(False, "--json", help="JSON格式输出"),
):
    """列出所有账户信息"""
    data, total = account_service.list_accounts(
        keyword=keyword or "",
        account_type=account_type or "",
        limit=limit,
        offset=offset,
    )
    output_list(
        data,
        columns=account_service.LIST_COLUMNS,
        column_labels=account_service.LIST_LABELS,
        title="账户列表",
        total=total,
        offset=offset,
        limit=limit,
        output_json=should_json(output_json),
    )


@app.command("detail")
def detail_account(
    account_id: str = typer.Argument(..., help="账号或卡号"),
    output_json: bool = typer.Option(False, "--json", help="JSON格式输出"),
):
    """查看单个账户详细信息"""
    data = account_service.get_account(account_id)
    if not data:
        typer.echo(f"未找到账号: {account_id}")
        raise typer.Exit(code=1)
    output_detail(
        data,
        columns=account_service.DETAIL_COLUMNS,
        column_labels=account_service.DETAIL_LABELS,
        title=f"账户详情 - {account_id}",
        output_json=should_json(output_json),
    )


@app.command("summary")
def summary(
    output_json: bool = typer.Option(False, "--json", help="JSON格式输出"),
):
    """查看账户汇总信息"""
    data = account_service.get_account_summary()
    output_summary(data, title="账户汇总", output_json=should_json(output_json))
