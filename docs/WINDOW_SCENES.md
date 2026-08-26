# Window Scene 设计规范

状态：Spike 设计（未实现）
版本：MVP 设计基线 v1
日期：2026-08-26

## 1. 定义与产品边界

**Window Scene** 是一个命名的、一次性可应用的窗口排列：它描述多个应用窗口在当前可用显示器上的相对位置，独立于 macOS Spaces。Scene 不是 Space、不是持续 tiling，也不是应用启动器。

第一版的约束：

- local-only；不使用 iCloud、网络同步或账号。
- apply 是一次性操作；不观察窗口变化，也不持续接管窗口。
- 不自动启动未运行的应用，不退出全屏，不切换或创建 Spaces。
- 不承诺原子性或回滚。每个 placement 独立尝试，允许部分成功并必须报告。
- 写入窗口必须复用 Window Resize Execution / Prepared Resize 和现有 WindowEngine 执行边界；Scene 不直接调用 AX，也不创建第二套帧计算或写入引擎。
- 本 Spike 只定义模型、决策和未来执行契约；不实现设置 UI、菜单、keybind、URL command、持久化代码或 apply executor。

### 1.1 术语

- **Scene Document**：可保存的 Scene 根记录。
- **Scene Placement**：Scene 中一个目标应用窗口及其显示器布局。
- **Display Topology Reference**：不依赖 CG display ID 的显示器拓扑引用。
- **Scene Apply Receipt**：一次 apply 的机器可读、脱敏结果。
- **稳定字段**：允许落盘并参与跨进程/重启解释的字段。
- **运行时字段**：只在一次 capture/apply 中存在，不能写入 Scene 文件。

## 2. 最小领域模型

以下是实现者应遵守的值模型；类型名是设计名，不要求本 Spike 添加 Swift 类型。

```text
SceneDocument {
  id: UUID                         // 稳定字段；不可因重命名改变
  name: String                     // 稳定字段；用户可修改，非空且受长度限制
  schemaVersion: Int               // 稳定字段；当前设计版本为 1
  createdAt: Instant?              // 稳定字段；可选，便于导入旧记录
  updatedAt: Instant?              // 稳定字段；可选，写入时更新
  placements: [ScenePlacement]     // 稳定字段；顺序是确定的 apply 顺序
  applyPolicy: SceneApplyPolicy    // 稳定字段；默认 bestEffort + neverLaunch
}

ScenePlacement {
  id: UUID                         // 稳定字段；用于回执，不是窗口 ID
  application: ApplicationIdentity
  windowHint: WindowIdentityHint   // 仅非敏感线索；可为空
  display: DisplayTopologyReference
  layout: RelativeLayout
  source: LayoutSource?            // action/grid provenance，可为空
}

ApplicationIdentity {
  bundleIdentifier: String         // 稳定字段；唯一必需应用身份
}

WindowIdentityHint {
  accessibilityIdentifier: String? // 仅在 AX 提供且不含内容时保存
  role: String?                    // AX role，例如 AXStandardWindow
  subrole: String?                 // AX subrole，例如 AXDialog
  requiresUserChoiceIfAmbiguous: Bool // v1 固定为 true
}

DisplayTopologyReference {
  role: DisplayRole                // main / internal / external / unspecified
  normalizedCenter: Point2D        // 相对于 capture 时虚拟桌面的 [0,1] 中心
  adjacency: AdjacencySignature    // 与 main/相邻显示器的相对关系
  aspectRatioBucket: AspectRatioBucket?
  scaleBucket: ScaleBucket?
}

RelativeLayout {
  x: Decimal                      // [0,1]，相对目标显示器 visible frame
  y: Decimal                      // [0,1]
  width: Decimal                  // (0,1]
  height: Decimal                 // (0,1]
}

LayoutSource =
  standardAction(identifier: String)
  | customAction(identifier: String)
  | grid(columns: Int, rows: Int, column: Int, row: Int)
  | capturedFrame

SceneApplyPolicy {
  matching: safeOnly | allowUserConfirmedFallback
  launch: neverLaunch             // v1 唯一值
  topology: autoRelativeWhenUnique | requireConfirmationOnDegraded
}
```

