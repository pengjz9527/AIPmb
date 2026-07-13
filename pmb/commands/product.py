from pmb.core.state import should_json
import typer
from typing import Optional

from pmb.core import product_service
from pmb.output.formatter import output_list, output_detail, output_stats
from pmb.output.table_render import render_list_table, render_detail_table
from pmb.output.json_render import render_json
from rich.console import Console

console = Console()

app = typer.Typer(help="银行产品查询")


@app.command("list")
def list_products(
    keyword: Optional[str] = typer.Option(None, "--keyword", "-k", help="模糊搜索（产品名称、描述、类型）"),
    category: Optional[str] = typer.Option(None, "--category", "-c",
                                           help="产品类别: deposit/loan/wealth/fund/insurance/forex/gold"),
    bank: Optional[str] = typer.Option(None, "--bank", "-b", help="银行名称: 招商银行/汉口银行"),
    risk_level: Optional[str] = typer.Option(None, "--risk-level", help="风险等级筛选"),
    limit: int = typer.Option(20, "--limit", help="每页记录数"),
    offset: int = typer.Option(0, "--offset", help="偏移量"),
    output_json: bool = typer.Option(False, "--json", help="JSON格式输出"),
):
    """列出银行产品"""
    data, total = product_service.list_products(
        keyword=keyword or "",
        category=category or "",
        bank=bank or "",
        risk_level=risk_level or "",
        limit=limit,
        offset=offset,
    )

    if should_json(output_json):
        # JSON输出
        json_data = []
        for row in data:
            item = {
                "产品类别": row.get("_product_category", ""),
                "银行": row.get("银行", ""),
            }
            for nc in ["产品名称", "产品名称/类别", "基金类别", "产品名称/业务"]:
                if nc in row and row.get(nc):
                    item["名称"] = row.get(nc)
                    break
            for tc in ["产品大类", "产品类型", "基金类型", "业务类型", "产品类别", "保险类型"]:
                if tc in row and row.get(tc):
                    item["类型"] = row.get(tc)
                    break
            json_data.append(item)
        render_json(json_data, total=total, offset=offset, limit=limit)
    else:
        # 表格输出 - 使用统一的简化列
        display_data = []
        for row in data:
            item = {"产品类别": row.get("_product_category", ""), "银行": row.get("银行", "")}
            for nc in ["产品名称", "产品名称/类别", "基金类别", "产品名称/业务"]:
                if nc in row and row.get(nc):
                    item["名称"] = row.get(nc)
                    break
            for tc in ["产品大类", "产品类型", "基金类型", "业务类型", "产品类别", "保险类型"]:
                if tc in row and row.get(tc):
                    item["类型"] = row.get(tc)
                    break
            if row.get("风险等级"):
                item["风险等级"] = row.get("风险等级")
            display_data.append(item)

        cols = ["产品类别", "银行", "名称", "类型", "风险等级"]
        labels = ["产品类别", "银行", "名称", "类型", "风险等级"]
        render_list_table(display_data, cols, labels, "产品列表", total, offset, limit)


@app.command("detail")
def detail_product(
    product_name: str = typer.Argument(..., help="产品名称"),
    category: Optional[str] = typer.Option(None, "--category", "-c", help="产品类别（可选，缩小范围）"),
    output_json: bool = typer.Option(False, "--json", help="JSON格式输出"),
):
    """查看产品详细信息"""
    data = product_service.get_product(product_name, category or "")
    if not data:
        typer.echo(f"未找到产品: {product_name}")
        raise typer.Exit(code=1)

    # 排除内部字段
    display_data = {k: v for k, v in data.items() if not k.startswith("_")}
    # 添加产品类别
    display_data["产品类别"] = data.get("_product_category", "")

    if should_json(output_json):
        render_json(display_data)
    else:
        cols = list(display_data.keys())
        render_detail_table(display_data, cols, cols, f"产品详情 - {product_name}")


@app.command("summary")
def summary(
    bank: Optional[str] = typer.Option(None, "--bank", "-b", help="按银行筛选"),
    category: Optional[str] = typer.Option(None, "--category", "-c", help="按类别筛选"),
    output_json: bool = typer.Option(False, "--json", help="JSON格式输出"),
):
    """产品统计汇总"""
    data = product_service.get_product_summary(bank=bank or "", category=category or "")
    output_stats(
        data,
        group_col_label="产品类别-银行",
        count_label="产品数量",
        total_label="",
        avg_label="",
        title="产品统计汇总",
        output_json=should_json(output_json),
    )


@app.command("categories")
def categories(
    output_json: bool = typer.Option(False, "--json", help="JSON格式输出"),
):
    """列出所有产品类别"""
    data = product_service.get_categories()
    if should_json(output_json):
        render_json(data)
    else:
        cols = ["类别标识", "类别名称", "产品数量", "银行分布"]
        labels = ["类别标识", "类别名称", "产品数量", "银行分布"]
        render_list_table(data, cols, labels, "产品类别列表", total=len(data), offset=0, limit=len(data))
