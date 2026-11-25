# 数据模型（Database）

> 本文档从代码中提取数据模型：
> - 学生端：`services/server-go/internal/model/models.go`（GORM 模型，`internal/database/init.go` 里 `AutoMigrate`）
> - 教师端：`services/server-java/service/src/main/java/com/system/service/**/entity/*.java`（MyBatis-Plus `@TableName`）
> - 跨端 SQL 引用：`services/server-java/service/src/main/resources/mapper/**/*.xml`、Go handler 中的原生 SQL
>
> **两端共享同一个 MySQL 实例、同一个数据库 `lingxi_jianqiu`**（见 `configs/config.json` 的 `database.db_name` 与 `application.yaml` 的 `SPRING_DATASOURCE_URL`）。

---

## 目录

1. [数据库归属与共享说明](#1-数据库归属与共享说明)
2. [学生端 GORM 模型（server-go）](#2-学生端-gorm-模型server-go)
3. [教师端实体与表（server-java）](#3-教师端实体与表server-java)
4. [跨端共享的核心业务表](#4-跨端共享的核心业务表)
5. [仅出现在 SQL 中的业务表（mapper 推导）](#5-仅出现在-sql-中的业务表mapper-推导)
6. [表清单速查](#6-表清单速查)

---

## 1. 数据库归属与共享说明

| 项 | 值 | 来源 |
| --- | --- | --- |
| 数据库类型 | MySQL 8 | `application.yaml`、`config.json` |
| 库名 | `lingxi_jianqiu` | `config.json` 的 `database.db_name`；`application.yaml` 的 `jdbc:mysql://.../lingxi_jianqiu` |
| 字符集 | `utf8mb4` | `config.json` |
| 时区 | `Asia/Shanghai` / `GMT+8` | `application.yaml` |
| 连接池（Go） | MaxIdle 10 / MaxOpen 100 | `internal/database/init.go` |
| 连接池（Java） | `maximum-pool-size: 20` | `application.yaml` |
| Redis | 同实例，`db 0` | `config.json`、`application.yaml` |

**共享关系**：`server-go` 与 `server-java` 连接同一个 MySQL 实例的同一个 `lingxi_jianqiu` 库。`server-go` 通过 GORM `AutoMigrate` 维护其模型对应的表；`server-java` 通过 MyBatis-Plus 与 mapper XML 读写同一批表（例如两端都访问 `student_profile`、`motion_analysis_data`、`student_physique`）。

> 命名提示：Go 侧表名遵循 GORM 默认命名策略（结构体名转蛇形、复数）。Java 实体通过 `@TableName` 显式指定表名，mapper XML 使用原生 SQL 引用的表名才是权威表名。下方表格在「表名」一列注明来源。

---

## 2. 学生端 GORM 模型（server-go）

模型定义于 `internal/model/models.go`；`AutoMigrate` 清单见 `internal/database/init.go`。

### 2.1 模型总览

| 结构体 | 用途 | 表名（来源） |
| --- | --- | --- |
| `User` | 用户账号（学生/教师/管理员） | `users`（GORM 默认；Java `User` 亦为 `users`） |
| `StudentProfile` | 学生档案 | `student_profile`（SQL 引用；见 §4.1） |
| `TeacherProfile` | 教师档案 | `teacher_profile`（GORM 默认；Java 实体同名表） |
| `JWTBlacklist` | JWT 黑名单（退出登录） | GORM 默认 |
| `JWTIP` | Token 与 IP 绑定记录 | GORM 默认 |
| `VideoProgress` | 视频观看进度 | GORM 默认 |
| `CourseCategory` | 课程分类 | GORM 默认 |
| `CourseInfo` | 课程信息 | GORM 默认 |
| `StudentPhysique` | 学生体质数据 | `student_physique`（Java 实体同名表） |
| `PracticeRecord` | 练习记录 | `practice_records`（SQL 引用） |
| `Schedule` | 日程计划 | GORM 默认 |
| `AITranscriptionTask` | AI 转录任务/笔记 | `ai_transcription_task`（SQL 引用） |
| `AIContentInfo` | AI 聊天内容记录 | `ai_content_info`（SQL 引用） |
| `AICardInfo` | AI 消息卡片 | GORM 默认 |
| `AIAnalysisResult` | AI 动作分析结果 | `ai_analysis_result`（SQL 引用） |
| `AINoteInfo` | AI 笔记 | GORM 默认 |
| `VideoHistory` | 视频/会话历史 | `video_history`（SQL 引用） |
| `MotionAnalysisData` | 动作分析原始 JSON | `motion_analysis_data`（Java 实体同名表） |
| `ScheduleEvent` | 日程事件（SpringBoot 侧） | GORM 默认 |
| `StudentCheckin` | 学生打卡记录 | `student_checkin`（SQL 引用） |
| `ShuttlecockSkill` | 毽球技能 | `shuttlecock_skills`（SQL 引用） |

### 2.2 `users`（User）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | uint PK | 主键 |
| `username` | varchar(50) unique | 登录名 |
| `password_hash` | varchar(128) | 密码哈希（bcrypt；Java 端为 SHA-256） |
| `password_salt` | varchar(16) | 密码盐 |
| `role` | enum(ADMIN/TEACHER/STUDENT) | 角色，默认 STUDENT |
| `active` | bool | 是否激活，默认 false |
| `avatar` | varchar(255) | 头像 |
| `email` | varchar(255) | 邮箱 |
| `telephone` | varchar(20) | 电话 |
| `created_at` / `updated_at` / `deleted_at` | datetime | 时间戳与软删除 |

### 2.3 `student_profile`（StudentProfile）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `user_id` | uint PK | 关联 `users.id` |
| `student_id` | uint unique | 学号 |
| `real_name` | varchar(50) | 真实姓名 |
| `gender` | varchar(2) | 性别 |
| `grade` | uint | 年级 |
| `major` | varchar(50) | 专业 |
| `class_id` | varchar(20) | 班级 ID（字符串，与 Java `class.id` 通过 `CONVERT(... CHAR)` 关联） |
| `avatar` | varchar(255) | 头像 |
| `email` | varchar(255) | 邮箱 |

> 注：Java mapper 中统一以 `student_profile.id` 作为学生主键、`student_profile.student_id` 作为学号（见 `AiMapper.xml`、`AnalysisMapper.xml`）。

### 2.4 `teacher_profile`（TeacherProfile）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | uint PK | 主键 |
| `teacher_id` | uint unique | 教师 ID |
| `name` | varchar(50) | 姓名 |
| `specialty` | varchar(100) | 专业方向 |
| `department` | varchar(100) | 院系 |
| `avatar` | varchar(255) | 头像 |
| `email` | varchar(255) | 邮箱 |

### 2.5 `video_progress`（VideoProgress）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | uint PK | 主键 |
| `user_id` | uint | 用户 ID（与 `video_path` 组成唯一键 `uk_user_video`） |
| `video_path` | varchar(500) | 视频路径 |
| `progress` | int | 进度（秒/百分比），默认 0 |
| `created_at` / `updated_at` | datetime | 时间戳 |

### 2.6 课程（CourseCategory / CourseInfo）

`CourseCategory`：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | uint PK | 分类 ID |
| `parent_id` | uint? | 父分类 |
| `name` | varchar(255) | 分类名 |
| `enabled` | bool | 是否启用 |
| `deleted_at` | datetime | 软删除 |

`CourseInfo`：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | uint PK | 课程 ID |
| `name` | varchar(255) | 课程名 |
| `category_id` | uint? | 分类 ID |
| `content` / `description` | text | 内容/描述 |
| `video_url` | varchar(500) | 视频地址 |
| `video_duration` | varchar(50) | 时长 |
| `teacher_name` | varchar(255) | 教师名 |
| `cover_image_url` | varchar(255) | 封面 |
| `level_name` | varchar(255) | 难度等级 |
| `create_by` | uint? | 创建者 |
| `create_time` / `update_time` | datetime | 时间 |
| `enabled` | bool | 是否启用 |
| `deleted_at` | datetime | 软删除 |

### 2.7 `student_physique`（StudentPhysique）

学生体质数据（体测成分）。字段较多，按用途分组：

| 分组 | 字段（示例） | 说明 |
| --- | --- | --- |
| 基础 | `student_id`, `weight`, `bmi` | 学生、体重、BMI |
| 体脂/肌肉 | `fat_percentage`, `skeletal_muscle_mass`, `visceral_fat_level`, `limb_skeletal_muscle_index`, `estimated_waist_hip_ratio` | 体脂率、骨骼肌量、内脏脂肪等级、四肢骨骼肌指数、腰臀比 |
| 形态 | `body_type`, `body_shape`, `basal_metabolism_rate`, `body_age` | 体型、体形、基础代谢、体龄 |
| 成分 | `moisture_rate`, `bone_salt_amount`, `protein_percentage`, `lean_body_mass`, `heart_rate` | 水分率、骨盐量、蛋白质率、去脂体重、心率 |
| 分段-水分/蛋白/脂肪 | `segment_moisture`, `segment_protein`, `segment_fat_mass`, `segment_bone_salt`, `segment_fat_total` | 分段总量 |
| 分段-脂肪部位 | `segment_fat_right_upper/left_upper/trunk/right_lower/left_lower` | 右上/左上/躯干/右下/左下肢脂肪 |
| 分段-肌肉部位 | `segment_skeletal_muscle_total`, `segment_skeletal_right_upper/left_upper/trunk/right_lower/left_lower` | 分段骨骼肌 |
| 时间 | `create_time`, `update_time` | 创建/更新时间 |

> Java 实体 `analysis/entity/StudentPhysique.java`（`@TableName("student_physique")`）使用驼峰字段，`map-underscore-to-camel-case: true` 自动映射到下划线列。

### 2.8 `practice_records`（PracticeRecord）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | uint PK | 主键 |
| `student_id` | uint index | 学生 ID |
| `action_type` | varchar(100) | 动作类型 |
| `video_url` | varchar(500) | 视频地址 |
| `result_data` | text（JSON） | 评估结果 JSON（含 `score`、关节评分等；`AiMapper.xml` 用 `JSON_EXTRACT(result_data,'$.score')`） |
| `created_at` | datetime | 创建时间 |

### 2.9 `schedule`（Schedule）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | uint PK | 主键 |
| `student_id` | uint index | 学生 ID |
| `schedule_date` | date | 日期 |
| `time` | time | 时间 |
| `type` | varchar(50) | 类型，默认 `warning` |
| `content` | text | 内容 |
| `created_at` | datetime | 创建时间 |

### 2.10 AI 相关表

**`ai_transcription_task`（AITranscriptionTask）** —— AI 转录任务/笔记：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | uint PK | 主键 |
| `task_id` | varchar(64) unique | 任务 ID |
| `video_url` | varchar(500) | 视频地址 |
| `transcription` | text | 转录文本 |
| `auto_chapters` | text | 自动章节 |
| `summarization` | text | 摘要 |
| `meeting_assistance`(列 `meeting_assistance`) | text | 会议辅助 |
| `personal_note`(列 `personal_note`) | text | 个人笔记 |
| `task_status` | varchar(50) | 状态，默认「进行中」 |
| `title` | varchar(255) | 标题 |
| `deleted` | int | 软删除标记，默认 0 |
| `create_time` | datetime | 创建时间 |

**`ai_content_info`（AIContentInfo）** —— AI 聊天/内容记录：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | uint PK | 主键 |
| `history_id` | uint index | 关联 `video_history.id` |
| `task_id` | varchar(64) | 任务 ID |
| `type` | varchar(20) | 类型，默认 `text` |
| `text` | text | 文本 |
| `card` | json | 卡片数据 |
| `sender` | varchar(10) | 发送方（user/ai） |
| `analysis` | json | 分析数据 |
| `created_at` | datetime | 创建时间 |

**`ai_analysis_result`（AIAnalysisResult）** —— AI 动作分析结果：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | uint PK | 主键 |
| `task_id` | varchar(64) unique | 任务 ID |
| `student_id` | uint index | 学生 ID |
| `analysis_data` | json | 分析数据 |
| `stability_score` | float | 稳定性评分 |
| `proficiency_score` | float | 熟练度评分 |
| `fluency_score` | float | 流畅度评分 |
| `overall_score` | float | 综合评分 |
| `feedback` | text | 反馈 |
| `created_at` | datetime | 创建时间 |

其余 AI 表：`AICardInfo`（消息卡片：`content_id`/`title`/`video_url`/`analysis`）、`AINoteInfo`（笔记：`task_id`/`student_id`/`video_url`/`title`/`auto_chapters`/`summarization`/`personal_note`/`task_status`）、`VideoHistory`（`history_id`/`student_id`/`content`/`created_at`）。

### 2.11 `motion_analysis_data`（MotionAnalysisData）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | uint PK | 主键 |
| `task_id` | varchar(64) unique | 任务 ID |
| `student_id` | uint index | 学生 ID |
| `analysis_data` | json | 动作分析原始 JSON（前端 `self/standard` 关节点、评分、`gvhResult` 等） |
| `created_at` | datetime | 创建时间 |

> Java 实体 `analysis/entity/MotionAnalysisData.java`（`@TableName("motion_analysis_data")`，字段 `studentId`/`analysisData`/`createdAt`）与此表对应，两端共享。

### 2.12 `schedule_event`（ScheduleEvent）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | uint PK | 主键 |
| `student_id` | uint index | 学生 ID |
| `title` | varchar(255) | 标题 |
| `start_time` / `end_time` | datetime | 起止时间 |
| `type` | varchar(50) | 类型 |
| `content` | text | 内容 |
| `created_at` | datetime | 创建时间 |

### 2.13 `student_checkin`（StudentCheckin）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | uint PK | 主键 |
| `student_id` | uint index | 学生 ID |
| `checkin_date` | date | 打卡日期 |
| `duration` | int | 学习时长（秒；`AnalysisMapper.xml` 用 `SUM(duration)/3600.0` 换算小时） |
| `checkin_type` | varchar(50) | 打卡类型 |
| `score` | decimal(4,1) | 打卡得分 |

### 2.14 `shuttlecock_skills`（ShuttlecockSkill）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | uint PK | 主键 |
| `student_id` | uint index | 学生 ID |
| `skill_name` | varchar(100) | 技能名 |
| `level` | int | 等级 |
| `learned_date` | date | 学习日期 |

> `AnalysisMapper.xml` 中该表还使用 `skill_type`、`personal_score`、`class_avg_score`、`updated_at` 等列（统计弱项与班级雷达图），说明实际表包含这些扩展列。

---

## 3. 教师端实体与表（server-java）

实体通过 `@TableName` 指定表名。

### 3.1 实体表

| 实体类 | 表名 | 用途 |
| --- | --- | --- |
| `auth/entity/User.java` | `users` | 账号（与学生端 `users` 同表） |
| `classes/entity/CourseClass.java` | `` `class` `` | 班级 |
| `homework/entity/Homework.java` | `teacher_homework` | 作业 |
| `homework/entity/HomeworkSubmission.java` | `teacher_homework_submission` | 作业提交 |
| `homework/entity/HomeworkFeedback.java` | `teacher_homework_feedback` | 作业反馈/批改 |
| `learning/entity/ActionVideo.java` | `teacher_action_videos` | 动作视频 |
| `profile/entity/TeacherProfile.java` | `teacher_profile` | 教师档案 |
| `analysis/entity/MotionAnalysisData.java` | `motion_analysis_data` | 动作分析（共享） |
| `analysis/entity/StudentPhysique.java` | `student_physique` | 体质（共享） |

### 3.2 `users`

见 §2.2（两端同表）。Java 端 `LoginRequestDTO` 传 `username`/`password`/`turnstileToken`，登录以 `SecureUtil.sha256(password + salt)` 比对 `password_hash`。

### 3.3 `class`（CourseClass）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | Long PK | 班级 ID |
| `name` | String | 班级名 |
| `teacher_id` | Long | 班主任/教师 ID |
| `grade` | Integer | 年级 |
| `created_at` / `updated_at` | datetime | 自动填充 |

### 3.4 `teacher_homework`（Homework）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | Long PK | 作业 ID |
| `title` | String | 标题 |
| `requirements` | String | 要求 |
| `demo_video_url` | String | 示范视频 |
| `deadline` | datetime | 截止时间 |
| `class_id` | Long | 班级 ID |
| `teacher_id` | Long | 教师 ID |
| `status` | Integer | 状态 |
| `created_at` / `updated_at` | datetime | 自动填充 |

### 3.5 `teacher_homework_submission`（HomeworkSubmission）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | Long PK | 提交 ID |
| `homework_id` | Long | 作业 ID |
| `student_id` | Long | 学生 ID |
| `video_url` | String | 提交视频 |
| `created_at` / `updated_at` | datetime | 自动填充 |

### 3.6 `teacher_homework_feedback`（HomeworkFeedback）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | Long PK | 反馈 ID |
| `submission_id` | Long | 提交 ID |
| `homework_id` | Long | 作业 ID |
| `ai_score` | decimal | AI 评分 |
| `teacher_score` | decimal | 教师评分 |
| `teacher_comment` | String | 教师评语 |
| `ai_suggestion` | String | AI 建议 |
| `status` | Integer | 状态（0 未批改） |
| `created_at` / `updated_at` | datetime | 自动填充 |

### 3.7 `teacher_action_videos`（ActionVideo）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | Long PK | 视频 ID |
| `title` | String | 标题 |
| `url` | String | 地址 |
| `duration` | String | 时长 |
| `category` | String | 分类 |
| `description` | String | 描述 |
| `teacher_id` | Long | 教师 ID |
| `class_id` | Long | 班级 ID |
| `created_at` / `updated_at` | datetime | 自动填充 |

### 3.8 `teacher_profile`（TeacherProfile）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | Long PK | 主键 |
| `teacher_id` | Long | 教师 ID |
| `name` | String | 姓名 |
| `avatar` | String | 头像 |
| `email` | String | 邮箱 |
| `phone` | String | 电话 |
| `gender` | Integer | 性别 |
| `specialty` | String | 专业方向 |
| `bio` | String | 简介 |
| `active` | Integer | 是否激活 |
| `department` | String | 院系 |
| `teaching_years` | Integer | 教龄 |
| `created_at` / `updated_at` | datetime | 自动填充 |

---

## 4. 跨端共享的核心业务表

以下表在 Java mapper XML 中被直接 SQL 引用，是教师端学情/首页/作业统计的数据底座；学生端 handler 的原生 SQL 也读写同名表。

### 4.1 `student_profile`

学生档案主表。Java 侧通过 `student_profile.id`（主键）、`student_id`（学号）、`real_name`、`avatar`、`class_id` 关联统计。字段见 §2.3。

### 4.2 `student_checkin`

打卡表。`AnalysisMapper.xml` 使用 `student_id`、`checkin_date`、`duration`。字段见 §2.13。

### 4.3 `shuttlecock_skills`

技能评分表。`AiMapper.xml`、`AnalysisMapper.xml`、`LearningMapper.xml` 使用 `student_id`、`skill_type`、`personal_score`、`class_avg_score`、`updated_at`。字段见 §2.14。

### 4.4 `action_scores`

动作评分表（学生端 `GetActionScores` 与 `AnalysisMapper.getStudentActionAnalysis` 使用）。列：`student_id`、`action_type`、`current_score`、`history_avg_score`、`recent_scores`、`feedback`。

### 4.5 `student_learning`

学习时长/行为表（`AnalysisMapper.getStudentStudyDuration` 等）。列：`student_id`、`learning_hours`、`action_type`、`score`、`checkin_date`、`start_learning_time`。

### 4.6 `homework_scores`

作业成绩表（`AnalysisMapper` 统计成绩均分/趋势/分布）。列：`student_id`、`score`、`homework_date`。

### 4.7 `ai_training_plans`

AI 训练计划表（`LearningMapper.xml` 核心表，教师端训练计划与审批）。关键列：`id`、`student_id`、`class_id`、`goal`、`tasks`(JSON)、`progress`、`review_status`（`待定`/`批准`/`驳回`）、`reviewer_id`、`reviewed_at`、`review_comment`、`week_start_date`、`week_end_date`、`week_number`、`total_weeks`、`full_plan_json`、`plan_source`、`lesson_id`、`created_at`。

### 4.8 `ai_teaching_advice`

AI 教学建议表（`AiTeachingAdviceMapper.xml`）。列：`id`、`target_type`（`CLASS`/`STUDENT`）、`target_id`、`priority_level`（`HIGH`/`MEDIUM`/`LOW`）、`title`、`description`、`suggestions`、`week_start_date`、`created_at`。

### 4.9 `motion_analysis_data` / `student_physique`

见 §2.11 / §2.7，两端共享。

---

## 5. 仅出现在 SQL 中的业务表（mapper 推导）

以下表未定义独立 Java 实体，但被 `resources/mapper/**/*.xml` 直接使用，属真实业务表：

### 5.1 课堂类

| 表 | 关键列 | 用途 | 出处 |
| --- | --- | --- | --- |
| `teacher_lesson` | `id`、`content`(标题)、`preview_image`、`video_url`、`video_duration`、`class_id`、`teacher_id`、`created_at` | 课堂课程/录播 | `ClassroomMapper.xml` |
| `teacher_knowledge_points` | `id`、`lesson_id`、`title`、`description`、`demo_video_url` | 知识点 | `ClassroomMapper.xml` |
| `teacher_classroom_notes` | `id`、`lesson_id`、`content`、`created_at` | 课堂笔记 | `ClassroomMapper.xml` |
| `teacher_class_notifications` | `id`、`class_id`、`teacher_id`、`title`、`content`、`type`、`created_at`、`updated_at` | 班级通知 | `HomeMapper.xml` |

### 5.2 作业与视频推荐

| 表 | 关键列 | 用途 | 出处 |
| --- | --- | --- | --- |
| `teacher_action_video_recommendations` | `video_id`、`student_id`、`teacher_id`、`comment`、`created_at` | 视频推荐给学生 | `ActionVideoMapper.xml` |
| `teacher_homework_submission` / `teacher_homework_feedback` | 见 §3.5 / §3.6 | 作业提交/反馈 | `HomeMapper.xml`、`HomeworkMapper.xml` |
| `homework_scores` | 见 §4.6 | 成绩统计 | `AnalysisMapper.xml` |

### 5.3 学情统计引用

| 表 | 关键列 | 用途 |
| --- | --- | --- |
| `student_learning` | `student_id`、`learning_hours`、`start_learning_time` | 学习时长趋势 |
| `student_checkin` | `student_id`、`checkin_date`、`duration` | 打卡/出勤 |
| `shuttlecock_skills` | `student_id`、`skill_type`、`personal_score` | 技能雷达/弱项 |
| `action_scores` | `student_id`、`action_type`、`current_score` | 动作能力 |
| `homework_scores` | `student_id`、`score`、`homework_date` | 成绩趋势 |
| `ai_training_plans` | 见 §4.7 | 训练计划/审批 |

---

## 6. 表清单速查

| 业务域 | 表名 | 端 |
| --- | --- | --- |
| 账号 | `users` | 两端共享 |
| 学生 | `student_profile` | 共享 |
| 教师 | `teacher_profile` | 共享 |
| 班级 | `class` | 教师端 |
| 课程 | `course_category`、`course_info` | 学生端 |
| 视频进度 | `video_progress` | 学生端 |
| 体质 | `student_physique` | 共享 |
| 动作分析 | `motion_analysis_data`、`ai_analysis_result`、`action_scores` | 共享 |
| 练习 | `practice_records` | 学生端 |
| 打卡 | `student_checkin` | 共享 |
| 技能 | `shuttlecock_skills` | 共享 |
| 学习 | `student_learning` | 共享 |
| 日程 | `schedule`、`schedule_event` | 学生端 |
| 作业 | `teacher_homework`、`teacher_homework_submission`、`teacher_homework_feedback`、`homework_scores` | 教师端/共享 |
| 训练计划 | `ai_training_plans` | 共享 |
| AI 教学建议 | `ai_teaching_advice` | 教师端 |
| AI 转录/笔记 | `ai_transcription_task`、`ai_note_info`、`ai_content_info`、`ai_card_info`、`video_history` | 学生端 |
| 课堂 | `teacher_lesson`、`teacher_knowledge_points`、`teacher_classroom_notes`、`teacher_action_videos`、`teacher_action_video_recommendations` | 教师端 |
| 通知 | `teacher_class_notifications` | 教师端 |
| 鉴权 | `jwt_blacklist`、`jwt_ip` | 学生端 |

---

> 维护提示：新增/修改表时同步更新本节表格，并确认两端命名（Go GORM 默认复数 vs Java `@TableName` 显式名）保持同一物理表，避免出现「同名不同表」。
