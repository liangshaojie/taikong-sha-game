# 太空杀 (TaikongSha)

使用 **Godot 4** 开发的社交推理类多人游戏，参考《Among Us / 太空杀》的核心玩法。

> 目标平台：PC（Steam）+ 微信小游戏
> 引擎版本：Godot 4.5+
> 脚本语言：GDScript

---

## 目录结构

```
taikong-sha-game/
├── scenes/                 # Godot 场景文件 (.tscn)
│   ├── lobby/              # 大厅相关场景（房间列表、创建房间、准备界面）
│   ├── game/               # 游戏中场景（主地图、玩家、任务点）
│   └── ui/                 # HUD、投票面板、设置等 UI 场景
│
├── scripts/                # GDScript 脚本 (.gd)
│   ├── network/            # 联网相关：Lobby、GameManager、RPC 处理
│   ├── player/             # 玩家逻辑：移动、动画、状态
│   ├── tasks/              # 任务系统：任务基类 + 具体任务
│   ├── voting/             # 会议与投票系统
│   └── utils/              # 通用工具：常量、辅助函数
│
├── assets/                 # 美术与音频资源（不进版本控制大文件放这里）
│   ├── sprites/            # 2D 精灵图
│   │   ├── characters/     # 角色立绘、动画帧
│   │   ├── ui/             # UI 图标、按钮
│   │   └── effects/        # 粒子、特效
│   ├── audio/              # 声音资源
│   │   ├── bgm/            # 背景音乐
│   │   └── sfx/            # 音效（脚步声、警报、击杀）
│   ├── fonts/              # 自定义字体
│   └── tiles/              # TileMap 地图瓦片集
│
├── docs/                   # 设计文档、技术笔记、决策记录
├── reference/              # 参考资料（截图、对比视频、灵感素材）
└── .github/                # CI / Issue 模板（可选）
```

---

## 快速开始

### 1. 安装 Godot

前往 [godotengine.org](https://godotengine.org/download/) 下载 Godot 4.5+（推荐 Standard 版本即可，体积小、够用）。

### 2. 在 Godot 中打开项目

1. 启动 Godot，点击右上角 **Import**
2. 浏览到 `~/Desktop/taikong-sha-game/` 目录
3. Godot 会自动生成 `project.godot` 和 `.godot/` 配置目录
4. 点击 **Import & Edit** 进入编辑器

### 3. 推荐编辑器配置

- **VSCode / Cursor**：作为 GDScript 外部编辑器（Godot 设置 → Editor Settings → External Editor）
- 安装插件：**Godot Tools**（VSCode）/ **godot-tools**（通用 LSP）

---

## 当前开发阶段

🚧 **Phase 0：项目初始化**（当前）

- [x] 目录结构搭建
- [ ] Godot 项目导入
- [ ] 单机 Demo：玩家在空白场景移动
- [ ] 第一个任务占位

---

## 开发路线图

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase 0 | 项目初始化 + 单机 Demo | 🚧 进行中 |
| Phase 1 | 本地双人原型（局域网互联） | ⏳ 待开始 |
| Phase 2 | 核心玩法（角色、任务、击杀、会议、投票） | ⏳ 待开始 |
| Phase 3 | 美术与音效打磨 | ⏳ 待开始 |
| Phase 4 | 上线准备（服务器、反作弊、移动端） | ⏳ 待开始 |

---

## 关键技术决策

| 维度 | 选择 | 理由 |
|------|------|------|
| 引擎 | Godot 4 | 2D 原生性能强、开源、导出微信小游戏方便 |
| 脚本 | GDScript | 与引擎集成最深、热重载、文档全 |
| 网络 | Godot 内置 ENet + `@rpc()` | 开箱即用，无需第三方 |
| 架构 | C/S（服务器权威） | 防作弊，匹配游戏机制 |
| 版本控制 | Git（建议接入） | 见 .gitignore |

---

## 参考资源

- [Godot 官方文档](https://docs.godotengine.org/en/stable/)
- [Godot 多人游戏教程](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
- [Godot Demo Projects](https://github.com/godotengine/godot-demo-projects) 中的 `networking/` 目录
