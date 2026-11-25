# 教师端前端 · teacher-web

翎翼毽球教学平台的教师端单页应用，覆盖教师工作台、课堂管理（视频回放 + AI 分析）、学习管理（AI 训练计划）、学情分析、作业管理与批改、个人信息等模块。

## 技术栈

| 类别 | 选型 |
| --- | --- |
| 框架 | Vue 3.5 + TypeScript 5.9 |
| 构建 | Vite 7 |
| 状态管理 | Pinia 3 |
| 路由 | Vue Router 5（`createWebHistory`） |
| UI | Element Plus 2.13 + `@element-plus/icons-vue` |
| 图表 | ECharts 6 + `echarts-liquidfill` + `vue-echarts` |
| 样式 | Tailwind CSS 4 + PostCSS |
| HTTP | Axios 1.13 |
| 代码规范 | oxlint + ESLint + Prettier |
| 部署 | Cloudflare Pages（`wrangler`，可选） |

**Node 版本要求**：`^20.19.0 || >=22.12.0`

## 目录结构

```
teacher-web/
├── public/                    # 静态资源
├── src/
│   ├── api/                   # 接口封装（auth / ai / analysis / class / classroom / homework / learning / profile）
│   ├── assets/                # 图片与全局样式
│   ├── components/
│   │   ├── captcha/           # Turnstile 人机验证
│   │   ├── common/            # 通用组件
│   │   └── layout/            # 布局骨架（侧边栏、头部、内容区、主题切换）
│   ├── constants/             # 全局常量
│   ├── hooks/                 # 组合式函数（useHomeData / useHomework / useAnalysis / useLearningManagement）
│   ├── router/                # 路由与登录守卫
│   ├── stores/                # Pinia Store（user / class）
│   ├── types/                 # 类型声明
│   ├── utils/                 # request 封装与工具函数
│   └── views/
│       ├── home/              # 教师工作台
│       ├── classroom/         # 课堂管理 - 视频回放与 AI 分析
│       ├── learning/          # 学习管理 - AI 训练计划与视频库
│       ├── analysis/          # 学情分析
│       ├── homework/          # 作业管理与批改
│       └── profile/           # 个人信息
├── index.html
├── vite.config.ts
└── wrangler.jsonc
```

## 常用命令

```bash
npm install                 # 依赖安装（国内建议加 --registry=https://registry.npmmirror.com）
npm run dev                 # 开发服务器 http://localhost:5173
npm run build               # 类型检查 + 生产构建，产物输出到 dist/
npm run type-check          # 仅类型检查
npm run lint                # oxlint + ESLint 自动修复
npm run format              # Prettier 格式化
npm run preview             # 基于 wrangler 本地预览
```

## 开发代理

`vite.config.ts` 中已配置开发代理，默认后端为 `http://localhost:9002`（`services/server-java`）：

| 前缀 | 目标 |
| --- | --- |
| `/api` | `http://localhost:9002` |
| `/videos` | `http://localhost:9002` |

> 若 `server-java` 修改端口，请同步修改此处代理目标。

## 路由与权限

`src/router/index.ts` 中带 `requireAuth: true` 的路由由 Pinia `useUserStore().token` 守门：

| 路径 | 页面 |
| --- | --- |
| `/login` | 登录（公开） |
| `/home` | 教师工作台 |
| `/classroom` | 课堂管理 - 视频回放 |
| `/learning` | 学习管理 - AI 课堂 |
| `/analysis` | 学情分析 |
| `/homework` | 作业管理 |
| `/homework/grade` | 批改作业 |
| `/profile` | 个人信息 |
