## 方案

1. `OfficialChallengeCoordinator` 增加 `let webSession: WebSession`，init 参数为 `webSession: WebSession = .shared`；生产调用点不传参，行为不变。
2. `makeView()` 中 `configuration.websiteDataStore = webSession.dataStore`，并改为 `await webSession.prepare(api: api)`。
3. `VerificationWebTests` 每个测试创建独立的 `WebSession()`（各自持有新的 nonPersistent 数据存储），传给 coordinator。
4. 回归验证：先复现默认并行 `swift test` 的失败；修复后连续运行默认 `swift test` 与 `swift test --no-parallel`，确认 238/29 通过。

## 取舍

- 不给 `WebSession.shared` 加锁：reset 与 prepare 的跨测试干扰本质是测试隔离问题；加锁会掩盖共享单例耦合，并给生产路径引入不必要的并发复杂度。
- 不用 `.serialized` 标记测试套件：Swift Testing 的 `.serialized` 只在套件内部生效，无法阻止两个套件之间的并行交错，默认命令仍会暴露竞态。
- 注入 seam 只是内部 init 参数，默认值保持 `.shared`，对生产调用点零影响。

## 风险

- 每个验证测试会新建一个 nonPersistent 数据存储，WebKit 实例数从 1 增到 3（仅测试），开销可忽略。
- 若未来测试依赖 `WebSession.shared` 的跨测试状态，注入后行为更隔离，属于改进方向。

## 测试策略

- 复现：循环运行默认 `swift test`，捕获并保存 `验证会话未准备好` 失败日志。
- 修复后：默认 `swift test` 连续 3 次通过；`swift test --no-parallel` 通过；`swift build` 无警告。
