# 本地开发指南

> 本指南面向在本仓库上开发的工程师，覆盖环境要求、依赖安装、四端启动、环境变量、代码规范与常见问题。
> 所有版本、命令均来自仓库实际配置（`package.json`、`go.mod`、`pom.xml`、`application.yaml`、`configs/config.json`）。

---

## 目录

1. [环境要求](#1-环境要求)
2. [获取代码与 WSL 路径](#2-获取代码与-wsl-路径)
3. [依赖安装](#3-依赖安装)
4. [启动顺序与命令](#4-启动顺序与命令)
5. [环境变量说明](#5-环境变量说明)
6. [代码规范与质量检查](#6-代码规范与质量检查)
7. [常见问题](#7-常见问题)

---

## 1. 环境要求

| 组件 | 版本要求 | 依据 |
| --- | --- | --- |
| Node.js | 教师端 `^20.19.0 \|\| >=22.12.0`；学生端建议 20+（依赖 `@tsconfig/node20`、`@types/node ^20`） | `apps/teacher-web/package.json` 的 `engines`；`apps/student-web/package.json` 的 devDependencies |
| 包管理 | npm（两前端均自带 `package-lock.json`） | 仓库现状 |
| Go | `1.23` | `services/server-go/go.mod` |
| JDK | `21` | `services/server-java/pom.xml` 的 `java.version=21` |
| Maven | 3.9+（建议，需支持 Java 21） | Spring Boot 3.4.4 要求 |
| MySQL | `8.x`，字符集 `utf8mb4`，时区 `Asia/Shanghai` | `configs/config.json`、`application.yaml` |
| Redis | `7.x` | `configs/config.json`、`application.yaml` |
| Python（可选） | 3.10+，用于 `tools/yolo-detector` | `yolo_server.py` |

> 说明：学生端、教师端开发端口都默认 `5173`，**不要同时启动两端**（端口冲突）；需要并行时可分别改用不同端口或分机启动。

---

## 2. 获取代码与 WSL 路径

本仓库在 Windows 上的物理路径为：

```
D:\AiWork\shuttlecock-action-assessment
```

**在 WSL 中通过以下路径访问本仓库：**

```bash
/mnt/d/AiWork/shuttlecock-action-assessment
```

例如在 WSL（Ubuntu）中进入仓库并查看结构：

```bash
cd /mnt/d/AiWork/shuttlecock-action-assessment
ls
# apps  deploy  docs  services  tools  README.md
```

> 提示：在 WSL 下访问 `/mnt/d` 的 I/O 性能低于 Linux 原生文件系统；前端 `node_modules` 体积大时建议在 WSL 内操作或使用 Windows 终端直接于 `D:\` 下开发。

---

## 3. 依赖安装

> **开始之前：媒体资源需要自行补齐**
>
> 为保持仓库轻量，训练 / 演示类媒体**不纳入版本控制**（`.gitignore` 已排除 `*.mp4`、`*.fbx`、`*.glb`、`*.csv`、`*.pt` 等）。
> 克隆后以下目录为空，各目录内附有 `README.md` 说明所需文件清单、命名规则与引用位置：
>
> | 目录 | 缺失内容 | 影响 |
> | --- | --- | --- |
> | `apps/student-web/public/videos/` | 课程视频 | 课程中心 / 智能课堂无法播放 |
> | `apps/student-web/public/motion-demo-view/` | FBX/GLB 模型、真人演示视频 | 3D 动作演示页无内容 |
> | `apps/student-web/public/motion-capture-data/` | 动作捕捉 CSV | 动作评估无法比对打分 |
> | `services/server-java/public/` | 课堂回放视频 | 课堂回放无内容 |
> | `tools/yolo-detector/` | `yolov8n.pt` | YOLO 检测不可用（可选组件） |
>
> 未补齐时**不影响启动与登录**，仅相关页面功能不可用。UI 图标、Logo 等小体积静态资源已随仓库提交。

### 3.1 前端依赖（npm，强调国内镜像）

两个前端都使用 npm。为加速国内下载，建议先设置镜像源为 `registry.npmmirror.com`：

```bash
# 全局设置（推荐）
npm config set registry https://registry.npmmirror.com

# 或仅对单次安装生效
npm install --registry=https://registry.npmmirror.com

# 验证
npm config get registry
```

**学生端**（`apps/student-web`）：

```bash
cd apps/student-web
npm install --registry=https://registry.npmmirror.com
```

**教师端**（`apps/teacher-web`）：

```bash
cd apps/teacher-web
npm install --registry=https://registry.npmmirror.com
```

### 3.2 Go 依赖（`services/server-go`）

```bash
cd services/server-go
# 使用国内代理加速
go env -w GOPROXY=https://goproxy.cn,direct
go mod download
```

### 3.3 Java 依赖（`services/server-java`）

```bash
cd services/server-java
# 建议在 ~/.m2/settings.xml 配置阿里云镜像
mvn -q -DskipTests clean install
```

### 3.4 Python 依赖（可选，`tools/yolo-detector`）

```bash
cd tools/yolo-detector
pip install fastapi uvicorn opencv-python ultralytics -i https://pypi.tuna.tsinghua.edu.cn/simple
```

> 仓库内已带 `yolov8n.pt` 模型权重；视频源需通过 `YOLO_VIDEO` 环境变量指定（见 §5.4）。

---

## 4. 启动顺序与命令

推荐顺序：**基础中间件 → 后端 → 前端**。

### 4.1 第一步：准备 MySQL 与 Redis

1. 启动 MySQL 8（端口 `3306`）与 Redis 7（端口 `6379`）。
2. 创建数据库（若不存在）：

```sql
CREATE DATABASE IF NOT EXISTS lingxi_jianqiu
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

3. 学生端 `server-go` 启动时会执行 `AutoMigrate`（见 `internal/database/init.go`），自动创建其模型对应的表；`server-go` 与 `server-java` 共用同一 `lingxi_jianqiu` 库，教师端所需的表由数据库既有数据/结构提供。

### 4.2 第二步：启动学生端后端 `server-go`（:8001）

```bash
cd services/server-go
go run cmd/server/main.go
# 看到 "服务启动于 :8001" 即成功
```

### 4.3 第三步：启动教师端后端 `server-java`（:9002）

```bash
cd services/server-java
# 方式一：Spring Boot 插件启动 service 模块
mvn -pl service -am spring-boot:run

# 方式二：先整体打包，再运行可执行 jar（产物位于 service/target）
mvn -q -DskipTests clean package
java -jar service/target/service-0.0.1-SNAPSHOT.jar
```

接口文档（Knife4j/Swagger）：`http://localhost:9002/doc.html`、`http://localhost:9002/swagger-ui.html`。

### 4.4 第四步：启动前端

**学生端**（`apps/student-web`，默认 5173，代理 `/api`、`/videos`、`/uploads` → `:8001`）：

```bash
cd apps/student-web
npm run dev          # vite --mode dev
```

**教师端**（`apps/teacher-web`，默认 5173，代理 `/api`、`/videos` → `:9002`）：

```bash
cd apps/teacher-web
npm run dev
```

> 两端开发端口同为 5173，请按需逐个启动，或在 `vite.config.ts` 的 `server.port` 中改为不同端口。

### 4.5 第五步（可选）：启动 YOLO 检测服务

```bash
cd tools/yolo-detector
export YOLO_VIDEO=/path/to/classroom.mp4   # Windows: set YOLO_VIDEO=D:\path\classroom.mp4
python yolo_server.py                       # 默认 0.0.0.0:8000
# 健康检查：http://localhost:8000/health
```

---

## 5. 环境变量说明

### 5.1 `server-go`（优先级：环境变量 > `configs/config.json` > 内置默认值）

加载逻辑见 `internal/config/config.go` 的 `applyEnv`。可用环境变量：

| 环境变量 | 对应配置 | 默认值 |
| --- | --- | --- |
| `SERVER_ADDR` | `server_addr` | `:8001` |
| `VIDEO_BASE_PATH` | `video_base_path` | `./data/videos` |
| `UPLOADS_PATH` | `uploads_path` | `./data/uploads` |
| `DB_HOST` / `DB_PORT` / `DB_USER` / `DB_PASSWORD` / `DB_NAME` / `DB_CHARSET` | `database.*` | `127.0.0.1` / `3306` / `root` / 空 / `lingxi_jianqiu` / `utf8mb4` |
| `REDIS_HOST` / `REDIS_PORT` / `REDIS_PASSWORD` / `REDIS_DB` | `redis.*` | `127.0.0.1` / `6379` / 空 / `0` |
| `JWT_SECRET` / `JWT_ACCESS_EXPIRY` / `JWT_REFRESH_EXPIRY` | `jwt.*` | `change-me-in-production` / `14400` / `604800` |
| `DEEPSEEK_API_KEY` / `DEEPSEEK_BASE_URL` / `DEEPSEEK_MODEL` | `deepseek.*` | 空 / `https://api.deepseek.com/v1` / `deepseek-chat` |
| `DASHSCOPE_API_KEY` | `dashscope.api_key` | 空 |
| `SENDGRID_API_KEY` | `sendgrid.api_key` | 空 |
| `CLOUDFLARE_SITE_KEY` / `CLOUDFLARE_SECRET_KEY` | `cloudflare_turnstile.*` | 空 |

> 生产环境务必用环境变量注入 `JWT_SECRET`、`DB_PASSWORD`、`DEEPSEEK_API_KEY`，不要提交明文到 `configs/config.json`。

### 5.2 `server-java`（`service/src/main/resources/application.yaml`）

| 环境变量 | 含义 | 默认值 |
| --- | --- | --- |
| `SERVER_PORT` | 服务端口 | `9002` |
| `SPRING_DATASOURCE_URL` | JDBC URL | `jdbc:mysql://localhost:3306/lingxi_jianqiu?...` |
| `SPRING_DATASOURCE_USERNAME` / `SPRING_DATASOURCE_PASSWORD` | 数据库账号密码 | `root` / 空 |
| `SPRING_DATA_REDIS_HOST` / `SPRING_DATA_REDIS_PORT` / `SPRING_DATA_REDIS_PASSWORD` | Redis 连接 | `localhost` / `6379` / 空 |
| `PUBLIC_VIDEO_PATH` / `PUBLIC_UPLOAD_PATH` | 公共文件根目录 | `./public` / `./uploads` |
| `DEEPSEEK_API_KEY` / `DEEPSEEK_BASE_URL` / `DEEPSEEK_MODEL` | DeepSeek 配置 | 空 / `https://api.deepseek.com` / `deepseek-chat` |
| `CLOUDFLARE_TURNSTILE_SECRET` | Turnstile 密钥 | 测试用官方固定值 |

### 5.3 学生端前端（`apps/student-web`）

由 Vite `import.meta.env` 注入（文件 `.env.dev` / `.env.prod`）：

| 变量 | 含义 | `.env.dev` | `.env.prod` |
| --- | --- | --- | --- |
| `VITE_BACK_END_BASE_URL` | 后端基地址 | 空（走 Vite 同源代理） | `http://10.224.12.5:9002` |
| `VITE_PYTHON_BACK_END_BASE_URL` | Python 服务地址 | 空 | `http://10.224.12.5:5000` |
| `VITE_WS_BASE_URL` | WebSocket 基地址 | `ws://localhost:8001` | `wss://lxzj.tenir.cn/lxzj` |

### 5.4 教师端前端（`apps/teacher-web`）

- 无 `.env` 文件；`src/utils/request.ts` 中 `baseURL = import.meta.env.VITE_API_BASE_URL || ''`，开发态为空走 Vite 代理（`/api`、`/videos` → `localhost:9002`）。
- 如需指定后端，可创建 `.env.local` 增加 `VITE_API_BASE_URL=http://localhost:9002`。

### 5.5 YOLO（可选）

| 环境变量 | 含义 | 默认 |
| --- | --- | --- |
| `YOLO_VIDEO` | 待检测视频路径 | `assets/sample.mp4` |
| `YOLO_MODEL` | 模型权重 | `yolov8n.pt` |
| `YOLO_FRAME_SKIP` | 抽帧间隔 | `3` |
| `YOLO_EXPECTED_STUDENTS` | 预期人数（算出席率） | `10` |
| `YOLO_JPEG_QUALITY` | JPEG 质量 | `60` |
| `YOLO_PORT` | 监听端口 | `8000` |

---

## 6. 代码规范与质量检查

### 6.1 学生端（`apps/student-web`）

```bash
npm run type-check      # vue-tsc --build --force
npm run lint            # eslint . --ext ... --fix
npm run test            # vitest（watch）
npm run test:run        # vitest run（CI）
npm run test:coverage   # vitest run --coverage
```

- ESLint 8 + Prettier 3.6；SCSS 全局变量由 `vite.config.ts` 的 `additionalData` 注入 `@/style/global.scss`。

### 6.2 教师端（`apps/teacher-web`）

```bash
npm run type-check      # vue-tsc --build
npm run lint            # run-s lint:*（oxlint + eslint）
npm run lint:oxlint     # oxlint . --fix
npm run lint:eslint     # eslint . --fix --cache
npm run format          # prettier --write --experimental-cli src/
```

- 双 linter：oxlint ~1.50 + ESLint 10；Prettier 3.8；Tailwind 4（`@tailwindcss/postcss`）。

### 6.3 Go（`services/server-go`）

```bash
go build ./...          # 编译
go vet ./...            # 静态检查
go test -race ./...     # 竞态检测测试
gofmt -l .              # 列出未格式化文件
```

### 6.4 Java（`services/server-java`）

```bash
mvn -q -DskipTests clean package   # 编译打包
mvn test                           # 运行测试
mvn -pl service -am spring-boot:run # 本地启动
```

- 编码统一 UTF-8（`pom.xml` 中 `project.build.sourceEncoding=UTF-8`）。
- 控制器方法**必须**带 `@Operation(description 或 summary)`、控制器类**必须**带 `@Tag(name=...)`——`MyInterceptor` 会在缺失时抛出异常（见 `common-core/.../MyInterceptor.java`）。

---

## 7. 常见问题

**Q1：前端 5173 端口被占用 / 两端同时启动冲突？**
A：学生端与教师端开发端口都默认 5173，请逐个启动；或将其中一个 `vite.config.ts` 的 `server.port` 改为 `5174` 等。

**Q2：npm install 很慢或超时？**
A：设置镜像 `npm config set registry https://registry.npmmirror.com`，或安装时加 `--registry=https://registry.npmmirror.com`。

**Q3：学生端请求 404 / 跨域？**
A：确认 `server-go` 已在 `:8001` 启动，且通过 `npm run dev`（`--mode dev`）启动前端以命中 `vite.config.ts` 的代理；`.env.dev` 中 `VITE_BACK_END_BASE_URL` 为空表示走同源代理。

**Q4：教师端接口 401 或一直跳登录页？**
A：确认登录后 `localStorage` 中存有 token、请求头使用 `auth-token`（与 `application.yaml` 的 `sa-token.token-name` 一致）；确认 `server-java` 在 `:9002` 启动。

**Q5：教师端登录报 `NEED_CAPTCHA` 或安全验证失败？**
A：登录需要 Cloudflare Turnstile token（`UserServiceImpl.verifyTurnstile`）；本地若无法访问 Cloudflare，需配置可用的 Turnstile 测试密钥或检查网络。

**Q6：学生端登录提示验证码相关错误？**
A：登录流程会先请求 `GET /captcha`（或 `/api/v0/public/challenge/captcha`）获取验证码，再携带 `captcha` 调用 `/api/v0/student/auth/token`；确认 Redis 正常运行且未过期（验证码 TTL 5 分钟）。

**Q7：Go 服务启动报「数据库初始化失败」？**
A：检查 MySQL 是否启动、`lingxi_jianqiu` 库是否存在、`configs/config.json`（或 `DB_*` 环境变量）账号密码是否正确。

**Q8：AI 对话返回「DeepSeek API 密钥未配置」？**
A：需设置 `DEEPSEEK_API_KEY`（学生端还可用 `configs/config.json` 的 `deepseek.api_key`）。

**Q9：Java 启动找不到 `yolo_server.py`？**
A：`YoloServerRunner` 仅在 `yolo.enabled=true` 时启动，且会在多个候选路径查找脚本；不需要 YOLO 时保持默认关闭即可。

**Q10：WSL 下 `npm install` 报权限/软链错误？**
A：避免在 `/mnt/d` 上安装大体量 `node_modules`（Windows 文件系统对符号链接支持有限），建议在 Windows 原生终端开发前端，或在 WSL 的 Linux 文件系统内复制工程后再安装。

---

> 维护提示：修改端口、环境变量、脚本命令时请同步更新本文件与 `docs/architecture.md` 的「部署与运行形态」。
