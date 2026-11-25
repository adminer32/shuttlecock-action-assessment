# 3D 动作演示资源（不随仓库提交）

本目录用于存放「3D 动作演示」页面所需的模型与真人演示视频，**资源文件不纳入版本控制**。

## 需要的内容

```
motion-demo-view/
├── model/
│   ├── motion/          # 带动画的 FBX（每个动作一份）
│   │   ├── 单脚内侧踢球.fbx
│   │   ├── 双脚内侧踢球.fbx
│   │   ├── 大腿触球.fbx
│   │   ├── 正脚背发球.fbx
│   │   ├── 脚外侧发球.fbx
│   │   ├── 脚外侧踢球.fbx
│   │   ├── 脚背踢球.fbx
│   │   └── 蹦踢.fbx
│   ├── bone/            # 对应的骨骼 FBX
│   └── scene/           # 场景资源
│       ├── 羽毛球场.glb
│       ├── 篮球场.glb
│       └── EnvMapTexture.jpg
└── real-person-demo/    # 真人演示视频 mp4
```

## 引用位置

- `src/views/motion-demo/MotionDemoView.vue` —— 主演示页
- `src/views/home/components/ThreeBoxContainer/MotionDemo.vue` —— 首页演示卡片
- `src/views/header/CenterOption.vue` —— 顶部演示入口
- `src/assets/motion-demo-view/skill_data.json` —— 动作清单（该 JSON 参与打包，随仓库提交）

> 新增动作时，需同时更新 `skill_data.json` 与本目录的文件名，二者必须一致。
