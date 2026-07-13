from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path
from starlette.types import Scope, Receive, Send

from pmb.api.routers import (
    account_router,
    transaction_router,
    product_router,
    consumption_router,
    wealth_router,
    chat_router,
    recommendation_router,
    agent_router,
    upload_router,
    auth_router,
    purchase_router,
    ai_recommendation_router,
    payment_router,
    ai_insight_router,
)
from pmb.ai_manage.routers import (
    model_config_router,
    user_router,
    tagging_router,
    calendar_router,
    matching_router,
    conversation_router,
    held_product_router,
    skill_monitor_router,
    product_matching_router,
    profile_portrait_router,
    risk_assessment_router,
)


class SPAMiddleware:
    """ASGI middleware that serves static files with SPA fallback to index.html."""
    def __init__(self, directory: str):
        self.directory = Path(directory)
        self.static = StaticFiles(directory=str(directory), check_dir=False)

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] not in ("http", "websocket"):
            await self.static(scope, receive, send)
            return

        path = scope.get("path", "/")
        # Strip the mount prefix (/manage) to get the relative file path
        relative = path.removeprefix("/manage")
        file_path = self.directory / relative.lstrip("/") if relative.strip("/") else self.directory / "index.html"

        if relative.strip("/") and file_path.exists() and file_path.is_file():
            # Serve existing file, update scope path to match what StaticFiles expects
            scope["path"] = relative
            await self.static(scope, receive, send)
        else:
            # SPA fallback: serve index.html
            scope["path"] = "/index.html"
            await self.static(scope, receive, send)


def create_app() -> FastAPI:
    app = FastAPI(
        title="AI手机银行 API",
        description="AI原生手机银行后端服务，支持多智能体对话",
        version="0.1.0",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(account_router.router, prefix="/api/v1", tags=["账户"])
    app.include_router(transaction_router.router, prefix="/api/v1", tags=["交易"])
    app.include_router(product_router.router, prefix="/api/v1", tags=["产品"])
    app.include_router(consumption_router.router, prefix="/api/v1", tags=["消费"])
    app.include_router(wealth_router.router, prefix="/api/v1", tags=["财富"])
    app.include_router(chat_router.router, prefix="/api/v1", tags=["对话"])
    app.include_router(recommendation_router.router, prefix="/api/v1", tags=["推荐"])
    app.include_router(agent_router.router, prefix="/api/v1", tags=["智能体"])
    app.include_router(upload_router.router, prefix="/api/v1", tags=["上传"])
    app.include_router(auth_router.router, prefix="/api/v1", tags=["认证"])
    app.include_router(purchase_router.router, prefix="/api/v1", tags=["购买"])
    app.include_router(ai_recommendation_router.router, prefix="/api/v1", tags=["推荐"])

    # 缴费记录路由
    app.include_router(payment_router.router, prefix="/api/v1", tags=["缴费"])

    # AI 洞察路由
    app.include_router(ai_insight_router.router, prefix="/api/v1", tags=["AI洞察"])

    # AI-Manage 运营管理路由
    app.include_router(model_config_router.router, prefix="/api/v1", tags=["AI-Manage"])
    app.include_router(user_router.router, prefix="/api/v1", tags=["AI-Manage"])
    app.include_router(tagging_router.router, prefix="/api/v1", tags=["AI-Manage"])
    app.include_router(calendar_router.router, prefix="/api/v1", tags=["AI-Manage"])
    app.include_router(matching_router.router, prefix="/api/v1", tags=["AI-Manage"])
    app.include_router(conversation_router.router, prefix="/api/v1", tags=["AI-Manage"])
    app.include_router(skill_monitor_router.router, prefix="/api/v1", tags=["AI-Manage"])
    app.include_router(product_matching_router.router, prefix="/api/v1", tags=["AI-Manage"])
    app.include_router(profile_portrait_router.router, prefix="/api/v1", tags=["AI-Manage"])
    app.include_router(risk_assessment_router.router, prefix="/api/v1", tags=["风险测评"])

    # 持有产品路由
    app.include_router(held_product_router.router, prefix="/api/v1", tags=["持有产品"])

    # 静态文件服务: 上传文件目录
    uploads_dir = Path(__file__).parent.parent.parent / "uploads"
    uploads_dir.mkdir(exist_ok=True)
    app.mount("/uploads", StaticFiles(directory=str(uploads_dir)), name="uploads")

    # AI-Manage 运营管理前端 (Flutter Web, 同源部署在 /manage)
    manage_web_dir = Path(__file__).parent.parent.parent / "aipmb_manage" / "build" / "web"
    if manage_web_dir.exists():
        app.mount("/manage", SPAMiddleware(directory=str(manage_web_dir)), name="manage_web")

    @app.get("/api/v1/health")
    async def health_check():
        return {"status": "ok", "version": "0.1.0"}

    return app


app = create_app()