### 2.1 字段规则

- Scene ID 和 placement ID 是不透明 UUID。它们不是 `CGWindowID`、PID，也不允许被当作窗口身份使用。
- `name` 只用于用户组织 Scene，不参与窗口匹配；实现时应限制为非空、有限长度字符串，并拒绝控制字符。
- `Instant` 使用 UTC、可排序的 Codable 表示。时间字段不是匹配依据；如果实现选择省略时间，迁移不得伪造时间语义。
- `bundleIdentifier` 是唯一强身份。它可以用于查找应用，但不能推出应用是否正在运行。
- `accessibilityIdentifier` 只有在系统明确提供、且经过内容安全校验时才可选保存。窗口标题、文档名、完整路径、完整 URL、剪贴板、文档内容以及由这些内容派生的 hash 均禁止保存。
- role/subrole 是匹配辅助信息，不是秘密，也不是充分身份。`requiresUserChoiceIfAmbiguous` 固定为 `true`，防止未来实现把线索升级成猜测。
- `RelativeLayout` 永远相对于目标显示器当前的 visible frame，而不是屏幕坐标、像素坐标或 Spaces 坐标。capture 时须验证范围与非零尺寸；越界、重复或缺少 placement 的 Scene 不可应用。
- `source` 是可解释性/重建信息，不是第二套执行描述。`capturedFrame` 只表示由当前窗口帧捕获。incremental、focus、screen-switch、stash、minimize 等没有确定静态目标帧的 WindowAction 不可作为 Scene placement 的 source。
- `standardAction`/`customAction` identifier 必须来自未来版本化的 Line action catalog；不得把任意用户文本当作可执行 action。若 source 无法解析，仍可在布局安全且经用户选择的情况下使用已保存 `RelativeLayout`，并在回执报告 provenance unsupported。
- 第一版不保存应用启动参数、窗口标题、窗口列表、Space、完整显示器 ID 或当前窗口的 PID/CGWindowID。

### 2.2 同一应用的多个窗口

安全优先级如下：

1. 运行时若应用只有一个符合基本 AX 能力和 role/subrole 线索的候选窗口，才可自动匹配。
2. 若 placement 带有可验证的、非内容性的 accessibility identifier，且只有一个候选精确匹配，可匹配该窗口。
3. 同一 bundle 有多个候选，或线索缺失/冲突时，**不得**按标题、最近使用顺序、创建顺序、窗口坐标相似度或枚举顺序猜测。该 placement 必须进入 `needsUserChoice`；若当前入口没有选择界面，则跳过并报告 `noMatchingWindow`，附带 `ambiguousCandidates` 原因。
4. 用户选择只属于该次运行时决策，不能把 PID、CGWindowID 或标题写回 Scene。未来 UI 可以把选择绑定到本次运行的对象，但重启后必须重新验证。

因此，v1 可以保存同一应用的多个 placement，但只有在运行时候选身份可安全区分时才 apply；不能安全区分时宁可跳过。这是产品可预期的限制，不是待实现的隐式 fallback。

### 2.3 运行时模型与边界

实现层可在内存中持有 `RunningApplication`、PID、CGWindowID、当前 `Window`、当前 `NSScreen`、权限状态、候选列表和 Prepared Resize。这些都是运行时字段：

- 不编码进 Scene Document；
- 不写 Defaults、文件、日志或 URL 响应；
- 权限撤销、应用退出或 apply 结束后丢弃；
- 通过 Window Resize Execution 生成目标帧，再交给既有执行边界。

## 3. 显示器拓扑策略

### 3.1 Capture 表示

capture 时把可用显示器看作带属性的图：节点是当前 `NSScreen`，边表示主屏和 left/right/top/bottom 的相对邻接关系。保存：

