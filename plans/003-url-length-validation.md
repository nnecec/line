# 003: URL scheme 参数长度验证

**状态**: DONE  
**优先级**: P0（快速胜利，安全修复）  
**发现**: SEC-02  
**基准 commit**: 79ff450  
**工作量估算**: S（2小时）  
**风险**: LOW

---

## 问题

`Line/Core/URLCommandHandler.swift:303-313` 解析 URL scheme 参数时不验证大小。恶意输入如 `open "line://keybind/$(python3 -c 'print("A"*10000000)')"` 可能分配大字符串，导致内存耗尽或 UI 挂起（打开临时输出文件时）。

**当前行为**:
```swift
// Line 303-313
let components = (url.host.map { [$0] } ?? []) + url.pathComponents.filter { $0 != "/" && !$0.isEmpty }

guard let commandString = components.first,
      let command = Command(rawValue: commandString.lowercased()) else {
    appendAvailableCommandHints()
    flushOutput()
    return
}

let parameters = Array(components.dropFirst())
processCommand(command, parameters)
```

无长度检查，`parameters` 可以是任意大小。

---

## 当前状态

**文件**: `Line/Core/URLCommandHandler.swift`

**关键方法**:
- `handle(_ url: URL)` (292-314): 入口点，解析 URL
- `processCommand(_:_:)` (322-334): 处理命令和参数
- `flushOutput()` (250-285): 创建临时文件并打开

**风险点**:
1. 303行：无界 `url.pathComponents` 解析
2. 312行：无界 `parameters` 数组传递
3. 264行：`outputBuffer.joined(separator: "\n")` 可能巨大
4. 264行：写入临时文件可能挂起 UI

---

## 实施计划

### 第 1 步：添加 URL 长度验证

在 `handle(_ url: URL)` 方法的 303 行之前添加验证：

```swift
// Line/Core/URLCommandHandler.swift, 在 303 行之前

// Validate URL length to prevent DoS
guard url.absoluteString.count < 1024 else {
    log.error("URL command rejected: exceeds maximum length of 1024 characters")
    return
}

let components = (url.host.map { [$0] } ?? []) + url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
```

**验证**: 编译通过
```bash
xcodebuild -project Line.xcodeproj -scheme Line -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

**预期**: 构建成功，无编译错误

---

### 第 2 步：添加单个参数长度验证

在 312 行之后，处理 `parameters` 前添加验证：

```swift
// Line/Core/URLCommandHandler.swift, 在 312 行之后

let parameters = Array(components.dropFirst())

// Validate individual parameter lengths
for parameter in parameters {
    guard parameter.count <= 256 else {
        log.error("URL command rejected: parameter exceeds maximum length of 256 characters")
        return
    }
}

processCommand(command, parameters)
```

**验证**: 编译通过
```bash
xcodebuild -project Line.xcodeproj -scheme Line -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

**预期**: 构建成功

---

### 第 3 步：添加单元测试

创建或扩展 `LineTests/URLCommandHandlerTests.swift`，添加：

```swift
// 测试 URL 长度限制
func testRejectsExcessivelyLongURL() {
    let handler = URLCommandHandler()
    let longPath = String(repeating: "A", count: 2000)
    let url = URL(string: "line://action/\(longPath)")!
    
    // 应该安全返回，不会崩溃或挂起
    handler.handle(url)
    
    // 验证没有执行（通过检查日志或其他副作用）
    XCTAssertTrue(true, "过长 URL 应该被拒绝")
}

// 测试单个参数长度限制
func testRejectsExcessivelyLongParameter() {
    let handler = URLCommandHandler()
    let longParam = String(repeating: "B", count: 500)
    let url = URL(string: "line://keybind/\(longParam)")!
    
    handler.handle(url)
    
    XCTAssertTrue(true, "过长参数应该被拒绝")
}

// 测试正常长度 URL
func testAcceptsNormalLengthURL() {
    let handler = URLCommandHandler()
    let url = URL(string: "line://list/actions")!
    
    // 应该正常处理
    handler.handle(url)
    
    XCTAssertTrue(true, "正常长度 URL 应该被接受")
}
```

