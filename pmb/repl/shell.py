import shlex
import sys

from prompt_toolkit import PromptSession
from prompt_toolkit.history import FileHistory
from prompt_toolkit.completion import WordCompleter
from prompt_toolkit.formatted_text import HTML
from typer.testing import CliRunner

from pmb.cli import app

runner = CliRunner()

# 自动补全关键词
COMMANDS = [
    "account list", "account detail", "account summary",
    "transaction list", "transaction detail", "transaction summary",
    "product list", "product detail", "product summary", "product categories",
    "consumption list", "consumption detail", "consumption stats",
    "help", "exit", "quit",
]

OPTIONS = [
    "--keyword", "-k", "--type", "-t", "--source", "-s", "--direction", "-d",
    "--category", "-c", "--bank", "-b", "--risk-level", "--date-from", "--date-to",
    "--amount-min", "--amount-max", "--account", "--limit", "--offset",
    "--group-by", "--top", "--subcategory", "--channel", "--json",
    "--help", "-h",
]

VALUES = [
    "credit", "debit", "all", "income", "expense",
    "deposit", "loan", "wealth", "fund", "insurance", "forex", "gold",
    "招商银行", "汉口银行",
    "month", "year", "category", "subcategory", "channel", "merchant",
    "餐饮美食", "超市便利店", "网购电商", "公共交通", "还款", "退款", "分期",
]

completer = WordCompleter(
    COMMANDS + OPTIONS + VALUES,
    ignore_case=True,
    sentence=True,
)

BANNER = """
[bold]pmb[/bold] - 银行个人业务CLI服务 (交互模式)

可用命令:
  account list|detail|summary     账户信息查询
  transaction list|detail|summary 交易明细查询
  product list|detail|summary|categories  银行产品查询
  consumption list|detail|stats   消费记录查询
  help                            显示帮助
  exit / quit                     退出

所有命令支持 --json 输出JSON格式
"""


def start_repl():
    """启动交互式REPL"""
    from rich.console import Console
    console = Console()
    console.print(BANNER, highlight=False)

    history_file = _get_history_path()
    session: PromptSession = PromptSession(
        history=FileHistory(str(history_file)),
        completer=completer,
    )

    while True:
        try:
            text = session.prompt(
                HTML("<b>pmb&gt;</b> "),
            )
        except (EOFError, KeyboardInterrupt):
            console.print("\n[dim]再见![/dim]")
            break

        text = text.strip()
        if not text:
            continue
        if text in ("exit", "quit", "q"):
            console.print("[dim]再见![/dim]")
            break
        if text in ("help", "?", "h"):
            result = runner.invoke(app, ["--help"])
            console.print(result.output)
            continue

        # 解析命令并执行
        try:
            args = shlex.split(text)
        except ValueError as e:
            console.print(f"[red]参数解析错误: {e}[/red]")
            continue

        result = runner.invoke(app, args)
        if result.output:
            console.print(result.output, end="")
        if result.exception and not isinstance(result.exception, SystemExit):
            console.print(f"[red]错误: {result.exception}[/red]")


def _get_history_path():
    from pathlib import Path
    history_dir = Path.home() / ".pmb"
    history_dir.mkdir(exist_ok=True)
    return history_dir / "history"