- 主屏/内置/外接的**角色**，不是永久硬件身份；
- 每个节点在 capture 虚拟桌面包围盒中的归一化中心；
- 邻接签名；
- 粗粒度宽高比和 scale bucket，仅用于消歧，不用于身份确认。

不保存 `CGDirectDisplayID`。display ID 可作为本次运行的临时索引，但不能跨重启或机器配置变化匹配。

### 3.2 Apply 优先级

对每个 saved display reference，按以下顺序选择**唯一**目标：

1. **精确拓扑匹配**：主屏角色、邻接关系和显示器数量一致，且节点特征在容差内唯一。
2. **相对拓扑迁移**：允许逻辑分辨率、物理分辨率、scale 或 safe/visible frame 变化；用主屏锚点、邻接关系和归一化中心映射。加入/移除不相关显示器时，只要映射仍唯一，可忽略额外节点。
3. **当前屏回退**：仅在 `allowUserConfirmedFallback` 且用户明确确认时允许；多显示器下不能自动选择。`safeOnly` 永不执行此回退。
4. **跳过**：无唯一映射、拓扑不满足策略、目标屏不可用或确认被拒绝时跳过。

映射完成后，使用目标显示器当前 visible frame 将 RelativeLayout 转换为 frame。resolution/scale 变化本身不是错误；如果导致布局超出可用区域，裁剪或最小尺寸调整必须由现有 Window Resize Execution / WindowFrameResolver 决定，并在 placement 回执标为 degraded，而不是静默宣称 exact。

### 3.3 拓扑决策矩阵

| 输入条件 | 策略 | 自动结果 | 用户结果/回执 |
| --- | --- | --- | --- |
| 显示器数量、main 角色、邻接关系均一致 | 精确匹配 | 使用唯一对应屏；按当前 visible frame 重算帧 | 无确认；`exactTopology` |
| 分辨率或 scale 改变，但角色/邻接唯一 | 相对迁移 | 归一化布局迁移到当前 visible frame | 无确认；`relativeMigration` |
| 主屏改变，但旧 main 对应的新节点可由角色和图关系唯一确定 | 相对迁移 | 以新的 main 重新解图 | 无确认；`relativeMigration`，不使用旧 ID |
| 增加一块不改变原有图关系的屏幕 | 相对迁移 | 忽略额外屏；唯一映射的 placement 继续 | 可选提示；`relativeMigration` |
| 移除 Scene 引用的屏幕 | 安全匹配失败 | 不自动搬到另一块屏 | `topologyMismatch`；确认入口可选 `currentScreenFallback`，否则跳过 |
| 排列改变但图关系仍给出唯一映射 | 相对迁移 | 依邻接和归一化中心迁移 | `relativeMigration` |
| 排列改变且存在多个同样合理映射 | 禁止猜测 | 不 apply 该 placement | `topologyMismatch` / `ambiguousTopology`；要求确认或跳过 |
| 只有一块当前可用屏，Scene 引用无法解析 | 仅在用户确认策略下 | 不自动回退；确认后可映射当前屏 | `topologyMismatch` 或确认后的 `currentScreenFallback` |
| 多块当前可用屏，引用无法解析 | 禁止自动当前屏回退 | 不 apply | `topologyMismatch`；用户选择目标屏或跳过 |
| Stage Manager 改变可见/usable frame | 不读取或修改 Space 状态 | 使用当前 visible frame；隐藏/不可访问窗口不猜测 | 可迁移则 `relativeMigration`，否则 `topologyMismatch`/`noMatchingWindow` |
| 窗口处于全屏或系统不允许调整 | 不退出全屏、不操作 Spaces | 跳过该窗口 | `windowNotAdjustable`，原因 `fullscreenOrSystemManaged` |

Stage Manager 和全屏不是拓扑身份。Scene 不能承诺跨 Space 恢复；可见窗口能否被 AX 访问是运行时事实，失败必须报告。

## 4. 一次性 apply 与结果回执

