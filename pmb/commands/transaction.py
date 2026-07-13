from pmb.core.state import should_json
import typer
from typing import Optional

from pmb.core import transaction_service
from pmb.output.formatter import output_list, output_detail, output_stats

app = typer.Typer(help="交易明细查询")


@app.command("list")
def list_transactions(
    keyword: Optional[str] = typer.Option(None, "--keyword", "-k", help="模糊搜索（商户名、摘要、渠道）"),
    source: str = typer.Option("all", "--source", "-s", help="数据来源: credit/debit/all"),
    direction: Optional[str] = typer.Option(None, "--direction", "-d", help="收支方向: income(收入)/expense(支出)"),
    category: Optional[str] = typer.Option(None, "--category", help="交易分类/消费子类"),
    date_from: Optional[str] = typer.Option(None, "--date-from", help="起始日期 (YYYY-MM-DD/YYYY-MM/YYYY)"),
    date_to: Optional[str] = typer.Option(None, "--date-to", help="结束日期"),
    amount_min: Optional[float] = typer.Option(None, "--amount-min", help="最小金额"),
    amount_max: Optional[float] = typer.Option(None, "--amount-max", help="最大金额"),
    account: Optional[str] = typer.Option(None, "--account", help="账号/卡号"),
    limit: int = typer.Option(20, "--limit", help="每页记录数"),
    offset: int = typer.Option(0, "--offset", help="偏移量"),
    output_json: bool = typer.Option(False, "--json", help="JSON格式输出"),
):
    """列出交易明细"""
    data, total = transaction_service.list_transactions(
        keyword=keyword or "",
        source=source,
        direction=direction or "",
        category=category or "",
        date_from=date_from or "",
        date_to=date_to or "",
        amount_min=amount_min,
        amount_max=amount_max,
        account=account or "",
        limit=limit,
        offset=offset,
    )
    output_list(
        data,
        columns=transaction_service.LIST_COLUMNS,
        column_labels=transaction_service.LIST_LABELS,
        title="交易明细列表",
        total=total,
        offset=offset,
        limit=limit,
        output_json=should_json(output_json),
    )


@app.command("detail")
def detail_transaction(
    seq_no: int = typer.Argument(..., help="交易序号"),
    source: str = typer.Option("credit", "--source", "-s", help="数据来源: credit/debit"),
    output_json: bool = typer.Option(False, "--json", help="JSON格式输出"),
):
    """查看单笔交易详情"""
    data = transaction_service.get_transaction(seq_no, source)
    if not data:
        typer.echo(f"未找到交易: 序号={seq_no}, 来源={source}")
        raise typer.Exit(code=1)

    if source == "credit":
        cols = transaction_service.CREDIT_DETAIL_COLUMNS
    else:
        cols = transaction_service.DEBIT_DETAIL_COLUMNS

    output_detail(data, columns=cols, column_labels=cols, title=f"交易详情 #{seq_no}", output_json=should_json(output_json))


@app.command("summary")
def summary(
    source: str = typer.Option("all", "--source", "-s", help="数据来源: credit/debit/all"),
    date_from: Optional[str] = typer.Option(None, "--date-from", help="起始日期"),
    date_to: Optional[str] = typer.Option(None, "--date-to", help="结束日期"),
    group_by: str = typer.Option("month", "--group-by", help="分组维度: month/year/category/subcategory"),
    output_json: bool = typer.Option(False, "--json", help="JSON格式输出"),
):
    """交易汇总统计（支出统计）"""
    data = transaction_service.get_transaction_summary(
        source=source,
        date_from=date_from or "",
        date_to=date_to or "",
        group_by=group_by,
    )
    group_labels = {
        "month": "月份", "year": "年份", "category": "交易分类", "subcategory": "消费子类"
    }
    output_stats(
        data,
        group_col_label=group_labels.get(group_by, "分组"),
        title=f"交易汇总统计（按{group_labels.get(group_by, '分组')}）",
        output_json=should_json(output_json),
    )
