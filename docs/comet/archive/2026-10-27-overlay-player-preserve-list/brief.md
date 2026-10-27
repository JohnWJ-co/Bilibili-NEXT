# 目标

把内容区从“用播放器替换列表”改成“播放器覆盖列表”：从任何列表页进入播放器再返回时，底层列表不被销毁，滚动偏移、已加载的懒加载内容与滚动惯性都原样保留，与 iPad 端现有行为一致。

# 范围

只调整 macOS `RootView.content` 的容器结构，让列表常驻、播放器叠加；不改各列表页自身、播放器内部和导航逻辑。

## 目录结构

### 新建

无

### 修改

- Sources/BiliGlass/Views.swift — `RootView.content`（约 332–355 行）：`if showPlayer { PlayerPage } else { switch destination }` 改为 `ZStack`，目的地内容（switch）常驻并在播放时 `opacity(0)`、`allowsHitTesting(false)`、`accessibilityHidden(true)`；`showPlayer` 为真时在同一 ZStack 上层挂载 `PlayerPage`。调用处 `frame(maxWidth:maxHeight:)` 与 `clipShape(RoundedRectangle(cornerRadius: 24))` 不变。

### 删除

无

### 明确不建

- 不改 `Apps/iOS/Sources/MobileTablet.swift` — iPad 端已经是“列表常驻 + 播放器覆盖”的结构（60–65 行），无需改动。
- 不新增滚动位置缓存或列表数据缓存 — 目标就是不再销毁视图，避免再维护一套恢复逻辑。
- 不改各列表页（`browse`、`NativeDynamicsPage`、`HistoryPage`、`DownloadPage`、`NativeInboxPage`、`WebFunctionsPage`、`ProfilePage`）的加载与布局。

# 非目标

- 不改播放器页面内部（播放控制、评论、弹幕、画质切换）。
- 不改进入/离开播放器的导航状态（`store.showPlayer`、`navigationRevision`、迷你播放器、全屏）。
- 不改 iPad/iOS。
- 不发版：不动 CHANGELOG、应用内更新说明和 bundle 版本号。

# 验收示例

- A1：在热门、分区、关注动态、观看记录、收藏、消息、下载、更多任一列表页滚动到中部，进入播放器后点返回，列表仍在原来的滚动位置，不回到顶部。
- A2：返回后已加载的懒加载内容（后续视频行、会话、记录）仍在，不重新请求第一页、不出现整页白屏或闪烁。
- A3：播放器打开时底层列表不可见、不可点击、不被 VoiceOver 聚焦；播放器覆盖整个内容区，圆角、尺寸与改动前一致。
- A4：播放器打开期间列表视图保持挂载（不销毁）；关闭播放器后列表立即可交互，若原本处于惯性滚动应继续滚动。
- A5：播放器现有行为不变：返回按钮、迷你播放器、全屏、双击/键盘返回、自动播放下一条、侧栏折叠展开都正常。
- A6：空状态分支仍正确显示：未登录进入“我的主页”显示登录提示，搜索无结果显示“没有找到视频”，播放器关闭后立即可交互。
- A7：`swift build` 无警告，`swift test` 全部通过（不新增失败）。

# 关键决定

- 采用 `ZStack`：列表始终在最底层常驻，`showPlayer` 时叠加 `PlayerPage`，与 iPad `MobileTablet.swift` 的 `ZStack` + `opacity/allowsHitTesting/accessibilityHidden` 写法一致。
- 列表隐藏用 `opacity(0)`、`allowsHitTesting(false)`、`accessibilityHidden(true)`，不用条件挂载，确保滚动视图与其已加载内容不被销毁。
- `PlayerPage` 仍只在 `showPlayer` 时挂载、关闭即销毁，保持现有内存与生命周期行为。
- 改动集中在 `content` 一处，不触碰列表页与播放器内部。

# 验证期望

- `swift build` 无警告；`swift test` 238 项全部通过。
- 用隔离 QA bundle 实机截图核对：播放器覆盖时内容区尺寸与圆角不变，列表页静态显示正常；滚动偏移保留需真人点击验证（本机无辅助功能权限）。
