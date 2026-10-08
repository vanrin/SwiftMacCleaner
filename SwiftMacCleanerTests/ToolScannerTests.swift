//
//  ToolScannerTests.swift
//  SwiftMacCleanerTests
//

import Foundation
import Testing
@testable import SwiftMacCleaner

/// A throwaway folder that stands in for a home directory.
private struct Sandbox {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "mdc-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    @discardableResult
    func file(_ path: String, bytes: Int = 16, age days: Double = 0) throws -> URL {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 7, count: bytes).write(to: url)
        try setAge(days, of: url)
        return url
    }

    func setAge(_ days: Double, of url: URL) throws {
        let date = Date().addingTimeInterval(-days * 86_400)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }
}

struct ContainersScannerTests {
    @Test func readsTheVolumeSizeFromADockerRow() {
        let output = """
        {"Active":"3","Reclaimable":"4GB (50%)","Size":"8GB","TotalCount":"6","Type":"Local Volumes"}
        """
        let rows = ContainersScanner.parse(output)
        #expect(rows.first?.type == "Local Volumes")
        #expect(ContainersScanner.bytes(from: rows.first?.size ?? "") == 8_000_000_000)
        // Volumes never become an item, however much is reclaimable.
        #expect(ContainersScanner.items(from: rows, docker: "/usr/local/bin/docker").isEmpty)
    }
}

struct IDEScannerTests {
    @Test func splitsAFolderNameIntoProductAndVersion() {
        #expect(IDEScanner.parse(folderName: "IntelliJIdea2025.2")?.product == "IntelliJIdea")
        #expect(IDEScanner.parse(folderName: "IntelliJIdea2025.2")?.version == "2025.2")
        #expect(IDEScanner.parse(folderName: "AndroidStudio2024.3.1")?.version == "2024.3.1")
        #expect(IDEScanner.parse(folderName: "consentOptions") == nil)
        #expect(IDEScanner.parse(folderName: "Chrome") == nil)
        #expect(IDEScanner.friendlyName("IntelliJIdea") == "IntelliJ IDEA")
    }

    @Test func comparesVersionsNumerically() {
        #expect(IDEScanner.isNewer("2025.3", than: "2025.2"))
        #expect(IDEScanner.isNewer("2025.10", than: "2025.9"))
        #expect(!IDEScanner.isNewer("2024.3", than: "2025.1"))
    }

    @Test func keepsTheNewestVersionOfEachProductAndOffersTheRest() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        // 2025.2 has not been opened for months; 2025.3 and Android Studio run daily.
        for path in ["Library/Caches/JetBrains/IntelliJIdea2025.2/index/a.bin", "Library/Caches/JetBrains/IntelliJIdea2025.2/index",
                     "Library/Caches/JetBrains/IntelliJIdea2025.2"] {
            if path.hasSuffix(".bin") { try sandbox.file(path, bytes: 11_000_000, age: 200) } else { try sandbox.setAge(200, of: sandbox.root.appending(path: path)) }
        }
        try sandbox.file("Library/Application Support/JetBrains/IntelliJIdea2025.2/options/ide.xml", bytes: 2_000_000, age: 200)
        try sandbox.setAge(200, of: sandbox.root.appending(path: "Library/Application Support/JetBrains/IntelliJIdea2025.2/options"))
        try sandbox.setAge(200, of: sandbox.root.appending(path: "Library/Application Support/JetBrains/IntelliJIdea2025.2"))
        try sandbox.file("Library/Caches/JetBrains/IntelliJIdea2025.3/index/a.bin", bytes: 11_000_000)
        try sandbox.file("Library/Logs/JetBrains/IntelliJIdea2025.3/idea.log", bytes: 11_000_000)
        try sandbox.file("Library/Caches/Google/AndroidStudio2024.3/index/a.bin", bytes: 11_000_000)
        try sandbox.file("Library/Caches/Google/Chrome/Default/Cache/a.bin", bytes: 11_000_000)
        // An older PyCharm that was opened yesterday is in use, newer install or not.
        try sandbox.file("Library/Logs/JetBrains/PyCharm2025.1/idea.log", bytes: 11_000_000)
        try sandbox.file("Library/Caches/JetBrains/PyCharm2025.2/index/a.bin", bytes: 11_000_000)

