"""异步 API 客户端 — Skill 通过 HTTP 调用 FAST API 端点

使用方式:
    from pmb.skills.api_client import create_client

    async def execute(self, **kwargs):
        api = create_client(user_name=kwargs.get("user_name", ""))
        accounts, _ = await api.list_accounts()
        stats, _ = await api.get_consumption_stats(group_by="category")
"""

import os
import time
from typing import Any
from urllib.parse import quote

import httpx

API_BASE_URL = os.environ.get("PMB_API_BASE_URL", "http://localhost:8000")


class SkillApiError(Exception):
    """API 调用异常"""
    def __init__(self, message: str, code: int = -1):
        super().__init__(message)
        self.code = code


class SkillApiClient:
    """Skill 专用异步 HTTP 客户端

    - 自动注入 x-user-name header（URL 编码）
    - 自动解包 ApiResponse 信封 {code, message, data, total} -> 返回 (data, total)
    - 自动记录 TraceContext 供技能监控模块追踪
    """

    def __init__(self, base_url: str = "", user_name: str = ""):
        self.base_url = base_url.rstrip("/") or API_BASE_URL.rstrip("/")
        self.user_name = user_name
        self._client: httpx.AsyncClient | None = None

    async def _get_client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(timeout=30.0)
        return self._client

    async def close(self):
        if self._client:
            await self._client.aclose()
            self._client = None

    def _headers(self) -> dict:
        h = {}
        if self.user_name:
            h["x-user-name"] = quote(self.user_name, safe="")
        return h

    async def _get(self, path: str, params: dict | None = None) -> tuple[Any, int]:
        """发起 GET 请求，解包 ApiResponse，返回 (data, total)"""
        client = await self._get_client()
        url = f"{self.base_url}{path}"

        t0 = time.perf_counter()
        resp = await client.get(url, params=params, headers=self._headers())
        elapsed_ms = int((time.perf_counter() - t0) * 1000)
        self._record_trace(path, elapsed_ms)

        resp.raise_for_status()
        body = resp.json()
        code = body.get("code", -1)
        if code != 0:
            raise SkillApiError(body.get("message", "API error"), code=code)

        data = body.get("data")
        total = body.get("total", 0)
        if total is None:
            total = len(data) if isinstance(data, list) else 0
        return data, total

    def _record_trace(self, path: str, duration_ms: int):
        """记录 API 调用到 TraceContext"""
        try:
            from pmb.ai_manage.services.skill_monitor_service import (
                _trace_active,
                _trace_stack,
            )
            if _trace_active.get():
                traces = list(_trace_stack.get())
                traces.append({
                    "service_name": "api_client",
                    "function_name": f"GET {path}",
                    "duration_ms": duration_ms,
                    "row_count": 0,
                })
                _trace_stack.set(traces)
        except Exception:
            pass

    # ===== 账户 API =====

    async def list_accounts(
        self, account_type: str = "", limit: int = 100
    ) -> tuple[list, int]:
        params = {"limit": limit}
        if account_type:
            params["account_type"] = account_type
        return await self._get("/api/v1/accounts", params)

    async def get_account_summary(self) -> tuple[list[dict], int]:
        return await self._get("/api/v1/accounts/summary")

    # ===== 消费 API =====

    async def get_consumption_stats(
        self,
        group_by: str = "subcategory",
        date_from: str = "",
        date_to: str = "",
        top: int = 10,
    ) -> tuple[list, int]:
        params = {
            "group_by": group_by,
            "top": top,
        }
        if date_from:
            params["date_from"] = date_from
        if date_to:
            params["date_to"] = date_to
        return await self._get("/api/v1/consumptions/stats", params)

    # ===== 产品 API =====

    async def list_products(
        self, category: str = "", risk_level: str = "", limit: int = 20
    ) -> tuple[list, int]:
        params = {"limit": limit}
        if category:
            params["category"] = category
        if risk_level:
            params["risk_level"] = risk_level
        return await self._get("/api/v1/products", params)

    # ===== 交易 API =====

    async def list_transactions(
        self,
        source: str = "all",
        direction: str = "",
        date_from: str = "",
        date_to: str = "",
        category: str = "",
        limit: int = 20,
        offset: int = 0,
    ) -> tuple[list, int]:
        params = {
            "source": source,
            "limit": limit,
            "offset": offset,
        }
        if direction:
            params["direction"] = direction
        if date_from:
            params["date_from"] = date_from
        if date_to:
            params["date_to"] = date_to
        if category:
            params["category"] = category
        return await self._get("/api/v1/transactions", params)

    # ===== 持有产品 API =====

    async def list_loans(self, limit: int = 100, offset: int = 0) -> tuple[list, int]:
        params = {"limit": limit, "offset": offset}
        if self.user_name:
            params["user_name"] = self.user_name
        return await self._get("/api/v1/held-products/loans", params)

    async def get_loan_detail(self, loan_id: str) -> dict | None:
        data, _ = await self._get(f"/api/v1/held-products/loans/{loan_id}")
        return data if data else None

    # ===== 缴费 API =====

    async def list_payments(
        self,
        payment_type: str = "",
        date_from: str = "",
        date_to: str = "",
        limit: int = 100,
        offset: int = 0,
    ) -> tuple[list, int]:
        """查询缴费记录"""
        params = {"limit": limit, "offset": offset}
        if payment_type:
            params["payment_type"] = payment_type
        if date_from:
            params["date_from"] = date_from
        if date_to:
            params["date_to"] = date_to
        return await self._get("/api/v1/payments", params)

    async def get_payment_summary(self) -> tuple[dict, int]:
        """获取缴费汇总统计"""
        return await self._get("/api/v1/payments/summary")

    async def get_payment_forecast(self) -> tuple[list, int]:
        """获取待缴费预测"""
        return await self._get("/api/v1/payments/forecast")


def create_client(user_name: str = "", base_url: str = "") -> SkillApiClient:
    """便捷工厂函数"""
    return SkillApiClient(base_url=base_url, user_name=user_name)
