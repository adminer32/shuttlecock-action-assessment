#!/usr/bin/env bash
# ============================================================
# 查看服务日志（默认跟随全部服务）
# 用法：
#   ./scripts/logs.sh                 # 跟随所有服务日志
#   ./scripts/logs.sh server-go       # 只看某个服务
#   ./scripts/logs.sh --tail=200 mysql
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

COMPOSE_CMD="${COMPOSE_CMD:-podman-compose}"

echo ">> 查看日志（Ctrl+C 退出）……"
exec "${COMPOSE_CMD}" logs -f "$@"
