import Testing
@testable import BiliGlass

struct DefaultQualityTests {
  @Test func automaticUsesHighestAvailable() {
    #expect(DefaultQuality.resolve(0, available: [16, 64, 80]) == 80)
    #expect(DefaultQuality.resolve(0, available: []) == nil)
  }

  @Test func fullHDPrefersHighest1080PVariant() {
    #expect(DefaultQuality.resolve(80, available: [80, 112, 116, 120]) == 116)
    #expect(DefaultQuality.resolve(80, available: [80, 120]) == 80)
    #expect(DefaultQuality.resolve(80, available: [112, 120]) == 112)
  }

  @Test func missingTierFallsBackToHighestAvailable() {
    #expect(DefaultQuality.resolve(80, available: [16, 64, 120]) == 120)
    #expect(DefaultQuality.resolve(127, available: [16, 64]) == 64)
  }

  @Test func hdFamilyAndExactTiers() {
    #expect(DefaultQuality.resolve(64, available: [64, 74]) == 74)
    #expect(DefaultQuality.resolve(32, available: [16, 32, 64]) == 32)
  }
}
