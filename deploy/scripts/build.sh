#!/usr/bin/env bash
# ============================================================
# 构建全部镜像（不启动）
# 用法：
#   ./scripts/build.sh                 # 构建全部镜像
#   ./scripts/build.sh server-go       # 仅构建指定服务
#
# 说明：构建上下文为仓库根目录，通过各 Dockerfile 内的
#       ${REGISTRY_MIRROR} 使用国内可拉取的镜像源前缀。
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

COMPOSE_CMD="${COMPOSE_CMD:-podman-compose}"

if [[ ! -f .env ]]; then
  echo ">> 未找到 .env，正在从 .env.example 复制……"
  cp .env.example .env
fi

echo ">> 开始构建镜像……"
if [[ $# -gt 0 ]]; then
  # 仅构建指定服务
  "${COMPOSE_CMD}" build "$@"
else
  "${COMPOSE_CMD}" build
fi

echo ">> 构建完成。可用 ./scripts/up.sh 启动服务。"
