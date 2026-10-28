import Foundation

/// 设置中的默认清晰度。存基础档位 ID；同一档位有多个码率/帧率版本时取最高可用的一条。
enum DefaultQuality: Int, CaseIterable, Identifiable {
  case automatic = 0
  case ultra8K = 127
  case ultra4K = 120
  case fullHD = 80
  case hd = 64
  case sd = 32
  case smooth = 16

  var id: Int { rawValue }

  var title: String {
    switch self {
    case .automatic: "自动（最高可用）"
    case .ultra8K: "8K"
    case .ultra4K: "4K"
    case .fullHD: "1080P"
    case .hd: "720P"
    case .sd: "480P"
    case .smooth: "360P"
    }
  }

  /// 1080P 与 720P 在 B 站会按码率、帧率拆成多个 qn。
  var familyIDs: [Int] {
    switch self {
    case .automatic: []
    case .fullHD: [80, 112, 116]
    case .hd: [64, 74]
    default: [rawValue]
    }
  }

  /// 优先取所设档位里最高的可用流；整个档位缺失时回退到视频提供的最高清晰度。
  static func resolve(_ raw: Int, available ids: [Int]) -> Int? {
    let highest = ids.max()
    guard let preference = DefaultQuality(rawValue: raw), preference != .automatic else {
      return highest
    }
    return preference.familyIDs.filter(ids.contains).max() ?? highest
  }
}
