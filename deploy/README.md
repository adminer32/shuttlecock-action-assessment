# 翎翼毽球教学平台 —— 部署文档（Podman + Podman Compose）

本文档说明如何在 **WSL2** 环境中使用 **Podman / podman-compose** 以容器方式部署整套「翎翼毽球教学平台」。

---

## 一、架构与端口总览

| 组件 | 类型 | 容器内端口 | 宿主机端口 | 说明 |
| --- | --- | --- | --- | --- |
| `mysql` | MySQL 8.0 | 3306 | 3306（可改） | 业务数据库，命名卷 `mysql_data` 持久化 |
| `redis` | Redis 7 | 6379 | 6379（可改） | 缓存，命名卷 `redis_data` 持久化 |
| `server-go` | 学生端后端（Go 1.23 + Gin） | 8001 | 不对外（经 nginx 反代） | 提供 `/api`、`/videos`、`/uploads` |
| `server-java` | 教师端后端（Spring Boot 3.4） | 9002 | 不对外（经 nginx 反代） | 多模块 Maven，运行模块为 `service` |
| `student-web` | 学生端前端（Vue3 + nginx） | 80 | **8080** | 访问入口，反代 `/api`、`/videos`、`/uploads` -> server-go |
| `teacher-web` | 教师端前端（Vue3 + nginx） | 80 | **8081** | 访问入口，反代 `/api`、`/videos` -> server-java |

所有服务在自定义 bridge 网络 `lingxi-net` 中，通过服务名互相访问。

```
浏览器 ──► student-web(8080) ──/api,/videos,/uploads──► server-go(8001) ──► mysql / redis
        └► teacher-web(8081) ──/api,/videos──────────► server-java(9002) ─► mysql / redis
```

---

## 二、前置条件

### 2.1 必须：在 WSL 中访问本仓库

> **重要：本文档所有命令都必须在 WSL（Linux 子系统）中执行，而不是在 Windows 的 PowerShell / CMD 中执行。**
>
> 本仓库位于 Windows 的 `D:\AiWork\shuttlecock-action-assessment`，在 WSL 中需通过挂载路径访问：

```bash
# 进入仓库（注意是 /mnt/d 而不是 D:\）
cd /mnt/d/AiWork/shuttlecock-action-assessment
ls            # 应能看到 apps/ services/ deploy/ 等目录
```

Windows 盘符 `D:` 在 WSL 中对应 `/mnt/d`，后续所有 `deploy` 目录操作均在 `/mnt/d/AiWork/shuttlecock-action-assessment/deploy` 下进行。

### 2.2 安装 WSL2（如尚未安装）

在 **Windows PowerShell（管理员）** 中执行一次：

```powershell
wsl --install
# 安装完成后重启电脑；默认会安装 Ubuntu 发行版
wsl --set-default-version 2   # 确认使用 WSL2
```

重启后从开始菜单打开 Ubuntu，按提示创建 Linux 用户名和密码。

### 2.3 在 WSL 中安装 Podman 与 podman-compose

进入 WSL（Ubuntu）后执行（以 Ubuntu 24.04 / 22.04 为例）：

```bash
sudo apt-get update
sudo apt-get install -y podman podman-compose
```

验证安装：

```bash
podman --version
podman-compose --version
```

> 若系统源中 `podman-compose` 版本较老或不可用，可用 pip 安装：
> ```bash
> sudo apt-get install -y python3-pip
> pip3 install --user podman-compose
> # 确保 ~/.local/bin 在 PATH 中
> echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc && source ~/.bashrc
> ```

### 2.4 配置 Podman 以 rootless 方式运行（推荐）

WSL 下通常以普通用户使用 rootless podman。确认可用：

```bash
podman info
```

若报错提示未初始化，可先执行：

```bash
podman system migrate
```

> 说明：rootless podman 无法直接绑定 1024 以下端口，但本编排对外映射的端口（8080 / 8081 / 3306 / 6379）均大于 1024，无需额外处理。

---

## 三、国内镜像源配置

为加快拉取与构建速度，本编排已使用国内镜像源前缀，需同时配置 Podman 与构建工具。

### 3.1 Podman 镜像仓库镜像（registries.conf）

编辑（rootless 用户级）`~/.config/containers/registries.conf`，或（系统级）`/etc/containers/registries.conf`：

```toml
# ~/.config/containers/registries.conf
unqualified-search-registries = ["docker.io"]

[[registry]]
prefix = "docker.io"
location = "docker.io"

# 为 docker.io 配置多个国内加速镜像
[[registry.mirror]]
location = "docker.m.daocloud.io"
[[registry.mirror]]
location = "dockerproxy.com"
```

