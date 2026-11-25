# 接口文档（API Reference）

> 本文档从代码中真实提取路由，**每一条都可回溯到源码**：
> - 学生端（Go）路由：`services/server-go/cmd/server/main.go`
> - 教师端（Java）路由：`services/server-java/service/src/main/java/com/system/service/*/controller/*.java`
>
> 统一约定见 [§0](#0-统一约定)。

---

## 目录

- [0. 统一约定](#0-统一约定)
- [1. 学生端接口（server-go，:8001）](#1-学生端接口server-go8001)
  - [1.1 公开接口（无 JWT）](#11-公开接口无-jwt)
  - [1.2 `/api/*`（需 JWT）](#12-apijwt)
  - [1.3 `/api/v0/ai/*`（需 JWT）](#13-apiv0ai需-jwt)
  - [1.4 `/api/v0/student/*`（需 JWT）](#14-apiv0student需-jwt)
  - [1.5 `/api/v0/teacher/*`（需 JWT）](#15-apiv0teacher需-jwt)
  - [1.6 `/api/v0/transcribe/*`（需 JWT）](#16-apiv0transcribe需-jwt)
  - [1.7 WebSocket](#17-websocket)
- [2. 教师端接口（server-java，:9002）](#2-教师端接口server-java9002)
  - [2.1 认证 `/api/system/user`](#21-认证-apIsystemuser)
  - [2.2 班级 `/api/class`](#22-班级-apiclass)
  - [2.3 首页 `/api/home`](#23-首页-apihome)
  - [2.4 作业 `/api/homework`](#24-作业-apihomework)
  - [2.5 学习管理 `/api/learning`](#25-学习管理-apilearning)
  - [2.6 课堂 `/api/classroom`](#26-课堂-apiclassroom)
  - [2.7 学情分析 `/api/analysis`](#27-学情分析-apianalysis)
  - [2.8 AI `/api/ai`](#28-ai-apiai)
  - [2.9 教师档案 `/api/profile`](#29-教师档案-apiprofile)
  - [2.10 文件 `/api/file`、`/api/public`](#210-文件-apifileapipublic)
- [3. 鉴权机制说明](#3-鉴权机制说明)

---

## 0. 统一约定

### 0.1 基地址

| 服务 | 开发地址 | 前端代理 |
| --- | --- | --- |
| 学生端后端 | `http://127.0.0.1:8001` | student-web `vite.config.ts`：`/api`、`/videos`、`/uploads` → `:8001` |
| 教师端后端 | `http://localhost:9002` | teacher-web `vite.config.ts`：`/api`、`/videos` → `:9002` |

### 0.2 响应包络

**学生端（Go）** —— `pkg/response/response.go`：

```json
{ "status": "success", "message": "可选提示", "data": { } }
```

`status` 取值 `success` / `error`；鉴权失败返回 HTTP 401/403，参数错误返回 400。

**教师端（Java）** —— `common-core/.../web/RestResponse.java`：

```json
{ "code": 200, "message": "ok", "data": { } }
```

前端 `request.ts` 以 `code === 200` 判定成功，`401` 触发登出跳转。

### 0.3 鉴权方式

| 端 | 请求头 / 参数 | 说明 |
| --- | --- | --- |
| 学生端 | `access_token: <jwt>` 或 `Authorization: Bearer <jwt>` 或 `?token=` / `?access_token=` | JWT HS512 |
| 教师端 | `auth-token: <token>` | Sa-Token，`token-name: auth-token` |

---

## 1. 学生端接口（server-go，:8001）

路由来源：`services/server-go/cmd/server/main.go`。

### 1.1 公开接口（无 JWT）

| Method | Path | 说明 | 鉴权 |
| --- | --- | --- | --- |
| POST | `/token` | 账号密码登录，返回 `access_token`/`refresh_token`/`expires_in`/`token_id` | 无 |
| GET | `/token` | 校验 token 是否有效，返回 `valid`/`user_id`/`role` | 无 |
| POST | `/token/refresh` | 用 `refresh_token` 换新 token 对 | 无 |
| GET | `/vtoken` | 游客 token 探活（固定返回 `{status:"ok"}`） | 无 |
| POST | `/vtoken` | 发送邮箱验证码（Redis 存 `vtoken:<email>`，15 分钟） | 无 |
| GET | `/captcha` | 获取图形验证码（SVG，Redis 存 `captcha:<ip>`，5 分钟） | 无 |
| POST | `/file/operation/upload` | 上传文件（≤100MB，写入 `uploads_path`） | 无 |
| GET | `/videos/*` | 课程视频静态资源（映射 `video_base_path`） | 无 |
| GET | `/uploads/*` | 用户上传静态资源（映射 `uploads_path`） | 无 |

### 1.2 `/api/*`（需 JWT）

挂载于 `r.Group("/api", jwtAuth)`。

| Method | Path | Handler | 说明 | 鉴权 |
| --- | --- | --- | --- | --- |
| POST | `/api/analysis/save` | `content.SaveAnalysis` | 保存动作分析数据到 `motion_analysis_data` | JWT |
| GET | `/api/analysis/history` | `content.GetAnalysisHistory` | 按 `student_id` 取最近 50 条分析记录 | JWT |
| GET | `/api/analysis/queryByTaskId` | `content.QueryByTaskId` | 按 `taskId` 查 `ai_analysis_result` | JWT |
| GET | `/api/analysis/generateTrainingPlan` | `content.GenerateTrainingPlan` | 生成训练计划（当前返回示例 items） | JWT |
| GET | `/api/physique/query` | `student.GetPhysique` | 查询学生体质数据 | JWT |
| POST | `/api/physique/create` | `student.CreatePhysique` | 新建体质数据 | JWT |
| PUT | `/api/physique/update` | `student.UpdatePhysique` | 按 `student_id` 更新体质数据 | JWT |
| POST | `/api/course/query` | `course.QueryCourses` | 按父分类扫描视频目录返回课程列表 | JWT |
| GET | `/api/course/getNoteById` | `course.GetNoteById` | 按 `id` 查笔记（`ai_transcription_task`） | JWT |
| GET | `/api/video/progress` | `video.GetProgress` | 查询用户视频观看进度 | JWT |
| POST | `/api/video/progress` | `video.SaveProgress` | 保存/更新视频观看进度 | JWT |
| POST | `/api/video/history/save` | `video.SaveHistory` | 新建/更新 `video_history` | JWT |
| POST | `/api/video/history/query` | `video.QueryHistory` | 查询历史记录列表 | JWT |
| GET | `/api/video/history/detail` | `video.GetHistoryDetail` | 按 `historyId` 取内容列表（卡片/文本） | JWT |
| DELETE | `/api/video/history/del` | `video.DeleteHistory` | 按 `ids` 批量删除历史 | JWT |
| POST | `/api/ai/NotePolishing` | `ai.NotePolishing` | DeepSeek 笔记润色 | JWT |
| GET | `/api/visualization/getMotionNameAnalysis` | `student.GetMotionNameAnalysis` | 按动作名聚合 `ai_analysis_result` 各维度均分 | JWT |
| GET | `/api/visualization/queryHistoricalTrends` | `student.GetHistoricalTrends` | 近 30 天趋势 | JWT |
| GET | `/api/visualization/getStatsByCreateBy` | `student.GetStatsByCreateBy` | 笔记/分析数量统计 | JWT |
| GET | `/api/content/queryCategory` | `content.QueryCategory` | 返回内容分类（盘踢/磕踢/拐踢/绷踢） | JWT |
| POST | `/api/content/insert` | `content.InsertContent` | 插入 `ai_content_info`（multipart） | JWT |

### 1.3 `/api/v0/ai/*`（需 JWT）

挂载于 `api.Group("/v0").Group("/ai")`。

| Method | Path | Handler | 说明 | 鉴权 |
| --- | --- | --- | --- | --- |
| POST | `/api/v0/ai/chat` | `ai.Chat` | 通用 AI 对话（DeepSeek） | JWT |
| POST | `/api/v0/ai/coach/chat` | `ai.CoachChat` | 教练对话，可带 `action_context` 动作评分 | JWT |
| GET | `/api/v0/ai/models` | `ai.ListModels` | 返回可用模型列表 | JWT |
| GET | `/api/v0/ai/health` | `ai.HealthCheck` | AI 健康检查 | JWT |
| POST | `/api/v0/ai/queryPersonalNotes` | `ai.QueryPersonalNotes` | 分页查询个人笔记（`ai_transcription_task`） | JWT |
| POST | `/api/v0/ai/addTranscriptionTask` | `ai.AddTranscriptionTask` | 新建转录任务 | JWT |
| POST | `/api/v0/ai/updateNote` | `ai.UpdateNote` | 更新笔记标题/个人笔记 | JWT |
| DELETE | `/api/v0/ai/del` | `ai.DeleteNotes` | 按 `ids` 软删除笔记 | JWT |
| GET | `/api/v0/ai/queryTaskStatus` | `ai.QueryTaskStatus` | 按 `taskId` 查任务状态 | JWT |

### 1.4 `/api/v0/student/*`（需 JWT）

挂载于 `api.Group("/v0").Group("/student")`。

| Method | Path | Handler | 说明 | 鉴权 |
| --- | --- | --- | --- | --- |
| GET | `/api/v0/student/learning/stats/:studentId` | `student.GetLearningStats` | 学习统计（总时长/打卡/动作种类/均分/等级） | JWT |
| GET | `/api/v0/student/learning/action-scores/:studentId` | `student.GetActionScores` | 按动作类型聚合评分 | JWT |
| GET | `/api/v0/student/learning/shuttlecock-skills/:studentId` | `student.GetShuttlecockSkills` | 毽球技能列表 | JWT |
| GET | `/api/v0/student/learning/weekly-trend/:studentId` | `student.GetWeeklyTrend` | 近 8 周趋势 | JWT |
| GET | `/api/v0/student/learning/checkin-records/:studentId` | `student.GetCheckinRecords` | 近 30 条打卡记录 | JWT |
| POST | `/api/v0/student/learning/practice-record` | `student.SavePracticeRecord` | 保存练习记录 | JWT |
| GET | `/api/v0/student/learning/practice-records/:studentId` | `student.GetPracticeRecords` | 练习记录列表 | JWT |
| GET | `/api/v0/student/learning/practice-record/:recordId` | `student.GetPracticeRecord` | 单条练习记录 | JWT |
| DELETE | `/api/v0/student/learning/practice-record/:recordId` | `student.DeletePracticeRecord` | 删除练习记录 | JWT |
| GET | `/api/v0/student/schedule/query` | `schedule.QuerySchedules` | 按月份查询日程 | JWT |
| POST | `/api/v0/student/schedule/save` | `schedule.SaveSchedule` | 新建/更新日程 | JWT |
| DELETE | `/api/v0/student/schedule/del` | `schedule.DeleteSchedules` | 按 `ids` 批量删除日程 | JWT |
| GET | `/api/v0/student/physique/` | `student.GetPhysique` | 查询体质（同上 handler） | JWT |
| POST | `/api/v0/student/physique/` | `student.CreatePhysique` | 新建体质 | JWT |
| PUT | `/api/v0/student/physique/` | `student.UpdatePhysiqueData` | 更新体质 | JWT |
| GET | `/api/v0/student/auth/` | `student.GetProfile` | 获取学生档案 | JWT |
| POST | `/api/v0/student/auth/` | `student.CreateProfile` | 新建学生档案 | JWT |
| GET | `/api/v0/student/users/profile` | `student.GetUserProfile` | 用户 + 学生档案聚合信息 | JWT |

### 1.5 `/api/v0/teacher/*`（需 JWT）

挂载于 `api.Group("/v0").Group("/teacher")`。

| Method | Path | Handler | 说明 | 鉴权 |
| --- | --- | --- | --- | --- |
| GET | `/api/v0/teacher/lessons` | `course.GetTeacherLessons` | 教师课程列表（可按 `class_id`/`teacher_id` 过滤） | JWT |
| GET | `/api/v0/teacher/lessons/:lessonId` | `course.GetTeacherLesson` | 课程详情 | JWT |

### 1.6 `/api/v0/transcribe/*`（需 JWT）

挂载于 `api.Group("/v0").Group("/transcribe")`。

| Method | Path | Handler | 说明 | 鉴权 |
| --- | --- | --- | --- | --- |
| POST | `/api/v0/transcribe/transcribe` | `transcribe.TranscribeVideo` | 视频转录（占位返回） | JWT |
| POST | `/api/v0/transcribe/analyze` | `transcribe.AnalyzeTranscription` | DeepSeek 分析转录（章节/摘要/关键词） | JWT |
| POST | `/api/v0/transcribe/full-process` | `transcribe.FullProcessVideo` | 完整处理流水线（置为处理中） | JWT |
| GET | `/api/v0/transcribe/health` | `transcribe.HealthCheck` | 健康检查 | JWT |

### 1.7 WebSocket

| Path | Handler | 说明 | 鉴权 |
| --- | --- | --- | --- |
| GET `/ws/ai` | `websocket.HandleAIChat` | AI 流式对话（init / chat 协议） | `?token=` |
| GET `/ws/teacher/notification` | `websocket.HandleTeacherNotification` | 教师提醒通道（30s 心跳 pong） | `?token=` |

> WebSocket 注册在根引擎上（`r.GET`），不受 `/api` 组中间件约束，改由 query `token` 传参。

---

## 2. 教师端接口（server-java，:9002）

路由来源：各 `*/controller/*.java` 的 `@RequestMapping` 类注解 + 方法级 `@*Mapping`。

### 2.1 认证 `/api/system/user`

控制器：`auth/controller/UserController.java`（类级 `@SaCheckRole("TEACHER")`）

| Method | Path | 说明 | 鉴权 |
| --- | --- | --- | --- |
| POST | `/api/system/user/login` | 登录（带 Cloudflare Turnstile），返回 `auth-token` | `@SaIgnore` 公开 |
| GET | `/api/system/user/me` | 获取当前登录用户信息 | TEACHER |
| POST | `/api/system/user/logout` | 注销 | TEACHER |

### 2.2 班级 `/api/class`

控制器：`classes/controller/ClassController.java`（类级 `@SaCheckRole("TEACHER")`）

| Method | Path | 说明 | 鉴权 |
| --- | --- | --- | --- |
| GET | `/api/class/list` | 获取当前教师所属班级列表 | TEACHER |

### 2.3 首页 `/api/home`

控制器：`home/controller/HomeController.java`

| Method | Path | 说明 | 鉴权 |
| --- | --- | --- | --- |
| GET | `/api/home/overview` | 班级概览（学生数/今日作业提交/今日打卡） | TEACHER |
| GET | `/api/home/pending` | 待处理事项（`teacherId`、可选 `classId`） | TEACHER |
| GET | `/api/home/notices` | 通知列表（分页 `page`/`size`） | TEACHER |
| POST | `/api/home/notice` | 发布通知 | TEACHER |
| PUT | `/api/home/notice` | 编辑通知 | TEACHER |
| DELETE | `/api/home/notice/{id}` | 删除通知 | TEACHER |

### 2.4 作业 `/api/homework`

控制器：`homework/controller/HomeworkController.java`（类级 `@SaCheckRole("TEACHER")`）

| Method | Path | 说明 | 鉴权 |
| --- | --- | --- | --- |
| GET | `/api/homework/list` | 作业列表（可选 `classId`） | TEACHER |
| GET | `/api/homework/{id}` | 作业详情 | TEACHER |
| POST | `/api/homework` | 发布新作业 | TEACHER |
| PUT | `/api/homework/{id}` | 更新作业 | TEACHER |
| DELETE | `/api/homework/{id}` | 删除作业 | TEACHER |
| GET | `/api/homework/{homeworkId}/submissions` | 学生提交列表 | TEACHER |
| GET | `/api/homework/submission/{submissionId}` | 单条提交详情 | TEACHER |
| PUT | `/api/homework/submission/{submissionId}/grade` | 批改作业 | TEACHER |

### 2.5 学习管理 `/api/learning`

控制器：`learning/controller/LearningController.java`

| Method | Path | 说明 | 鉴权 |
| --- | --- | --- | --- |
| GET | `/api/learning/overview` | 班级学习概览（`classId`） | TEACHER |
| GET | `/api/learning/students` | 学生列表（`classId`，可选 `keyword`） | TEACHER |
| GET | `/api/learning/plan` | 按 `studentId` 取训练计划详情 | TEACHER |
| GET | `/api/learning/plan/current-week` | 当前周计划 | TEACHER |
| GET | `/api/learning/plan/week` | 指定周计划（`weekNumber`） | TEACHER |
| GET | `/api/learning/plan/all` | 学生全部周计划（历史） | TEACHER |
| GET | `/api/learning/plan/groups` | 学生计划分组 | TEACHER |
| PUT | `/api/learning/plan/review` | 审批训练计划 | TEACHER |
| GET | `/api/learning/videos` | 动作视频列表（可选 `classId`/`category`） | TEACHER |
| POST | `/api/learning/videos` | 添加动作视频 | TEACHER |
| POST | `/api/learning/videos/recommend` | 推荐视频给学生 | TEACHER |
| DELETE | `/api/learning/plan/group` | 删除学生某个计划组 | TEACHER |

### 2.6 课堂 `/api/classroom`

控制器：`classroom/controller/ClassroomController.java`

| Method | Path | 说明 | 鉴权 |
| --- | --- | --- | --- |
| GET | `/api/classroom/lessons` | 课程列表（`classId`） | TEACHER |
| GET | `/api/classroom/knowledge` | 知识点列表（`lessonId`） | TEACHER |
| GET | `/api/classroom/notes` | 课堂笔记列表（`lessonId`） | TEACHER |
| POST | `/api/classroom/knowledge` | 添加知识点 | TEACHER |
| POST | `/api/classroom/note` | 添加课堂笔记 | TEACHER |
| POST | `/api/classroom/notes/save` | 批量保存课堂笔记 | TEACHER |
| POST | `/api/classroom/analyze` | 分析课堂视频（出勤/参与度） | TEACHER |
| PUT | `/api/classroom/knowledge/{id}/video` | 更新知识点视频 URL | TEACHER |

### 2.7 学情分析 `/api/analysis`

控制器：`analysis/controller/AnalysisController.java`

| Method | Path | 说明 | 鉴权 |
| --- | --- | --- | --- |
| GET | `/api/analysis/class/{classId}/dashboard` | 班级学情概览（可选 `month`） | TEACHER |
| GET | `/api/analysis/student/{studentId}/dashboard` | 学生学情概览（可选 `month`） | TEACHER |
| GET | `/api/analysis/class/{classId}/students` | 班级学生列表 | TEACHER |
| GET | `/api/analysis/student/{studentId}/motion-analysis` | 学生动作分析数据 | TEACHER |
| GET | `/api/analysis/student/{studentId}/physique` | 学生体质数据 | TEACHER |

### 2.8 AI `/api/ai`

控制器：`ai/controller/AiController.java`（类级 `@SaCheckRole("TEACHER")`）

| Method | Path | 说明 | 鉴权 |
| --- | --- | --- | --- |
| POST | `/api/ai/generate-homework` | AI 生成作业 | TEACHER |
| POST | `/api/ai/generate-plan` | AI 生成训练计划 | TEACHER |
| POST | `/api/ai/save-plan` | 保存 AI 生成的训练计划（拆分为周记录） | TEACHER |
| GET | `/api/ai/advice/class/{classId}` | 获取班级 AI 教学建议 | TEACHER |
| POST | `/api/ai/advice/class/{classId}/regenerate` | 重新生成班级 AI 建议 | TEACHER |
| GET | `/api/ai/advice/student/{studentId}` | 获取学生 AI 个性化改进建议 | TEACHER |
| POST | `/api/ai/advice/student/{studentId}/regenerate` | 重新生成学生 AI 建议 | TEACHER |

### 2.9 教师档案 `/api/profile`

控制器：`profile/controller/TeacherProfileController.java`（类级 `@SaCheckRole("TEACHER")`）

| Method | Path | 说明 | 鉴权 |
| --- | --- | --- | --- |
| GET | `/api/profile/me` | 获取当前登录教师档案 | TEACHER |
| PUT | `/api/profile/me` | 更新当前教师档案 | TEACHER |

### 2.10 文件 `/api/file`、`/api/public`

控制器：`common/controller/FileController.java`、`common/controller/PublicFileController.java`

| Method | Path | 说明 | 鉴权 |
| --- | --- | --- | --- |
| POST | `/api/file/upload` | 通用文件上传（方法级 `@SaCheckRole("TEACHER")`） | TEACHER（见 §3 说明） |
| GET | `/api/file/download/{fileName}` | 文件下载（方法级 `@SaCheckRole("TEACHER")`） | TEACHER（见 §3 说明） |
| GET | `/api/file/{fileName:.+}` | 公共文件读取（视频播放，支持 Range） | 公开 |
| GET | `/api/public/file/{fileName:.+}` | 公共文件服务（视频/图片播放，支持 Range） | 公开 |

---

## 3. 鉴权机制说明

### 3.1 学生端（Go）

- 除 §1.1 公开接口与 §1.7 WebSocket 外，其余所有 `/api/**` 均挂在 `jwtAuth`（`middleware.JWTAuth`）之后。
- `JWTAuth` 行为：从 `Authorization`/`?token=`/`?access_token=` 取 token → 验签 → 查 Redis 黑名单 `jwt:blacklist:<jti>` → 注入 `user_id`/`username`/`role`/`token_id` 到上下文。

### 3.2 教师端（Java）

- `WebMvcInterceptorConfig` 将 `MyInterceptor` 注册到 `/**`，并排除：
  `/v3/api-docs/**`、`/swagger-resources/**`、`/webjars/**`、`/doc.html`、`/swagger-ui/**`、`/swagger-ui.html`、`/favicon.ico`、`/error`、`/api/file/**`、`/api/images/**`。
- `MyInterceptor.preHandle` 对未被 `@SaIgnore` 标记的方法执行：`StpUtil.checkLogin()` → 校验 Session 用户 → `StpUtil.checkRole("TEACHER")`。
- 因此即便某些控制器未写类级 `@SaCheckRole`，只要经过该拦截器就要求 `TEACHER` 登录。
- 提交 `@SaIgnore` 的登录接口直接放行。
- **注意**：`/api/file/**` 被拦截器排除，因此 `FileController` 的 `@SaCheckRole("TEACHER")` 方法在实际运行时不会经拦截器校验（这是当前代码行为）；公共读取 `GET /api/file/{fileName}`、`/api/public/file/{fileName}` 为公开接口。

### 3.3 参数说明补充

- 分页参数统一为 `page`（默认 1）、`size`（默认 5/按接口），学生端部分接口用 `student_id` 查询参数。
- 学生端 `:studentId`、`:recordId`、`:lessonId` 为路径参数。
- 教师端 `{classId}`、`{studentId}`、`{id}` 等为路径变量。

---

> 维护提示：路由变更时必须同步 `services/server-go/cmd/server/main.go` 与 Java `controller`，并更新本文表格。
