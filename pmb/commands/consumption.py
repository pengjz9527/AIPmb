from pmb.core.state import should_json
import typer
from typing import Optional

from pmb.core import consumption_service
from pmb.output.formatter import output_list, output_detail, output_stats

app = typer.Typer(help="消费记录查询")


@app.command("list")
def list_consumption(
    keyword: Optional[str] = typer.Option(None, "--keyword", "-k", help="模糊搜索（商户名、子类、渠道）"),
    subcategory: Optional[str] = typer.Option(None, "--subcategory", help="消费细分子类（如 餐饮美食、超市便利店）"),
    category: Optional[str] = typer.Option(None, "--category", help="交易分类（消费/还款/退款/分期）"),
    channel: Optional[str] = typer.Option(None, "--channel", help="支付渠道（财付通/支付宝等）"),
    date_from: Optional[str] = typer.Option(None, "--date-from", help="起始日期"),
    date_to: Optional[str] = typer.Option(None, "--date-to", help="结束日期"),
    amount_min: Optional[float] = typer.Option(None, "--amount-min", help="最小金额"),
    amount_max: Optional[float] = typer.Option(None, "--amount-max", help="最大金额"),
    limit: int = typer.Option(20, "--limit", help="每页记录数"),
    offset: int = typer.Option(0, "--offset", help="偏移量"),
    output_json: bool = typer.Option(False, "--json", help="JSON格式输出"),
):
    """列出消费记录"""
    data, total = consumption_service.list_consumption(
        keyword=keyword or "",
        subcategory=subcategory or "",
        category=category or "",
        channel=channel or "",
        date_from=date_from or "",
        date_to=date_to or "",
        amount_min=amount_min,
        amount_max=amount_max,
        limit=limit,
        offset=offset,
    )
    output_list(
        data,
        columns=consumption_service.LIST_COLUMNS,
        column_labels=consumption_service.LIST_LABELS,
        title="消费记录列表",
        total=total,
        offset=offset,
        limit=limit,
        output_json=should_json(output_json),
    )


@app.command("detail")
def detail_consumption(
    seq_no: int = typer.Argument(..., help="消费记录序号"),
    output_json: bool = typer.Option(False, "--json", help="JSON格式输出"),
):
    """查看消费记录详情"""
    data = consumption_service.get_consumption(seq_no)
    if not data:
        typer.echo(f"未找到消费记录: 序号={seq_no}")
        raise typer.Exit(code=1)
    output_detail(
        data,
        columns=consumption_service.DETAIL_COLUMNS,
        column_labels=consumption_service.DETAIL_COLUMNS,
        title=f"消费记录详情 #{seq_no}",
        output_json=should_json(output_json),
    )


@app.command("stats")
def stats(
    group_by: str = typer.Option("subcategory", "--group-by",
                                 help="分组维度: subcategory/category/channel/merchant/month/year"),
    date_from: Optional[str] = typer.Option(None, "--date-from", help="起始日期"),
    date_to: Optional[str] = typer.Option(None, "--date-to", help="结束日期"),
    top: int = typer.Option(10, "--top", help="显示前N条"),
    output_json: bool = typer.Option(False, "--json", help="JSON格式输出"),
):
    """消费统计分析（按分组维度统计支出）"""
    data = consumption_service.get_consumption_stats(
        group_by=group_by,
        date_from=date_from or "",
        date_to=date_to or "",
        top=top,
    )
    group_labels = {
        "subcategory": "消费子类", "category": "交易分类",
        "channel": "支付渠道", "merchant": "商户",
        "month": "月份", "year": "年份",
    }
    output_stats(
        data,
        group_col_label=group_labels.get(group_by, "分组"),
        title=f"消费统计（按{group_labels.get(group_by, '分组')}）",
        output_json=should_json(output_json),
    )
