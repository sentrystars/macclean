# MacClean

macOS 系统清理工具，帮助您分析磁盘使用情况、清理缓存和垃圾文件，释放存储空间。

## 功能

- **仪表盘** — 概览磁盘用量，包括总容量、已用空间、系统数据、缓存和废纸篓
- **垃圾清理** — 扫描并清空废纸篓
- **缓存清理** — 识别并清理系统与用户缓存
- **深度清理** — 清理 Time Machine 本地快照、编译缓存等系统数据
- **存储分析** — 诊断大文件和应用存储占用
- **智能扫描** — 一键扫描可清理项

## 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- Apple Silicon 或 Intel Mac

## 构建

### 前置条件

- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（可选，用于从 `project.yml` 生成项目文件）

### 构建步骤

```bash
# 构建应用并生成 DMG
./build.sh
```

构建产物位于 `build/` 目录：
- `MacClean.app` — 应用
- `MacClean.dmg` — 分发包

### 分发包

```bash
# 构建并打包
./package.sh

# 构建并公证（需要配置 Apple ID）
APPLE_ID="you@example.com" TEAM_ID="YOURTEAMID" ./package.sh --notarize
```

## 项目结构

```
MacClean/
├── MacClean/                 # 主应用源码
│   ├── MacCleanApp.swift     # 应用入口
│   ├── ContentView.swift     # 主视图
│   ├── Extensions/           # Swift 扩展
│   ├── Models/               # 数据模型
│   ├── Resources/            # 资源文件（图标等）
│   ├── Services/             # 业务服务
│   ├── Utilities/            # 工具类
│   ├── ViewModels/           # 视图模型
│   └── Views/                # 视图层
├── HelperTool/               # 特权辅助工具
├── build.sh                  # 构建脚本
├── package.sh                # 打包脚本
└── project.yml               # XcodeGen 项目配置
```

## 技术栈

- **语言**: Swift 6
- **框架**: SwiftUI, Observation
- **最低部署目标**: macOS 14.0
- **并发**: Swift Structured Concurrency (async/await)
- **项目生成**: XcodeGen（可选）
