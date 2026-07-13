"""图片/语音上传路由"""
import os
import uuid
from pathlib import Path

from fastapi import APIRouter, UploadFile, File, HTTPException
from pmb.api.schemas.common import ApiResponse

router = APIRouter()

# 上传目录
UPLOAD_DIR = Path(__file__).parent.parent.parent.parent / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)

# 允许的文件类型
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/gif", "image/webp"}
ALLOWED_AUDIO_TYPES = {"audio/mpeg", "audio/wav", "audio/mp4", "audio/ogg"}

# 最大文件大小 (10MB)
MAX_FILE_SIZE = 10 * 1024 * 1024


@router.post("/upload/image", summary="上传图片")
async def upload_image(file: UploadFile = File(...)):
    """
    上传图片文件，返回可访问的URL。
    支持: JPEG, PNG, GIF, WebP
    """
    # 验证文件类型
    if file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"不支持的图片格式: {file.content_type}，仅支持 JPEG/PNG/GIF/WebP",
        )

    # 读取文件
    content = await file.read()

    # 验证文件大小
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=400,
            detail=f"文件过大，最大允许 10MB",
        )

    # 生成唯一文件名
    ext = _get_extension(file.content_type)
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = UPLOAD_DIR / filename

    # 保存文件
    with open(filepath, "wb") as f:
        f.write(content)

    # 返回 URL (相对路径，前端需自行拼接 baseUrl)
    return ApiResponse(data={
        "url": f"/uploads/{filename}",
        "filename": filename,
        "size": len(content),
        "content_type": file.content_type,
    })


@router.post("/upload/voice", summary="上传语音")
async def upload_voice(file: UploadFile = File(...)):
    """
    上传语音文件，返回可访问的URL。
    支持: MP3, WAV, M4A, OGG
    """
    # 验证文件类型
    if file.content_type not in ALLOWED_AUDIO_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"不支持的音频格式: {file.content_type}",
        )

    # 读取文件
    content = await file.read()

    # 验证文件大小
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=400,
            detail=f"文件过大，最大允许 10MB",
        )

    # 生成唯一文件名
    ext = _get_extension(file.content_type)
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = UPLOAD_DIR / filename

    # 保存文件
    with open(filepath, "wb") as f:
        f.write(content)

    return ApiResponse(data={
        "url": f"/uploads/{filename}",
        "filename": filename,
        "size": len(content),
        "content_type": file.content_type,
    })


def _get_extension(content_type: str) -> str:
    """根据 content_type 获取文件扩展名"""
    mapping = {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/gif": ".gif",
        "image/webp": ".webp",
        "audio/mpeg": ".mp3",
        "audio/wav": ".wav",
        "audio/mp4": ".m4a",
        "audio/ogg": ".ogg",
    }
    return mapping.get(content_type, "")
