# MacClean

macOS 系统清理工具：分析磁盘占用、按应用粒度清理缓存与垃圾文件、清理系统数据与开发缓存。

## 功能

- **概览（Dashboard）** — 磁盘用量、缓存/废纸篓占比、清理历史、一键智能扫描
- **缓存清理（Cache Cleanup）** — 按应用粒度列出用户缓存、日志、容器缓存、应用缓存，可排序、逐项勾选、Finder 定位
- **深度清理（Deep Cleanup）** — 系统缓存/日志、临时文件、Claude VM 镜像、Xcode 产物、容器缓存
- **系统维护** — 刷新 DNS、清理 Time Machine 本地快照、删除失效模拟器、清空废纸篓、释放内存、重建 Spotlight 索引
- **存储分析（Storage Analysis）** — 磁盘概况、大文件（按文件粒度）、最大目录、应用占用排行、本地快照管理、多卷/外置盘
- **系统数据分析（System Data）** — 拆解 macOS「存储空间」里说不清的 System Data：模拟器运行时、开发缓存、应用支持数据、系统数据库等，按「可清理 / 需确认 / 系统管理」分级，并给出一键定位
- **开发者缓存** — npm / pnpm / uv / pip / Puppeteer / Gradle / Maven / Cargo / rustup / CoreSimulator Caches，接入安全策略后一键清理
- **废纸篓管理** — 查看内容、清空
- **应用卸载器** — 列出 /Applications 与 ~/Applications，按 bundle id 精确匹配残留文件，应用与残留**一律移入废纸篓**
- **重复文件查找** — 按大小分桶 + 流式 SHA-256 判定，每组保留最早一份，其余移入废纸篓
- **隐私清理** — 浏览历史、Cookie、最近使用项；路径白名单硬编码，清理前校验浏览器是否已退出
- **启动项管理** — 展示 LaunchAgents / LaunchDaemons，用户级启动项可启停或删除，系统级只读
- **菜单栏** — 常驻菜单栏查看磁盘用量与快捷操作
- **通知与自动化** — 低磁盘空间系统通知；可选的每周自动清理（仅安全项，强制移入废纸篓）
- **多卷支持** — 存储分析可切换系统盘/外置盘作为分析范围
- **设置** — 回收站模式、二次确认、默认勾选策略、临时文件保留天数、大文件阈值、排除列表、提醒与自动化

## 安全设计

所有删除动作都必须通过 `CleanupPolicy» 裁决：

1. **白名单优先** — 只有明确列出的目录子树才可能被删除；
2. **容器目录本身永不删除** — 例如 `~/Library/Caches»、`~/.Trash» 只能清理其内容；
3. **用户数据一律拒绝** — 浏览器 `Default»/`Profile *» 配置、书签、Cookie、钥匙串、应用包等；
4. **符号链接一律拒绝**，避免绕过白名单；
5. **SIP 保护路径一律拒绝**；
6. **失败不再被吞掉** — 被拒绝或执行失败的条目会带着原因回传到界面；
7. **特权操作批量执行** — 路径经策略校验后写入 0600 权限的 NUL 分隔清单，交给 root 的命令是常量字符串，不存在命令注入。

扫描结果默认只勾选「安全」级别条目；删除前可开启二次确认；也可以在设置中改为「先移入废纸篓」（可恢复）。

## 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- Apple Silicon 或 Intel Mac
- 建议授予「完全磁盘访问」权限（系统设置 → 隐私与安全性 → 完全磁盘访问），否则部分目录无法统计

## 构建

### 方式一：Xcode / xcodebuild（常规环境）

```bash
./build.sh            # 自动 xcodegen + xcodebuild，并生成 DMG
```

需要 Xcode 15+。安装了 XcodeGen 时会自动从 `project.yml» 生成工程（含共享 Scheme）。

### 方式二：纯 swiftc（受限环境 / CI）

某些沙箱或 CI 环境无法写入 clang 的默认模块缓存目录（`$DARWIN_USER_CACHE_DIR/clang»，
即 `/var/folders/<xx>/<hash>/C/clang»），会导致 `xcodebuild» 在 `CreateBuildDescription»
阶段的 clang 探测直接失败。此时使用：

```bash
./tools/build-app.sh Release
```

它用 `swiftc -module-cache-path <工程内目录> -Xfrontend -disable-sandbox» 直接编译并组装
`build/restricted/MacClean.app»，完全不经过 xcodebuild。`build.sh» 在 xcodebuild 失败时也会自动回退到它。

### 打包与公证

> 注意：磁盘映像创建（hdiutil / diskutil image create）在沙箱环境中会被系统拒绝，
> `build.sh` 检测到失败会跳过 DMG 并给出提示，App 产物不受影响。请在普通终端中生成 DMG。

```bash
APPLE_ID="you@example.com" TEAM_ID="YOURTEAMID" ./package.sh --notarize
```

## 测试

逻辑测试（安全策略、tmutil 解析、格式化、进程执行与超时）不依赖 XCTest，直接编译运行：

```bash
./tools/run-tests.sh
```

也可以通过 Xcode 的 `MacCleanTests» scheme 构建运行。CI 配置见 `.github/workflows/ci.yml»。

## 项目结构

```
MacClean/
├── MacClean/
│   ├── Models/        # 数据模型（扫描项、分类、结果、设置选项、维护动作）
│   ├── Services/      # CleanupPolicy（安全策略）、Scan/Cleanup/Privilege/Maintenance/Diagnostic
│   ├── ViewModels/    # 各页面的 @Observable 视图模型
│   ├── Views/         # SwiftUI 视图
│   ├── Extensions/    # FileManager / Process 扩展
│   ├── Utilities/     # 日志、常量、格式化
│   └── Resources/     # 图标、本地化
├── MacCleanTests/     # 轻量测试运行器
├── tools/             # build-app.sh / run-tests.sh
└── project.yml        # XcodeGen 工程描述
```

## 视觉风格

- macOS 26 (Tahoe) 及以上：使用系统 **Liquid Glass**——卡片/面板走 `glassEffect`，主/次按钮走 `.glassProminent` / `.glass`，窗口使用渐变底色提供折射层次
- macOS 14 / 15：同一套代码通过 `@available` 自动回退到实心卡片 + 细描边样式
- 玻璃只用在**容器**上，不给每一行加玻璃，避免大量离屏合成带来的渲染开销

## 技术栈

- Swift 6（严格并发检查）、SwiftUI + Observation
- 最低部署目标 macOS 14.0
- 扫描/清理全部运行在 detached 任务中，支持真正的取消与增量进度

## 已知限制与后续方向

- 本地化目前覆盖界面框架文案（zh-Hans）；正文为中文源语言，英文环境下会中英混排
- 未实现：应用卸载器、重复文件查找、隐私清理（浏览器历史/Cookie）、启动项管理
- 未实现：菜单栏常驻、磁盘告警通知、定时自动清理
- 存储分析目前只统计系统盘（home 所在卷），未支持外置盘
- `/Library/Caches»、`/System/Library/Caches» 等系统路径需要管理员授权；`/System/Library/Caches»
  受 SIP 保护，即使授权也可能无法删除