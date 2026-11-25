#!/usr/bin/env bash
# ============================================================
# 启动整套服务（构建镜像并后台运行）
# 用法：./scripts/up.sh [额外参数...]
# 需在 WSL 中执行，例如：
#   cd /mnt/d/AiWork/shuttlecock-action-assessment/deploy
#   ./scripts/up.sh
# ============================================================
set -euo pipefail

# 切换到 deploy 目录（compose 文件所在处）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

COMPOSE_CMD="${COMPOSE_CMD:-podman-compose}"

# 首次部署：若没有 .env 则从示例复制
if [[ ! -f .env ]]; then
  echo ">> 未找到 .env，正在从 .env.example 复制，请按需修改后再执行……"
  cp .env.example .env
  echo ">> 已生成 .env，请检查其中的密码、密钥等配置。"
fi

echo ">> 启动服务（首次会构建镜像，耗时较长）……"
"${COMPOSE_CMD}" up -d --build "$@"

echo ">> 当前容器状态："
"${COMPOSE_CMD}" ps

echo ""
echo ">> 学生端： http://localhost:${STUDENT_WEB_PORT:-$(grep -E '^STUDENT_WEB_PORT=' .env | cut -d= -f2 || echo 8080)}"
echo ">> 教师端： http://localhost:${TEACHER_WEB_PORT:-$(grep -E '^TEACHER_WEB_PORT=' .env | cut -d= -f2 || echo 8081)}"
