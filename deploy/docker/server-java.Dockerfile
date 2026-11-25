# syntax=docker/dockerfile:1
# ============================================================
# 教师端后端（Spring Boot 3.4 多模块 Maven）镜像
# 多阶段：maven:3.9-eclipse-temurin-21 构建 -> eclipse-temurin:21-jre 运行
# 可运行模块是 service，产物 service/target/*.jar
# 构建上下文为仓库根目录：
#   podman build -f deploy/docker/server-java.Dockerfile -t lingxi/server-java:latest .
# ============================================================

# 国内可拉取的镜像源前缀，可通过 --build-arg 覆盖
ARG REGISTRY_MIRROR=docker.m.daocloud.io

# ---------- 构建阶段 ----------
FROM ${REGISTRY_MIRROR}/library/maven:3.9-eclipse-temurin-21 AS builder

# 配置阿里云 Maven 镜像，加速依赖下载
COPY deploy/docker/maven-settings.xml /root/.m2/settings.xml

WORKDIR /build

# 复制整个多模块工程（common + service）
COPY services/server-java/ ./

# 跳过测试打包，repackage 生成可执行 jar
RUN mvn -B -DskipTests package

# 统一产物路径，避免版本号变化影响后续 COPY
RUN mkdir -p /out && cp service/target/service-*.jar /out/app.jar

# ---------- 运行阶段 ----------
FROM ${REGISTRY_MIRROR}/library/eclipse-temurin:21-jre AS runtime

# 安装 curl（用于容器健康检查）与时区数据
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl tzdata \
    && rm -rf /var/lib/apt/lists/*

ENV TZ=Asia/Shanghai

WORKDIR /app
COPY --from=builder /out/app.jar /app/app.jar

# JVM 参数：适配容器内存限制，可通过环境变量 JAVA_OPTS 覆盖
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

EXPOSE 9002

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
