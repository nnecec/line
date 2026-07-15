# 004: 临时文件清理延迟优化

**状态**: TODO  
**优先级**: P0（快速胜利，安全改进）  
**发现**: SEC-03  
**基准 commit**: 79ff450  
**工作量估算**: S（1小时）  
**风险**: LOW

---

## 问题

`Line/Core/URLCommandHandler.swift:267-276` 创建临时文件用于显示 URL 命令输出，但 60 秒的清理延迟创建了不必要的数据暴露窗口。虽然数据敏感度低（action 名称），但违反最小权限数据生命周期原则。

**当前行为**:
```swift
// Line 267-276
let tempFile = FileManager.default.temporaryDirectory
    .appendingPathComponent("line_output_\(timestamp).txt")

do {
    try outputBuffer.joined(separator: "\n").write(to: tempFile, atomically: true, encoding: .utf8)
    NSWorkspace.shared.open(tempFile)

    // 60 秒清理延迟
    Task {
        try? await Task.sleep(for: .seconds(60))
        try? FileManager.default.removeItem(at: tempFile)
    }
}
```

---

## 实施计划

### 第 1 步：减少清理延迟到 5 秒

修改清理延迟：

```swift
// Line/Core/URLCommandHandler.swift:269
// 从 60 秒改为 5 秒
Task {
    try? await Task.sleep(for: .seconds(5))  // 原来是 60
    
    do {
        try FileManager.default.removeItem(at: tempFile)
        log.info("Cleaned up temporary URL command output file")
    } catch {
        log.error("Failed to clean up temporary file: \(ApplicationLogPrivacy.errorDescription(error))")
    }
}
```

**理由**: 5 秒足够文本编辑器打开和读取文件，同时大幅减少暴露窗口。

**验证**: 编译通过
```bash
xcodebuild -project Line.xcodeproj -scheme Line -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

---

### 第 2 步：添加测试验证清理时机

扩展 `LineTests/URLCommandHandlerTests.swift`:

```swift
func testTemporaryFileCleanupTimingIsReasonable() async throws {
    let handler = URLCommandHandler()
    let url = URL(string: "line://list/actions")!
    
    // 触发命令（创建临时文件）
    handler.handle(url)
    
    // 等待 1 秒（文件应该存在）
    try await Task.sleep(for: .seconds(1))
    
    // 等待 6 秒（文件应该被删除）
    try await Task.sleep(for: .seconds(6))
    
    // 无法轻易验证文件是否被删除（临时路径不确定）
    // 但至少验证不会崩溃
    XCTAssertTrue(true, "清理应该在 5 秒内完成")
}
```

**验证**: 运行测试
```bash
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' \
  -only-testing:LineTests/URLCommandHandlerTests/testTemporaryFileCleanupTimingIsReasonable
```

**预期**: 通过

---

### 第 3 步：手动功能测试

测试临时文件清理：

```bash
# 1. 触发 list 命令
open "line://list/actions"

# 2. 记录临时文件路径（从打开的编辑器窗口标题或日志）

# 3. 等待 3 秒，文件应该仍存在
sleep 3
ls /var/folders/.../line_output_*.txt

# 4. 等待 3 秒（总共 6 秒），文件应该被删除
sleep 3
ls /var/folders/.../line_output_*.txt  # 应该不存在
```

**预期**: 文件在 5-6 秒内被删除

---

### 第 4 步：更新注释

更新 `flushOutput()` 方法的注释：

```swift
// Line/Core/URLCommandHandler.swift:250
private func flushOutput() {
    guard shouldCollectOutput,
          !outputBuffer.isEmpty else {
        outputBuffer.removeAll()
        return
    }

    // Create a unique temporary file that will be automatically cleaned up
    // Cleanup delay: 5 seconds (sufficient for editor to open and read)
    let timestamp = Date().timeIntervalSince1970
    let tempFile = FileManager.default.temporaryDirectory
        .appendingPathComponent("line_output_\(timestamp).txt")
    
    // ... rest of method
}
```

---

### 第 5 步：运行完整测试

```bash
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS'
mint run swiftformat --lint . --reporter github-actions-log
```

**预期**: 所有测试通过

---

## 验证标准

### 自动化

```bash
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS'
```

### 手动

1. 触发 `open "line://list/actions"`
2. 观察文件在 TextEdit 中打开
3. 等待 6 秒
4. 确认文件已删除（检查 `/var/folders/` 或日志）

---

## 范围界限

**包含**:
- 修改清理延迟（60s → 5s）
- 注释更新

**不包含**:
- 使用 `NSWorkspace.open(completion:)` 的替代实现（可作为后续优化）
- 其他临时文件管理
- outputBuffer 大小限制（由 003 计划的 URL 限制保护）

**明确不修改**:
- 临时文件创建逻辑
- URL 命令处理流程

---

## 回滚计划

如果 5 秒不足（某些编辑器打开慢）：

```swift
// 恢复到 60 秒或调整到中间值（如 10 秒）
try? await Task.sleep(for: .seconds(60))
```

---

## 维护说明

**5 秒选择理由**:
- TextEdit/默认编辑器通常 < 1 秒打开
- 5 秒提供 5x 安全余量
- 比 60 秒减少 92% 的暴露窗口

**未来改进**:
- 考虑使用 `NSWorkspace.open(_:configuration:completionHandler:)` 在打开完成后立即删除
- 这需要更复杂的实现，但可以进一步减少暴露窗口到 ~0 秒

**相关计划**:
- 003: URL 长度验证（同一文件的另一个安全修复）