### 4.1 执行顺序

未来 executor 应先读取一次权限和拓扑快照，再按 Scene 中 placement 的稳定顺序处理。每个 placement：应用运行检查 → 候选窗口匹配 → 拓扑解析 → 生成 Prepared Resize → 通过既有 execution boundary apply。应用激活、AX 读取或窗口写入失败不应中断其余 placement，除非用户取消。

apply 不包含启动应用、Space 操作、回滚或持续监听。取消是协作式的：尚未开始的 placement 标记 `cancelled`，已经成功的 placement 不回滚。

### 4.2 机器结果

Scene 级状态至少包括：

- `fullyApplied`：所有 placement 都成功；
- `partiallyApplied`：至少一个成功且至少一个失败、跳过或取消；
- `noMatchingWindow`：无成功，且存在运行中的应用但没有可安全匹配窗口；
- `applicationNotRunning`：无成功，且所有未处理 placement 的应用都未运行；v1 不启动它们；
- `permissionDenied`：开始或执行时 Accessibility 权限不足，未进行有效写入；
- `topologyMismatch`：无成功，且至少一个 placement 没有满足拓扑策略的唯一映射；
- `windowNotAdjustable`：无成功，且候选窗口存在但不可调整（包括全屏/系统管理窗口）；
- `cancelled`：用户在任何 placement 成功前取消；
- `unknownFailure`：无成功且错误不能安全归类。

若失败类型混合且已有成功，统一为 `partiallyApplied`，同时保留每个 placement 的原始原因。若没有成功但有多个失败类型，按诊断优先级返回：`permissionDenied` > `cancelled` > `topologyMismatch` > `applicationNotRunning`/`noMatchingWindow` > `windowNotAdjustable` > `unknownFailure`；完整明细仍在 placement 结果中。

### 4.3 Placement 回执

```text
SceneApplyReceipt {
  sceneID: UUID
  schemaVersion: Int
  overall: OverallApplyStatus
  topologyResolution: exactTopology | relativeMigration | confirmedFallback | notResolved
  appliedCount: Int
  skippedCount: Int
  startedAt: Instant
  finishedAt: Instant
  placements: [PlacementReceipt]
}

PlacementReceipt {
  placementID: UUID
  bundleIdentifier: String?        // 可用于诊断；不含标题/路径/URL
  status: applied | skipped | failed | cancelled
  reason: ApplyReason
  topology: exactTopology | relativeMigration | confirmedFallback | notResolved
  candidateCount: Int?             // 数量，不返回候选名称
  degraded: Bool
}
```

`ApplyReason` 包括 `ok`、`applicationNotRunning`、`permissionDenied`、`noMatchingWindow`、`ambiguousCandidates`、`topologyMismatch`、`ambiguousTopology`、`windowNotAdjustable`、`fullscreenOrSystemManaged`、`cancelled`、`schemaUnsupported`、`provenanceUnsupported`、`unknownFailure`。回执默认不返回窗口标题、应用路径、文档名、URL、候选窗口对象、AX 属性 dump 或错误原文；日志只允许使用 bundle ID、Scene/placement UUID、状态和错误码。

`SceneApplyReceipt.topologyResolution` 是摘要字段，不替代 placement 字段：全部成功且全部精确时为 `exactTopology`；没有 fallback 且至少一个 placement 通过相对迁移时为 `relativeMigration`；任一 placement 使用了用户确认回退时为 `confirmedFallback`；没有任何 placement 完成拓扑解析时为 `notResolved`。逐 placement 的 `topology` 才是诊断事实。

## 5. 持久化、迁移与数据生命周期（设计，不实现）

### 5.1 存储位置与格式

选择单一、local-only 的版本化 JSON 文件：

```text
~/Library/Application Support/Line/Window Scenes/scenes.json
```

Scene 不进入散落的 Defaults key，也不使用 iCloud 容器。目录权限目标为仅当前用户可访问，文件权限目标为 user read/write。实现必须通过专用 repository 隔离编码、迁移和文件 I/O；本 Spike 不创建该 repository。

