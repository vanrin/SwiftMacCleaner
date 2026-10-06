//
//  PackageCacheScanner.swift
//  Mac Disk Cleaner
//

import Foundation

nonisolated enum PackageCacheScanner {
    struct Cache {
        var title: String
        var path: String
        var detail: String
        var preselected: Bool? = nil
    }

    static let caches: [Cache] = [
        Cache(title: "npm cache", path: ".npm/_cacache", detail: "Packages npm has downloaded"),
        Cache(title: "npx cache", path: ".npm/_npx", detail: "Packages npx fetched to run once"),
        Cache(title: "pnpm store", path: "Library/pnpm/store", detail: "Packages pnpm has downloaded. Installed projects keep working"),
        Cache(title: "Yarn cache", path: "Library/Caches/Yarn", detail: "Packages Yarn has downloaded"),
        Cache(title: "Yarn Berry cache", path: ".yarn/berry/cache", detail: "Packages Yarn has downloaded"),
        Cache(title: "Bun cache", path: ".bun/install/cache", detail: "Packages Bun has downloaded"),
        Cache(title: "CocoaPods cache", path: "Library/Caches/CocoaPods", detail: "Pods downloaded for past installs"),
        Cache(title: "Dart and Flutter packages", path: ".pub-cache/hosted", detail: "Packages from pub.dev, fetched again by flutter pub get"),
        Cache(title: "Dart packages from Git", path: ".pub-cache/git", detail: "Git dependencies, cloned again by flutter pub get"),
        Cache(title: "Homebrew downloads", path: "Library/Caches/Homebrew", detail: "Installers for formulae and casks you already installed"),
        Cache(title: "pip cache", path: "Library/Caches/pip", detail: "Wheels pip has downloaded or built"),
        Cache(title: "uv cache", path: ".cache/uv", detail: "Packages uv has downloaded or built"),
        Cache(title: "Poetry cache", path: "Library/Caches/pypoetry", detail: "Packages Poetry has downloaded"),
        Cache(title: "Swift Package Manager cache", path: "Library/Caches/org.swift.swiftpm", detail: "Package checkouts, cloned again when resolved"),
        Cache(title: "Carthage cache", path: "Library/Caches/org.carthage.CarthageKit", detail: "Dependencies Carthage has built"),
        Cache(title: "Cargo registry", path: ".cargo/registry", detail: "Crates downloaded from crates.io"),
        Cache(title: "Cargo Git checkouts", path: ".cargo/git", detail: "Git dependencies, cloned again by cargo build"),
        Cache(title: "Go build cache", path: "Library/Caches/go-build", detail: "Compiled packages, rebuilt on the next go build"),
        Cache(title: "Playwright browsers", path: "Library/Caches/ms-playwright", detail: "Browsers downloaded for tests"),
        Cache(title: "Cypress binaries", path: "Library/Caches/Cypress", detail: "Cypress versions downloaded for tests"),
        Cache(title: "Puppeteer browsers", path: ".cache/puppeteer", detail: "Browsers downloaded for automation"),
        Cache(title: "Electron downloads", path: "Library/Caches/electron", detail: "Electron builds downloaded by npm"),
        Cache(title: "node-gyp headers", path: "Library/Caches/node-gyp", detail: "Node headers for building native modules"),
        Cache(title: "Maven repository", path: ".m2/repository",
              detail: "Downloaded again by Maven, except anything you installed locally with mvn install",
              preselected: false),
    ]

    /// Folders in ~/Library/Caches that belong to this area, so the general cache scan skips them.
    static let claimedCacheFolders: Set<String> = Set(caches.compactMap { cache in
        let prefix = "Library/Caches/"
        return cache.path.hasPrefix(prefix) ? String(cache.path.dropFirst(prefix.count)) : nil
    })

    static func scan(_ context: ScanContext) async -> AreaScanResult {
        let candidates = caches.map {
            PathCandidate(title: $0.title, detail: $0.detail, url: context.home.appending(path: $0.path),
                          preselected: $0.preselected, hint: "~/" + $0.path)
        }
        let items = await Sizing.items(prefix: "packages.caches", from: candidates, minimumSize: 5_000_000)
        guard !items.isEmpty else { return AreaScanResult() }
        let names = items.prefix(4).map(\.title).joined(separator: ", ")
        let finding = Finding(
            id: "packages.caches",
            area: .packageCaches,
            tier: .safe,
            title: "Package manager caches",
            summary: names + (items.count > 4 ? " and \(items.count - 4) more" : ""),
            explanation: "Copies of packages your package managers have already downloaded. Anything a project needs is fetched again the next time you install.",
            method: .delete,
            actionTarget: "Each package manager's cache folder",
            items: items
        )
        return AreaScanResult(findings: [finding])
    }
}
