import SwiftUI

/// Right-hand column of the player page, after the official web layout. The
/// stage beside it never scrolls, so reading recommendations or comments no
/// longer drags the video and danmaku layers through every scrolled frame.
struct PlayerSidebar: View {
  @Bindable var store: Store
  @State private var tab = Tab.intro
  private enum Tab { case intro, comments }
  var body: some View {
    let detail = store.playback.detail
    VStack(spacing: 0) {
      HStack(spacing: 24) {
        tabButton("简介", .intro)
        tabButton("评论", .comments, count: store.videoActions.counts.replies ?? detail?.counts.replies)
        Spacer()
      }.padding(.horizontal, 20)
      Divider()
      ScrollView {
        Group {
          if let detail {
            switch tab {
            case .intro: VideoIntro(store: store, detail: detail)
            case .comments:
              if detail.aid > 0 {
                CommentsView(store: store, aid: detail.aid, compactHeader: true)
              } else {
                Text("离线视频没有评论").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(30)
              }
            }
          } else if store.playback.loading {
            ProgressView().frame(maxWidth: .infinity).padding(40)
          }
        }.padding(20)
      }
      // A new video or tab starts at the top, like switching pages.
      .id("\(detail?.video.bvid ?? "")|\(tab)")
    }
    .floatingGlass(24).clipShape(RoundedRectangle(cornerRadius: 24))
    .onChange(of: detail?.video.bvid) { tab = .intro }
  }
  private func tabButton(_ title: String, _ value: Tab, count: Int? = nil) -> some View {
    Button { tab = value } label: {
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(title).font(.headline)
        if let count { Text(VideoCard.countText(count)).font(.caption).foregroundStyle(.secondary) }
      }
      .foregroundStyle(tab == value ? biliPink : .primary)
      .padding(.vertical, 14)
      .overlay(alignment: .bottom) {
        if tab == value { Capsule().fill(biliPink).frame(width: 20, height: 3) }
      }
      .contentShape(Rectangle())
    }.buttonStyle(.plain)
  }
}

