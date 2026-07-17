# AGENTS.md

本文件说明自动化编码 Agent 在 Line 仓库中的工作约束。始终使用中文与用户交互。

## 项目概览

Line 是一个使用 Swift、SwiftUI 和 AppKit 构建的 macOS 26 窗口管理器，fork 自 [MrKai77/Loop](https://github.com/MrKai77/Loop) 的 commit `9661bcb`。应用需要辅助功能权限，通过公开辅助功能 API 管理窗口，并在可用时动态加载部分 SkyLight 私有符号。

## 常用命令

```bash
xcodebuild -resolvePackageDependencies -project Line.xcodeproj -scheme Line
xcodebuild -project Line.xcodeproj -scheme Line -configuration Debug CODE_SIGNING_ALLOWED=NO build
# Required CI path (skip Accessibility e2e):
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' \
  -skip-testing:LineTests/EndToEndIntegrationTests
# Or: make test-unit / make test-coverage
xcodebuild -project Line.xcodeproj -scheme "Line (GH ACTIONS)" -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
ruby scripts/release/update_appcast_test.rb
mint run swiftformat --lint . --reporter github-actions-log
```

本地调试使用 `Line` scheme。CI 的必过 job 是 unit tests + 计算器覆盖率下限；`EndToEndIntegrationTests` 单独 job，无权限时用 `XCTSkip`。发布配置检查使用 `Line (GH ACTIONS)`。

公开发版使用 **Publish** 工作流（仅 `workflow_dispatch` on `main`）：semantic-release 按 Conventional Commits 计算 `vX.Y.Z`，产物为 `Line-X.Y.Z.zip` / `Line-X.Y.Z.dmg` / `SHA256SUMS.txt`（无 Developer ID），正式 GitHub Release，再用 `SPARKLE_PRIVATE_KEY` 签 zip 并开 `automation/appcast-vX.Y.Z` PR。Sparkle 公钥在 `Line/Config.xcconfig`；`Config` 里的 VERSION 可为 `0.0.0`，打包时注入版本。Node 发版依赖见根目录 `package.json` / `package-lock.json`（仅 tooling）。

## 现行架构

应用入口位于 `Line/App/LineApp.swift` 和 `Line/App/AppDelegate.swift`。

`LineCoordinator` 是窗口管理的顶层协调器，负责应用级编排，并把具体职责交给：

- `TriggerCoordinator`，处理键盘和鼠标触发器。
- `GridModeCoordinator`，处理网格选择与覆盖层。
- `SessionManager`，管理当前窗口操作会话和 `ResizeContext`。

窗口操作模型位于 `Line/Window Management/Window Action/`。帧计算应放在可独立测试的 calculator 或 policy 类型中，窗口写入由 `WindowEngine` 和辅助功能封装完成。

设置界面位于 `Line/Settings Window/`，持久化键位于 `Line/Extensions/Defaults+Extensions.swift` 及相关扩展。当前构建没有 iCloud entitlement，所有设置按本地数据处理。

Sparkle 是唯一受支持的更新器。应用侧封装位于 `Line/Updater/SparkleUpdater.swift`，更新源是仓库根目录的 `appcast.xml`。不要重新引入自定义下载器、特权安装 Helper 或第二套版本比较逻辑。

SkyLight 调用必须通过 `Line/Private APIs/` 中的动态符号加载层。每个调用点都要处理符号缺失，并保留安全降级路径。

## 依赖

主要 SwiftPM 依赖包括 Defaults、Luminare、Scribe 和 Sparkle。Luminare 与 Scribe 使用精确 revision。升级依赖时必须检查许可证、安全公告、macOS 26 兼容性，并提交更新后的 `Package.resolved`。

## 修改约束

- AppKit、窗口状态和 UI 生命周期代码保持在主 Actor。
- 优先修改现有深层模块，不为单一调用增加无意义的 manager、service 或 wrapper。
- 修复行为缺陷时先在稳定边界补回归测试，再修改实现。
- 不在日志中记录窗口标题、完整路径、完整 URL、剪贴板内容或文档内容。
- 新增用户可见文案时同步更新 `Line/Localizable.xcstrings`。
- 私有 API、辅助功能、URL Scheme、更新、签名和 entitlement 修改必须说明安全边界。
- 不提交证书、私钥、token、provisioning profile、keychain、DerivedData、归档产物或本地计划文档。
- 不使用 `git reset --hard`、`git checkout --` 等命令覆盖用户改动。
- 文件搜索优先使用 `rg` 和 `rg --files`，文件修改使用 `apply_patch`。

## 测试要求

小范围修改先运行对应测试，阶段性运行 Debug 构建，结束前运行完整测试和 Release 配置的无签名构建。涉及真实窗口的功能还要检查多显示器、全屏、Stage Manager、无辅助功能权限和私有符号不可用的情况。

纯计算、解析、迁移和状态策略应使用单元测试。必须操作真实窗口的代码通过窄协议或 policy 类型隔离，避免让大部分测试依赖辅助功能权限。

## 文档与开源治理

公开工程文档位于根目录和 `docs/`。架构变化同步更新 `docs/ARCHITECTURE.md`，发布链路变化同步更新 `docs/RELEASES.md`，网络和数据处理变化同步更新 `docs/PRIVACY.md` 与 `Line/InternetAccessPolicy.plist`。

不要把临时审计报告、实施计划、调试日志或本机绝对路径提交到仓库。需要保留的长期决策应整理成稳定的架构或发布文档。
