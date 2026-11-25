<div align="center">

# 翎翼毽球教学平台

**Shuttlecock Action Assessment Platform**

面向毽球教学的「AI 动作评估 + 智能课堂」一体化平台

学生端 · 教师端 · Go 后端 · Java 后端 · 3D 动作演示 · DeepSeek 智能助教

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Go](https://img.shields.io/badge/Go-1.23-00ADD8.svg)](https://go.dev/)
[![Java](https://img.shields.io/badge/Java-21-ED8B00.svg)](https://openjdk.org/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.4.4-6DB33F.svg)](https://spring.io/projects/spring-boot)
[![Vue](https://img.shields.io/badge/Vue-3.5-42B883.svg)](https://vuejs.org/)
[![Vite](https://img.shields.io/badge/Vite-5%20%2F%207-646CFF.svg)](https://vitejs.dev/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.x-3178C6.svg)](https://www.typescriptlang.org/)
[![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1.svg)](https://www.mysql.com/)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D.svg)](https://redis.io/)
[![Podman](https://img.shields.io/badge/Podman-Ready-892CA0.svg)](https://podman.io/)

</div>

---

## 目录

- [项目简介](#项目简介)
- [核心功能](#核心功能)
- [系统架构](#系统架构)
- [技术栈](#技术栈)
- [仓库结构](#仓库结构)
- [快速开始](#快速开始)
  - [方式一：容器化部署（推荐）](#方式一容器化部署推荐)
  - [方式二：本地开发](#方式二本地开发)
- [服务与端口](#服务与端口)
- [配置说明](#配置说明)
- [文档](#文档)
- [参与贡献](#参与贡献)
- [开源许可](#开源许可)

---

## 项目简介

**翎翼毽球教学平台**是一套面向毽球（Shuttlecock）专项教学的完整解决方案。平台借助计算机视觉与 3D 动作可视化技术，把「动作示范 → 动作捕捉 → 动作评分 → 个性化训练建议」串成闭环，同时为教师提供课堂回放、学情分析、作业批改与 AI 教学建议等教学管理能力。

平台由**两条独立但协同的业务线**组成：

| 业务线 | 使用者 | 前端 | 后端 |
| --- | --- | --- | --- |
| **学生学习线** | 学生 | `apps/student-web`（端口 5173） | `services/server-go`（端口 8001） |
| **教师教学线** | 教师 | `apps/teacher-web`（端口 5173） | `services/server-java`（端口 9002） |

两条业务线共享同一个 MySQL 实例与 Redis 实例，数据层互通；AI 能力统一接入 DeepSeek。

> **设计取舍**：学生端后端采用 Go（高并发 WebSocket 流式 AI 对话 + 视频转录），教师端后端采用 Spring Boot（复杂业务编排、多模块分层、Sa-Token 权限体系）。这是历史演进与场景适配共同形成的架构，两端通过 `/api/v0/teacher/*` 轻量旁路与共享数据库保持协同。

---

## 核心功能

### 学生学习线

| 功能 | 说明 |
| --- | --- |
| **3D 动作演示** | 基于 Three.js 加载 FBX 骨骼动画与 GLB 场景，多角度展示毽球标准动作 |
| **AI 陪练** | WebSocket 流式对话，DeepSeek 驱动的动作答疑与训练指导，支持笔记润色 |
| **动作评估** | 上传/录制动作视频，后端结合动作捕捉数据（CSV）逐项评分并给出改进建议 |
| **体质分析** | 身高体重、体脂、肌肉分布等指标的可视化（雷达图、人体肌肉图、液位图） |
| **课程中心** | 课程分类树、视频播放进度记录、笔记查看 |
| **智能课堂** | AI 课堂讲解、课堂回放、课程视频在线学习 |
| **个人主页** | 学习统计、打卡记录、周趋势、日程管理、个人信息维护 |

### 教师教学线

| 功能 | 说明 |
| --- | --- |
| **教师工作台** | 班级概览、待处理事项、通知公告、今日课表 |
| **课堂管理** | 课堂视频回放 + 逐帧 AI 分析（出勤率、参与度、动作识别） |
| **学习管理** | AI 生成训练计划、计划审阅、视频库与学生分组推荐 |
| **学情分析** | 班级/学生双维度看板、雷达图、能力分布、趋势曲线、AI 教学建议 |
| **作业管理** | 作业创建/编辑/删除、学生提交查看、在线批改与反馈 |
| **个人信息** | 教师档案维护、头像上传 |

---

## 系统架构

```
                         ┌──────────────────────────┐
                         │        浏览器 / 移动端      │
                         └───────────┬──────────────┘
                                     │ HTTPS
              ┌──────────────────────┴──────────────────────┐
              │                                             │
    ┌─────────▼──────────┐                       ┌──────────▼─────────┐
    │  student-web :5173 │                       │  teacher-web :5173 │
    │  Vue 3 + Vite 5    │                       │  Vue 3 + Vite 7    │
    │  antd-vue / 3D     │                       │  Element Plus      │
    └─────────┬──────────┘                       └──────────┬─────────┘
              │ /api /videos /uploads                       │ /api /videos
              │                                             │
    ┌─────────▼──────────┐                       ┌──────────▼─────────┐
    │   server-go :8001  │                       │ server-java :9002  │
    │   Gin + GORM       │                       │ Spring Boot 3.4.4  │
    │   JWT HS512        │                       │ Sa-Token + MP      │
    │   WebSocket ×2     │                       │ JavaCV (FFmpeg)    │
    └──────┬──────┬──────┘                       └──────────┬─────────┘
           │      │                                         │
           │      └──────────────┬──────────────────────────┘
           │                     │
    ┌──────▼──────┐       ┌──────▼──────┐        ┌────────────────────┐
    │  MySQL 8.0  │       │  Redis 7    │        │  DeepSeek API      │
    │ lingxi_     │       │  会话/缓存   │        │  (对话 / 计划 /     │
    │ jianqiu     │       │             │        │   作业 / 建议)      │
    └─────────────┘       └─────────────┘        └────────────────────┘

    ┌───────────────────────────────────────────────────────────────┐
    │  可选组件：tools/yolo-detector（Python + FastAPI + YOLOv8）     │
    │  通过 /ws/analysis 向教师端推送课堂视频检测帧与出勤/参与度指标      │
    └───────────────────────────────────────────────────────────────┘
```

### 请求链路要点

1. **学生端**：`student-web` → Vite 代理 `/api`、`/videos`、`/uploads` → `server-go:8001`；AI 对话经 `/ws/ai` 走 WebSocket 流式返回。
2. **教师端**：`teacher-web` → Vite 代理 `/api`、`/videos` → `server-java:9002`；课堂通知经 `/ws/teacher/notification`。
3. **数据互通**：两端连接同一个 MySQL 库（`lingxi_jianqiu`），教师在教师端下发的作业与训练计划，学生在学生端可见。
4. **AI 集成**：学生侧对话/笔记润色由 Go 端调用 DeepSeek；教师侧训练计划/作业/教学建议由 Java 端 `DeepSeekClient` 调用 DeepSeek。

详见 [docs/architecture.md](docs/architecture.md)。

---

## 技术栈

| 分层 | 学生端 | 教师端 |
| --- | --- | --- |
| **前端框架** | Vue 3.5 + TypeScript 5.4 | Vue 3.5 + TypeScript 5.9 |
| **构建工具** | Vite 5 | Vite 7 |
| **状态管理** | Pinia 2 | Pinia 3 |
| **路由** | Vue Router 4 | Vue Router 5 |
| **UI 组件库** | Ant Design Vue 4 + Element Plus 2 | Element Plus 2.13 |
| **图表/3D** | ECharts 5、Three.js 0.174 | ECharts 6、vue-echarts |
| **样式** | SCSS | Tailwind CSS 4 |
| **后端语言** | Go 1.23 | Java 21 |
| **后端框架** | Gin 1.10 + GORM 1.25 | Spring Boot 3.4.4 |
| **持久层** | GORM + MySQL 驱动 | MyBatis-Plus 3.5.9 + 自研 BaseJdbcDao |
| **鉴权** | JWT HS512 + bcrypt | Sa-Token 1.39 |
| **实时通信** | gorilla/websocket | Spring WebSocket |
| **媒体处理** | — | JavaCV 1.5.11（含 FFmpeg） |
| **API 文档** | — | Knife4j 4.5（`/swagger-ui.html`） |
| **AI** | DeepSeek（`deepseek-chat`） | 自封装 `DeepSeekClient` |
| **中间件** | MySQL 8.0 + Redis 7 | MySQL 8.0 + Redis 7 |

---

## 仓库结构

```
shuttlecock-action-assessment/
├── apps/                          # 前端应用
│   ├── student-web/               # 学生端（Vue 3 + Vite 5，端口 5173）
│   └── teacher-web/               # 教师端（Vue 3 + Vite 7，端口 5173）
├── services/                      # 后端服务
│   ├── server-go/                 # 学生端后端（Go + Gin，端口 8001）
│   │   ├── cmd/server/            # 程序入口
│   │   ├── configs/               # 配置文件
│   │   ├── internal/              # config / database / cache / model / middleware / router / handler / websocket
│   │   └── pkg/                   # jwt / response / util
│   └── server-java/               # 教师端后端（Spring Boot 3.4.4，端口 9002）
│       ├── common/                # 公共库：common-core / common-jdbc / common-knife4j
│       └── service/               # 业务模块：ai / analysis / auth / classes / classroom / common / home / homework / learning / profile
├── tools/
│   └── yolo-detector/             # 可选：Python + FastAPI + YOLOv8 课堂视频检测
├── deploy/                        # 容器化部署（Podman Compose + 国内镜像加速）
│   ├── docker/                    # 各服务 Dockerfile 与 Nginx 配置
│   ├── scripts/                   # 一键构建/启停脚本
│   └── podman-compose.yml
├── docs/                          # 项目文档
│   ├── architecture.md            # 系统架构
│   ├── api.md                     # 接口文档
│   ├── development.md             # 开发指南
│   ├── database.md                # 数据模型
│   └── README.md                  # 文档索引
├── README.md
└── LICENSE
```

**代码规模**：Go 20 个源文件 / Java 125 个源文件 / Vue 127 个单文件组件 / TypeScript 103 个模块。

---

## 快速开始

### 环境要求

| 依赖 | 版本 | 用途 |
| --- | --- | --- |
| Node.js | `^20.19.0` 或 `>=22.12.0` | 前端构建与开发 |
| Go | 1.23+ | `server-go` |
| JDK | 21 | `server-java` |
| Maven | 3.9+ | `server-java` 构建 |
| MySQL | 8.0+ | 数据存储 |
| Redis | 7+ | 缓存与会话 |
| Podman / Docker | 4.x / 20.x | 容器化部署（可选） |

### 方式一：容器化部署（推荐）

项目提供完整的 Podman Compose 部署工程，并默认使用**国内可拉取的镜像源**，无需额外配置即可在国内网络环境下构建启动。

> **Windows 用户注意**：请在 WSL2 中通过 `/mnt/d/` 路径访问本仓库，例如
> `cd /mnt/d/AiWork/shuttlecock-action-assessment`，不要直接在 PowerShell 中执行 Podman 命令。

```bash
# 1. 进入仓库（WSL 中）
cd /mnt/d/AiWork/shuttlecock-action-assessment/deploy

# 2. 准备环境变量
cp .env.example .env
vim .env                       # 填入数据库密码、JWT secret、DeepSeek API Key

# 3. 构建并启动全部服务
./scripts/build.sh
./scripts/up.sh

# 4. 查看状态与日志
podman ps
./scripts/logs.sh
```

启动后访问：

| 服务 | 地址 |
| --- | --- |
| 学生端 | http://localhost:8080 |
| 教师端 | http://localhost:8081 |
| 学生端后端 | http://localhost:8001 |
| 教师端后端 | http://localhost:9002 |

国内镜像加速细节（Podman `registries.conf`、npm `npmmirror`、Maven 阿里云、`GOPROXY`）与排错说明见 [deploy/README.md](deploy/README.md)。

### 方式二：本地开发

```bash
# 1. 启动基础设施（MySQL 3306 + Redis 6379）
#    首次需创建数据库并导入表结构，详见 docs/database.md

# 2. 启动学生端后端
cd services/server-go
go mod download
go run cmd/server/main.go            # :8001

# 3. 启动教师端后端
cd services/server-java
mvn -DskipTests install
mvn -pl service -am spring-boot:run  # :9002

# 4. 启动学生端前端
cd apps/student-web
npm install --registry=https://registry.npmmirror.com
npm run dev                          # :5173

# 5. 启动教师端前端（另开终端，端口冲突时按提示切换）
cd apps/teacher-web
npm install --registry=https://registry.npmmirror.com
npm run dev                          # :5173
```

> 两个前端开发端口默认都是 5173，**同时开发时请修改其中之一的 `vite.config.ts` 端口**（例如教师端改为 5174）。

完整环境变量、代码规范与常见问题见 [docs/development.md](docs/development.md)。

---

## 服务与端口

| 服务 | 目录 | 默认端口 | 说明 |
| --- | --- | --- | --- |
| 学生端前端 | `apps/student-web` | 5173 | Vite 开发服务器 |
| 教师端前端 | `apps/teacher-web` | 5173 | Vite 开发服务器（建议改 5174） |
| 学生端后端 | `services/server-go` | 8001 | REST + WebSocket |
| 教师端后端 | `services/server-java` | 9002 | REST + Knife4j 文档 |
| YOLO 检测服务 | `tools/yolo-detector` | 8000 | 可选，WebSocket 推流 |
| MySQL | — | 3306 | 共享数据库 `lingxi_jianqiu` |
| Redis | — | 6379 | 缓存 / 会话 |

### 关键接口分组

| 前缀 | 归属 | 鉴权 |
| --- | --- | --- |
| `/token`、`/vtoken`、`/captcha` | server-go | 公开 / 游客 |
| `/api/*` | server-go | JWT |
| `/api/v0/ai/*` | server-go | JWT |
| `/api/v0/student/*` | server-go | JWT |
| `/api/v0/teacher/*` | server-go | JWT（只读课程目录） |
| `/api/v0/transcribe/*` | server-go | JWT |
| `/ws/ai`、`/ws/teacher/notification` | server-go | WebSocket |
| `/api/system/user/*`、`/api/class/*`、`/api/classroom/*`、`/api/homework/*`、`/api/learning/*`、`/api/home/*`、`/api/analysis/*`、`/api/ai/*`、`/api/profile/*` | server-java | Sa-Token |

完整接口清单（含方法、路径、说明）见 [docs/api.md](docs/api.md)。

---

## 配置说明

### server-go（`services/server-go/configs/config.json`）

配置优先级：**环境变量 > `configs/config.json` > 内置默认值**。容器化部署时建议只保留结构，敏感项全部由环境变量注入。

| 环境变量 | 配置项 | 说明 |
| --- | --- | --- |
| `SERVER_ADDR` | `server_addr` | 监听地址，默认 `:8001` |
| `VIDEO_BASE_PATH` | `video_base_path` | 课程视频根目录（映射 `/videos/*`） |
| `UPLOADS_PATH` | `uploads_path` | 用户上传目录（映射 `/uploads/*`） |
| `DB_HOST` `DB_PORT` `DB_USER` `DB_PASSWORD` `DB_NAME` `DB_CHARSET` | `database.*` | MySQL 连接 |
| `REDIS_HOST` `REDIS_PORT` `REDIS_PASSWORD` `REDIS_DB` | `redis.*` | Redis 连接 |
| `JWT_SECRET` `JWT_ACCESS_EXPIRY` `JWT_REFRESH_EXPIRY` | `jwt.*` | 签名密钥与有效期（秒） |
| `DEEPSEEK_API_KEY` `DEEPSEEK_BASE_URL` `DEEPSEEK_MODEL` | `deepseek.*` | DeepSeek 配置 |
| `DASHSCOPE_API_KEY` | `dashscope.api_key` | DashScope（占位） |
| `CLOUDFLARE_SITE_KEY` `CLOUDFLARE_SECRET_KEY` | `cloudflare_turnstile.*` | 人机验证 |

### server-java（`services/server-java/service/src/main/resources/application.yaml`）

| 环境变量 | 说明 |
| --- | --- |
| `SERVER_PORT` | 服务端口，默认 9002 |
| `SPRING_DATASOURCE_URL` / `SPRING_DATASOURCE_USERNAME` / `SPRING_DATASOURCE_PASSWORD` | 数据源 |
| `SPRING_DATA_REDIS_HOST` / `SPRING_DATA_REDIS_PORT` / `SPRING_DATA_REDIS_PASSWORD` | Redis |
| `DEEPSEEK_API_KEY` / `DEEPSEEK_BASE_URL` / `DEEPSEEK_MODEL` | DeepSeek |
| `PUBLIC_VIDEO_PATH` / `PUBLIC_UPLOAD_PATH` | 公共文件（视频/上传）目录 |
| `CLOUDFLARE_TURNSTILE_SECRET` | 人机验证 Secret |

> ⚠️ **安全提示**：仓库中所有密钥字段均为占位值或空值。生产部署请通过环境变量或密钥管理服务注入，**切勿把真实密钥提交到仓库**。

---

## 文档

| 文档 | 内容 |
| --- | --- |
| [docs/architecture.md](docs/architecture.md) | 系统架构、模块职责、请求链路、鉴权与实时通信 |
| [docs/api.md](docs/api.md) | 全部 REST / WebSocket 接口清单 |
| [docs/development.md](docs/development.md) | 本地开发环境、启动顺序、代码规范、排错 |
| [docs/database.md](docs/database.md) | 数据模型与核心表结构 |
| [deploy/README.md](deploy/README.md) | Podman 容器化部署与国内镜像加速 |

---

## 参与贡献

1. Fork 本仓库并从 `master` 切出特性分支：`git checkout -b feat/your-feature`
2. 遵守各子项目的代码规范（前端 `npm run lint`，Go `gofmt`，Java 遵循阿里巴巴 Java 开发手册）
3. 提交前请自测：`go vet ./...`、`npm run type-check`、`mvn -DskipTests package`
4. 提交信息遵循约定式提交：`<类型>: <中文描述>`，例如 `feat: 新增课堂回放倍速播放`
5. 发起 Pull Request 并在描述中说明变更点与验证方式

---

## 开源许可

本项目基于 [MIT License](LICENSE) 开源。

Copyright (c) 2026 LingYi Shuttlecock Teaching Platform
