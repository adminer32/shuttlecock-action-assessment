# 教师端公共文件（不随仓库提交）

本目录对应 `server-java` 的 `public-file.paths` 配置，用于存放**无需鉴权**即可访问的
课堂回放视频、知识库视频与图片。

**媒体文件不纳入版本控制。**

## 说明

- 运行期由 `PublicFileController` 通过 `/api/public/file/{fileName}` 对外提供；
- 容器化部署时挂载到 `server-java` 容器内，并设置环境变量 `PUBLIC_VIDEO_PATH`；
- 典型内容：课堂回放 mp4、知识库视频、课件图片。

## 相关配置

```yaml
public-file:
  paths:
    - ${PUBLIC_VIDEO_PATH:./public}
    - ${PUBLIC_UPLOAD_PATH:./uploads}
```
