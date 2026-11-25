import Foundation

struct JournalEvent: Decodable { let op: String; let key: String; let now: Int; let value: String?; let ttl: Int? }
struct CheckFailed: Error { let message: String }
func check(_ value: Bool, _ message: String) throws { if !value { throw CheckFailed(message: message) } }

func tests() async throws {
    let cache = try Cache(capacity: 2)
    try await cache.put("a", value: "A", ttl: 10, now: 0)
    try await cache.put("b", value: "B", ttl: 10, now: 0)
    try check(try await cache.get("a", now: 1) == "A", "hit")
    try await cache.put("c", value: "C", ttl: 2, now: 1)
    try check(try await cache.get("b", now: 1) == nil, "LRU eviction")
    try check(try await cache.stats(now: 2).keysOldestFirst == ["a","c"], "order")
    try check(try await cache.get("c", now: 3) == nil, "expiration is inclusive")
    try await cache.put("a", value: "updated", ttl: 5, now: 3)
    try check(try await cache.get("a", now: 7) == "updated", "replacement renews TTL")
    try check(try await cache.get("a", now: 8) == nil, "renewed expiry")
    let stats = try await cache.stats(now: 8)
    try check(stats.hits == 2 && stats.misses == 3 && stats.evictions == 1 && stats.expirations == 2, "statistics")
    do { _ = try await cache.get("a", now: 7); throw CheckFailed(message: "reversed time accepted") } catch CacheError.clockReversed {}
    do { try await cache.put("a", value: "a", ttl: 0, now: 8); throw CheckFailed(message: "zero TTL accepted") } catch CacheError.invalidLifetime {}
    do { try await cache.put("a", value: "a", ttl: 1, now: Int.max); throw CheckFailed(message: "overflow accepted") } catch CacheError.timeOverflow {}
    do { _ = try Cache(capacity: 0); throw CheckFailed(message: "zero capacity accepted") } catch CacheError.invalidCapacity {}
    let concurrent = try Cache(capacity: 100)
    try await withThrowingTaskGroup(of: Void.self) { group in
        for index in 0..<100 { group.addTask { try await concurrent.put(String(index), value: String(index), ttl: 1, now: 0) } }
        try await group.waitForAll()
    }
    try check(try await concurrent.stats(now: 0).keysOldestFirst.count == 100, "concurrent writes isolated")
    print("12 cache checks passed")
}

@main struct Runner {
    static func main() async {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            if args == ["--test"] { try await tests(); return }
            if args.count != 1 || args == ["--help"] {
                print("Usage: swift run cache-journal journal.json | --test\nCapacity 2; timestamps and TTLs are explicit integer ticks.")
                if args != ["--help"] { exit(2) }; return
            }
            let events = try JSONDecoder().decode([JournalEvent].self, from: Data(contentsOf: URL(fileURLWithPath: args[0])))
            let cache = try Cache(capacity: 2)
            for event in events {
                switch event.op {
                case "put":
                    guard let value = event.value, let ttl = event.ttl else { throw CheckFailed(message: "put requires value and ttl") }
                    try await cache.put(event.key, value: value, ttl: ttl, now: event.now)
                case "get": print("\(event.key)=\(try await cache.get(event.key, now: event.now) ?? "<miss>")")
                default: throw CheckFailed(message: "unknown operation: \(event.op)")
                }
            }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(try await cache.stats(now: events.last?.now ?? 0)), as: UTF8.self))
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8)); exit(1)
        }
    }
}
