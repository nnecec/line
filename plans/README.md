# Line 改进计划索引

**审计基准**: commit `79ff450` (2026-07-15)  
**审计深度**: 标准（standard）  
**代码规模**: ~8,200 行 Swift 代码，150 个源文件，15 个测试文件

## 优先级排序

按杠杆率（影响/工作量，根据置信度和修复风险调整）排序：

| # | 标题 | 类别 | 影响 | 工作量 | 风险 | 状态 |
|---|------|------|------|--------|------|------|
| 001 | URL scheme 参数长度无界限，潜在内存耗尽 | 安全 | MED | S | LOW | DONE |
| 002 | 临时文件暴露窗口（60秒清理延迟） | 安全 | LOW | S | LOW | TODO |
| 003 | AccessibilityManager 权限状态机未测试 | 测试 | HIGH | M | MED | TODO |
| 004 | WindowDragManager 拖拽捕捉逻辑零测试覆盖 | 测试 | MED | L | MED | TODO |
| 005 | 私有 API 符号加载无验证覆盖 | 测试 | LOW | M | LOW | TODO |
| 006 | WindowActionEngine apply() 执行流缺少集成测试 | 测试 | MED | M | MED | TODO |
| 007 | CustomWindowActionCalculator 几何边缘情况测试 | 测试 | LOW | S | LOW | DONE |
| 009 | Grid Layout 几何计算未测试 | 测试 | MED | M | MED | TODO |
| 010 | SystemWindowManager macOS 15 集成零覆盖 | 测试 | MED | M | MED | TODO |
| 011 | ResizeContext 状态包装缺少特性测试 | 测试 | LOW | S | LOW | TODO |
| 012 | WindowAction 帧计算边缘情况测试不足 | 测试 | MED | M | MED | TODO |
| 013 | 并发 action 处理和取消未测试 | 测试 | MED | S | MED | DONE |
| 014 | RectangleTranslationLayer 导入逻辑未测试 | 测试 | LOW | S | LOW | TODO |
| 015 | Window 和 WindowUtility 核心操作缺少单元测试 | 测试 | MED | L | MED | TODO |
| 016 | 缺少完整的触发器→action→apply 流程集成测试 | 测试 | MED | L | MED | TODO |
| 017 | 缺少一键验证基础设施 | 测试 | LOW | S | LOW | TODO |
| 018 | SkyLight framework 加载无签名验证 | 安全 | MED | M | MED | TODO |

## 依赖关系

```
011 (一键验证) → 所有测试计划的基础设施
001 (AccessibilityManager) → 002, 005, 006, 009, 012 (需要权限的测试)
```

**推荐执行顺序**:
1. **快速胜利** (立即可做，高价值): 011 → 003 → 004 → 007 → 008
2. **测试基础** (解锁其他测试): 001
3. **核心路径** (高风险区域): 009 → 005 → 006 → 010
4. **大型投资** (长期价值): 002 → 012

## 已考虑但拒绝的发现

- **AXUIElement 强制类型转换**: `AXUIElement+Extensions.swift:92-119` 中的 `as!` 和 `assert` 是 CoreFoundation API 的标准模式，类型由 AXValueType 保证
- **动态 SkyLight 符号加载**: 这是有意的架构决策（已在 AGENTS.md 中记录），所有调用点都处理符号缺失
- **本地 Defaults 存储**: 无 iCloud 是有意的（当前构建配置）
- **Accessibility API 使用**: 核心功能，权限检查已存在

## 未审计区域

**标准审计未覆盖**（需要 `deep` 模式才能完全覆盖）：
- 性能审计（agent 遇到 API 限制）
- 正确性审计（agent 部分完成后遇到 API 限制）
- 完整的技术债务分析（未派遣 agent）
- 依赖漏洞扫描（需要 `swift package audit` 或手动审查）
- 方向/功能建议（需要显式 `next` 调用）

## 注释

所有计划文件编号格式：`NNN-slug.md`  
状态值：`TODO` | `IN_PROGRESS` | `BLOCKED` | `DONE` | `REJECTED`
