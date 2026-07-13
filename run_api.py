"""API服务启动入口"""
import uvicorn


if __name__ == "__main__":
    uvicorn.run(
        "pmb.api.app:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )
