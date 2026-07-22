#!/usr/bin/env python3
"""AIPmb 一键部署到阿里云轻量服务器"""
import os
import io
import tarfile
import paramiko
from pathlib import Path

# ---- 服务器配置 ----
HOST = "39.107.68.177"
USER = "root"
PASSWORD = "TianSha9527"
IMAGE_NAME = "aipmb"
CONTAINER_NAME = "aipmb-app"
PORT = 8000

PROJECT_ROOT = Path(__file__).parent

# ---- 需要上传的文件/目录 ----
UPLOAD_ITEMS = [
    "Dockerfile",
    "run_api.py",
    "pyproject.toml",
    "pmb/",
    "coredatas/",
    "data/",
    "downloads/",
    "landing/",
    "rag_docs/",
    "uploads/",
    "aipmb_manage/build/web/",
]


def create_tar() -> bytes:
    """将项目文件打包为 tar.gz（内存中）"""
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for item in UPLOAD_ITEMS:
            src = PROJECT_ROOT / item
            if not src.exists():
                print(f"  ⚠️  跳过（不存在）: {item}")
                continue
            tar.add(src, arcname=item)
            print(f"  ✅ {item}")
    buf.seek(0)
    return buf.getvalue()


def ssh_exec(client: paramiko.SSHClient, cmd: str) -> tuple[str, str, int]:
    """执行远程命令，返回 (stdout, stderr, exit_code)"""
    stdin, stdout, stderr = client.exec_command(cmd)
    out = stdout.read().decode()
    err = stderr.read().decode()
    rc = stdout.channel.recv_exit_status()
    return out, err, rc


def main():
    print("=" * 60)
    print("AIPmb 一键部署")
    print("=" * 60)

    # 1. 打包项目
    print("\n[1/5] 打包项目文件 ...")
    tar_data = create_tar()
    print(f"  打包完成: {len(tar_data) / 1024 / 1024:.1f} MB")

    # 2. 连接服务器
    print(f"\n[2/5] 连接服务器 {HOST} ...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, username=USER, password=PASSWORD, timeout=15)
    sftp = client.open_sftp()
    print("  已连接")

    # 3. 上传文件
    print("\n[3/5] 上传项目文件到服务器 ...")
    remote_tar = "/root/aipmb.tar.gz"
    sftp.putfo(io.BytesIO(tar_data), remote_tar)
    print(f"  已上传到 {remote_tar}")

    # 4. 构建镜像
    print("\n[4/5] 服务器构建 Docker 镜像 ...")
    build_cmd = (
        f"cd /root && rm -rf aipmb-src && mkdir aipmb-src && "
        f"tar -xzf aipmb.tar.gz -C aipmb-src && "
        f"cd aipmb-src && "
        f"docker build -t {IMAGE_NAME}:latest . 2>&1"
    )
    out, err, rc = ssh_exec(client, build_cmd)
    if rc != 0:
        # 打印最后 20 行错误
        lines = (out + err).strip().split("\n")
        for line in lines[-20:]:
            print(f"  {line}")
        print(f"\n  ❌ 构建失败 (exit={rc})")
        client.close()
        return
    lines = (out + err).strip().split("\n")
    for line in lines[-5:]:
        print(f"  {line}")
    print(f"  ✅ 镜像构建成功")

    # 5. 启动容器
    print("\n[5/5] 启动容器 ...")
    run_cmd = (
        f"docker rm -f {CONTAINER_NAME} 2>/dev/null; "
        f"docker run -d "
        f"--name {CONTAINER_NAME} "
        f"--restart unless-stopped "
        f"-p {PORT}:8000 "
        f"{IMAGE_NAME}:latest"
    )
    out, err, rc = ssh_exec(client, run_cmd)
    print(f"  {out.strip()}")

    # 验证
    check_cmd = f"docker ps --filter name={CONTAINER_NAME} --format '{{{{.Status}}}}'"
    out, err, rc = ssh_exec(client, check_cmd)
    if "Up" in out:
        print(f"  ✅ 容器运行中: {out.strip()}")
        print(f"\n  🌐 访问地址: http://{HOST}:{PORT}")
        print(f"  📊 管理后台: http://{HOST}:{PORT}/manage/")
    else:
        print(f"  ❌ 容器未运行: {out.strip()}")
        logs_cmd = f"docker logs --tail 20 {CONTAINER_NAME}"
        out, err, rc = ssh_exec(client, logs_cmd)
        print(f"  日志:\n{out}")

    sftp.close()
    client.close()
    print("\n部署完成！")


if __name__ == "__main__":
    main()
