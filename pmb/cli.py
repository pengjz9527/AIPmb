import typer
from typing import Optional

from pmb.commands import account, transaction, product, consumption, rag_commands
from pmb import __version__

app = typer.Typer(
    name="pmb",
    help="银行个人业务CLI服务接口",
    no_args_is_help=True,
)

# 注册子命令组
app.add_typer(account.app, name="account")
app.add_typer(transaction.app, name="transaction")
app.add_typer(product.app, name="product")
app.add_typer(consumption.app, name="consumption")
app.add_typer(rag_commands.app, name="rag")


# 全局状态
from pmb.core.state import state


def version_callback(value: bool):
    if value:
        typer.echo(f"pmb v{__version__}")
        raise typer.Exit()


def json_callback(value: bool):
    if value:
        state.json_output = True
    return value


@app.callback()
def main(
    version: Optional[bool] = typer.Option(
        None, "--version", "-v",
        help="显示版本号",
        callback=version_callback,
        is_eager=True,
    ),
    json_output: Optional[bool] = typer.Option(
        None, "--json",
        help="所有子命令使用JSON格式输出",
        callback=json_callback,
        is_eager=True,
    ),
):
    """银行个人业务CLI服务接口

    提供账户查询、交易明细、银行产品、消费记录等服务。
    所有查询命令都支持 --json 参数输出JSON格式。
    """
    pass


@app.command("repl")
def repl():
    """进入交互式REPL模式"""
    from pmb.repl.shell import start_repl
    start_repl()
