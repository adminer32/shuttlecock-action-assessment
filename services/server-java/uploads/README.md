# 教师端用户上传目录（不随仓库提交）

本目录对应 `server-java` 的上传落盘位置，由 `FileService` 在教师上传作业附件、
课件、视频时写入。

**上传产物不纳入版本控制**（见根级 `.gitignore`）。

## 说明

- 上传接口：`POST /api/file/upload`
- 下载接口：`GET /api/file/download/{fileName}`
- 容器化部署时挂载到 `server-java` 容器内，并设置环境变量 `PUBLIC_UPLOAD_PATH`
- 目录会在首次上传时自动创建，无需预置内容
