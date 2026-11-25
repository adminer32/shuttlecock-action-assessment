#!/usr/bin/env bash
# ============================================================
# 停止并移除容器（默认保留数据卷）
# 用法：
#   ./scripts/down.sh          # 停止并移除容器/网络，保留数据卷
#   ./scripts/down.sh -v       # 同时删除数据卷（会清空数据库等数据！）
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

COMPOSE_CMD="${COMPOSE_CMD:-podman-compose}"

echo ">> 停止服务……"
"${COMPOSE_CMD}" down "$@"

if [[ "${1:-}" == "-v" || "${1:-}" == "--volumes" ]]; then
  echo ">> 已连同数据卷一并删除（数据库、上传文件等数据将被清空）。"
fi
