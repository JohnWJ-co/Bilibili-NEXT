import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import CoreImage

enum AppLayout {
  static let toolbarHeight: CGFloat = 68
  static let panelRadius: CGFloat = 24
  static let pageInset: CGFloat = 8
  static let pageTitle: Font = .system(size: 28, weight: .bold)
}

/// Neutral press feedback without inheriting the window's accent tint.
struct NavigationButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.foregroundStyle(.primary)
      .opacity(configuration.isPressed ? 0.72 : 1)
  }
}

extension View {
  func floatingGlass(_ radius: CGFloat = 22) -> some View { appGlass(radius, tint: .primary.opacity(0.035)) }
  func appGlass(_ radius: CGFloat = 14, tint: Color = .clear) -> some View {
    blurPanel(RoundedRectangle(cornerRadius: radius), tint: tint)
  }
  func blurPanel<S: InsettableShape>(_ shape: S, tint: Color = .clear) -> some View {
    modifier(BlurSurface(shape: shape, tint: tint))
  }
  func appAppearance() -> some View { modifier(AppAppearance()) }
  func cardSurface(_ radius: CGFloat = 22, tint: Color = .clear) -> some View {
    modifier(CardSurface(radius: radius, tint: tint))
  }
  func cardHover() -> some View { modifier(CardHover()) }
  func pausesCardHoverWhileScrolling() -> some View { modifier(ScrollHoverPause()) }
}
extension EnvironmentValues {
  /// Set while the enclosing scroll view moves, so cards sliding under a still pointer don't animate.
  @Entry var cardHoverSuspended = false
}
private func panelEdge(_ scheme: ColorScheme) -> Color {
  scheme == .dark ? .white.opacity(0.08) : .black.opacity(0.06)
}
/// Plain Gaussian blur for fixed panels. Liquid Glass layers refraction,
/// specular highlights and shape morphing on top, re-rendered as content moves.
private struct BlurSurface<S: InsettableShape>: ViewModifier {
  let shape: S
  let tint: Color
  @AppStorage("glassStyle") private var style = "clear"
  @Environment(\.colorScheme) private var scheme
  func body(content: Content) -> some View {
    content.background {
      ZStack {
        shape.fill(style == "clear" ? Material.ultraThin : Material.regular)
        if tint != .clear { shape.fill(tint) }
        shape.strokeBorder(panelEdge(scheme), lineWidth: 1)
      }
    }
  }
}
/// Static fill for rows and cards in long scrolling lists: any backdrop blur
/// re-samples behind every visible row on every scrolled frame.
private struct CardSurface: ViewModifier {
  let radius: CGFloat
  let tint: Color
  @Environment(\.colorScheme) private var scheme
  func body(content: Content) -> some View {
    content.background {
      let shape = RoundedRectangle(cornerRadius: radius)
      ZStack {
        shape.fill(scheme == .dark ? Color(white: 0.2).opacity(0.45) : Color.white.opacity(0.55))
        if tint != .clear { shape.fill(tint) }
        shape.strokeBorder(panelEdge(scheme), lineWidth: 1)
      }
    }
  }
}
/// Replaces the system glass buttons: one solid pink fill everywhere, no backdrop
/// sampling. The fill ignores `.tint` so a neutral tint can't wash out the label.
struct PanelButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.controlSize) private var controlSize
  func makeBody(configuration: Configuration) -> some View {
    let small = controlSize == .small || controlSize == .mini
    configuration.label
      .foregroundStyle(.white)
      .padding(.horizontal, small ? 8 : 10).padding(.vertical, small ? 3 : 4)
      .frame(minHeight: small ? 20 : 24)
      .background(biliPink, in: .rect(cornerRadius: small ? 5 : 6))
      .contentShape(.rect(cornerRadius: 6))
      .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.4)
  }
}
extension ButtonStyle where Self == PanelButtonStyle {
  static var panel: PanelButtonStyle { PanelButtonStyle() }
}
private struct ScrollHoverPause: ViewModifier {
  @State private var scrolling = false
  func body(content: Content) -> some View {
    content.environment(\.cardHoverSuspended, scrolling)
      .onScrollPhaseChange { _, phase in scrolling = phase.isScrolling }
  }
}
private struct AppAppearance: ViewModifier {
  @AppStorage("appearance") private var appearance = "dark"
  func body(content: Content) -> some View {
    content.preferredColorScheme(appearance == "system" ? nil : appearance == "light" ? .light : .dark)
  }
}
private struct CardHover: ViewModifier {
  @State private var hovering = false
  @AppStorage("interfaceAnimations") private var animations = true
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.cardHoverSuspended) private var suspended
  func body(content: Content) -> some View {
    let lifted = hovering && !suspended && animations && !reduceMotion
    // Hit testing off while scrolling keeps the hover dispatcher from walking
    // every card the content slides under the pointer.
    content.scaleEffect(lifted ? 1.012 : 1)
      .animation(animations && !reduceMotion ? .smooth(duration: 0.18) : nil, value: lifted)
      .onHover { hovering = $0 }
      .allowsHitTesting(!suspended)
  }
}
struct GlassBackdrop: View {
  @Environment(\.colorScheme) private var scheme
  @AppStorage("backgroundImage") private var path = ""
  @AppStorage("backgroundBlur") private var blur = false
  @AppStorage("backgroundOpacity") private var opacity = 0.7
  @State private var image: NSImage?
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        LinearGradient(colors: scheme == .dark ? [Color(red: 0.025, green: 0.05, blue: 0.09), Color(red: 0.13, green: 0.20, blue: 0.28)] :
          [Color(red: 0.94, green: 0.96, blue: 0.99), Color(red: 0.79, green: 0.85, blue: 0.92)],
          startPoint: .topLeading, endPoint: .bottomTrailing)
        RadialGradient(colors: [.cyan.opacity(scheme == .dark ? 0.12 : 0.13), .clear],
                       center: .bottomLeading, startRadius: 30, endRadius: 850)
        RadialGradient(colors: [biliPink.opacity(0.12), .clear], center: .topTrailing, startRadius: 0, endRadius: 650)
        if let image, !path.isEmpty {
          Image(nsImage: image).resizable().scaledToFill()
            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
            .opacity(opacity)
          (scheme == .dark ? Color.black : Color.white).opacity(scheme == .dark ? 0.18 : 0.25)
        }
      }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
      .task(id: BackgroundRequest(path: path, blur: blur, size: geometry.size)) {
        let request = BackgroundRequest(path: path, blur: blur, size: geometry.size)
        guard !path.isEmpty else { image = nil; return }
        let decoded = try? await BackgroundImages.shared.render(request)
        guard !Task.isCancelled else { return }
        guard let decoded else { image = nil; return }
        image = NSImage(cgImage: decoded, size: .zero)
      }
    }.ignoresSafeArea().allowsHitTesting(false)
  }
}
/// Quantized layout avoids decoding/blur work for every pixel of a window resize.
struct BackgroundRequest: Hashable, Sendable {
  let path: String
  let blur: Bool
  let width: Int
  let height: Int
  init(path: String, blur: Bool, size: CGSize) {
    self.path = path; self.blur = blur
    width = max(128, Int(ceil(size.width / 128)) * 128)
    height = max(128, Int(ceil(size.height / 128)) * 128)
  }
}
actor BackgroundImages {
  static let shared = BackgroundImages()
  private var cached: (URL, CGImage)?
  private var rendered: (BackgroundRequest, CGImage)?
  private let context = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])
  func trimMemory() { cached = nil; rendered = nil; context.clearCaches() }
  func render(_ request: BackgroundRequest) throws -> CGImage {
    try Task.checkCancellation()
    if let rendered, rendered.0 == request { return rendered.1 }
    let image = try load(URL(fileURLWithPath: request.path))
    guard request.blur else { return image }
    let scale = max(Double(request.width) / Double(image.width), Double(request.height) / Double(image.height))
    let source = CIImage(cgImage: image)
    let blurred = source.clampedToExtent()
      .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 22 / scale])
      .cropped(to: source.extent)
    guard let output = context.createCGImage(blurred, from: source.extent) else { return image }
    try Task.checkCancellation()
    rendered = (request, output)
    return output
  }
  func load(_ url: URL) throws -> CGImage {
    if let cached, cached.0 == url { return cached.1 }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 3200, kCGImageSourceShouldCacheImmediately: true,
      ] as CFDictionary) else { throw BiliError(text: "无法读取这张背景图片") }
    cached = (url, image)
    rendered = nil
    return image
  }
  func importImage(_ original: URL) throws -> URL {
    let image = try load(original)
    let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("BiliGlass/Appearance")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent(UUID().uuidString + ".png")
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
      throw BiliError(text: "无法保存背景图片")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw BiliError(text: "无法保存背景图片") }
    cached = (url, image)
    return url
  }
}
