import Testing
@testable import OpenCanCore

@Test func plistContainsForwarderArgsForMappings() {
    let plist = RootHelper.launchdPlist([
        .init(publicPort: 443, bindPort: 48443),
        .init(publicPort: 80, bindPort: 48080),
    ])
    #expect(plist.contains("<string>com.opencan.helper</string>"))
    #expect(plist.contains("<string>/usr/bin/python3</string>"))
    #expect(plist.contains("<string>443:48443</string>"))
    #expect(plist.contains("<string>80:48080</string>"))
    #expect(plist.contains("<key>RunAtLoad</key>"))
}

@Test func forwarderScriptIsRunnablePython() {
    #expect(RootHelper.forwarderScript.contains("def serve("))
    #expect(RootHelper.forwarderScript.contains("create_connection"))
}