写入流程：同目录创建临时文件 → 完整编码并 flush → 原子 replace `scenes.json` → 保留一个 `scenes.json.bak`。启动读取 current；current 无法解码时尝试 backup；两者均损坏则将文件移入带时间戳的 quarantine 文件并以空库启动，同时报告不含内容的诊断码。不能通过部分 JSON 猜测恢复 placement，也不能覆盖仍可读的 current。

### 5.2 Schema 与迁移

- 根 `schemaVersion` 必填；当前设计版本为 1。
- 读取旧版本时执行纯、幂等、逐版本迁移，并在成功迁移后一次性写回；迁移前保留 backup。
- 缺少版本、未知字段或重复 placement 不得静默当作最新格式。缺版本/重复 ID/非法相对值的记录进入 `invalidScene`，不参与 apply，并可在诊断中报告计数。
- 读取比当前更新的 schema 时只返回 `schemaUnsupported`，不覆盖、不降级、不丢字段；待应用升级后再处理。
- 迁移不能从旧数据重新构造标题、路径、URL、剪贴板、文档内容或内容 hash。

预期 v1→v2 的迁移示例是增加明确的 `source` 或拓扑 bucket，而不是改变 Window Scene 语义。任何会改变匹配或布局解释的迁移必须增加 schema 版本和测试夹具。

### 5.3 备份、恢复、删除与重命名

- 重命名只更新 name 和 updatedAt，不改变 Scene ID、placement ID 或布局。
- 删除需按 ID 定位并原子写回；不存在的 ID 是幂等 no-op。
- 恢复只接受完整且当前支持的文档；恢复导入不得合并来自外部的窗口运行时 ID。
- 导出/导入若未来提供，必须是明确用户操作，且导出文件沿用同样字段禁区；不通过 URL 传递 Scene 数据。
- 损坏文件恢复后不自动“修复”未知数据；用户应能获得脱敏的损坏/备份使用结果。

## 6. 入口与安全边界

v1 不接入 URL scheme、keybind、设置 UI 或菜单项。这样可以先验证匹配和拓扑风险，不在没有确认界面时误用危险 fallback。

未来若接入 `line://`，必须新增独立的、版本化的 command contract（例如明确的 scene ID 和 apply policy），并复用同一个 executor/receipt。不得把 Scene JSON、窗口身份、拓扑或布局塞进现有 action URL 参数，不得让 URL 调用扩大返回窗口信息；当前 URL scheme 无调用方认证，因此必须重新评估确认、权限和错误披露边界。此项是未来工作，不是本 Spike 的接口承诺。

未来 keybind 也只能引用本地 Scene ID，不携带 Scene 内容；在用户可见入口与权限/拓扑确认 UX 定义前，不创建开关或绑定。

## 7. 非目标与状态图

### 7.1 非目标

- macOS Spaces 的创建、切换、命名或事务恢复。
- 自动启动应用、恢复应用状态、恢复文档或窗口内容。
- 持续 tiling、窗口出现/消失监听后的自动重排。
- 云同步、iCloud、网络 API、账号和遥测。
- 基于标题、路径、URL、剪贴板、文档内容或其 hash 的匹配。
- 原子 apply、全量回滚、跨应用事务锁。
- 新的 AX 写入、SkyLight 直接调用或第二套 frame calculator。

### 7.2 状态图

```text
captured (runtime only)
  -> validated -> draft (future persistence)
  -> stored -> loaded(schema checked)
  -> ready
  -> matching
       -> permissionDenied
       -> appNotRunning (never launch)
       -> noMatchingWindow / needsUserChoice
       -> topologyResolving
            -> exactTopology
            -> relativeMigration
            -> confirmedFallback
            -> topologyMismatch
       -> prepared(Prepared Resize)
            -> applied
            -> windowNotAdjustable / unknownFailure
  -> applying -> fullyApplied | partiallyApplied | terminal failure
  -> cancelled (no rollback)
```