> 本编排默认 `REGISTRY_MIRROR=docker.m.daocloud.io`，Dockerfile 与 compose 会直接把镜像名写成
> `${REGISTRY_MIRROR}/library/xxx`，因此即使不改 registries.conf 也能拉取。
> 若你的网络更适合其它镜像站，只需改 `.env` 中的 `REGISTRY_MIRROR` 即可。

### 3.2 npm 镜像源（前端构建）

统一使用 `https://registry.npmmirror.com`。本项目的 Dockerfile 已在 `npm ci` 时显式指定：

```dockerfile
RUN npm ci --registry=https://registry.npmmirror.com
```

`apps/student-web/.npmrc` 中也已配置 `registry=https://registry.npmmirror.com/`，二者一致性可保证构建时走国内源。

### 3.3 Maven 阿里云镜像（后端构建）

`deploy/docker/maven-settings.xml` 已内置阿里云 `public` / `spring` 仓库镜像，构建 `server-java` 镜像时会自动拷贝到构建容器的 `/root/.m2/settings.xml`。核心片段：

```xml
<mirror>
  <id>aliyun-public</id>
  <url>https://maven.aliyun.com/repository/public</url>
  <mirrorOf>central</mirrorOf>
</mirror>
```

> 若要在宿主机本地构建时也生效，可把同内容放到 `~/.m2/settings.xml`。

### 3.4 Go 模块代理（后端构建）

`server-go` 的 Dockerfile 已设置：

```dockerfile
ENV GOPROXY=https://goproxy.cn,direct
```

---

## 四、目录结构

```
deploy/
├── docker/
│   ├── student-web.Dockerfile      # 学生端前端镜像（多阶段 node -> nginx）
│   ├── teacher-web.Dockerfile      # 教师端前端镜像（多阶段 node -> nginx）
│   ├── server-go.Dockerfile        # 学生端 Go 后端镜像（CGO_ENABLED=0 静态编译）
│   ├── server-java.Dockerfile      # 教师端 Java 后端镜像（maven -> jre）
│   ├── maven-settings.xml          # 阿里云 Maven 镜像配置
│   ├── .dockerignore               # 构建上下文忽略规则
│   └── nginx/
│       ├── student-web.conf        # 学生端 nginx（SPA + 反代 server-go）
│       └── teacher-web.conf        # 教师端 nginx（SPA + 反代 server-java）
├── mysql/
│   └── init/                       # MySQL 首次初始化 SQL 目录（放 *.sql）
├── scripts/
│   ├── up.sh                       # 启动（构建 + 后台运行）
│   ├── down.sh                     # 停止（可 -v 删除数据卷）
│   ├── logs.sh                     # 查看/跟随日志
│   └── build.sh                    # 仅构建镜像
├── .env.example                    # 环境变量示例（复制为 .env）
├── podman-compose.yml              # 编排定义
└── README.md                       # 本文档
```

---

## 五、快速开始

```bash
# 1) 在 WSL 中进入仓库的 deploy 目录
cd /mnt/d/AiWork/shuttlecock-action-assessment/deploy

# 2) 准备环境变量
cp .env.example .env
# 按需修改 .env：数据库密码、REDIS_PASSWORD、JWT_SECRET、DEEPSEEK_API_KEY 等

# 3) 赋执行权限（首次）
chmod +x scripts/*.sh

# 4) 构建并启动
./scripts/up.sh

# 5) 访问
#   学生端： http://localhost:8080
#   教师端： http://localhost:8081
```

> 首次构建会拉取基础镜像并安装依赖，耗时较长（视网络而定）。之后构建会命中缓存。

---

## 六、常用命令

### 6.1 启动 / 停止 / 查看日志 / 重建

```bash
# 启动（已在运行则等价于 up -d）
./scripts/up.sh

# 停止并移除容器（保留数据卷）
./scripts/down.sh

# 停止并删除数据卷（会清空数据库和上传文件，谨慎使用！）
./scripts/down.sh -v

# 查看某服务日志（实时跟随）
./scripts/logs.sh server-go
./scripts/logs.sh server-java
./scripts/logs.sh mysql

# 仅构建镜像（不启动），可指定单个服务
./scripts/build.sh
./scripts/build.sh student-web
```

等价的 podman-compose 原始命令（在 deploy 目录下）：

```bash
podman-compose up -d --build          # 构建并启动
podman-compose ps                     # 查看状态
podman-compose logs -f server-go      # 查看日志
podman-compose restart server-go      # 重启单个服务
podman-compose down                   # 停止并移除
```

### 6.2 修改代码后重建

前端 / 后端代码变更后，需要重新构建对应镜像：

```bash
# 重建全部并重启
podman-compose up -d --build

# 只重建某个服务（例如改了学生端前端）
podman-compose build student-web
podman-compose up -d student-web
```

