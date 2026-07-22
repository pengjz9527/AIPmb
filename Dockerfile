# ---- AIPmb 银行个人业务服务 Docker 镜像 ----
FROM python:3.12-slim

# 阿里云镜像加速（apt + pip）
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources 2>/dev/null; \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources 2>/dev/null; \
    echo 'Done'

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 用阿里云 PyPI 镜像安装依赖
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/

# 安装 Python 依赖
RUN pip install --no-cache-dir \
    typer[all]>=0.9.0 \
    rich>=13.0 \
    openpyxl>=3.1 \
    prompt-toolkit>=3.0 \
    fastapi>=0.109.0 \
    "uvicorn[standard]>=0.27.0" \
    dashscope>=1.14.0 \
    python-multipart>=0.0.6 \
    websockets>=12.0 \
    openai>=2.0 \
    httpx>=0.26.0 \
    chromadb>=0.5.0 \
    setuptools>=68.0

# 复制项目文件
COPY pmb/ ./pmb/
COPY aipmb_manage/build/web/ ./aipmb_manage/build/web/
COPY coredatas/ ./coredatas/
COPY data/ ./data/
COPY downloads/ ./downloads/
COPY landing/ ./landing/
COPY rag_docs/ ./rag_docs/
COPY uploads/ ./uploads/
COPY run_api.py ./

# 确保上传目录存在
RUN mkdir -p /app/uploads /app/output

# 环境变量（镜像内置默认值，运行时可通过 -e 覆盖）
ENV LLM_API_KEY=sk-S3T9C8gOvb8AortgWj5hobJilMVC2gl0BpzPuZIQMR8ywu0r
ENV LLM_BASE_URL=https://api.moonshot.cn/v1
ENV LLM_MODEL=kimi-k2.5
ENV DASHSCOPE_API_KEY=sk-ws-H.EMEDHIE.ssIC.MEUCIDIfHEc_YXeuD83ahU6Rj6J8KQEgmvogK4snRfaLqjTpAiEA6a5h1vmP4inyXP3LNbjRTvUqGditYBIEjxJec_7nYxs

EXPOSE 8000

CMD ["python", "run_api.py"]
