# 学生端前端 · student-web

翎翼毽球教学平台的学生端单页应用，提供动作演示、AI 陪练、动作评估、体质分析、课程中心、智能课堂等能力。

## 技术栈

| 类别 | 选型 |
| --- | --- |
| 框架 | Vue 3.5 + TypeScript 5.4 |
| 构建 | Vite 5 |
| 状态管理 | Pinia 2 |
| 路由 | Vue Router 4（`createWebHistory`） |
| UI | Ant Design Vue 4 + Element Plus 2（部分组件） |
| 图表 | ECharts 5（含 `echarts-liquidfill`、`echarts-wordcloud`） |
| 3D | Three.js 0.174（FBX 动作模型、GLB 场景） |
| 富文本 | `@wangeditor/editor-for-vue` |
| 国际化 | Vue I18n 11 |
| 测试 | Vitest 2 + `@vue/test-utils` |

## 目录结构

```
student-web/
├── public/                        # 不参与打包的静态资源
│   ├── components/                # 独立注入脚本（浮动公告、Cloudflare 人机验证页）
│   ├── iconfont/                  # 图标字体
│   ├── motion-capture-data/       # 动作捕捉 CSV 数据（动作评分对比用）
│   ├── motion-demo-view/          # 3D 动作演示资源（FBX/GLB 模型、真人演示视频）
│   ├── static/                    # 公共静态图片与脚本
│   └── videos/                    # 课程与专项动作视频（不随仓库提交，见目录内 README）
├── src/
│   ├── api/                       # 按业务域拆分的接口封装
│   ├── assets/                    # 参与打包的图片、JSON 数据与样式
│   ├── components/                # 通用 UI 组件（feedback / navigation / layout / data-display / data-entry / common）
│   ├── constants/                 # 全局常量
│   ├── directives/                # 自定义指令（拖拽、尺寸监听、滑入动画）
│   ├── i18n/                      # 中英文语言包
│   ├── router/                    # 路由与登录守卫
│   ├── stores/                    # Pinia Store
│   ├── style/                     # 全局 SCSS
│   ├── tests/                     # 单元测试
│   ├── types/                     # 全局类型声明
│   ├── utils/                     # 工具函数（HTTP、动作 CSV 解析、Three 封装等）
│   └── views/                     # 页面级组件
│       ├── home/                  # 首页
│       ├── login/                 # 登录 / 注册
│       ├── motion-demo/           # 3D 动作演示
│       ├── ai-learn-friend/       # AI 陪练
│       ├── personal-analysis/     # 动作评估 / 体质分析 / 学情分析
│       ├── personal-homepage/     # 个人主页与日程
│       ├── smart-class/           # 智能课堂、课程中心、课堂回放
│       └── header/                # 全局头部
├── index.html
├── vite.config.ts
└── vitest.config.ts
```

## 常用命令

```bash
npm install                 # 依赖安装（国内建议加 --registry=https://registry.npmmirror.com）
npm run dev                 # 开发服务器 http://localhost:5173
npm run build:prod          # 生产构建，产物输出到 dist/
npm run preview             # 预览构建产物
npm run type-check          # vue-tsc 类型检查
npm run lint                # ESLint 自动修复
npm run test:run            # Vitest 单次运行
```

## 开发代理

`vite.config.ts` 中已配置开发代理，默认后端为 `http://127.0.0.1:8001`（`services/server-go`）：

| 前缀 | 目标 | 说明 |
| --- | --- | --- |
| `/api` | `http://127.0.0.1:8001` | 业务接口 |
| `/videos` | `http://127.0.0.1:8001` | 课程视频 |
| `/uploads` | `http://127.0.0.1:8001` | 用户上传文件 |
| `/gvhmr` | `http://127.0.0.1:8000` | 动作捕捉推理服务（可选） |

## 环境变量

见 `.env.dev` / `.env.prod`：

| 变量 | 说明 |
| --- | --- |
| `VITE_BACK_END_BASE_URL` | 后端基础地址，留空则走 Vite 代理 |
| `VITE_WS_BASE_URL` | WebSocket 地址，默认 `ws://localhost:8001` |
| `VITE_PYTHON_BACK_END_BASE_URL` | Python 推理服务地址（可选） |

> 顶部导航与页面标题依赖 `src/i18n/*.json`，新增页面时请同步补充对应语言键。