        let installs = IDEScanner.installs(home: sandbox.root)
        #expect(installs.map { $0.product + $0.version } == ["AndroidStudio2024.3", "IntelliJIdea2025.2", "IntelliJIdea2025.3", "PyCharm2025.1", "PyCharm2025.2"])
        let (current, old) = IDEScanner.split(installs)
        #expect(current.map(\.version).sorted() == ["2024.3", "2025.2", "2025.3"])
        #expect(old.map(\.version) == ["2025.2", "2025.1"])

        let result = await IDEScanner.scan(ScanContext(home: sandbox.root))
        let caches = try #require(result.findings.first { $0.id == "ides.jetbrains" })
        #expect(!caches.items.contains { $0.paths.first?.path.contains("IntelliJIdea2025.2") == true })
        #expect(caches.items.contains { $0.paths.first?.path.contains("IntelliJIdea2025.3") == true })
        let oldVersions = try #require(result.findings.first { $0.id == "ides.oldVersions" })
        #expect(oldVersions.items.map(\.title) == ["IntelliJ IDEA 2025.2"])
        #expect(oldVersions.items.first?.paths.count == 2)
        #expect(oldVersions.method == .trash)
        #expect(result.protected.map(\.title) == ["PyCharm 2025.1"])
        #expect(result.protected.first?.rule == .recentlyUsed)
    }
}

struct ModelsScannerTests {
    @Test func namesAHuggingFaceRepositoryFromItsFolder() {
        #expect(ModelsScanner.huggingFaceName(folderName: "models--meta-llama--Llama-3.1-8B") == "meta-llama/Llama-3.1-8B")
        #expect(ModelsScanner.huggingFaceName(folderName: "datasets--squad") == "squad")
        #expect(ModelsScanner.huggingFaceName(folderName: ".locks") == nil)
        #expect(ModelsScanner.huggingFaceName(folderName: "version.txt") == nil)
    }

    @Test func parsesTheOllamaModelList() {
        let output = """
        NAME                ID              SIZE      MODIFIED
        llama3.1:8b         42182419e950    4.7 GB    3 weeks ago
        nomic-embed-text    0a109f422b47    274 MB    2 months ago
        """
        let items = ModelsScanner.ollamaItems(fromList: output, ollama: "/opt/homebrew/bin/ollama")
        #expect(items.map(\.title) == ["llama3.1:8b", "nomic-embed-text"])
        #expect(items.first?.size == 4_700_000_000)
        #expect(items.last?.size == 274_000_000)
        #expect(items.first?.command == ["/opt/homebrew/bin/ollama", "rm", "llama3.1:8b"])
        #expect(items.first?.preselected == false)
        #expect(items.first?.detail.contains("3 weeks ago") == true)
    }

    @Test func offersOldHuggingFaceModelsAndProtectsRecentOnes() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.file(".cache/huggingface/hub/models--old--one/blobs/a.bin", bytes: 120_000_000)
        try sandbox.setAge(200, of: sandbox.root.appending(path: ".cache/huggingface/hub/models--old--one"))
        try sandbox.file(".cache/huggingface/hub/models--fresh--two/blobs/a.bin", bytes: 120_000_000)

        let result = await ModelsScanner.scan(ScanContext(home: sandbox.root, staleDays: 60))
        let finding = try #require(result.findings.first { $0.id == "models.downloads" })
        #expect(finding.items.map(\.title) == ["old/one"])
        #expect(finding.items.first?.preselected == false)
        #expect(result.protected.map(\.title) == ["fresh/two (Hugging Face model)"])
        #expect(result.protected.first?.rule == .recentlyUsed)
    }
}
