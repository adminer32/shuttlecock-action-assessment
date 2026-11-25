# syntax=docker/dockerfile:1
# ============================================================
# 教师端前端（Vue3 + Vite）镜像
# 多阶段：node:22-alpine 构建 -> nginx:alpine 运行
# 构建上下文为仓库根目录：
#   podman build -f deploy/docker/teacher-web.Dockerfile -t lingxi/teacher-web:latest .
# ============================================================

# 国内可拉取的镜像源前缀，可通过 --build-arg 覆盖
ARG REGISTRY_MIRROR=docker.m.daocloud.io

# ---------- 构建阶段 ----------
FROM ${REGISTRY_MIRROR}/library/node:22-alpine AS builder
WORKDIR /app

# 复制教师端源码（.dockerignore / --ignorefile 已排除 node_modules）
COPY apps/teacher-web/ ./

# 使用国内 npm 镜像源安装依赖（必须显式指定 --registry）
RUN npm ci --registry=https://registry.npmmirror.com

# 注意：npm run build 会先执行 vue-tsc 类型检查，再 vite build，产物目录为默认 dist/
RUN npm run build

# ---------- 运行阶段 ----------
FROM ${REGISTRY_MIRROR}/library/nginx:alpine AS runtime

# 复制默认构建产物目录 dist/
COPY --from=builder /app/dist/ /usr/share/nginx/html/
# 教师端 nginx 站点配置（SPA 回退 + 反向代理）
COPY deploy/docker/nginx/teacher-web.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