private struct VideoIntro: View {
  @Bindable var store: Store
  let detail: Detail
  @State private var expanded = false
  @State private var owner: Profile?
  @State private var followBusy = false
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      ownerRow
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(detail.video.title).font(.title3.weight(.semibold)).lineLimit(expanded ? nil : 2)
            .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
          Spacer(minLength: 0)
          Button { expanded.toggle() } label: {
            HStack(spacing: 2) {
              Text(expanded ? "收起" : "展开")
              Image(systemName: expanded ? "chevron.up" : "chevron.down").imageScale(.small)
            }.font(.callout).foregroundStyle(.secondary).fixedSize()
          }.buttonStyle(.plain)
        }
        HStack(spacing: 14) {
          Label(VideoCard.countText(detail.video.views), systemImage: "play.rectangle")
          Label(VideoCard.countText(detail.counts.danmaku), systemImage: "text.bubble")
          if let date = detail.video.publishedAt {
            Label(date.formatted(AppDateFormat.timestamp), systemImage: "clock").help("发布时间 · 当前时区")
          }
        }.labelStyle(CompactLabelStyle()).font(.caption).foregroundStyle(.secondary)
        if expanded { details }
      }
      if detail.aid > 0 { VideoActionBar(store: store, detail: detail) }
      Divider()
      pages
      queue
      VideoDiscovery(store: store)
    }
    .task(id: detail.ownerID) {
      owner = nil
      guard detail.ownerID > 0 else { return }
      owner = try? await store.api.profile(detail.ownerID)
    }
  }
  private var ownerRow: some View {
    HStack(spacing: 12) {
      Button { store.showProfile(detail.ownerID) } label: {
        HStack(spacing: 10) {
          Thumbnail(url: owner?.face ?? detail.ownerFace, mode: .fill, placeholder: "person.crop.circle.fill")
            .frame(width: 44, height: 44).clipShape(Circle())
          VStack(alignment: .leading, spacing: 3) {
            Text(detail.video.author).font(.headline).lineLimit(1)
            if let owner {
              Text("\(VideoCard.countText(owner.fans))粉丝 · \(owner.videos)投稿").font(.caption).foregroundStyle(.secondary)
            }
          }
        }.contentShape(Rectangle())
      }.buttonStyle(.plain).disabled(detail.ownerID == 0)
      Spacer(minLength: 8)
      if detail.ownerID > 0 && detail.ownerID != store.account?.mid {
        let followed = owner?.isFollowed == true
        Button { Task { await toggleFollow() } } label: {
          Label(followed ? "已关注" : "关注", systemImage: followed ? "checkmark" : "plus")
            .font(.callout.weight(.medium)).padding(.horizontal, 14).frame(height: 30)
            .foregroundStyle(followed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white))
            .background(followed ? AnyShapeStyle(.primary.opacity(0.1)) : AnyShapeStyle(biliPink), in: .rect(cornerRadius: 8))
        }.buttonStyle(NavigationButtonStyle()).disabled(owner == nil || followBusy)
      }
    }
  }
  private var details: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(detail.video.bvid).font(.caption.monospaced()).foregroundStyle(.tertiary).textSelection(.enabled)
      if !detail.description.isEmpty {
        Text(detail.description).font(.callout).foregroundStyle(.secondary).lineSpacing(4).textSelection(.enabled)
      }
      if !store.extras.tags.isEmpty {
        ScrollView(.horizontal) {
          HStack(spacing: 6) {
            ForEach(store.extras.tags) { tag in
              Button(tag.title) { store.query = tag.title; store.search() }.buttonStyle(.plain)
                .font(.caption).padding(.horizontal, 10).padding(.vertical, 5)
                .background(.primary.opacity(0.08), in: Capsule())
            }
          }
        }.scrollIndicators(.hidden)
      }
    }
  }
  @ViewBuilder private var pages: some View {
    let playback = store.playback
    if detail.pages.count > 1 && !playback.isOffline {
      let index = detail.pages.firstIndex { $0.id == playback.selectedCID }.map { $0 + 1 } ?? 1
      EpisodeList(title: "视频选集", progress: "\(index)/\(detail.pages.count)", count: detail.pages.count) {
        ForEach(detail.pages) { page in
          EpisodeRow(title: "P\(page.number) \(page.title)", current: playback.selectedCID == page.id) {
            playback.selectPage(page.id, api: store.api, resume: store.position(detail.video.bvid, cid: page.id))
          }.disabled(playback.loading)
        }
      }
    }
  }
  @ViewBuilder private var queue: some View {
    if !store.currentQueue.isEmpty {
      EpisodeList(title: store.currentQueueTitle, progress: nil, count: store.currentQueue.count) {
        ForEach(store.currentQueue) { item in
          EpisodeRow(title: item.title, current: item.bvid == detail.video.bvid
            && (item.cid == nil || item.cid == store.playback.selectedCID)) { store.playQueueItem(item) }
        }
      }
    }
  }
  private func toggleFollow() async {
    guard store.account != nil else { store.login(); return }
    guard let current = owner, !followBusy else { return }
    followBusy = true
    defer { followBusy = false }
    do {
      _ = try await store.api.post(
        "/x/relation/modify", ["fid": "\(detail.ownerID)", "act": current.isFollowed ? "2" : "1", "re_src": "11"])
      owner?.isFollowed.toggle()
    } catch { store.interactionMessage = error.localizedDescription }
  }
}

/// Pages and playlists scroll inside a capped box so a long series doesn't
/// push recommendations several screens down.
private struct EpisodeList<Rows: View>: View {
  let title: String
  let progress: String?
  let count: Int
  @ViewBuilder let rows: Rows
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(title).font(.headline).lineLimit(1)
        if let progress { Text("(\(progress))").font(.caption).foregroundStyle(.secondary) }
      }
      ScrollView { LazyVStack(spacing: 2) { rows } }
        .frame(height: min(300, CGFloat(count) * EpisodeRow.height))
        .background(.primary.opacity(0.04), in: .rect(cornerRadius: 10))
    }
  }
}
private struct EpisodeRow: View {
  static let height: CGFloat = 36
  let title: String
  let current: Bool
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if current { Image(systemName: "waveform").foregroundStyle(biliPink) }
        Text(title).font(.callout).lineLimit(1).foregroundStyle(current ? biliPink : .primary)
        Spacer(minLength: 0)
      }.padding(.horizontal, 12).frame(height: Self.height)
        .background(current ? biliPink.opacity(0.12) : .clear, in: .rect(cornerRadius: 8))
        .contentShape(Rectangle())
    }.buttonStyle(.plain)
  }
}