> 建议修改后执行 `podman-compose build --no-cache <service>` 做一次无缓存构建，排除旧层干扰。

---

## 七、首次初始化数据库

1. **数据库自动创建**：`mysql` 容器首次启动时会依据环境变量 `MYSQL_DATABASE`（默认 `lingxi_jianqiu`）自动创建数据库，并根据 `MYSQL_USER` / `MYSQL_PASSWORD` 创建业务账号并授权。

2. **业务表结构**：
   - 学生端 `server-go` 使用 GORM `AutoMigrate`，启动时会**自动建表**，无需手动执行 DDL；
   - 教师端 `server-java`（MyBatis-Plus）依赖既有表结构。若有建表 / 种子数据脚本，请放入 `deploy/mysql/init/` 目录（如 `01-schema.sql`、`02-seed.sql`）。

3. **初始化脚本执行时机**：`deploy/mysql/init/` 通过 `docker-entrypoint-initdb.d` 挂载到 mysql 容器。**仅在数据卷为空（首次启动）时按文件名字典序执行一次**。

4. **需要重新初始化时**：

```bash
# 删除数据卷后重新启动（会清空全部数据库数据！）
./scripts/down.sh -v
./scripts/up.sh
```

5. **手动导入数据（可选）**：

```bash
# 方式一：把脚本放进 deploy/mysql/init/ 后重新初始化（见上）
# 方式二：进入容器执行
podman exec -i lingxi-mysql mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" lingxi_jianqiu < your_dump.sql
```

> 注意：初始化目录为空时，仅会自动创建空数据库，业务表由 `server-go` 的 AutoMigrate 在首次启动时建立。

---

## 八、环境变量说明

全部变量见 `deploy/.env.example`，主要项：

| 变量 | 作用 | 默认值 |
| --- | --- | --- |
| `REGISTRY_MIRROR` | 国内镜像源前缀 | `docker.m.daocloud.io` |
| `TZ` | 时区 | `Asia/Shanghai` |
| `MYSQL_ROOT_PASSWORD` | MySQL root 密码 | `root_change_me` |
| `MYSQL_DATABASE` | 业务数据库名 | `lingxi_jianqiu` |
| `MYSQL_USER` / `MYSQL_PASSWORD` | 业务数据库账号/密码 | `lingxi` / `lingxi_change_me` |
| `MYSQL_PORT` | MySQL 宿主端口 | `3306` |
| `REDIS_PASSWORD` | Redis 密码 | `redis_change_me` |
| `REDIS_PORT` | Redis 宿主端口 | `6379` |
| `JWT_SECRET` | JWT 签名密钥 | `please_change_this_jwt_secret` |
| `DEEPSEEK_API_KEY` | DeepSeek Key | 空 |
| `DEEPSEEK_BASE_URL` / `DEEPSEEK_MODEL` | DeepSeek 地址/模型 | `https://api.deepseek.com` / `deepseek-chat` |
| `STUDENT_WEB_PORT` / `TEACHER_WEB_PORT` | 前端对外端口 | `8080` / `8081` |

### 后端环境变量映射（供排查参考）

`server-go`（变量名严格对应 `internal/config/config.go`）：
`SERVER_ADDR`、`DB_HOST`、`DB_PORT`、`DB_USER`、`DB_PASSWORD`、`DB_NAME`、`DB_CHARSET`、`REDIS_HOST`、`REDIS_PORT`、`REDIS_PASSWORD`、`REDIS_DB`、`JWT_SECRET`、`DEEPSEEK_API_KEY`、`DEEPSEEK_BASE_URL`、`DEEPSEEK_MODEL`、`UPLOADS_PATH`、`VIDEO_BASE_PATH`。
容器工作目录为 `/app`，`configs/config.json` 已被拷贝进镜像，环境变量优先级最高。

`server-java`（对应 `application.yaml` 占位符）：
`SERVER_PORT`、`SPRING_DATASOURCE_URL`、`SPRING_DATASOURCE_USERNAME`、`SPRING_DATASOURCE_PASSWORD`、`SPRING_DATA_REDIS_HOST`、`SPRING_DATA_REDIS_PORT`、`SPRING_DATA_REDIS_PASSWORD`、`DEEPSEEK_API_KEY`、`DEEPSEEK_BASE_URL`、`DEEPSEEK_MODEL`、`PUBLIC_VIDEO_PATH`、`PUBLIC_UPLOAD_PATH`。

---

## 九、常见问题排查

### 9.1 前端能打开但接口 502 / 请求失败

