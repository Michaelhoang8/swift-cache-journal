import Foundation

enum CacheError: Error { case invalidCapacity, invalidLifetime, invalidKey, clockReversed, timeOverflow }
struct CacheStats: Codable, Sendable {
    let hits: Int
    let misses: Int
    let evictions: Int
    let expirations: Int
    let keysOldestFirst: [String]
}

actor Cache {
    private struct Entry { let value: String; let expires: Int }
    private let capacity: Int
    private var values: [String: Entry] = [:]
    private var order: [String] = []
    private var clock = 0
    private var hits = 0, misses = 0, evictions = 0, expirations = 0

    init(capacity: Int) throws {
        guard capacity > 0 else { throw CacheError.invalidCapacity }
        self.capacity = capacity
    }
    private func advance(_ now: Int) throws {
        guard now >= clock else { throw CacheError.clockReversed }
        clock = now
        let expired = order.filter { values[$0]!.expires <= now }
        for key in expired { values.removeValue(forKey: key) }
        expirations += expired.count
        order.removeAll { values[$0] == nil }
    }
    func put(_ key: String, value: String, ttl: Int, now: Int) throws {
        guard !key.isEmpty else { throw CacheError.invalidKey }
        guard ttl > 0 else { throw CacheError.invalidLifetime }
        let (expiry, overflow) = now.addingReportingOverflow(ttl)
        guard !overflow else { throw CacheError.timeOverflow }
        try advance(now)
        if values[key] == nil && values.count == capacity {
            values.removeValue(forKey: order.removeFirst())
            evictions += 1
        }
        values[key] = Entry(value: value, expires: expiry)
        order.removeAll { $0 == key }
        order.append(key)
    }
    func get(_ key: String, now: Int) throws -> String? {
        try advance(now)
        guard let entry = values[key] else { misses += 1; return nil }
        hits += 1
        order.removeAll { $0 == key }
        order.append(key)
        return entry.value
    }
    func stats(now: Int) throws -> CacheStats {
        try advance(now)
        return CacheStats(hits: hits, misses: misses, evictions: evictions, expirations: expirations, keysOldestFirst: order)
    }
}
