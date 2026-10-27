---
generated_from_state_version: 11
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 2
- 验证器尝试次数: 1
- 完成时间: 2026-10-27T16:04:58.906Z
- 摘要: 独立验收通过。产品 diff 与上一轮字节一致，overlay 产品改动仍只有 RootView.content：ZStack 中列表常驻、showPlayer 时 PlayerPage 覆盖。上轮独立实机探针确认列表 NSScrollView offset 600 在播放器打开/关闭后保持不变，列表对象与文档高度 2939 不变；播放器覆盖 1140x682 内容区；返回、迷你播放器、侧栏折叠正常。本轮 Runtime 与独立复跑的 swift build 均无警告，swift test --no-parallel 均 238/29 通过。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1：在热门、分区、关注动态、观看记录、收藏、消息、下载、更多任一列表页滚动到中部，进入播放器后点返回，列表仍在原来的滚动位置，不回到顶部。 | 产品 diff 与上一轮验收字节完全一致（git diff 哈希 f883025c… 相同），Views.swift:332-361 的 ZStack/Group 结构未变。复用上轮独立实机探针：推荐列表 NSScrollView 设为 offset 600，打开播放器期间同一对象仍为 600，关闭后仍为 600，截图首行内容一致。 |
| A2 | passed | brief.md | A2：返回后已加载的懒加载内容（后续视频行、会话、记录）仍在，不重新请求第一页、不出现整页白屏或闪烁。 | 同一列表 NSScrollView 在播放器打开前、打开期间、关闭后均存在，documentView 高度始终为 1140x2939；leavePlayer 仅置 showPlayer=false（Store.swift:391-393），不触发 reload。未观察到白屏或视图重建；未直接抓包核对请求次数，但视图与已加载文档高度均未变化。 |
| A3 | passed | brief.md | A3：播放器打开时底层列表不可见、不可点击、不被 VoiceOver 聚焦；播放器覆盖整个内容区，圆角、尺寸与改动前一致。 | 列表应用 .opacity(showPlayer ? 0 : 1)、.allowsHitTesting(!showPlayer)、.accessibilityHidden(showPlayer)。上轮实机 view tree：播放器 NSScrollView 与列表同为 1140x682，截图覆盖整个内容区；外层 content.frame(maxWidth:maxHeight:) 与 clipShape(RoundedRectangle(cornerRadius:24)) 调用未改。VoiceOver 聚焦未直接实测（AXIsProcessTrusted=false），按 accessibilityHidden 代码路径判定。 |
| A4 | passed | brief.md | A4：播放器打开期间列表视图保持挂载（不销毁）；关闭播放器后列表立即可交互，若原本处于惯性滚动应继续滚动。 | 上轮实机：播放器打开期间列表 NSScrollView（1140x682，doc 2939，offset 600）与播放器 NSScrollView 同时挂载；关闭后同一列表对象仍在、offset 600 且立即显示。惯性滚动未直接实测，但视图未销毁已由对象地址与 clipView bounds 独立确认。 |
| A5 | passed | brief.md | A5：播放器现有行为不变：返回按钮、迷你播放器、全屏、双击/键盘返回、自动播放下一条、侧栏折叠展开都正常。 | 上轮注入点击实测：topbar 返回按钮关闭播放器并回到列表；关闭后迷你播放器出现；侧栏 logo 可折叠为 56pt 图标轨并再次展开。全屏、双击/键盘返回、自动播放下一条未逐项点验；这些路径不在 diff 内（Store/Player/MiniPlayer 未改），现有播放器/队列测试全部通过。 |
| A6 | passed | brief.md | A6：空状态分支仍正确显示：未登录进入“我的主页”显示登录提示，搜索无结果显示“没有找到视频”，播放器关闭后立即可交互。 | 未登录主页与搜索无结果分支在 diff 中未改动（Views.swift:333-345 的 ContentUnavailableView 与 browse 的“没有找到视频”分支保持原样，仅被 Group/ZStack 包裹）；上轮搜索态在同一容器下实机渲染正常（search-empty5.png）。两个空状态本身未实机触发（已登录且搜索有结果），按未改分支代码判定。 |
| A7 | passed | brief.md | A7：`swift build` 无警告，`swift test` 全部通过（不新增失败）。 | Runtime action 12 的必需检查：swift build 通过（exit 0），swift test --no-parallel 通过（exit 0，238 tests / 29 suites，8.1s）。独立复核：全新 scratch path 的 swift build 通过且无 warning/error；全新 scratch path 的 swift test --no-parallel 通过（238/29，8.5s）。默认并行 swift test 的既有 WebSession/LoginRestorationTests 竞态与本次 diff 无关，本轮接受的检查为顺序执行，Tests/WebSession 文件无改动。 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| swift build | build | . | passed | 0 | 874 ms |
| swift test --no-parallel | test --no-parallel | . | passed | 0 | 8142 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- swift build: passed — Build complete!（无警告）
- swift test --no-parallel: passed — 连续 2 次 238 tests / 29 suites passed
- scroll offset probe: passed — 播放器开/关前后列表 NSScrollView offset 均为 600、文档高度 4451
- 已知限制: AXIsProcessTrusted=false、CGPreflightPostEventAccess=false，无法用系统辅助功能做点击/键盘/VoiceOver 验证；实机点击通过 lldb 在应用进程内注入 NSEvent 完成。
- 已知限制: 滚动位置由程序设置 offset=600 验证，未覆盖真实触控板滚动惯性与减速过程。
- 已知限制: 未登录主页/搜索空状态未实机覆盖（会改动登录态；B 站对无意义查询仍返回结果）。
- 已知限制: 默认并行 `swift test` 存在本次改动之前就有的 WebSession.shared 竞态；验证使用 `swift test --no-parallel`。建议后续单独修复该测试隔离问题。

