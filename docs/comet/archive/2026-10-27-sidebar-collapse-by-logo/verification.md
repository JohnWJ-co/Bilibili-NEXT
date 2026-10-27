---
generated_from_state_version: 8
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 1
- 验证器尝试次数: 1
- 完成时间: 2026-10-27T14:42:48.650Z
- 摘要: A1-A7 全部通过。独立核对：当前未提交 diff 仅改 Views.swift/GlassStyle.swift；logo 为唯一折叠入口，SettingsLink 与 sidebarToggle 已从侧栏头部删除；sidebarRailWidth=56、展开 224；折叠态 11 图标/账号菜单/提示点与悬停逻辑、⌥⌘S 与动态无障碍标签、@AppStorage 持久化与动画条件均在代码中成立。渲染证据 v2-*.png 来自隔离 QA bundle（local.BiliGlass.qa；二进制含新符号与文案，且无 Sources 晚于其构建），展开头部实测 224pt、折叠轨道实测 56pt、窗口为最小内容 1020×700；QA 进程无参数启动后呈折叠且 defaults sidebarCollapsed=1，证明重启读取持久化状态。Runtime 记录 swift build（exit 0，无 warning）与 swift test（exit 0，238 tests/29 suites passed）与当前候选匹配并复用；未请求补充检查。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1：展开态侧栏顶部只有粉色 logo 和“Bilibili NEXT”文字，设置（滑块）图标和独立折叠按钮图标都不再出现。 | 代码：Views.swift:163-170 展开态头部只有 sidebarLogo + Text("Bilibili NEXT")；全仓 grep 无 sidebarToggle，侧栏头部的 SettingsLink(slider.horizontal.3) 已删除。渲染：v2-expanded-1020.png 为完整窗口 2040×1464px（2x，1020×732pt=1020×700 内容+32pt 标题栏），头部卡片像素实测 448px=224pt，只含粉色 logo 与标题；v2-expanded-topright.png 与主截图逐像素一致（offset 1300,0），顶部栏齿轮仍在。QA bundle 二进制含新符号 AppLayout.sidebarRailWidth 与“收起侧栏/展开侧栏”字符串，且无 Sources 文件晚于该二进制。 |
| A2 | passed | brief.md | A2：展开态点击 logo，侧栏在 224pt 动画收窄为 56pt 的图标轨；折叠态再次点击 logo（顶部卡片里的 logo）恢复 224pt 展开态。 | 代码：sidebarLogo 是唯一折叠入口，Button 动作 sidebarCollapsed.toggle()（Views.swift:193-203）；宽度在 AppLayout.sidebarWidth=224 与 sidebarRailWidth=56 间切换（155-157, GlassStyle.swift:7-8），并挂 .animation(sidebarAnimation, value: sidebarCollapsed)（36,158-160）；折叠态同一 logo 按钮顶部卡片整块 contentShape 可点。渲染：展开截图头部卡片实测 448px=224pt，折叠截图实测 112px=56pt（均为 2x 原图测量），折叠态仍显示同一 logo 按钮。持久化读取：QA 进程 60678 于 22:25:45 无参数启动后直接呈折叠 56pt，defaults 中 sidebarCollapsed=1。限制：本机 AXIsProcessTrusted=false、CGPreflightPostEventAccess=false，无法注入点击；按任务约定以代码路径+双状态实机渲染+持久化读取判定。 |
| A3 | passed | brief.md | A3：折叠态只显示 11 个导航图标（推荐、热门、分区、关注动态、消息 + 观看记录、收藏、稍后再看、下载、我的主页、更多），图标完整不裁切、不重叠、不显示文字；当前页仍有粉色高亮。 | 渲染：v2-collapsed-1020.png 在内容区最小 1020×700 下，左侧精确裁剪 v2-collapsed-1020-left.png 显示两张玻璃卡片共 11 个图标：house/flame/square.grid.2x2/person.2/bubble…（推荐、热门、分区、关注动态、消息）+ clock/star/text.badge.plus/arrow.down.circle/person.crop.circle/ellipsis.circle（观看记录、收藏、稍后再看、下载、我的主页、更多）；无文字、无裁切/重叠，推荐项保留粉色选中底色。代码：navigationRail 两组 5+6（Views.swift:177-183,204-224），图标 20×20、行高 34、卡片内宽 44pt（56-2×6）。 |
| A4 | passed | brief.md | A4：折叠态下消息未读或下载进行中仍显示提示点，鼠标悬停图标仍显示对应名称（如“消息”）。 | 代码：railIndicator 仅在 messages 未读 total>0 或 downloads.activeCount>0 时显示 7pt 粉色圆点，overlay 于图标 topTrailing，offset(4,-3)（Views.swift:214,225-230）；几何落在 44×34 行内（图标右缘 32，点右缘 36+3.5=39.5<44），不会被 ScrollView.clipped() 裁切；.help(d.rawValue) 保留“消息”等悬停名称（220），accessibilityLabel 动态附带未读数/下载数（231-239）。限制：截图时账号未读为 0、无进行中下载，提示点未在截图中实拍；结论基于条件代码与轨道内几何，非截图。 |
| A5 | passed | brief.md | A5：折叠态点击账号头像仍能打开“我的主页 / 设置 / 重新登录 / 退出登录”菜单；未登录时显示登录图标且点击可发起登录；恢复登录中显示小号进度圈。 | 代码：折叠态 accountFooter→accountRail（Views.swift:240-268）。已登录时 Menu 标签为 32pt 圆形头像（frame maxWidth infinity + contentShape Rectangle，整行可点），菜单项依次“我的主页 / 设置(SettingsLink) / 重新登录 / 退出登录”；未登录时 person.crop.circle 登录按钮调用 store.login()；store.restoring 时显示 controlSize(.small) 的 ProgressView。渲染：v2-collapsed-1020.png 底部账号卡片仅显示居中头像。限制：无事件注入权限，未脚本点开菜单；菜单内容与分支由代码路径核对。 |
| A6 | passed | brief.md | A6：折叠态与展开态都保留键盘切换 ⌥⌘S，VoiceOver 读到“收起侧栏/展开侧栏”，且删除侧栏设置图标后设置窗口仍可从顶部栏齿轮、账号菜单或 ⌘, 打开。 | 代码：logo 按钮带 .keyboardShortcut("s", modifiers:[.command,.option]) 与动态 .accessibilityLabel(sidebarCollapsed ? "展开侧栏" : "收起侧栏")（Views.swift:200-202），折叠/展开两态渲染同一 sidebarLogo；QA 二进制含“收起侧栏/展开侧栏”字符串。设置入口未受影响：顶部栏 gearshape SettingsLink（Views.swift:324，v2-expanded-topright.png 可证）、账号菜单 SettingsLink（248/373）、Settings scene（BiliGlassApp.swift:49）提供系统 ⌘,。限制：AXIsProcessTrusted=false（AX 读取 windows err -25211），无法脚本验证 VoiceOver 朗读或按键注入。 |
| A7 | passed | brief.md | A7：折叠状态重启应用后保持；窗口为最小尺寸 1020×700 时折叠态布局不错位、图标轨不出现横向裁切。 | 持久化：@AppStorage("sidebarCollapsed")（Views.swift:10）读写；QA 应用无参数进程 60678（22:25:45 启动）当前呈折叠，defaults read local.BiliGlass.qa 为 sidebarCollapsed=1，当前 1512×895 窗口下轨道像素实测 56pt。最小窗口：v2-collapsed-1020.png 为完整窗口 2040×1464px=1020×732pt（alpha 圆角、32pt 标题栏），即内容区 1020×700；左裁剪显示 11 图标与账号卡片完整、无横向裁切/重叠，内容区获得更宽空间。动画：sidebarAnimation = animations && !reduceMotion ? .smooth(0.22) : nil（Views.swift:9,158-160），interfaceAnimations 键与 Preferences（Preferences.swift:25,150）一致，关闭界面动画或系统减少动态效果即无动画。 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| swift build | build | . | passed | 0 | 2353 ms |
| swift test | test | . | passed | 0 | 2828 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- swift build: passed — Build complete! (11.97s)，无警告输出
- swift test: passed — Test run with 238 tests in 29 suites passed
- 隔离 QA bundle 实机截图: passed — 独立 bundle id local.BiliGlass.qa，实拍展开态 1020×732 与折叠态 56pt，见 outputs/sidebar-collapse/v2-*.png
- 已知限制: 本机未授予辅助功能权限（AXIsProcessTrusted=false，CGEvent/osascript 注入无效），无法脚本点击 logo；点击手势由用户验收确认。
- 已知限制: 截图时未读消息为 0，折叠态未读提示点未在本轮实拍；点位按 7pt 点 + 偏移(4,-3) 落在 44×34 行内，上一轮 88pt 版本曾实拍同一点位。

