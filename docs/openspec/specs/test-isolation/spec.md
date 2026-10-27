# test-isolation Specification

## Purpose
确保并行运行的测试之间不会通过共享 WebKit 会话互相清空 cookie，使验证挑战相关测试在默认并行执行下稳定、可重复。

## Requirements

### Requirement: 验证挑战测试使用独立 WebSession

涉及验证挑战的测试 SHALL 为每个测试注入独立的 `WebSession`，不得依赖进程级 `WebSession.shared` 的跨测试状态；生产代码 MUST 继续默认使用 `WebSession.shared`。

#### Scenario: 并行登出不影响验证页

- **WHEN** 验证挑战测试加载验证页的同时，另一个测试调用 `api.logout()` 触发 `WebSession.shared.reset()`
- **THEN** 验证页仍能读取到自己的 `bili_jct`，测试不因共享 cookie 被清空而失败

#### Scenario: 生产路径保持共享会话

- **WHEN** 生产代码创建 `OfficialChallengeCoordinator` 且未显式传入 `webSession`
- **THEN** 协调器使用 `WebSession.shared`，官方验证行为与改动前一致