## 阻塞项

_无。_

## 风险与跳过的工作

- A3 的 VoiceOver 聚焦与 A4 的惯性滚动未直接实测（AXIsProcessTrusted=false、CGPreflightPostEventAccess=false）；分别由 accessibilityHidden 代码路径和视图常驻证据支持。
- A1/A2 的实机探针覆盖推荐列表；其它列表页共用同一 content 容器，未逐页实机滚动验证。
- A5 的全屏、双击/键盘返回、自动播放下一条与 A6 的两个空状态未逐项点验，依据未改代码路径与现有测试。
- 默认并行 swift test 仍存在既有 WebSession/LoginRestorationTests 竞态；本轮按 Runtime 的顺序检查 swift test --no-parallel 验收，产品代码与测试文件均未改动。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | fail | A7 | A1-A6 通过：独立实机探针确认列表 offset 600 在播放器打开/关闭后保持不变，列表对象与文档高度 2939 不变；播放器 1140x682 覆盖内容区；返回/迷你播放器/侧栏折叠正常。A7 失败：Runtime 的 swift test 检查两次在既有 VerificationWebTests 上因 WebSession/LoginRestorationTests 并行竞态失败（exit 1），尽管独立默认与串行 swift test 均 238/29 通过。按 Runtime 证据判定 fail，建议修复该测试隔离后重验。 | 2026-10-27T15:54:59.540Z |
| 1 | 2 | 1 | pass | — | 独立验收通过。产品 diff 与上一轮字节一致，overlay 产品改动仍只有 RootView.content：ZStack 中列表常驻、showPlayer 时 PlayerPage 覆盖。上轮独立实机探针确认列表 NSScrollView offset 600 在播放器打开/关闭后保持不变，列表对象与文档高度 2939 不变；播放器覆盖 1140x682 内容区；返回、迷你播放器、侧栏折叠正常。本轮 Runtime 与独立复跑的 swift build 均无警告，swift test --no-parallel 均 238/29 通过。 | 2026-10-27T16:04:58.906Z |



## 结论

独立验收通过。产品 diff 与上一轮字节一致，overlay 产品改动仍只有 RootView.content：ZStack 中列表常驻、showPlayer 时 PlayerPage 覆盖。上轮独立实机探针确认列表 NSScrollView offset 600 在播放器打开/关闭后保持不变，列表对象与文档高度 2939 不变；播放器覆盖 1140x682 内容区；返回、迷你播放器、侧栏折叠正常。本轮 Runtime 与独立复跑的 swift build 均无警告，swift test --no-parallel 均 238/29 通过。
