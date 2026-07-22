#!/bin/bash
# 构建 Flutter Web 管理后台，部署到 /manage 子路径
# 关键：必须使用 --base-href /manage/，否则浏览器无法加载 JS/CSS 资源导致白屏！
set -e

cd "$(dirname "$0")/aipmb_manage"
echo ">>> 构建 Flutter Web 管理后台 (base-href=/manage/) ..."
flutter build web --base-href /manage/
echo ">>> 构建完成: aipmb_manage/build/web/"
