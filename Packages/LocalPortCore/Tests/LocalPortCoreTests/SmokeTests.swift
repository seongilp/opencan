import Testing
@testable import LocalPortCore

@Test func packageVersionIsSet() {
    #expect(LocalPortCore.version == "0.1.0")
}
