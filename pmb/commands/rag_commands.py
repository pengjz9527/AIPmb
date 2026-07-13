"""RAG 知识库索引管理 CLI 命令"""
import typer
from rich.console import Console
from rich.table import Table

from pmb.rag.indexer import ProductIndexer

console = Console()
app = typer.Typer(help="RAG知识库索引管理")


@app.command("build")
def build_index(
    force: bool = typer.Option(False, "--force", "-f", help="强制重建索引（即使已存在）"),
):
    """构建产品知识库向量索引

    从 coredatas/ 目录下的 7 类产品 Excel 文件中提取产品信息，
    调用 Embedding API 向量化后存入 ChromaDB 向量库。
    """
    console.print("[bold cyan]正在构建产品知识库索引...[/bold cyan]")
    indexer = ProductIndexer()
    result = indexer.build_index(force=force)

    if result.get("status") == "skipped":
        console.print(f"[yellow]⏭  {result['reason']}[/yellow]")
        _print_status(result)
        return

    if result.get("status") == "empty":
        console.print("[red]✗ 未找到任何产品数据，请检查 coredatas/ 目录[/red]")
        return

    console.print(f"[green]✓ 索引构建完成！[/green]")
    _print_status(result)


@app.command("status")
def index_status():
    """查看知识库索引状态"""
    indexer = ProductIndexer()
    result = indexer.get_status()
    _print_status(result)


@app.command("rebuild")
def rebuild_index():
    """重建索引（删除旧数据后重新构建）"""
    console.print("[bold yellow]正在重建产品知识库索引...[/bold yellow]")
    indexer = ProductIndexer()
    result = indexer.rebuild_index()

    if result.get("status") == "empty":
        console.print("[red]✗ 重建失败：未找到任何产品数据[/red]")
        return

    console.print(f"[green]✓ 索引重建完成！[/green]")
    _print_status(result)


def _print_status(result: dict):
    """格式化打印索引状态"""
    doc_count = result.get("document_count", 0)
    categories = result.get("categories", {})
    collection = result.get("collection_name", "")
    persist_dir = result.get("persist_dir", "")

    table = Table(title="知识库索引状态")
    table.add_column("项目", style="cyan")
    table.add_column("值", style="green")

    table.add_row("Collection", collection)
    table.add_row("持久化目录", persist_dir)
    table.add_row("文档总数", str(doc_count))

    if categories:
        cat_str = ", ".join(f"{k}({v})" for k, v in sorted(categories.items()))
        table.add_row("各类别数量", cat_str)
    else:
        table.add_row("各类别数量", "暂无数据")

    console.print(table)
