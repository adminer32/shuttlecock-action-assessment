# syntax=docker/dockerfile:1
# ============================================================
# 学生端前端（Vue3 + Vite）镜像
# 多阶段：node:22-alpine 构建 -> nginx:alpine 运行
# 构建上下文为仓库根目录：
#   podman build -f deploy/docker/student-web.Dockerfile -t lingxi/student-web:latest .
# ============================================================

# 国内可拉取的镜像源前缀，可通过 --build-arg 覆盖
ARG REGISTRY_MIRROR=docker.m.daocloud.io

# ---------- 构建阶段 ----------
FROM ${REGISTRY_MIRROR}/library/node:22-alpine AS builder
WORKDIR /app

# 复制学生端源码（.dockerignore / --ignorefile 已排除 node_modules，避免宿主机依赖污染）
COPY apps/student-web/ ./

# 使用国内 npm 镜像源安装依赖（必须显式指定 --registry）
RUN npm ci --registry=https://registry.npmmirror.com

# 容器化部署下前端接口走同源反向代理（nginx），构建时清空外部地址，
# 使 axios / fetch 使用相对路径（/api/...）。这些变量优先级高于 .env.prod。
ENV VITE_BACK_END_BASE_URL=""
ENV VITE_PYTHON_BACK_END_BASE_URL=""
ENV VITE_WS_BASE_URL=""

# 注意：build:prod = vite build --mode prod，产物目录为 dist/
RUN npm run build:prod

# ---------- 运行阶段 ----------
FROM ${REGISTRY_MIRROR}/library/nginx:alpine AS runtime

# 复制构建产物
COPY --from=builder /app/dist/ /usr/share/nginx/html/
# 学生端 nginx 站点配置（SPA 回退 + 反向代理）
COPY deploy/docker/nginx/student-web.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
