# ADR 016：Window Scene 产品与技术设计 Spike

- 状态：Accepted（Spike 设计；尚未实现）
- 日期：2026-08-26
- 基于：已审查提交 `34eff1f`（012–015 代码链）
- 范围：Window Scene 的最小领域模型、拓扑、匹配、回执和未来实现边界

## 背景

Line 已有 first-class grid、多显示器布局、Window Resize Execution 和 `Prepared Resize`。Window Scene 需要把多个应用窗口的相对布局组合成可重复应用的命名工作上下文，但不能变成第二套窗口写入引擎、持续 tiling manager 或 macOS Spaces 控制器。

Window 身份和显示器身份都存在风险：标题可能是文档名，应用可有多个窗口，`CGDirectDisplayID` 不是永久用户身份；Accessibility 权限和全屏/Stage Manager 状态也会在运行时变化。因此，Spike 选择安全失败和可解释的部分成功，而不是猜测或伪造原子事务。

## 决定

### 1. Scene 是 local-only、一次性 apply 的版本化文档

Scene Document 使用不透明 Scene ID、名称、schema version、可选 UTC 时间字段、有序 placements 和明确的 apply policy。第一版设计使用单一版本化 JSON 文件 `~/Library/Application Support/Line/Window Scenes/scenes.json`，配合同目录临时文件原子替换和一个 `.bak` 备份；不散落在 Defaults key，不使用 iCloud。

Scene 只存 bundle identifier、经过安全约束的非内容性窗口线索、相对显示器拓扑引用、相对 visible-frame 布局和可选 action/grid provenance。绝不存标题、文档名、完整路径、完整 URL、剪贴板、文档内容、由这些内容派生的 hash、PID、CGWindowID、Space ID 或应用启动参数。

Schema 必须逐版本迁移；未知新版本拒绝并保留原文件，损坏 current 尝试 backup，均损坏则 quarantine 并以空库启动。迁移和诊断都不能从旧数据猜测或恢复敏感字段。

**理由**：这与现有 local-first、无 iCloud entitlement 和隐私约束一致；集中版本化文件可审计、备份和恢复，避免继续增加无版本 Defaults patch。一次性 apply 保持 Line 当前产品边界。

### 2. 窗口匹配只允许可验证的唯一候选

bundle identifier 是强应用身份。运行时仅当应用存在且候选窗口唯一时自动匹配；如果存在安全校验过的 accessibility identifier，则可在其唯一精确匹配时使用。role/subrole 只作辅助线索。同一应用多窗口在缺少唯一、非内容性线索，或线索冲突时，不得按标题、路径、最近使用、创建顺序、坐标相似度或枚举顺序猜测。必须进入 `needsUserChoice`；没有交互入口时跳过并报告 `noMatchingWindow` + `ambiguousCandidates`。

应用未运行时永不自动启动。权限不足、不可调整窗口、全屏/系统管理窗口和无法唯一解析的拓扑各自产生明确 placement reason。每个 placement 独立处理；已有成功后其他失败的 Scene 级状态为 `partiallyApplied`，不能包装为事务成功。

**理由**：同一 bundle 的窗口无法在不使用内容性信息的情况下稳定区分时，跳过比误移动私密或错误窗口更安全。部分成功与现有 Accessibility 的现实失败模式相符。

### 3. 显示器使用相对拓扑，不把 display ID 当永久身份

capture 保存 display role、虚拟桌面归一化中心、邻接签名和粗粒度 aspect/scale bucket；不保存 `CGDirectDisplayID`。apply 按唯一精确拓扑 → 唯一相对拓扑迁移 → 用户确认的当前屏回退 → 跳过的顺序处理。分辨率、scale、排列变化可在唯一映射时迁移到当前 visible frame；移除引用屏、多重合理映射、无法解析的多屏情况禁止自动猜测。Stage Manager 和全屏不是 Scene 身份，Line 不切换/创建 Spaces，也不自动退出全屏。

**理由**：显示器硬件 ID 的持久性不足；拓扑关系和相对布局可以跨常见几何变化重建，但歧义必须暴露给用户。未有确认 UI 前，降级情况只能跳过。

### 4. 真实执行必须复用既有 execution boundary

未来 Scene executor 先获得权限/拓扑快照，匹配 placement，生成 `Prepared Resize`，再交给 Window Resize Execution / WindowEngine 的既有写入边界。Scene 不直接调用 AX、不实现第二套 frame calculator、不持续监听或回滚。此 Spike 不实现 executor、UI、菜单、keybind 或 URL command。