## 阻塞项

_无。_

## 风险与跳过的工作

- 无法注入点击/键盘/辅助功能事件（AXIsProcessTrusted=false、CGPreflightPostEventAccess=false；AX 读取 windows err -25211）：A2/A5/A6 的实时点击、键盘与 VoiceOver 朗读按代码路径+双状态实机渲染+持久化读取判定，未做端到端输入注入。
- 截图时消息未读为 0 且无进行中下载，A4 提示点未实拍；按条件代码与 56pt 轨道几何核对（7pt 点右缘 39.5pt < 44pt 内容宽）。
- v2 截图窗口为 1020×732pt，按 32pt 标题栏与根视图 22pt 顶部内边距推得内容区 1020×700（最小尺寸）；横向为精确最小宽度 1020pt。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | pass | — | A1-A7 全部通过。独立核对：当前未提交 diff 仅改 Views.swift/GlassStyle.swift；logo 为唯一折叠入口，SettingsLink 与 sidebarToggle 已从侧栏头部删除；sidebarRailWidth=56、展开 224；折叠态 11 图标/账号菜单/提示点与悬停逻辑、⌥⌘S 与动态无障碍标签、@AppStorage 持久化与动画条件均在代码中成立。渲染证据 v2-*.png 来自隔离 QA bundle（local.BiliGlass.qa；二进制含新符号与文案，且无 Sources 晚于其构建），展开头部实测 224pt、折叠轨道实测 56pt、窗口为最小内容 1020×700；QA 进程无参数启动后呈折叠且 defaults sidebarCollapsed=1，证明重启读取持久化状态。Runtime 记录 swift build（exit 0，无 warning）与 swift test（exit 0，238 tests/29 suites passed）与当前候选匹配并复用；未请求补充检查。 | 2026-10-27T14:42:48.650Z |



## 结论

A1-A7 全部通过。独立核对：当前未提交 diff 仅改 Views.swift/GlassStyle.swift；logo 为唯一折叠入口，SettingsLink 与 sidebarToggle 已从侧栏头部删除；sidebarRailWidth=56、展开 224；折叠态 11 图标/账号菜单/提示点与悬停逻辑、⌥⌘S 与动态无障碍标签、@AppStorage 持久化与动画条件均在代码中成立。渲染证据 v2-*.png 来自隔离 QA bundle（local.BiliGlass.qa；二进制含新符号与文案，且无 Sources 晚于其构建），展开头部实测 224pt、折叠轨道实测 56pt、窗口为最小内容 1020×700；QA 进程无参数启动后呈折叠且 defaults sidebarCollapsed=1，证明重启读取持久化状态。Runtime 记录 swift build（exit 0，无 warning）与 swift test（exit 0，238 tests/29 suites passed）与当前候选匹配并复用；未请求补充检查。
