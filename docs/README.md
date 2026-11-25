# 翎翼毽球教学平台 · 技术文档

本目录是「翎翼毽球教学平台」monorepo 的技术文档索引。所有文档均以仓库源码为依据编写，涉及的路由、表结构、端口、依赖版本都可回溯到代码。

## 文档清单

| 文档 | 一句话说明 |
| --- | --- |
| [系统架构设计](architecture.md) | 整体拓扑、技术选型与理由、模块职责、两端请求链路、鉴权对比、WebSocket、DeepSeek 集成与 3D 动作数据流（含 ASCII 架构图）。 |
| [接口文档](api.md) | 从 `main.go` 与 Java `controller/*.java` 真实提取的全部路由，按业务域分组列出 Method/Path/说明/鉴权要求。 |
| [本地开发指南](development.md) | 环境要求、依赖安装（含国内镜像）、四端启动顺序与命令、环境变量、代码规范与常见问题；含 WSL 访问路径说明。 |
| [数据模型](database.md) | 从 Go 模型、Java 实体与 mapper XML 提取的核心数据表字段与用途，说明两端共享同一 MySQL（`lingxi_jianqiu`）。 |

## 阅读建议

- 想快速了解系统怎么跑起来 → 先看 [系统架构设计](architecture.md) 的「整体拓扑」，再看 [本地开发指南](development.md)。
- 前后端对接接口 → 直接查 [接口文档](api.md)。
- 排查数据问题 / 写 SQL → 查 [数据模型](database.md)。

## 仓库结构速览

```
apps/student-web/     学生端  Vue3.5 + TS + Vite5 + Pinia2 + Ant Design Vue4 + ECharts5 + Three.js（dev :5173）
apps/teacher-web/     教师端  Vue3.5 + TS + Vite7 + Pinia3 + Element Plus2 + ECharts6 + Tailwind4（dev :5173）
services/server-go/   学生端后端  Go 1.23 + Gin + GORM + MySQL + Redis + JWT HS512（:8001）
services/server-java/ 教师端后端  Java 21 + Spring Boot 3.4.4 + MyBatis-Plus + Sa-Token（:9002）
tools/yolo-detector/  YOLOv8 + FastAPI 课堂检测（可选，WS /ws/analysis，:8000）
deploy/               容器化部署（由专人负责）
docs/                 本文档目录
```

> 文档维护：路由、表结构、端口、依赖版本变更时，请同步更新对应文档。
