import Testing
@testable import OpenCanCore

@Test func pfRulesForwardPublicPortsToBindPorts() {
    let rules = SystemSetup.pfRules([
        .init(from: 443, to: 8443),
        .init(from: 80, to: 8080),
    ])
    #expect(rules.contains("port = 443 -> 127.0.0.1 port 8443"))
    #expect(rules.contains("port = 80 -> 127.0.0.1 port 8080"))
    #expect(rules.contains("rdr pass on lo0"))
}
