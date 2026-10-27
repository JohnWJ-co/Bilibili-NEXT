## 1. 复现与证据

- [x] 1.1 循环运行默认 `swift test`，捕获 `验证会话未准备好` 失败日志并保存

## 2. 修复

- [x] 2.1 `OfficialChallengeCoordinator` 增加可注入 `webSession`（默认 `.shared`），`makeView()` 使用实例的数据存储
- [x] 2.2 `VerificationWebTests` 每个测试使用独立 `WebSession()` 并注入 coordinator

## 3. 验证

- [x] 3.1 `swift build` 无警告
- [x] 3.2 默认并行 `swift test` 连续 3 次 238/29 通过
- [x] 3.3 `swift test --no-parallel` 通过（238/29）
