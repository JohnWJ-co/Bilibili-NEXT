import AppKit
import SwiftUI

extension View {
  /// Empty window chrome that behaves like the title bar `.hiddenTitleBar`
  /// removes: drag to move the window, double-click per the system setting.
  func titleBarBehavior() -> some View {
    contentShape(Rectangle())
      .gesture(WindowDragGesture())
      .allowsWindowActivationEvents(true)
      .onTapGesture(count: 2) { performTitleBarDoubleClick() }
  }
}

/// Mirrors System Settings › Desktop & Dock › "Double-click a window's title bar to".
@MainActor func performTitleBarDoubleClick() {
  guard let window = NSApp.keyWindow else { return }
  switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
  case "Minimize": window.performMiniaturize(nil)
  case "None": break
  default: window.performZoom(nil)
  }
}
