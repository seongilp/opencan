import Testing
@testable import OpenCanCore

@Test func resolvesExactHost() async {
    let r = RouteResolver()
    await r.upsert(host: "myapp.localhost", upstream: Upstream(host: "127.0.0.1", port: 3000))
    let u = await r.upstream(forHostHeader: "myapp.localhost")
    #expect(u == Upstream(host: "127.0.0.1", port: 3000))
}

@Test func ignoresPortSuffixAndCase() async {
    let r = RouteResolver()
    await r.upsert(host: "MyApp.localhost", upstream: Upstream(host: "127.0.0.1", port: 8000))
    let u = await r.upstream(forHostHeader: "myapp.localhost:8443")
    #expect(u == Upstream(host: "127.0.0.1", port: 8000))
}

@Test func returnsNilForUnknownHost() async {
    let r = RouteResolver()
    let u = await r.upstream(forHostHeader: "nope.localhost")
    #expect(u == nil)
}

@Test func removeDropsRoute() async {
    let r = RouteResolver()
    await r.upsert(host: "a.localhost", upstream: Upstream(host: "127.0.0.1", port: 1))
    await r.remove(host: "a.localhost")
    let u = await r.upstream(forHostHeader: "a.localhost")
    #expect(u == nil)
}