SceneApplyReceipt 至少包含 Scene/placement ID、schema version、总体状态、拓扑解析方式、计数、时间和脱敏的 placement reason。总体状态包含 `fullyApplied`、`partiallyApplied`、`noMatchingWindow`、`applicationNotRunning`、`permissionDenied`、`topologyMismatch`、`windowNotAdjustable`、`cancelled`、`unknownFailure`。回执和日志只可暴露 bundle identifier、UUID、状态、错误码和候选数量，不暴露标题、路径、URL、AX dump 或错误原文。

**理由**：复用 Prepared Resize 保持架构单一；placement 级回执使权限、拓扑和窗口能力失败可诊断且不误导用户。

### 5. 第一版不接入 URL/keybind，未来入口必须版本化

第一版不创建 Scene 设置开关、菜单项、keybind 或 URL command。未来入口只能引用本地 Scene ID 和明确版本化的 apply policy，复用同一 executor/receipt；不得把 Scene JSON、布局、拓扑或窗口身份塞入现有 action URL 参数。由于 `line://` 无调用方认证，未来接入需另行评审确认、权限和错误披露。

**理由**：没有歧义选择和拓扑确认 UX 时，公开入口会把危险 fallback 变成不可逆的自动行为；保持现有 URL action contract 不变可避免扩大本地自动化的信息面。

## Alternatives / Rejected options

| 方案 | 决定 | 原因 |
| --- | --- | --- |
| 直接持久化 PID/CGWindowID/CG display ID | 拒绝 | 进程、窗口和显示器 ID 不能作为跨重启/拓扑变化的用户身份，且会把运行时对象泄露到磁盘 |
| 按窗口标题、完整路径、URL 或内容 hash 匹配 | 拒绝 | 泄露敏感内容且稳定性差；违反隐私边界 |
| 同应用多窗口按枚举顺序/最近使用/坐标猜测 | 拒绝 | 不可验证，可能移动错误窗口；v1 必须用户选择或跳过 |
| 未运行应用由 Scene 自动启动 | 拒绝 | 扩大产品权限和生命周期，不是窗口排列职责 |
| 把 Scene 存成多个 Defaults key | 拒绝 | 无集中 schema、迁移、备份和损坏恢复边界，容易形成散落 patch |
| 将 Scene 当作 macOS Space 并恢复 Space | 拒绝 | Spaces 不是 Line 可稳定控制的事务系统；Scene 独立于 Spaces |
| apply 前后全量回滚、跨应用原子事务 | 拒绝 | Accessibility 写入不可可靠事务化；会制造虚假的原子性保证。采用逐 placement best-effort receipt |
| 持续监听并自动重排 | 拒绝 | 超出当前一次性 window manager 边界，接近持续 tiling |
| 第一版加入 URL/keybind | 延后 | 需要独立确认 UX、权限与本地无认证自动化风险评审；不应把未验证设计暴露为入口 |
| 创建新的 Scene 窗口写入引擎 | 拒绝 | 与 Window Resize Execution/Prepared Resize 重复，增加行为分叉和测试面 |

## 后果

正面：数据边界清晰，跨显示器变化有可审计的降级策略；错误窗口和敏感内容不会因匹配而持久化；实现者可以先测试纯值模型、拓扑和 receipt，不需要 Accessibility 权限。

代价：同一应用多窗口经常需要用户选择；引用屏移除时可能跳过而不是自动搬迁；没有 UI 前无法实际解决歧义；部分成功不可回滚。未来 MVP 必须先定义 capture 和确认 UX，再考虑用户可见入口。

## 后续实施边界

1. 纯 Codable/Equatable Scene 值模型、schema 校验和 migration fixtures。
2. 纯匹配、拓扑解析和总体 receipt policy；覆盖主屏改变、增减屏、scale/分辨率、排列、Stage Manager、全屏。
3. local-only repository 的原子写入、backup/recovery/quarantine。
4. 通过 Prepared Resize 接入执行 adapter，逐 placement best-effort。
5. 独立定义 capture、歧义选择、拓扑确认 UI；之后才评审菜单/设置、keybind 或 versioned URL contract。

本 ADR 及 [`WINDOW_SCENES.md`](../WINDOW_SCENES.md) 是设计 spike，不构成上述实现已经存在的声明。
