# syntax=docker/dockerfile:1
# ============================================================
# 学生端后端（Go 1.23 + Gin）镜像
# 多阶段：golang:1.23-alpine 构建（静态编译，CGO_ENABLED=0）-> alpine 运行
# 构建上下文为仓库根目录：
#   podman build -f deploy/docker/server-go.Dockerfile -t lingxi/server-go:latest .
# ============================================================

# 国内可拉取的镜像源前缀，可通过 --build-arg 覆盖
ARG REGISTRY_MIRROR=docker.m.daocloud.io

# ---------- 构建阶段 ----------
FROM ${REGISTRY_MIRROR}/library/golang:1.23-alpine AS builder

# Go 模块国内代理
ENV GOPROXY=https://goproxy.cn,direct
ENV CGO_ENABLED=0

WORKDIR /src

# 先复制 go.mod / go.sum 以利用依赖层缓存
COPY services/server-go/go.mod services/server-go/go.sum ./
RUN go mod download

# 复制全部源码并静态编译
COPY services/server-go/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server

# ---------- 运行阶段 ----------
FROM ${REGISTRY_MIRROR}/library/alpine:3.20 AS runtime

# ca-certificates 用于 HTTPS 出站（DeepSeek 等），tzdata 用于设置时区
RUN apk add --no-cache ca-certificates tzdata
ENV TZ=Asia/Shanghai

# 工作目录固定为 /app，程序默认读取相对路径 configs/config.json
WORKDIR /app

COPY --from=builder /out/server /app/server

# 拷贝配置目录；容器内仍可用环境变量覆盖（环境变量优先级最高）
COPY services/server-go/configs /app/configs

# 数据目录（可通过 compose 挂载命名卷持久化）
RUN mkdir -p /app/data/uploads /app/data/videos

EXPOSE 8001

# 入口：读取 /app/configs/config.json 后由环境变量覆盖
ENTRYPOINT ["/app/server"]
