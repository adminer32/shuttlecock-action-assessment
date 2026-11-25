# 系统架构设计

> 本文档描述「翎翼毽球教学平台」monorepo 的整体架构、技术选型、模块职责、请求链路、鉴权方案、实时通信、AI 集成与 3D 动作演示数据流。
> 所有内容均以仓库当前代码为依据，涉及的文件路径、端口、依赖版本均可回溯到源码。

---

## 目录

1. [整体拓扑](#1-整体拓扑)
2. [技术选型与理由](#2-技术选型与理由)
3. [模块职责划分](#3-模块职责划分)
4. [学生端请求链路](#4-学生端请求链路)
5. [教师端请求链路](#5-教师端请求链路)
6. [鉴权方案对比](#6-鉴权方案对比)
7. [实时通信（WebSocket）](#7-实时通信websocket)
8. [AI 集成（DeepSeek）](#8-ai-集成deepseek)
9. [3D 动作演示与动作评估数据流](#9-3d-动作演示与动作评估数据流)
10. [部署与运行形态](#10-部署与运行形态)

---

## 1. 整体拓扑

平台由「学生端」和「教师端」两条相互独立、又共享同一个 MySQL 数据库的业务线组成。学生端由 Go 后端服务，教师端由 Java（Spring Boot）后端服务。

```
                          ┌───────────────────────────────────────────────┐
                          │               浏览器 / 移动端 Web               │
                          └───────────────┬───────────────┬───────────────┘
                                          │               │
                     HTTP + WebSocket     │               │   HTTP
                     (Vite 代理 /api)     │               │   (Vite 代理 /api、/videos)
                                          ▼               ▼
                      ┌────────────────────────┐   ┌────────────────────────┐
                      │  apps/student-web       │   │  apps/teacher-web       │
                      │  Vue3.5 + TS + Vite5     │   │  Vue3.5 + TS + Vite7     │
                      │  Pinia2                  │   │  Pinia3                  │
                      │  Ant Design Vue4         │   │  Element Plus2           │
                      │  ECharts5 + Three.js     │   │  ECharts6 + Tailwind4    │
                      │  dev :5173               │   │  dev :5173               │
                      └───────────┬─────────────┘   └───────────┬─────────────┘
                                  │                             │
              proxy /api,/videos,/uploads → :8001               │ proxy /api,/videos → :9002
              proxy /gvhmr → :8000                              │
                                  ▼                             ▼
                 ┌──────────────────────────┐    ┌──────────────────────────────────┐
                 │  services/server-go       │    │  services/server-java             │
                 │  Go 1.23 + Gin 1.10       │    │  Java 21 + Spring Boot 3.4.4      │
                 │  GORM + MySQL + Redis     │    │  Maven 多模块                     │
                 │  JWT (HS512)              │    │  MyBatis-Plus + Sa-Token          │
                 │  gorilla/websocket        │    │  port :9002                       │
                 │  port :8001               │    │                                   │
                 └───────┬─────────┬────────┘    └───────────────┬───────────────────┘
                         │         │                              │
                         │         │  MySQL(3306) / Redis(6379)  │
                         └─────────┴──────────────┬───────────────┘
                                                  ▼
                                   ┌─────────────────────────────┐
                                   │  MySQL 8  lingxi_jianqiu 库  │
                                   │  Redis 7（缓存/黑名单/验证码）│
                                   └─────────────────────────────┘

                 ┌──────────────────────────┐
                 │  tools/yolo-detector      │   (可选组件)
                 │  Python YOLOv8 + FastAPI   │
                 │  WS /ws/analysis  :8000   │
                 └──────────────────────────┘
```

要点：

- **两条业务线相互独立**：学生端只访问 `server-go`（`/api/*`、`/ws/*`），教师端只访问 `server-java`（`/api/*`）。`server-go` 额外暴露少量只读的 `/api/v0/teacher/*` 课程目录接口（`main.go` 第 116-118 行）。
- **共享数据层**：两端使用同一个 MySQL 实例、同一个库 `lingxi_jianqiu`（见 `services/server-go/configs/config.json` 与 `services/server-java/service/src/main/resources/application.yaml`），Redis 亦为同一实例。
- **可选推理组件**：`tools/yolo-detector` 是独立 Python 服务，通过 WebSocket `/ws/analysis` 推送 YOLOv8 课堂检测画面与出勤/参与度指标，不参与业务主链路。

---

## 2. 技术选型与理由

### 2.1 学生端前端 `apps/student-web`

| 类别 | 选型 | 版本（package.json） | 理由 |
| --- | --- | --- | --- |
| 框架 | Vue | `^3.5.13` | Composition API + `<script setup>`，适合复杂交互页面 |
| 语言 | TypeScript | `~5.4.0` | 类型安全，配合 `vue-tsc` 做类型检查 |
| 构建 | Vite | `^5.3.1` | 冷启动快，开发代理配置直观 |
| 状态 | Pinia | `^2.1.7` | 官方推荐状态管理，Store 拆分清晰 |
| 组件库 | Ant Design Vue | `^4.2.6` | 表格/表单组件完整，`unplugin-vue-components` 按需自动引入 |
| 图表 | ECharts | `^5.6.0`（另有 `echarts-liquidfill`、`echarts-wordcloud`） | 学情趋势、雷达图、词云 |
| 3D | Three.js | `^0.174.0` | 动作骨架 3D 演示（GLTF/FBX/CSV 骨骼动画） |
| HTTP | Axios | `^1.7.9` | 统一封装于 `src/utils/HttpUtil.ts` |
| 测试 | Vitest | `^2.1.9` | 与 Vite 同源，单元测试 |

### 2.2 教师端前端 `apps/teacher-web`

| 类别 | 选型 | 版本（package.json） | 理由 |
| --- | --- | --- | --- |
| 框架 | Vue | `^3.5.29` | 同上 |
| 语言 | TypeScript | `~5.9.3` | 同上 |
| 构建 | Vite | `^7.3.1` | 更新的构建工具链 |
| 状态 | Pinia | `^3.0.4` | 同上 |
| 组件库 | Element Plus | `^2.13.6` | 教师端后台表单/弹窗风格 |
| 图表 | ECharts | `^6.0.0`（`vue-echarts ^8`） | 学情分析大屏 |
| 样式 | Tailwind CSS | `^4.2.2` | 原子化快速布局 |
| 质量 | oxlint + eslint + prettier | `~1.50.0` / `^10` / `3.8.1` | 双 linter + 格式化 |
| 部署 | wrangler | `^4.76.0` | Cloudflare Pages 预览/部署 |

> Node 版本要求：教师端 `package.json` 显式声明 `engines.node = "^20.19.0 || >=22.12.0"`；学生端依赖 `@tsconfig/node20`。

### 2.3 学生端后端 `services/server-go`

| 类别 | 选型 | 版本（go.mod） | 理由 |
| --- | --- | --- | --- |
| 语言 | Go | `1.23` | 高并发、单二进制部署 |
| Web 框架 | Gin | `v1.10.0` | 路由分组、中间件生态成熟 |
| ORM | GORM | `v1.25.12`（驱动 `gorm.io/driver/mysql v1.5.7`） | 自动迁移、链式查询 |
| 缓存 | go-redis | `v9.7.0` | Token 黑名单、验证码、限流 |
| JWT | golang-jwt | `v5.2.1` | `HS512` 签名 |
| WebSocket | gorilla/websocket | `v1.5.3` | AI 对话、教师提醒通道 |
| 密码 | golang.org/x/crypto | `v0.31.0` | bcrypt 校验 |
| UUID | google/uuid | `v1.6.0` | Token ID |

### 2.4 教师端后端 `services/server-java`

| 类别 | 选型 | 版本（pom.xml） | 理由 |
| --- | --- | --- | --- |
| 语言 | Java | `21` | LTS，`record`/模式匹配 |
| 框架 | Spring Boot | `3.4.4` | 企业级生态 |
| 构建 | Maven | 多模块（`common` + `service`） | 公共能力复用 |
| 持久层 | MyBatis-Plus | `3.5.9`（+ `mybatis-spring-boot-starter 3.0.5`） | 复杂 SQL 用 XML，简单 CRUD 用 MP |
| 鉴权 | Sa-Token | `1.39.0` | 会话式登录 + 注解式角色校验 |
| 工具 | Hutool `5.8.35`、Guava `33.2.1-jre`、Fastjson2 `2.0.54` | — | — |
| 媒体 | JavaCV `1.5.11`（含 FFmpeg） | — | 视频抽帧等 |
| 文档 | Knife4j `4.5.0` | — | OpenAPI3 文档 |

### 2.5 可选推理 `tools/yolo-detector`

| 类别 | 选型 | 来源 |
| --- | --- | --- |
| 推理 | Ultralytics YOLOv8（`yolov8n.pt`） | `yolo_server.py` |
| 服务 | FastAPI + uvicorn | `yolo_server.py` |
| 传输 | WebSocket `/ws/analysis`，JPEG base64 帧 | `yolo_server.py` |

---

## 3. 模块职责划分

### 3.1 仓库顶层

| 路径 | 职责 |
| --- | --- |
| `apps/student-web/` | 学生端 SPA |
| `apps/teacher-web/` | 教师端 SPA |
| `services/server-go/` | 学生端后端（Go） |
| `services/server-java/` | 教师端后端（Spring Boot） |
| `tools/yolo-detector/` | YOLOv8 课堂检测（可选） |
| `deploy/` | 容器化部署（由专人负责，本文档不涉及） |
| `docs/` | 技术文档 |

### 3.2 `services/server-go` 内部分层

| 目录 | 职责 |
| --- | --- |
| `cmd/server/main.go` | 入口：读取配置、初始化 DB/Redis、注册全部路由、优雅关闭 |
| `internal/config/` | 配置加载（`configs/config.json` + 环境变量覆盖，见 `config.go`） |
| `internal/database/` | GORM 初始化与 `AutoMigrate`（`init.go`）、事务封装（`tx.go`） |
| `internal/cache/` | Redis 客户端初始化 |
| `internal/model/models.go` | 全部 GORM 模型定义 |
| `internal/middleware/auth.go` | JWT 鉴权中间件、`RequireRole`、`RateLimit` |
| `internal/router/router.go` | `Deps{DB,RDB,Config}` 依赖注入容器 |
| `internal/handler/*` | 按业务域划分的 handler（`user`/`ai`/`content`/`course`/`video`/`schedule`/`student`/`transcribe`） |
| `internal/websocket/websocket.go` | `/ws/ai`、`/ws/teacher/notification` |
| `pkg/jwt`、`pkg/response`、`pkg/util` | 通用 JWT、统一响应、参数解析 |

> Handler 统一采用「函数返回 `gin.HandlerFunc`」的工厂风格，通过 `router.Deps` 注入依赖，例如 `content.SaveAnalysis(deps)`。

### 3.3 `services/server-java` 多模块

| 模块 / 包 | 职责 |
| --- | --- |
| `common/common-core` | 实体基类、DTO、`BaseJdbcDao`、Sa-Token 拦截器 `MyInterceptor`、全局异常、`RestResponse`/`PageQuery`/`PageResult` |
| `common/common-jdbc` | JDBC 工具、MySQL/PostgreSQL SQL 执行器 |
| `common/common-knife4j` | Knife4j / OpenAPI 配置 |
| `service` | 业务主模块（可启动的 Spring Boot 应用，`ServiceApplication`） |
| `service.auth` | 登录/登出/用户信息 `UserController`、`UserServiceImpl` |
| `service.classes` | 班级列表 `ClassController` |
| `service.classroom` | 课堂（课程回放/知识点/笔记/视频分析）`ClassroomController` |
| `service.home` | 工作台首页统计与通知 `HomeController` |
| `service.homework` | 作业发布/批改/提交/反馈 `HomeworkController` |
| `service.learning` | 学习管理：训练计划、动作视频 `LearningController` |
| `service.analysis` | 学情分析 `AnalysisController` |
| `service.ai` | DeepSeek 客户端、AI 作业/计划/教学建议 `AiController` |
| `service.common` | 文件上传/公共文件 `FileController`、`PublicFileController`、`YoloServerRunner` |
| `service.profile` | 教师档案 `TeacherProfileController` |

每个业务子包遵循 `controller / service / service.impl / mapper / entity / dto / vo` 的标准分层。

---

## 4. 学生端请求链路

以「登录 → 拉取个人信息 → 动作评估」为例：

```
浏览器
  │
  │ 1) POST /api/v0/student/auth/token  (username, hashedPassword, captcha)
  ▼
Vite dev server (:5173)  ── proxy /api → http://127.0.0.1:8001 ──►  server-go (:8001)
                                                                     ├─ 校验用户 & 验证码
                                                                     └─ 签发 access_token + refresh_token (JWT HS512)
  │◄────────────────── { success, access_token, refresh_token } ─────┘
  │
  │ 2) 后续请求：Header `access_token: <token>`（HttpUtil 请求拦截器注入，见 src/utils/HttpUtil.ts）
  │    GET /api/v0/student/users/profile
  ▼
server-go ── middleware.JWTAuth 校验签名 + Redis 黑名单检查 ──► handler 查 users + student_profile
  │
  │ 3) 动作评估：POST /api/content/insert (multipart：aiContentInfo + file + motionName)
  │    POST /api/analysis/save (student_id + analysis_data JSON)
  ▼
server-go ── content.SaveAnalysis ──► 写入 motion_analysis_data 表
```

关键事实：

- 学生端 Axios 实例 `baseURL = import.meta.env.VITE_BACK_END_BASE_URL`，开发态为空串，请求走 Vite 同源代理（`vite.config.ts` 中 `/api`、`/videos`、`/uploads` → `:8001`）。
- 请求拦截器把 `localStorage.access_token` 注入到 `access_token` 请求头（`HttpUtil.ts` 第 14-17 行）。
- `server-go` 的 `extractToken` 依次读取 `Authorization`、`?token=`、`?access_token=`（`middleware/auth.go` 第 66-79 行），因此 WebSocket 与部分 GET 接口用 query 传 token。
- Token 结构 `{user_id, username, role, jti}`，登出后的 `jti` 进入 Redis 黑名单 `jwt:blacklist:<jti>`（`middleware/auth.go` 第 29-34 行）。

---

## 5. 教师端请求链路

以「登录 → 首页概览 → 作业批改」为例：

```
浏览器
  │ 1) POST /api/system/user/login  { username, password, turnstileToken }
  ▼
Vite dev server (:5173) ── proxy /api → http://localhost:9002 ──►  server-java (:9002)
                                                                     ├─ UserServiceImpl.login：SHA-256(password+salt) 校验
                                                                     ├─ 校验 Cloudflare Turnstile
                                                                     ├─ 校验 role == TEACHER
                                                                     └─ StpUtil.login(id) 返回 auth-token
  │◄──────────────── { code:200, message, data: <token> } ────────────┘
  │
  │ 2) 后续请求：Header `auth-token: <token>`（request.ts 拦截器注入）
  │    GET /api/home/overview?classId=xxx
  ▼
server-java ── MyInterceptor：StpUtil.checkLogin + checkRole("TEACHER") ──► HomeController
  │
  │ 3) 作业批改：GET /api/homework/{id}/submissions → PUT /api/homework/submission/{sid}/grade
  ▼
HomeworkController ── HomeworkServiceImpl ──► teacher_homework_* 表
```

关键事实：

- 教师端 Axios 实例 `baseURL = import.meta.env.VITE_API_BASE_URL || ''`，请求头键名固定为 `auth-token`（`src/utils/request.ts` 第 6 行），与 `application.yaml` 的 `sa-token.token-name: auth-token` 一致。
- 响应拦截器按 `RestResponse{ code, message, data }` 解包：`code !== 200` 时弹 `ElMessage` 错误，`401` 时清 token 并跳 `/login`。
- `MyInterceptor`（`common-core/.../MyInterceptor.java`）对所有 `/**` 生效，`WebMvcInterceptorConfig` 排除了 Swagger、`/api/file/**`、`/api/images/**`；`@SaIgnore` 方法（如登录）直接放行。
- 登录成功在 `StpUtil.getSession()` 中写入 `SYS_USER_KEY` 与 `Role`，后续拦截器据此校验。

---

## 6. 鉴权方案对比

| 维度 | 学生端（`server-go`） | 教师端（`server-java`） |
| --- | --- | --- |
| 方案 | 自实现 JWT，`HS512` 签名 | Sa-Token 会话式登录 |
| 令牌载体 | `Authorization` / `?token=` / `?access_token=` | 请求头 `auth-token`（`sa-token.token-name`） |
| 令牌格式 | JWT（`jti`/`user_id`/`username`/`role`/`exp`） | UUID 风格 token（`token-style: uuid`） |
| 有效期 | access `14400s`、refresh `604800s`（`config.json`） | `timeout: 300000s`，`active-timeout: -1` |
| 会话状态 | 无状态校验 + Redis 黑名单 `jwt:blacklist:<jti>` | 服务端会话（Sa-Token Session），支持 `StpUtil.getSession()` |
| 密码存储 | bcrypt（`password_hash` + `password_salt`） | SHA-256(password+salt)（`SecureUtil.sha256`） |
| 角色控制 | 代码中定义了 `RequireRole(...)` 中间件（`middleware/auth.go`），但当前路由**未启用**，`/api/**` 仅校验 JWT 有效性，不做角色限制 | `@SaCheckRole("TEACHER")` 注解 + `StpUtil.checkRole`，强制 TEACHER |
| 人机校验 | 图形验证码 `GET /captcha`（SVG，Redis 存 `captcha:<ip>`） | Cloudflare Turnstile（登录时 `verifyTurnstile`） |
| 并发登录 | 允许多端 | `is-concurrent: true`、`is-share: false` |
| 关键实现 | `pkg/jwt/jwt.go`、`internal/middleware/auth.go`、`internal/handler/user/user.go` | `UserServiceImpl`、`MyInterceptor`、`application.yaml` |

> 两端鉴权互不通用：学生端 token 只对 `server-go` 有效，教师端 token 只对 `server-java` 有效，因为签名密钥 / 会话存储完全独立。

---

## 7. 实时通信（WebSocket）

两端各有一个 WebSocket 端点，均由 `server-go` 提供（`internal/websocket/websocket.go`）。

### 7.1 `/ws/ai`（AI 流式对话）

| 项 | 说明 |
| --- | --- |
| 处理函数 | `websocket.HandleAIChat` |
| 升级 | `gorilla/websocket`，`CheckOrigin` 恒为 true |
| 连接参数 | `?token=<access_token>`（学生端 `aiChatStore.ts` / `motionAssessmentStore.ts` 拼接） |
| 客户端 → 服务端 | `{"type":"init","task_id":"..."}` 或 `{"type":"chat","content":"..."}` |
| 服务端 → 客户端 | `init`：`{"type":"init","status":"success","has_context":bool}`；`chat`：`{"type":"chat","content":"...","status":"success/error"}` |
| 上下文 | 若 `task_id` 命中 `ai_transcription_task` 且有转录文本，会作为 system 消息拼入 |
| 模型 | `deepseek-chat`（`websocket.go` 第 111 行） |

### 7.2 `/ws/teacher/notification`（教师提醒通道）

| 项 | 说明 |
| --- | --- |
| 处理函数 | `websocket.HandleTeacherNotification` |
| 心跳 | 服务端每 30s 推送 `{"type":"pong"}`（`websocket.go` 第 74-81 行） |
| 客户端心跳 | 学生端 `teacherNotificationStore.ts` 每 30s 发送 `{"type":"ping"}` |
| 重连 | 客户端指数/固定间隔重连，最大 10 次（`MAX_RECONNECT_ATTEMPTS`） |

### 7.3 `/ws/analysis`（YOLO 课堂检测，独立于 Go 服务）

| 项 | 说明 |
| --- | --- |
| 提供方 | `tools/yolo-detector/yolo_server.py`（FastAPI，默认 `:8000`） |
| 帧传输 | 逐帧 JPEG base64 `image` 字段 + `detected` 人数 + `attendanceRate`/`engagement` |
| 环境变量 | `YOLO_VIDEO`、`YOLO_MODEL`、`YOLO_FRAME_SKIP`、`YOLO_EXPECTED_STUDENTS`、`YOLO_JPEG_QUALITY`、`YOLO_PORT` |

> 注意：`/ws/analysis` 由 Python 服务提供，不在 `server-go` 路由表中；学生端 `vite.config.ts` 将 `/gvhmr` 代理到 `:8000`，是动作重建（GVHMR）相关转发。

---

## 8. AI 集成（DeepSeek）

DeepSeek 在两端各有一套调用封装，均为「OpenAI 兼容 /chat/completions」协议。

### 8.1 学生端（Go）

| 项 | 说明 |
| --- | --- |
| 配置 | `config.json` → `deepseek.{api_key, base_url, model}`，默认 `https://api.deepseek.com/v1`、`deepseek-chat` |
| 调用点 | `internal/handler/ai/ai.go`（`Chat`、`CoachChat`、`NotePolishing`）、`internal/handler/transcribe/transcribe.go`（`AnalyzeTranscription`）、`internal/websocket/websocket.go` |
| 请求 | `POST {base_url}/chat/completions`，`Authorization: Bearer <api_key>` |
| 用途 | AI 教练「翎析」对话、动作数据解读、笔记润色、视频转录分析（自动章节/摘要/关键词） |
| 超时 | 30~60s（`context.WithTimeout`） |

`CoachChat` 会把结构化动作评分作为 system 上下文注入：
```
【当前动作分析数据】
动作类型: %s
髋关节评分: %.1f  膝关节评分: %.1f  踝关节评分: %.1f
抬脚高度评分: %.1f  综合评分: %.1f
%s(feedback)
```

### 8.2 教师端（Java）

| 项 | 说明 |
| --- | --- |
| 配置 | `application.yaml` → `deepseek.{api-key, base-url, model, max-tokens:4096, temperature:0.7}` |
| 客户端 | `service/ai/client/DeepSeekClient.java`（Spring `RestTemplate`，连接超时 15s、读超时 120s） |
| 请求 | `POST {base-url}/v1/chat/completions` |
| 服务层 | `AiServiceImpl`（作业/计划生成）、`AiTeachingAdviceServiceImpl`（班级/学生教学建议） |
| Prompt | `service/ai/prompt/PromptTemplates.java` |
| 结构化输出 | 模型返回 JSON，`cleanJsonResponse` 去除 ```` ```json ```` 包裹后解析 |

AI 生成教学建议的数据来源（`AiTeachingAdviceServiceImpl`）：学生会话基础信息（`AiMapper.getStudentBasicInfo`，联表 `users/student_profile/shuttlecock_skills`）、弱项（`getStudentWeakness`）、近期活动（`getStudentRecentActivity`，读 `practice_records`）、班级/学生雷达数据（`AnalysisMapper`）。生成结果写入 `ai_teaching_advice` 表。

---

## 9. 3D 动作演示与动作评估数据流

### 9.1 3D 动作演示（Three.js）

| 组件 | 说明 |
| --- | --- |
| `apps/student-web/src/utils/ThreeUtil.ts` | 封装 `GLTFLoader`、`FBXLoader`、`FontLoader`、`OrbitControls`、相机/渲染器创建 |
| `Motion3DViewer.vue` | 解析 CSV 骨骼数据（`[SegmentNames&Hierarchy]` / `[SegmentData]`），逐帧构建 22 段骨骼连接（Hips→Spine→…→ToeBase），以球体 + 线段渲染骨架，`requestAnimationFrame` 循环播放 |
| 数据格式 | 每帧每段 16 个浮点数，取偏移 `+8..+14` 为位置 `(x,y,z)` 与四元数 `(qx,qy,qz,qw)` |
| 视角 | `PerspectiveCamera(60)` + `OrbitControls`（阻尼、距离限制 200~3000） |

播放流程：
```
CSV 文件 ──fetch──► parseCSV() ──► MotionFrame[]（骨骼名→{position, rotation}）
                                          │
                                          ▼
                         animate() 每帧 updateSkeleton(frame)
                                          │
                         球体 Mesh 更新位置/四元数 + 线段端点更新
```

### 9.2 动作评估数据流（端到端）

```
① 采集/上传
   学生端上传动作视频 → POST /api/content/insert (multipart: aiContentInfo+file+motionName)
      → server-go content.InsertContent → 写 ai_content_info

② 评估结果落库
   POST /api/analysis/save { student_id, analysis_data(JSON) }
      → content.SaveAnalysis → 写 motion_analysis_data（analysis_data 含 self/standard 关节点、
        stability/proficiency/fluency/overall 评分、各关节 feedback）

③ 结果查询
   GET /api/analysis/queryByTaskId?taskId=...  → 返回 ai_analysis_result（评分 + feedback）
   GET /api/analysis/history?student_id=...    → 返回近 50 条 motion_analysis_data

④ 历史详情（卡片 + 聊天）
   POST /api/video/history/save → 写 video_history
   GET  /api/video/history/detail?historyId=... → 返回 ai_content_info（card/text 列表）

⑤ AI 教练解读
   POST /api/v0/ai/coach/chat { message, action_context:{hip/knee/ankle/foot_height/overall} }
      → DeepSeek 基于评分给出改进建议
```

`gvhResult`（GVHMR 人体动作重建）中的 `eval_results`、`elevation_records` 等字段在前端 `getMotionAssessmentHistoryListApi.ts` 中被解析为关节评分与抬脚高度曲线，用于雷达图与逐帧动作对比展示。

---

## 10. 部署与运行形态

| 组件 | 默认端口 | 启动方式 |
| --- | --- | --- |
| `server-go` | 8001 | `go run cmd/server/main.go`（读取 `configs/config.json`，支持环境变量覆盖） |
| `server-java` | 9002 | `mvn -pl service -am spring-boot:run`（`ServiceApplication`） |
| `student-web` | 5173 | `npm run dev`（Vite，`--mode dev`） |
| `teacher-web` | 5173 | `npm run dev`（Vite） |
| `yolo-detector` | 8000 | `python yolo_server.py`（可选） |

- 生产构建：学生端 `npm run build:prod`（产物 `dist/`）；教师端 `npm run build`（产物 `dist/`）。
- `server-java` 的 `service/common/config/YoloServerRunner` 在 `yolo.enabled=true` 时会以子进程方式拉起 `yolo_server.py`（默认端口 `8007`），属可选能力；脚本位于 `tools/yolo-detector/yolo_server.py`，需通过 `yolo.script-path` 指定。
- 容器化部署位于 `deploy/`，由专人维护，不在本文档范围内。

---

> 文档维护：路由、表结构、端口、依赖版本变更时，请同步更新 `docs/api.md`、`docs/database.md`、`docs/development.md`。