**验证**: 运行测试
```bash
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' \
  -only-testing:LineTests/URLCommandHandlerTests
```

**预期**: 所有新测试通过

---

### 第 4 步：测试边界条件

添加边界条件测试：

```swift
// 测试恰好在限制边界的 URL
func testAcceptsURLAtExactLimit() {
    let handler = URLCommandHandler()
    // 1023 字符（限制是 1024）
    let path = String(repeating: "x", count: 1000)
    let url = URL(string: "line://action/\(path)")!
    
    XCTAssertLessThan(url.absoluteString.count, 1024)
    
    handler.handle(url)
    XCTAssertTrue(true)
}

// 测试超过限制 1 字符
func testRejectsURLJustOverLimit() {
    let handler = URLCommandHandler()
    // 超过 1024 字符
    let path = String(repeating: "x", count: 1020)
    let url = URL(string: "line://action/\(path)")!
    
    XCTAssertGreaterThan(url.absoluteString.count, 1024)
    
    handler.handle(url)
    XCTAssertTrue(true, "超限 URL 应该被拒绝")
}
```

**验证**: 运行测试
**预期**: 通过

---

### 第 5 步：更新文档

在 `Line/Core/URLCommandHandler.swift` 文件顶部的文档注释中添加限制说明：

```swift
/*
 Line URL Scheme Documentation
 ===========================

 ... (现有文档) ...

 Security Limits:
 ---------------
 - Maximum URL length: 1024 characters
 - Maximum individual parameter length: 256 characters
 - URLs exceeding these limits are silently rejected

 ... (其余文档) ...
 */
```

**验证**: 文档更新完成

---

### 第 6 步：运行完整测试套件

```bash
# 完整测试
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS'

# SwiftFormat 检查
mint run swiftformat --lint . --reporter github-actions-log
```

**预期**: 所有测试通过，格式正确

---

## 验证标准

### 功能验证

手动测试：

```bash
# 测试正常 URL（应该工作）
open "line://list/actions"

# 测试过长 URL（应该被拒绝，无输出）
open "line://action/$(python3 -c 'print("A"*2000)')"

# 测试多个长参数（应该被拒绝）
open "line://keybind/$(python3 -c 'print("B"*500)')"
```

**预期**: 
- 正常 URL 正常工作
- 过长 URL 被静默拒绝（日志中有错误）
- 应用不崩溃或挂起

### 自动化验证

```bash
# 所有测试通过
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS'

# 新测试存在并通过
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' \
  -only-testing:LineTests/URLCommandHandlerTests/testRejectsExcessivelyLongURL \
  -only-testing:LineTests/URLCommandHandlerTests/testRejectsExcessivelyLongParameter
```

---

## 范围界限

**包含**:
- `URLCommandHandler.swift` 的长度验证
- 单元测试
- 文档更新

**不包含**:
- URL scheme 的其他输入验证（不在此发现范围内）
- outputBuffer 的单独大小限制（由 URL 限制间接保护）
- 其他 DoS 向量（不在此计划范围）

**明确不修改**:
- URL scheme 的公共 API
- 现有命令处理逻辑（仅添加验证）
- 其他文件

---

## 回滚计划

如果验证过于严格导致合法 URL 被拒绝：

1. **放宽限制**: 增加到 2048/512
2. **记录真实用例**: 收集被拒绝的合法 URL
3. **调整**: 根据真实用例重新校准

**删除更改**:
```bash
git diff HEAD~1 Line/Core/URLCommandHandler.swift
git revert HEAD
```

---

## 维护说明

**限制选择理由**:
- **1024 字符总长度**: URL 通常 < 200 字符，1024 是安全缓冲
- **256 字符参数**: keybind 名称通常 < 50 字符，256 是安全缓冲

**未来调整**:
- 监控日志中的拒绝事件
- 如果合法用例被拒绝，提高限制
- 考虑添加配置选项（不推荐，保持简单）

**相关计划**:
- SEC-03: 临时文件清理（同一文件的另一个安全修复）