## 8. 数据字典

| 字段/概念 | 稳定性 | 含义 | 禁止内容 |
| --- | --- | --- | --- |
| `SceneDocument.id` | 稳定 | Scene 不透明身份 | PID、CGWindowID |
| `name` | 稳定 | 用户命名 | 不作为窗口身份 |
| `schemaVersion` | 稳定 | 解码/迁移版本 | 静默降级 |
| `placements` | 稳定 | 窗口排列声明 | 标题、路径、URL、内容 |
| `bundleIdentifier` | 稳定 | 应用身份 | 应用路径、命令行参数 |
| `windowHint` | 稳定（可选） | 非内容性 AX 线索 | 标题、文档名、内容 hash |
| `DisplayTopologyReference` | 稳定 | 相对拓扑描述 | CG display ID、Space ID |
| `RelativeLayout` | 稳定 | visible frame 内归一化布局 | 永久像素坐标 |
| `source` | 稳定（可选） | action/grid provenance | 任意可执行 URL |
| PID/CGWindowID/Window | 运行时 | 本次 apply 的对象 | 任何落盘/日志输出 |
| `Prepared Resize` | 运行时 | 既有执行边界的输入 | Scene 第二执行引擎 |
| `SceneApplyReceipt` | 运行时 | 脱敏结果 | 标题、路径、URL、AX dump |

## 9. 结果示例

以下示例只展示机器可读摘要；`placements` 省略的字段仍必须遵守回执定义。

### 示例 A：全成功

条件：两块显示器拓扑精确匹配，Mail 和 Terminal 各有唯一候选，权限有效，两个 Prepared Resize 均成功。

```json
{
  "overall": "fullyApplied",
  "topologyResolution": "exactTopology",
  "appliedCount": 2,
  "skippedCount": 0,
  "placements": [
    {"placementID":"…mail…", "bundleIdentifier":"com.apple.mail", "status":"applied", "reason":"ok", "topology":"exactTopology", "degraded":false},
    {"placementID":"…terminal…", "bundleIdentifier":"com.apple.Terminal", "status":"applied", "reason":"ok", "topology":"exactTopology", "degraded":false}
  ]
}
```

用户摘要：`Scene“工作”已应用：2 个窗口已排列。`

### 示例 B：应用未运行

条件：Scene 只有一个 placement，目标应用未运行；策略为 `neverLaunch`。

```json
{
  "overall": "applicationNotRunning",
  "topologyResolution": "notResolved",
  "appliedCount": 0,
  "skippedCount": 1,
  "placements": [
    {"placementID":"…", "bundleIdentifier":"com.example.Editor", "status":"skipped", "reason":"applicationNotRunning", "topology":"notResolved", "degraded":false}
  ]
}
```

用户摘要：`未应用：目标应用未运行；Line 不会自动启动应用。`

### 示例 C：多显示器减少

条件：Scene 捕获时有两块屏，引用右侧外接屏已移除；另一 placement 在主屏成功。没有用户确认，因此不使用当前屏回退。

```json
{
  "overall": "partiallyApplied",
  "topologyResolution": "relativeMigration",
  "appliedCount": 1,
  "skippedCount": 1,
  "placements": [
    {"placementID":"…main…", "bundleIdentifier":"com.example.Notes", "status":"applied", "reason":"ok", "topology":"relativeMigration", "degraded":false},
    {"placementID":"…external…", "bundleIdentifier":"com.example.Terminal", "status":"skipped", "reason":"topologyMismatch", "topology":"notResolved", "degraded":false}
  ]
}
```

用户摘要：`Scene 部分应用：1 个窗口已排列；1 个窗口因显示器已不可用而跳过。`

### 示例 D：权限撤销

条件：apply 开始前 Accessibility 权限被撤销。

