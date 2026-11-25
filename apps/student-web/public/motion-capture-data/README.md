# 动作捕捉数据（不随仓库提交）

本目录用于存放「动作评估」功能用于比对打分的动作捕捉 CSV 数据，**数据文件不纳入版本控制**。

## 需要的内容

每个动作一份 CSV，文件名与动作中文名一致：

```
motion-capture-data/
├── 绷踢.csv
├── 盘踢.csv
├── 磕踢.csv
├── 对踢.csv
├── 拐踢.csv
├── 头触球.csv
├── 胸触球.csv
├── 跳踢.csv
└── 蹦踢.csv
```

## 引用位置

- `src/utils/MotionCSVUtil.ts` —— 动作名 → CSV 路径映射
- `src/views/personal-analysis/MotionAnalysisView/MotionAnalysisView.vue` —— 3D 动作回放与评分

> CSV 为标准动作捕捉关键点序列（每帧若干关节点坐标），由动作捕捉设备导出后放至此处即可。
