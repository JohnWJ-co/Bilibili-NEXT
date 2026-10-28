import AVKit
import SwiftUI

let biliPink = Color(red: 0.86, green: 0.24, blue: 0.43)
struct RootView: View {
  @Bindable var store: Store
  @Environment(\.scenePhase) private var phase
  @FocusState private var searchFocused: Bool
  @State private var diagnosticChallenge: InteractionChallenge?
  var body: some View {
    ZStack {
      if !store.fullscreen.isPresented { GlassBackdrop() }
      GeometryReader { _ in
        VStack(spacing: 16) {
          topbar
          if let reason = store.loginUpgradeReason, !store.loginUpgradeDismissed {
            HStack(spacing: 12) {
              Image(systemName: "person.crop.circle.badge.exclamationmark")
              Text(reason.message).font(.callout).fixedSize(horizontal: false, vertical: true)
              Spacer(minLength: 0)
              Button("重新登录") { store.login() }.buttonStyle(.panel)
              Button("稍后") { store.loginUpgradeDismissed = true }.buttonStyle(.panel)
            }.padding(14).floatingGlass(18)
          }
          if searchFocused && !store.showPlayer { SearchAssistance(store: store) }
          content.frame(maxWidth: .infinity, maxHeight: .infinity).clipShape(
            RoundedRectangle(cornerRadius: 24))
        }.padding(.horizontal, 20).padding(.bottom, 20).padding(.top, 22)
          .opacity(store.fullscreen.isPresented ? 0 : 1)
          .allowsHitTesting(!store.fullscreen.isPresented)
          .accessibilityHidden(store.fullscreen.isPresented)
      }
      if !store.fullscreen.isPresented {
        // The strip from the window's top edge down to the panels stands in
        // for the hidden title bar.
        GeometryReader { g in
          VStack(spacing: 0) {
            Color.clear.frame(height: g.safeAreaInsets.top + 22).titleBarBehavior()
            Spacer(minLength: 0)
          }.ignoresSafeArea(edges: .top)
        }
      }
      if store.fullscreen.isPresented {
        FullscreenPlayerContent(store: store, close: { store.fullscreen.close() }).ignoresSafeArea()
      }
      if store.showsMiniPlayer {
        VStack { Spacer(); HStack { Spacer(); MiniPlayer(store: store) } }.padding(24)
      }
    }
    .tint(biliPink).appAppearance().frame(minWidth: 1020, maxWidth: .infinity, minHeight: 700, maxHeight: .infinity)
    .background { InitialWindowFocus().frame(width: 0, height: 0) }
    .containerBackground(.black, for: .window)
    .sheet(item: $store.imageGallery) { ImageGallery(target: $0) }
    .sheet(item: $diagnosticChallenge) { challenge in
      VStack {
        HStack { Text("官方验证").font(.headline); Spacer(); Button("关闭") { diagnosticChallenge = nil } }.padding(16)
        OfficialChallengeView(api: store.api, challenge: challenge) {
          diagnosticChallenge = nil
          let args = ProcessInfo.processInfo.arguments
          if let i = args.firstIndex(of: "--full-coin-check"), args.indices.contains(i + 2) {
            Task { await Diagnostics.fullCoinCheck(api: store.api, bvid: args[i + 1],
              output: URL(fileURLWithPath: args[i + 2]).appendingPathExtension("verified.json")) }
          }
        }
      }.frame(width: 640, height: 560)
    }
    .sheet(item: $store.reportTarget) { VideoReportForm(store: store, video: $0) }
    .confirmationDialog("拉黑这个 UP 主？", isPresented: Binding(get: { store.blockTarget != nil }, set: { if !$0 { store.blockTarget = nil } }), titleVisibility: .visible, presenting: store.blockTarget) { video in
      Button("拉黑", role: .destructive) { Task { await store.blockAuthor(video) }; store.blockTarget = nil }
    }
    .sheet(item: $store.webTarget) { target in
      VStack(spacing: 0) {
        HStack {
          Spacer()
          Button("完成") { store.webTarget = nil }
        }.padding(12)
        OfficialWebPanel(target: target, api: store.api)
      }.frame(minWidth: 1000, minHeight: 720)
    }
    .sheet(item: $store.profileTarget) { target in
      VStack {
        HStack {
          Spacer()
          Button("关闭") { store.profileTarget = nil }
        }.padding()
        ProfilePage(store: store, mid: target.id).padding(.horizontal, 16).padding(.bottom, 16)
      }.frame(minWidth: 900, minHeight: 650).background { GlassBackdrop() }
    }
    .overlay(alignment: .bottom) {
      if let text = store.interactionMessage {
        HStack {
          Text(text)
          Button {
            store.interactionMessage = nil
          } label: {
            Image(systemName: "xmark")
          }.buttonStyle(.plain)
        }.padding(14).blurPanel(Capsule()).padding(20)
      }
    }
    .sheet(isPresented: $store.showLogin, onDismiss: { store.closeLogin() }) {
      LoginSheet(store: store)
    }
    .task {
      await store.start()
      let args = ProcessInfo.processInfo.arguments
      if let i = args.firstIndex(of: "--full-coin-check"), args.indices.contains(i + 2) {
        await Diagnostics.fullCoinCheck(api: store.api, bvid: args[i + 1], output: URL(fileURLWithPath: args[i + 2]),
          showChallenge: args.contains("--show-coin-challenge") ? { diagnosticChallenge = $0 } : nil)
      }
      if let i = args.firstIndex(of: "--message-read-checks"), args.indices.contains(i + 1) { await Diagnostics.messageReadCheck(store: store, output: URL(fileURLWithPath: args[i + 1])) }
      if let i = args.firstIndex(of: "--feature-read-checks"), args.indices.contains(i + 1) { await Diagnostics.featureReadChecks(store: store, output: URL(fileURLWithPath: args[i + 1])) }
      if let i = args.firstIndex(of: "--preview-read-check"), args.indices.contains(i + 2) { await Diagnostics.previewReadCheck(api: store.api, bvid: args[i + 1], output: URL(fileURLWithPath: args[i + 2])) }
      if let i = args.firstIndex(of: "--special-diagnostics"), args.indices.contains(i + 2) {
        await Diagnostics.special(store: store, output: URL(fileURLWithPath: args[i + 1]), bvid: args[i + 2])
      }
      if let i = args.firstIndex(of: "--native-diagnostics"), args.indices.contains(i + 1) {
        await Diagnostics.nativeFeatures(store: store, output: URL(fileURLWithPath: args[i + 1]))
      }
      if let i = args.firstIndex(of: "--community-diagnostics"), args.indices.contains(i + 1) {
        await Diagnostics.community(store: store, output: URL(fileURLWithPath: args[i + 1]))
      }
      if let i = args.firstIndex(of: "--video-diagnostics"), args.indices.contains(i + 2) {
        await Diagnostics.run(
          store: store, output: URL(fileURLWithPath: args[i + 1]), bvids: [args[i + 2]])
      }
      if let i = args.firstIndex(of: "--diagnostics"), args.indices.contains(i + 1) {
        await Diagnostics.run(store: store, output: URL(fileURLWithPath: args[i + 1]))
      }
    }
    .task {
      let args = ProcessInfo.processInfo.arguments
      if let i = args.firstIndex(of: "--state-output"), args.indices.contains(i + 1) {
        await Diagnostics.state(store: store, output: URL(fileURLWithPath: args[i + 1]))
      }
    }
    .task(id: "\(phase):\(store.api.authenticationGeneration):\(store.account?.mid ?? 0)") {
      guard store.account != nil else { store.messageUnread.reset(); return }
      guard phase == .active else { return }
      await store.messageUnread.poll(api: store.api)
    }
    .onDisappear {
      store.playback.stop()
      store.danmaku.stop()
      store.comments.stop()
      store.downloads.persist()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
      store.playback.saveCurrentProgress()
    }
    .onChange(of: store.searchFocus) { searchFocused = true }
    .onChange(of: store.playerFocus) { searchFocused = false; store.playback.focusPlayer() }
    .onChange(of: store.navigationRevision) {
      if !store.showPlayer { searchFocused = false; NSApp.keyWindow?.makeFirstResponder(nil) }
    }
  }
  private func navigationButtons(_ items: [Destination]) -> some View {
    HStack(spacing: 4) {
      ForEach(items) { d in
        Button {
          store.navigate(d)
        } label: {
          let selected = store.destination == d && !store.showPlayer
          Image(systemName: d.icon)
            .font(.system(size: 17, weight: selected ? .semibold : .regular))
            .frame(width: 20, height: 20)
            .overlay(alignment: .topTrailing) { railIndicator(d).accessibilityHidden(true) }
            .frame(width: 34, height: 34).contentShape(
              RoundedRectangle(cornerRadius: 10)
            )
            .background(selected ? biliPink.opacity(0.19) : .clear, in: .rect(cornerRadius: 10))
            .foregroundStyle(.primary)
        }.buttonStyle(NavigationButtonStyle()).tint(.primary).help(d.rawValue)
          .accessibilityLabel(railLabel(d))
      }
    }
  }
  @ViewBuilder private func railIndicator(_ d: Destination) -> some View {
    if d == .messages && store.messageUnread.counts.total > 0
      || d == .downloads && store.downloads.activeCount > 0 {
      Circle().fill(biliPink).frame(width: 7, height: 7).offset(x: 4, y: -3)
    }
  }
  private func railLabel(_ d: Destination) -> String {
    switch d {
    case .messages where store.messageUnread.counts.total > 0:
      "\(d.rawValue)，\(store.messageUnread.counts.total) 条未读"
    case .downloads where store.downloads.activeCount > 0:
      "\(d.rawValue)，\(store.downloads.activeCount) 个下载中"
    default: d.rawValue
    }
  }
  private var accountAvatar: some View {
    Group {
      if let account = store.account {
        Menu {
          Button("我的主页") { store.navigate(.profile) }
          SettingsLink { Text("设置") }
          Button("重新登录") { store.login() }
          Button("退出登录", role: .destructive) { store.logout() }
        } label: {
          Thumbnail(url: account.face, mode: .fill, placeholder: "person.crop.circle.fill")
            .frame(width: 32, height: 32).clipShape(
              Circle())
            .frame(width: 40, height: 40).contentShape(Rectangle())
        }.buttonStyle(.plain).menuIndicator(.hidden).help(account.name)
          .accessibilityLabel(account.name)
      } else if store.restoring {
        ProgressView().controlSize(.small).frame(width: 40, height: 40)
      } else {
        Button {
          store.login()
        } label: {
          Image(systemName: "person.crop.circle").font(.title2).frame(width: 40, height: 40)
        }.buttonStyle(.plain).help("登录").accessibilityLabel("登录")
      }
    }
  }
  private var searchField: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
      TextField("搜索视频或粘贴 BV 号", text: $store.query).focused($searchFocused).textFieldStyle(.plain)
        .onSubmit { store.search() }
        .onExitCommand { searchFocused = false; NSApp.keyWindow?.makeFirstResponder(nil) }
      if !store.query.isEmpty {
        Button {
          store.clearSearch()
        } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
        }.buttonStyle(.plain).help("清除搜索")
      }
    }.padding(.horizontal, 15).frame(minWidth: 160, maxWidth: 520).frame(height: 44).appGlass(22)
  }
  private var topbar: some View {
    HStack(spacing: 10) {
      accountAvatar
      Divider().opacity(0.6).frame(height: 26)
      navigationButtons([.recommend, .popular, .regions, .dynamic, .messages])
      Divider().opacity(0.6).frame(height: 26)
      navigationButtons([.history, .favorites, .later, .downloads, .profile, .web])
      Divider().opacity(0.6).frame(height: 26)
      searchField
      Spacer(minLength: 0)
      if store.showPlayer {
        Button {
          store.backFromPlayer()
        } label: {
          Image(systemName: "chevron.left")
        }.buttonStyle(.panel).keyboardShortcut(.leftArrow, modifiers: .command)
          .help(UserDefaults.standard.bool(forKey: "stopPlaybackOnBack") ? "返回并停止播放（⌘←）" : "返回，小窗口继续播放（⌘←）")
      }
      Button {
        if store.showPlayer { store.playback.retry(api: store.api) } else { store.reload() }
      } label: {
        Image(systemName: "arrow.clockwise")
      }.keyboardShortcut("r", modifiers: .command).help("刷新（⌘R）")
    }.buttonStyle(.panel).padding(.horizontal, 12).frame(height: AppLayout.toolbarHeight)
      .background { Color.clear.titleBarBehavior() }.floatingGlass(AppLayout.panelRadius)
  }
  private var content: some View {
    ZStack {
      Group {
        switch store.destination {
        case .recommend, .popular, .regions, .favorites, .later: browse
        case .dynamic: NativeDynamicsPage(store: store)
        case .profile:
          if let account = store.account {
            ProfilePage(store: store, mid: account.mid)
          } else {
            ContentUnavailableView {
              Label("登录后查看主页", systemImage: "person.crop.circle")
            } actions: {
              Button("登录") { store.login() }
            }
          }
        case .history: HistoryPage(store: store)
        case .downloads: DownloadPage(store: store)
        case .messages: NativeInboxPage(store: store)
        case .web: WebFunctionsPage(store: store)
        }
      }
      .opacity(store.showPlayer ? 0 : 1)
      .allowsHitTesting(!store.showPlayer)
      .accessibilityHidden(store.showPlayer)
      if store.showPlayer {
        PlayerPage(store: store)
      }
    }
  }
  private var browse: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        HStack(alignment: .firstTextBaseline) {
          Text(store.activeQuery.isEmpty ? store.destination.rawValue : "搜索结果").font(
            .system(size: 28, weight: .bold))
          if !store.activeQuery.isEmpty { Text(store.activeQuery).foregroundStyle(.secondary) }
          Spacer()
          if store.busy { ProgressView().controlSize(.small) }
        }
        if !store.activeQuery.isEmpty { SearchFilters(store: store) }
        if store.destination == .regions && store.activeQuery.isEmpty { RegionSelector(store: store) }
        if [.favorites, .later].contains(store.destination) && store.activeQuery.isEmpty { LibraryToolbar(store: store) }
        if store.destination == .favorites && !store.folders.isEmpty {
          Picker("收藏夹", selection: $store.selectedFolder) {
            ForEach(store.folders) { f in Text(f.title + "（\(f.count)）").tag(f.id) }
          }.pickerStyle(.menu).onChange(of: store.selectedFolder) {
            store.videos = []
            store.reload()
          }
        }
        if let error = store.error, store.videos.isEmpty { ErrorBanner(text: error) { store.reload() } }
        if store.videos.isEmpty && store.searchUsers.isEmpty && !store.busy && !store.restoring && store.error == nil {
          ContentUnavailableView(
            "没有找到视频", systemImage: "magnifyingglass", description: Text("换个关键词试试"))
        }
        if !store.activeQuery.isEmpty && store.searchOptions.users { SearchUserResults(store: store) } else {
          videoGrid(store.destination == .later && !store.libraryQuery.isEmpty ? store.videos.filter { $0.title.localizedCaseInsensitiveContains(store.libraryQuery) || $0.author.localizedCaseInsensitiveContains(store.libraryQuery) } : store.videos)
        }
        if !store.videos.isEmpty || (!store.activeQuery.isEmpty && !store.searchUsers.isEmpty) {
          LoadMoreFooter(loading: store.busy, hasMore: store.hasMore, error: store.error, count: store.videos.count + store.searchUsers.count) { store.more() }
        }
      }.padding(AppLayout.pageInset).padding(.vertical, 8)
    }.pausesCardHoverWhileScrolling()
      .overlay { if store.busy && store.videos.isEmpty { ProgressView("正在加载") } }
  }
  private func videoGrid(_ videos: [Video]) -> some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 240, maximum: 390), spacing: 18)], alignment: .leading,
      spacing: 20
    ) {
      ForEach(videos.filter { !store.blockedAuthors.contains($0.ownerID ?? 0) }) { video in
        Button {
          store.openFeedVideo(video)
        } label: {
          VideoCard(video: video)
        }.buttonStyle(.plain).contextMenu {
          Button("播放") { store.open(video.bvid) }
          Button("稍后再看") { Task { do { let aid = try await store.api.videoAid(video); await store.addLater(aid) } catch { store.interactionMessage = error.localizedDescription } } }
          if store.destination == .later { Button("从稍后再看移除") { Task { do { try await store.api.removeWatchLater(video); store.reload() } catch { store.interactionMessage = error.localizedDescription } } } }
          Button("复制链接") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(
              "https://www.bilibili.com/video/\(video.bvid)", forType: .string)
          }
          Link("在浏览器打开", destination: URL(string: "https://www.bilibili.com/video/\(video.bvid)")!)
          VideoContextActions(store: store, video: video)
        }
      }
    }
  }
}
struct VideoCard: View {
  let video: Video
  var showsViews = true
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Thumbnail(url: video.cover, mode: .fill).aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12)).overlay(alignment: .bottomTrailing) {
          Text(Self.durationText(video.duration)).font(.caption.monospacedDigit()).foregroundStyle(.white)
            .padding(EdgeInsets(top: 4, leading: 7, bottom: 4, trailing: 7))
            .background(.black.opacity(0.72), in: Capsule()).padding(8)
        }
      Text(video.title).font(.system(size: 14, weight: .medium)).lineLimit(2)
        .frame(height: 38, alignment: .topLeading).foregroundStyle(.primary)
      HStack(spacing: 6) {
        Text(video.author).lineLimit(1)
        Spacer(minLength: 2)
        if showsViews {
          Image(systemName: "play").font(.system(size: 9))
          Text(Self.countText(video.views))
        }
      }.font(.caption).foregroundStyle(.secondary)
    }.padding(12).cardSurface(22).contentShape(RoundedRectangle(cornerRadius: 22)).cardHover()
  }
  static func countText(_ value: Int) -> String {
    value >= 10000 ? String(format: "%.1f万", Double(value) / 10000) : "\(value)"
  }
  static func durationText(_ t: Int) -> String {
    t >= 3600
      ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60)
      : String(format: "%d:%02d", t / 60, t % 60)
  }
}
struct Thumbnail: View {
  let url: String
  let mode: ContentMode
  var placeholder = "play.rectangle"
  @State private var loaded: (url: String, image: CGImage)?
  @State private var pixels = 0
  @Environment(\.displayScale) private var displayScale
  var body: some View {
    let target = Self.target(url)
    // Lazy grids drop a cell's state once it scrolls away; reading the memory
    // cache here lets a returning cell paint its cover on the first frame.
    let image = loaded?.url == url ? loaded?.image : target.flatMap { ThumbnailCache.shared.cached($0, maxPixelSize: 0) }
    Color.clear.overlay {
      if let image {
        Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: mode)
      } else {
        Rectangle().fill(.quaternary).overlay {
          Image(systemName: placeholder).font(.title).foregroundStyle(.tertiary)
        }
      }
    }.clipped()
    .onGeometryChange(for: Int.self) {
      ThumbnailCache.pixelSize(Int(max($0.size.width, $0.size.height) * displayScale))
    } action: { pixels = $0 }
    .task(id: "\(url)|\(pixels)") {
      guard pixels > 0, let target else { return }
      if let hit = ThumbnailCache.shared.cached(target, maxPixelSize: pixels) { loaded = (url, hit); return }
      guard let decoded = try? await ThumbnailCache.shared.thumbnail(target, maxPixelSize: pixels), !Task.isCancelled
      else { return }
      loaded = (url, decoded)
    }
  }
  private static func target(_ url: String) -> URL? {
    URL(string: url.hasPrefix("//") ? "https:" + url : url.replacingOccurrences(of: "http://", with: "https://"))
  }
}
struct ErrorBanner: View {
  let text: String
  let retry: () -> Void
  var body: some View {
    HStack {
      Image(systemName: "exclamationmark.circle")
      Text(text).textSelection(.enabled)
      Spacer()
      Button("重试", action: retry)
    }.padding(16).floatingGlass(18)
  }
}
struct PlayerPage: View {
  @Bindable var store: Store
  var body: some View {
    @Bindable var p = store.playback
    GeometryReader { viewport in
      HStack(alignment: .top, spacing: 16) {
        stage(p)
        PlayerSidebar(store: store).frame(width: min(405, max(305, viewport.size.width * 0.32 - 15)))
      }
    }.task(id: p.selectedCID) {
      if p.isOffline {
        store.danmaku.start(
          cid: p.selectedCID, api: store.api, player: p.player, localSidecar: p.localDanmaku)
      } else {
        store.danmaku.start(
          cid: p.selectedCID, aid: p.detail?.aid ?? 0, api: store.api, player: p.player)
      }
      if let detail = p.detail, !p.isOffline { await store.extras.load(detail: detail, cid: p.selectedCID, api: store.api) }
    }
  }
  /// The left column never scrolls. The video box takes every point the
  /// controls leave, so they stay pinned to the bottom edge; the player
  /// letterboxes inside it whatever the window's aspect ratio.
  private func stage(_ p: Playback) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      ZStack {
        NativePlayer(playback: p, items: store.danmaku.items, enabled: store.danmaku.enabled, toggleFullscreen: { store.fullscreen.open(store: store) })
        PlaybackStatusOverlay(playback: p)
        SubtitleOverlay(extras: store.extras, playback: p)
      }.frame(maxWidth: .infinity, minHeight: 180, maxHeight: .infinity)
        .background(.black).clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .top) {
          if p.isBoosting { Label(p.boostLabel, systemImage: "forward.fill").font(.callout).padding(10).blurPanel(Capsule()).padding(16).colorScheme(.dark).allowsHitTesting(false) }
        }
        .overlay { PlaybackDetailsOverlay(playback: p) }
      VStack(alignment: .leading, spacing: 12) {
        PlayerControls(playback: p, toggleFullscreen: { store.fullscreen.open(store: store) }, extras: store.extras)
        fitOrScroll(playbackRow(p))
        if let error = p.error { ErrorBanner(text: error) { p.retry(api: store.api) } }
        if let d = p.detail, d.aid > 0 { DanmakuComposer(store: store, aid: d.aid) }
      }.fixedSize(horizontal: false, vertical: true)
    }.padding(16).floatingGlass(24).clipShape(RoundedRectangle(cornerRadius: 24))
  }
  /// Rows keep their natural layout when they fit and scroll sideways when the sidebar squeezes them.
  private func fitOrScroll<Row: View>(_ row: Row) -> some View {
    ViewThatFits(in: .horizontal) {
      row
      ScrollView(.horizontal) { row }.scrollIndicators(.hidden)
    }
  }
  /// One row: features, quality and speed on the left; danmaku, details and download on the right.
  private func playbackRow(_ p: Playback) -> some View {
    HStack(spacing: 12) {
      PlaybackFeatureControls(store: store)
      if let s = p.streams {
        Menu {
          ForEach(Array(Set(s.videos.map(\.id))).sorted(by: >), id: \.self) { qn in
            Button {
              p.selectQuality(qn, api: store.api)
            } label: {
              if qn == p.selectedQuality {
                Label(s.names[qn] ?? "\(qn)", systemImage: "checkmark")
              } else {
                Text(s.names[qn] ?? "\(qn)")
              }
            }
          }
        } label: {
          Label(s.names[p.selectedQuality] ?? "清晰度", systemImage: "slider.horizontal.3")
        }.buttonStyle(.panel).help(formatSummary(p))
      }
      Menu {
        ForEach([0.5, 0.75, 1, 1.25, 1.5, 2], id: \.self) { rate in
          Button("\(rate.formatted())×") { p.setSpeed(Float(rate)) }
        }
      } label: {
        Text("\(Double(p.speed).formatted())×")
      }.buttonStyle(.panel)
      Spacer(minLength: 12)
      if let error = store.extras.subtitleError { Text(error).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
      Toggle("弹幕", isOn: $store.danmaku.enabled).toggleStyle(.switch).fixedSize()
        .onChange(of: store.danmaku.enabled) { UserDefaults.standard.set(store.danmaku.enabled, forKey: "danmakuEnabled") }
      Button { p.showsDetails.toggle() } label: { Image(systemName: "waveform.path.ecg") }.help("播放详情").accessibilityLabel("播放详情")
      if let d = p.detail, p.streams != nil {
        Menu {
          Button("缓存到应用") {
            store.downloads.enqueue(
              video: d.video, cid: p.selectedCID, qn: p.selectedQuality, api: store.api,
              cached: true)
          }
          Button("下载到其他位置…") {
            store.downloads.enqueue(
              video: d.video, cid: p.selectedCID, qn: p.selectedQuality, api: store.api,
              cached: false)
          }
          Divider()
          Button("下载弹幕 XML…") {
            Task {
              await store.downloads.saveDanmaku(
                video: d.video, cid: p.selectedCID, api: store.api)
            }
          }
        } label: {
          Label("下载", systemImage: "arrow.down")
        }.buttonStyle(.panel).disabled(p.loading)
      }
    }.buttonStyle(.panel).controlSize(.regular)
  }
  /// Decoded size and codec moved off the row into the quality button's tooltip.
  private func formatSummary(_ p: Playback) -> String {
    let size = p.actualSize.isEmpty ? "" : p.actualSize + (p.sourceFormat.isEmpty ? "" : " · " + p.sourceFormat)
    let lines = [size, p.decodedFormat].filter { !$0.isEmpty }
    return lines.isEmpty ? "清晰度" : lines.joined(separator: "\n")
  }
}
struct LoginSheet: View {
  @Bindable var store: Store
  var body: some View {
    VStack(spacing: 20) {
      HStack {
        Text("登录哔哩哔哩").font(.title2.weight(.semibold))
        Spacer()
        Button {
          store.showLogin = false
        } label: {
          Image(systemName: "xmark")
        }.buttonStyle(.panel).help("关闭")
      }
      ZStack {
        RoundedRectangle(cornerRadius: 16).fill(.white)
        if let image = store.qrImage {
          Image(nsImage: image).interpolation(.none).resizable().scaledToFit().padding(16).opacity(
            store.loginExpired ? 0.15 : 1)
        }
        if store.qrImage == nil && !store.loginExpired { ProgressView() }
        if store.loginExpired { Button("刷新二维码") { store.refreshQR() }.buttonStyle(.panel) }
      }.frame(width: 230, height: 230)
      Text(store.loginStatus).font(.callout).foregroundStyle(.secondary)
      Text("一次扫码即可使用浏览、收藏与投币。登录不会自动投币。")
        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
      Text("登录信息保存在 macOS 钥匙串").font(.caption).foregroundStyle(.tertiary)
    }.padding(28).frame(width: 380).background { GlassBackdrop() }
  }
}
