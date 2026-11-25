// swift-tools-version: 6.0
import PackageDescription

let package = Package(name: "CacheJournal", platforms: [.macOS(.v13)], products: [.executable(name: "cache-journal", targets: ["CacheJournal"])], targets: [.executableTarget(name: "CacheJournal")])
