## 问题

默认并行执行 `swift test` 时，`VerificationWebTests` 会偶发失败，报“验证会话未准备好，请关闭后重新打开验证”（csrfMissing）。Runtime 两次检查日志（4e157…、184c5b…）都只挂在该套件，且产品代码与测试文件在两次运行之间没有变化；本地多次默认运行也会随机出现同样失败。

## 根因

`WebSession.shared` 是进程级单例，内部持有 `WKWebsiteDataStore.nonPersistent()`。

1. `VerificationWebTests` 的 `OfficialChallengeCoordinator.makeView()` 先调用 `WebSession.shared.prepare(api:)` 把 `SESSDATA`/`bili_jct` 写入共享数据存储，再加载验证页。
2. 并行执行的 `LoginRestorationTests.logoutDuringValidationCannotRestoreAccount` 调用 `api.logout()`，进而执行 `WebSession.shared.reset()`，异步清空全部网站数据。
3. reset 与验证页读取 cookie 发生竞态，页面脚本拿不到 `bili_jct`，回调 failed("csrfMissing")，测试失败。

这是测试之间的共享全局状态隔离问题，不是播放器/侧栏等产品代码的缺陷。

## 修复目标

让验证挑战测试使用独立的 `WebSession` 实例，不再受共享单例 reset 的影响；生产行为保持不变（仍使用 `WebSession.shared`）。默认并行 `swift test` 应稳定通过。

## 范围

- `Sources/BiliGlass/OfficialChallenge.swift`：`OfficialChallengeCoordinator` 增加可注入的 `webSession`（默认 `.shared`），`makeView()` 使用该实例的数据存储与 `prepare`。
- `Tests/BiliGlassTests/VerificationWebTests.swift`：每个测试创建独立 `WebSession()` 并注入。
- 不修改 `WebSession` 实现、`API.logout()`、其它测试或产品行为。

## 非目标

- 不重构全局 WebKit 会话架构，不改登录/登出逻辑，不改验证页行为。
- 不为测试引入串行执行依赖；修复后默认并行命令应自身稳定。

## Capabilities

- 新增 `test-isolation`：约定验证挑战测试必须使用独立的 WebKit 会话，避免并行测试之间的 cookie 重置竞态。
