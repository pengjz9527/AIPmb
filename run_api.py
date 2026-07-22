"""API服务启动入口"""
import sys
from pathlib import Path
import uvicorn


def _check_manage_web():
    """检查管理后台 Web 构建是否存在且 base-href 正确"""
    index_html = (
        Path(__file__).parent
        / "aipmb_manage" / "build" / "web" / "index.html"
    )
    if not index_html.exists():
        print(
            "\n  ⚠️  管理后台 Web 未构建！"
            "\n  请执行: bash build_manage.sh"
            "\n",
            file=sys.stderr,
        )
        return
    content = index_html.read_text()
    if '<base href="/manage/">' not in content:
        print(
            "\n  ⚠️  管理后台 base-href 不正确（当前为 '/'），会导致白屏！"
            "\n  请执行: bash build_manage.sh"
            "\n",
            file=sys.stderr,
        )


if __name__ == "__main__":
    _check_manage_web()
    uvicorn.run(
        "pmb.api.app:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )
