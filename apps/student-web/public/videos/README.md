# 课程视频（不随仓库提交）

本目录用于存放学生端「课程中心」「智能课堂」播放的课程视频，**媒体文件不纳入版本控制**。

## 需要的内容

按课程分类建子目录，常见的目录名为：

```
videos/
├── single-special-moves/     # 单人专项动作
│   ├── 绷踢.mp4
│   ├── 盘踢.mp4
│   ├── 磕踢.mp4
│   └── 拐踢.mp4
└── <其他课程分类>/
```

> 目录名使用英文 kebab-case；视频文件名沿用动作中文名，前端 `AiClassView.vue`
> 中的 `actionVideoMap` 与后端课程表的 `video_url` 字段均直接引用这些路径。

## 如何获取

1. 向课程视频的维护者索取，或从已有的部署环境导出；
2. 放入本目录后，确认文件名与 `actionVideoMap` / 课程数据里的 `video_url` 一致；
3. 本地开发直接生效（Vite 会把 `public/` 原样提供）；
4. 容器化部署时，将本目录挂载到 `server-go` 容器内并设置 `VIDEO_BASE_PATH`，
   或挂载到 `server-java` 容器并设置 `PUBLIC_VIDEO_PATH`。

## 相关配置

| 位置 | 变量 |
| --- | --- |
| `services/server-go/configs/config.json` | `video_base_path` / 环境变量 `VIDEO_BASE_PATH` |
| `services/server-java/service/src/main/resources/application.yaml` | `public-file.paths` / 环境变量 `PUBLIC_VIDEO_PATH` |