- 检查后端是否健康：`podman-compose ps`，确认 `server-go` / `server-java` 为 healthy。
- 查看后端日志：`./scripts/logs.sh server-go`（或 `server-java`）。
- 确认后端能连上数据库：日志中若出现数据库连接失败，检查 `.env` 中 `MYSQL_*` 与 `REDIS_PASSWORD` 是否与容器实际一致。

### 9.2 server-go 启动即退出 / 报数据库初始化失败

- 首次启动需等待 mysql 健康检查通过后才会启动（`depends_on: condition: service_healthy`）。
- 若曾用不同的 `MYSQL_ROOT_PASSWORD` 初始化过数据卷，之后改密码不会生效（root 密码只在首次初始化时设置）。需 `./scripts/down.sh -v` 清空后重建。
- 检查数据库账号授权：默认 `MYSQL_USER` 已被授权访问 `MYSQL_DATABASE`。

### 9.3 server-java 启动慢 / 健康检查失败

- Spring Boot 首次启动需较长时间（`start_period` 设为 60s）；查看 `./scripts/logs.sh server-java`。
- 若报找不到数据源，确认 `SPRING_DATASOURCE_URL` 中的数据库名与 `MYSQL_DATABASE` 一致。
- 若需要业务表，请先按「第七节」导入表结构。

### 9.4 上传大视频失败 / 413 Request Entity Too Large

- nginx 已设置 `client_max_body_size 1024m`；后端也已放开 multipart 限制。
- 若仍受限，确认请求确实经过前端 nginx（8080/8081）而非直连后端。

### 9.5 WebSocket（AI 对话）连不上

- `server-go` 的 WebSocket 路由为根路径 `/ws/ai`、`/ws/teacher/notification`（不在 `/api` 前缀下）。
- 本编排的 `student-web.conf` 已补充 `location /ws/` 段，向 `server-go:8001` 透传 `Upgrade` / `Connection` 头并加长连接超时，可正常反代根路径 WebSocket。
- 若连不上：确认前端构建时 `VITE_WS_BASE_URL` / `VITE_BACK_END_BASE_URL` 已置空走同源（见 Dockerfile 中的 `ENV`），并用浏览器开发者工具确认实际连接地址是否为同源 `ws(s)://<当前域名>/ws/ai`。

### 9.6 rootless podman 端口/权限问题

- 确认 `podman info` 正常；如端口被占用，改 `.env` 中 `STUDENT_WEB_PORT` / `TEACHER_WEB_PORT` / `MYSQL_PORT` / `REDIS_PORT`。
- 若提示需要 `--userns` 等参数，通常是因为使用了低端口，本编排不涉及。

### 9.7 构建时下载依赖很慢或失败

- 确认已按「第三节」配置镜像源；
- npm 构建失败：可在 Dockerfile 中已固定 `--registry=https://registry.npmmirror.com`；
- Maven 失败：确认 `deploy/docker/maven-settings.xml` 存在且被 Dockerfile 拷入；
- Go 失败：确认 `GOPROXY=https://goproxy.cn,direct`（已内置）。

### 9.8 查看容器内服务是否监听

```bash
podman exec -it lingxi-server-go   sh -c 'wget -qO- http://127.0.0.1:8001/captcha | head'
podman exec -it lingxi-server-java sh -c 'curl -fsS http://127.0.0.1:9002/v3/api-docs | head'
```

---

## 十、备注与需在 deploy 之外配合的改动

- 前端镜像构建时会把 `VITE_BACK_END_BASE_URL` / `VITE_WS_BASE_URL` 置空，使前端走同源相对路径。若你的部署必须让浏览器直连某个绝对后端地址（例如前后端分域名），需要在 `apps/*/` 的 `.env.prod` 或 Dockerfile 的 `ENV` 中改写这些变量——这属于 `deploy/` 之外的改动。
- 若 `server-go` 需要读取真实视频目录（而非容器内 `data/videos`），可把宿主机视频目录挂载进容器并调整 `VIDEO_BASE_PATH`；相关宿主机路径需要在 `podman-compose.yml` 的 volumes 中补充（本文件已包含卷定义，可按需扩展）。
- 本仓库已在根级提供 `.gitignore`（含忽略 `deploy/.env`）与 `.containerignore`（构建上下文忽略规则），无需再手动创建。
- **构建上下文优化（已配置）**：各 Dockerfile 以仓库根目录为构建上下文，Docker/Podman 会读取根级 `.containerignore`（或 `.dockerignore`），其中已排除 `apps/*/node_modules`、`dist`、`target` 等，避免大目录进入构建上下文。
  > 注意：`.containerignore` **不能**排除 `deploy/` 目录，因为各 Dockerfile 需要从上下文 `COPY deploy/docker/nginx/*.conf` 与 `deploy/docker/maven-settings.xml`。
