import Foundation
import ImageIO

actor ThumbnailCache {
  static let shared = ThumbnailCache()
  private let cache: URLCache
  private let session: URLSession
  /// Keyed by URL alone; an entry serves any request at or below the size it was decoded for.
  private final class Entry {
    let image: CGImage
    let pixels: Int
    init(image: CGImage, pixels: Int) { self.image = image; self.pixels = pixels }
  }
  // NSCache is thread-safe, so views read it synchronously while scrolling
  // instead of waiting a frame on the actor and flashing the placeholder.
  private nonisolated(unsafe) let decoded = NSCache<NSString, Entry>()
  private var inFlight: [String: Task<CGImage, Error>] = [:]
  private var generation = UUID()
  init() {
    cache = URLCache(
      memoryCapacity: 0, diskCapacity: 128 * 1024 * 1024,
      directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("BiliGlass/Thumbnails", isDirectory: true))
    let c = URLSessionConfiguration.default
    c.urlCache = cache
    c.httpCookieStorage = nil
    c.timeoutIntervalForRequest = 20
    session = URLSession(configuration: c)
    // About 90 grid covers at the 900px bucket: several screens of scroll-back.
    decoded.totalCostLimit = 160 * 1024 * 1024
    decoded.countLimit = 400
  }
  /// Synchronous memory-cache lookup; `maxPixelSize` 0 accepts any decoded size.
  nonisolated func cached(_ url: URL, maxPixelSize: Int) -> CGImage? {
    guard let entry = decoded.object(forKey: url.absoluteString as NSString),
      maxPixelSize == 0 || entry.pixels >= Self.pixelSize(maxPixelSize) else { return nil }
    return entry.image
  }
  func data(_ url: URL) async throws -> Data {
    guard url.scheme == "https", let host = url.host,
      host == "hdslb.com" || host.hasSuffix(".hdslb.com") || host == "biliimg.com"
        || host.hasSuffix(".biliimg.com")
    else { throw BiliError(text: "封面地址无效") }
    let token = generation
    var request = URLRequest(url: url)
    API.mediaHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
    let (data, response) = try await session.data(for: request)
    try Task.checkCancellation()
    guard token == generation else { throw CancellationError() }
    guard (response as? HTTPURLResponse)?.statusCode == 200,
      response.mimeType?.hasPrefix("image/") == true, data.count < 64 * 1024 * 1024
    else { throw BiliError(text: "封面不可用") }
    return data
  }
  /// Quantized sizes avoid re-decoding on each window-resize pixel.
  nonisolated static func pixelSize(_ requested: Int) -> Int {
    [128, 256, 512, 900].first { $0 >= requested } ?? 900
  }
  func thumbnail(_ url: URL, maxPixelSize: Int = 900) async throws -> CGImage {
    let pixels = Self.pixelSize(maxPixelSize)
    let key = "\(pixels)|\(url.absoluteString)"
    if let image = cached(url, maxPixelSize: pixels) { return image }
    if let pending = inFlight[key] { return try await pending.value }
    let token = generation
    let pending = Task {
      let data = try await self.data(url)
      try Task.checkCancellation()
      return try await Self.decode(data, maxPixelSize: pixels)
    }
    inFlight[key] = pending
    defer { if token == generation { inFlight[key] = nil } }
    let image = try await pending.value
    try Task.checkCancellation()
    if token == generation, (decoded.object(forKey: url.absoluteString as NSString)?.pixels ?? 0) < pixels {
      decoded.setObject(Entry(image: image, pixels: pixels), forKey: url.absoluteString as NSString,
        cost: image.bytesPerRow * image.height)
    }
    return image
  }
  static func decode(_ data: Data, maxPixelSize: Int = 900) async throws -> CGImage {
    try await Task.detached(priority: .utility) {
      guard let source = CGImageSourceCreateWithData(data as CFData, nil),
        let image = CGImageSourceCreateThumbnailAtIndex(
          source, 0,
          [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize(maxPixelSize),
            kCGImageSourceShouldCacheImmediately: true,
          ] as CFDictionary)
      else { throw BiliError(text: "图片无法解码") }
      return image
    }.value
  }
  func trimMemory() {
    decoded.removeAllObjects()
  }
  func clear() {
    generation = UUID()
    inFlight.values.forEach { $0.cancel() }; inFlight.removeAll()
    decoded.removeAllObjects()
    cache.removeAllCachedResponses()
  }
}