```json
{
  "overall": "permissionDenied",
  "topologyResolution": "notResolved",
  "appliedCount": 0,
  "skippedCount": 2,
  "placements": [
    {"placementID":"…", "bundleIdentifier":"com.apple.mail", "status":"failed", "reason":"permissionDenied", "topology":"notResolved", "degraded":false},
    {"placementID":"…", "bundleIdentifier":"com.apple.Terminal", "status":"failed", "reason":"permissionDenied", "topology":"notResolved", "degraded":false}
  ]
}
```

用户摘要：`未应用：需要开启辅助功能权限。`

### 示例 E：窗口不可调整

条件：应用和候选窗口存在，但窗口处于全屏/系统管理状态，Line 不退出全屏也不操作 Space。

```json
{
  "overall": "windowNotAdjustable",
  "topologyResolution": "exactTopology",
  "appliedCount": 0,
  "skippedCount": 1,
  "placements": [
    {"placementID":"…", "bundleIdentifier":"com.example.Player", "status":"skipped", "reason":"fullscreenOrSystemManaged", "topology":"exactTopology", "degraded":false}
  ]
}
```

用户摘要：`未应用：窗口当前不可调整（可能处于全屏或由系统管理）。`

## 10. 测试矩阵

| 层级 | 输入 | 必须验证 |
| --- | --- | --- |
| 值模型 | v1 文档、空 Scene、重复 ID、非法布局、未知 schema | Codable round-trip；拒绝/诊断非法数据；未知新版本不降级 |
| 隐私 | 标题、路径、URL、剪贴板、文档内容出现在运行时候选 | 编码文档、回执和诊断均不出现这些字段或派生 hash |
| 匹配 | 单窗口、同应用多窗口、缺少 hint、唯一 identifier | 唯一候选才自动匹配；歧义只能用户选择/跳过 |
| 拓扑 | 主屏改变、增屏、减屏、分辨率/scale、重排 | 按矩阵选择 exact/relative/confirmation/skip；绝不使用 display ID 猜测 |
| 环境 | Stage Manager、全屏、不可调整、权限撤销 | 不操作 Spaces/全屏；返回明确 reason |
| apply 结果 | 五个结果示例以及混合失败 | 全成功、未运行、减屏、权限、不可调整和部分成功摘要正确 |
| 迁移 | 每个 schema fixture、损坏 current、可用 backup、两者损坏 | 幂等迁移、原子恢复、quarantine 不泄露内容 |
| 执行边界 | 生成 Prepared Resize、失败后继续 | 不直接 AX；一次 apply 按 placement 独立报告；不回滚/不持续 tiling |

## 11. 实施阶段与未决问题

### 建议阶段

1. **MVP 实施计划**：把本规范拆为版本化纯值模型、Scene repository、拓扑/匹配 policy、receipt、执行 adapter；先补纯单元测试。
2. **受控原型**：只支持唯一应用候选和 `capturedFrame`/grid provenance；接入现有 Prepared Resize，不提供用户可见开关。
3. **本地 persistence**：实现迁移、备份、恢复和诊断，完成隐私审查。
4. **交互设计**：单独定义 capture/apply、歧义选择和拓扑确认 UX；未完成前不接 URL/keybind。
5. **入口评审**：另立计划决定菜单、设置、keybind 或 versioned URL contract，并复核权限和信息披露。

### 未决问题（不得用猜测实现）

- capture 如何由用户明确选择窗口，以及如何在不保存窗口内容的情况下提供一次性多窗口选择。
- macOS AX 提供的 accessibility identifier 在支持应用中的稳定性和是否可能包含用户内容；需在实现前用 fixture/真实测试验证。
- 多显示器图同构存在歧义时，未来 UI 如何呈现用户选择；没有 UI 时只能跳过。
- 不同应用的最小/最大窗口约束如何由现有 Window Resize Execution 反馈为 `degraded`，而不改变 Scene 的归一化布局。
- source action catalog 的稳定 identifier、版本化和自定义 action 删除后的行为。
- 是否需要用户可见的 Scene 导出/导入；如需要，必须另做隐私和格式评审。
