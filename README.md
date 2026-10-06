# MacClean

macOS 系统清理与分析工具。Swift 6 + SwiftUI 编写，"安全优先"：每一个删除动作都必须先通过统一的安全策略裁决。

## 功能

### 清理

| 功能 | 说明 |
|---|---|
| **缓存清理** Cache Cleanup | 按应用粒度列出用户缓存、用户日志、容器缓存、应用缓存；可排序、逐项勾选、Finder 定位 |
| **深度清理** Deep Cleanup | 系统缓存/日志、临时文件、Claude VM 镜像、Xcode 产物、容器缓存；附带系统维护动作 |
| **开发者缓存** Developer Caches | npm、pnpm、uv/pip、Puppeteer、Selenium、Codex 运行时、HuggingFace、Gradle、Maven、Cargo、rustup、CoreSimulator Caches |
| **废纸篓管理** Trash | 查看内容、一键清空（只删内容，绝不删除 `.Trash` 目录本身） |

### 工具

| 功能 | 说明 |
|---|---|
| **系统数据分析** System Data | 把 macOS「存储空间」里说不清的 System Data 拆成 22 个可枚举构成项，按「可清理 / 需确认 / 系统管理」分级 |
| **存储分析** Storage Analysis | 磁盘概况、大文件（按文件粒度）、最大目录、应用占用排行、Time Machine 本地快照、多卷/外置盘 |
| **应用卸载器** Uninstaller | 扫描 /Applications 与 ~/Applications，按 bundle id 精确匹配残留；应用与残留一律移入废纸篓 |
| **重复文件查找** Duplicate Finder | 按大小分桶 + 流式 SHA-256；每组默认保留最早一份，其余移入废纸篓 |
| **隐私清理** Privacy | 浏览历史、Cookie、缓存、最近使用项；路径为代码内白名单，浏览器运行中拒绝执行 |
| **启动项管理** Login Items | 展示 LaunchAgents / LaunchDaemons；用户级可启停或删除，系统级只读 |

### 智能与自动化

- **概览** Dashboard — 磁盘用量、缓存/废纸篓占比、清理历史、一键智能扫描
- **系统维护** — 刷新 DNS、清理 Time Machine 本地快照、删除失效模拟器、清空废纸篓、释放内存、重建 Spotlight 索引
- **菜单栏** — 常驻菜单栏查看磁盘用量与快捷操作
- **通知与自动清理** — 低磁盘空间系统通知（24 小时节流）；可选的每周自动清理（仅安全项、强制移入废纸篓）
- **设置** — 回收站模式、二次确认、默认勾选策略、临时文件保留天数、大文件阈值、排除列表、提醒与自动化

## 安全设计

所有删除动作都必须通过 `CleanupPolicy` 裁决：

1. **白名单优先** — 只有明确列出的目录子树才可能被删除；
2. **容器目录本身永不删除** — 例如 `~/Library/Caches`、`~/.Trash` 只能清理其内容；
3. **用户数据一律拒绝** — 浏览器 `Default` / `Profile *` 配置、书签、Cookie、钥匙串、应用包等；
4. **符号链接一律拒绝**，避免绕过白名单；
5. **SIP 保护路径一律拒绝**；
6. **失败不再被吞掉** — 被拒绝或执行失败的条目会带着原因回传到界面；
7. **特权操作批量执行** — 路径经策略校验后写入 0600 权限的 NUL 分隔清单，交给 root 的命令是常量字符串，不存在命令注入。

针对不同场景有独立的裁决函数，互不越权：

| 裁决 | 适用范围 |
|---|---|
| `evaluate` | 缓存/深度清理的常规路径 |
| `evaluateDeveloperCache` | 开发者缓存清单内的路径 |
| `evaluateAllowingUninstall` | 卸载器的应用包与其关联文件 |
| `evaluateUserSelectedFile` | 大文件/重复文件中用户显式选择的普通文件 |
| `evaluatePrivacy` | 隐私清理的硬编码白名单 |

扫描结果默认只勾选「安全」级别条目；删除前可开启二次确认；也可以在设置中改为「先移入废纸篓」（可恢复）。

### 破坏性操作的额外约束

| 功能 | 约束 |
|---|---|
| 缓存/深度清理 | 走 CleanupPolicy 白名单；需要 root 的项集中一次授权 |
| 应用卸载 | 只处理非 `com.apple.*` 应用；应用包与残留**只移入废纸篓** |
| 重复文件 | 只在用户标准文件夹内；只移入废纸篓；默认每组保留最早一份 |
| 隐私清理 | 路径来自代码内硬编码白名单；浏览器运行中则拒绝执行 |
| 启动项 | 系统级只读；用户级启停用 `launchctl`，删除走废纸篓 |
| 每周自动清理 | 默认关闭；开启后只清理 safe 级别、强制移入废纸篓，并写入清理历史 |
| 系统数据 | 「系统管理」类（诊断数据库、swap、临时目录）只展示，不提供删除 |

## 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- Apple Silicon 或 Intel Mac
- 建议授予「完全磁盘访问」权限（系统设置 → 隐私与安全性 → 完全磁盘访问），否则部分目录无法统计

