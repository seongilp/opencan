import Testing
@testable import OpenCanCore

@Test func packageVersionIsSet() {
    #expect(OpenCanCore.version == "0.1.0")
}