## 构建

### 方式一：Xcode / xcodebuild（常规环境）

```bash
./build.sh            # 自动 xcodegen + xcodebuild，并生成 DMG
```

需要 Xcode 15+。安装了 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 时会自动从 `project.yml` 生成工程（含共享 Scheme）。

### 方式二：纯 swiftc（受限环境 / CI）

某些沙箱或 CI 环境无法写入 clang 的默认模块缓存目录（`$DARWIN_USER_CACHE_DIR/clang`，
即 `/var/folders/<xx>/<hash>/C/clang`），会导致 `xcodebuild` 在 `CreateBuildDescription`
阶段的 clang 探测直接失败。此时使用：

```bash
./tools/build-app.sh Release
```

它用 `swiftc -module-cache-path <工程内目录> -Xfrontend -disable-sandbox` 直接编译并组装
`build/restricted/MacClean.app`，完全不经过 xcodebuild。`build.sh` 在 xcodebuild 失败时也会自动回退到它。

### 打包与公证

> 磁盘映像创建（hdiutil / diskutil image create）在沙箱环境中会被系统拒绝，
> `build.sh` 检测到失败会跳过 DMG 并给出提示，App 产物不受影响。请在普通终端中生成 DMG。

```bash
APPLE_ID="you@example.com" TEAM_ID="YOURTEAMID" ./package.sh --notarize
```

## 测试

逻辑测试不依赖 XCTest，直接编译运行（当前 37 项：安全策略、tmutil 解析、格式化、进程执行与超时、卸载器路径、重复文件哈希、开发者缓存清单、系统数据构成项等）：

```bash
./tools/run-tests.sh
```

也可以通过 Xcode 的 `MacCleanTests` scheme 构建运行。CI 配置见 `.github/workflows/ci.yml`。

## 项目结构

```
MacClean/
├── MacClean/
│   ├── Models/        # 扫描项、分类、结果、设置选项、维护动作、卸载/重复/隐私/启动项/卷/系统数据模型
│   ├── Services/      # CleanupPolicy（安全策略）、Scan/Cleanup/Privilege/Maintenance/Diagnostic/
│   │                  # AppUninstaller/DuplicateFinder/Privacy/LoginItem/SystemData/StorageStore/Notification
│   ├── ViewModels/    # 各页面的 @Observable 视图模型
│   ├── Views/         # SwiftUI 视图（Dashboard/Cleanup/DeepClean/Diagnostics/Trash/Uninstaller/
│   │                  # Duplicates/Privacy/LoginItems/SystemData/Settings/MenuBar/Components）
│   ├── Extensions/    # FileManager / Process / View+Glass（Liquid Glass 适配）/ 主题
│   ├── Utilities/     # AppLog（os.Logger）、AppConstants、格式化
│   └── Resources/     # 图标、zh-Hans 本地化
├── MacCleanTests/     # 轻量测试运行器（37 项）
├── tools/             # build-app.sh / run-tests.sh
└── project.yml        # XcodeGen 工程描述
```

## 视觉风格

- macOS 26 (Tahoe) 及以上：使用系统 **Liquid Glass** —— 卡片/面板走 `glassEffect`，主/次按钮走 `.glassProminent` / `.glass`，窗口使用渐变底色提供折射层次
- macOS 14 / 15：同一套代码通过 `@available` 自动回退到实心卡片 + 细描边样式
- 玻璃只用在**容器**上，不给每一行加玻璃，避免大量离屏合成带来的渲染开销
- 适配层集中在 `View+Glass.swift`（`glassPanel` / `glassProminentButton` / `glassButton` / `appWindowBackground`）

## 技术栈

- Swift 6（严格并发检查）、SwiftUI + Observation
- 最低部署目标 macOS 14.0
- 扫描/清理全部运行在 detached 任务中，支持真正的取消与增量进度
- 失败与拒绝条目显式建模（`CleanupSummary.failures`）并回传界面

## 已知限制与后续方向

- 本地化目前覆盖界面框架文案（zh-Hans）；正文为中文源语言，英文环境下会中英混排
- 隐私清理暂未覆盖 Firefox（其 profile 目录名随机，需另外解析 `profiles.ini`）
- 全局/系统级启动项出于安全考虑只读，需在「系统设置 → 通用 → 登录项」中管理
- iOS 模拟器运行时（动辄十几 GB）目前只做展示，删除请在 Xcode → Settings → Platforms 操作
- 系统通知需要用户授权；未授权时低磁盘提醒会被静默跳过
- `/System/Library/Caches` 受 SIP 保护，即使已授权也可能无法删除
- Liquid Glass 仅在 macOS 26+ 生效，低版本使用回退样式
- 菜单栏/DMG 等需要图形会话与磁盘映像能力的操作在沙箱环境中不可用

### 路线图

- 模拟器运行时管理（列出 + 调用 `simctl runtime delete`）
- Firefox 隐私清理（解析 `profiles.ini`）
- 英文 `en.lproj` 完整本地化
- 清理策略的导入/导出与可配置白名单