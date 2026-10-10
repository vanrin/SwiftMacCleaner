//
//  DuplicatesTests.swift
//  SwiftMacCleanerTests
//
//  Duplicates: which files count as the same, what is left out of the search, what removing a copy
//  gives back when copies share their data, and that one copy of everything always stays.
//

import Foundation
import SwiftUI
import Testing
@testable import SwiftMacCleaner

/// A throwaway folder that stands in for a home directory.
private struct Home {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "mdc-duplicates-\(UUID().uuidString)")
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    var safety: SafetyGuard { SafetyGuard(root: root) }

    /// A file of `kilobytes`, every byte `fill`, with whatever `change` does to it.
    @discardableResult
    func file(_ path: String, fill: UInt8, kilobytes: Int = 300, change: (inout Data) -> Void = { _ in }) throws -> URL {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var data = Data(repeating: fill, count: kilobytes * 1_000)
        change(&data)
        try data.write(to: url)
        return url
    }

    func scan(_ folders: [String] = [""], safety: SafetyGuard? = nil) async throws -> DuplicateScan {
        let roots = folders.map { $0.isEmpty ? root : root.appending(path: $0) }
        return try #require(await DuplicateScanner.scan(roots: roots, home: root, safety: safety ?? self.safety))
    }
}

private func names(_ group: DuplicateGroup?) -> [String] {
    (group?.files ?? []).map(\.url.lastPathComponent)
}

/// A copy for tests that need no disk: `clones` is how many files on the disk point at its data.
private func copy(_ name: String, clone: UInt64, clones: Int = 1, own: Int64? = nil, locked: Bool = false) -> DuplicateFile {
    DuplicateFile(
        url: URL(fileURLWithPath: "/Users/demo/Documents/\(name)"), size: 1_000, allocated: 4_096,
        storage: FileStorage(cloneID: clone, cloneCount: clones, privateSize: own ?? (clones > 1 ? 0 : 4_096)),
        lockedReason: locked ? "It stays" : nil, inode: clone, modifiedNanoseconds: 0
    )
}

struct DuplicateScannerTests {
    @Test func findsFilesThatAreAlikeWhereverTheyAreAndWhateverTheyAreCalled() async throws {
        let home = try Home()
        defer { home.remove() }
        try home.file("Documents/report.pdf", fill: 0xA1)
        try home.file("Documents/Archive/other name.bin", fill: 0xA1)
        try home.file("Downloads/report (1).pdf", fill: 0xA1)
        // As long as the report, and nothing like it.
        try home.file("Documents/minutes.pdf", fill: 0xB2)
        // Alike at both ends and different in the middle: only the two that are alike all through count.
        try home.file("Documents/film.mov", fill: 0xC3, kilobytes: 1_000)
        try home.file("Documents/film again.mov", fill: 0xC3, kilobytes: 1_000)
        try home.file("Documents/film recut.mov", fill: 0xC3, kilobytes: 1_000) { $0[500_000] = 0 }
        // Too small to be worth reading.
        try home.file("Documents/note.txt", fill: 0xD4, kilobytes: 50)
        try home.file("Documents/note copy.txt", fill: 0xD4, kilobytes: 50)

        let scan = try await home.scan()
        #expect(scan.groups.count == 2)
        // The group that gives back the most comes first.
        let films = scan.groups[0]
        #expect(names(films) == ["film.mov", "film again.mov"])
        #expect(films.kind == .videos)
        #expect(films.size == 1_000_000)
        let reports = scan.groups[1]
        // The one to keep first: not named as a copy, not in Downloads, and the oldest.
        #expect(names(reports) == ["report.pdf", "other name.bin", "report (1).pdf"])
        #expect(reports.kind == .documents)
        #expect(names(reports).contains("minutes.pdf") == false)
        #expect(reports.extras.map(\.url.lastPathComponent) == ["other name.bin", "report (1).pdf"])
        // Separate copies each take their own space, so removing two gives two files' worth back.
        #expect(reports.reclaimable == reports.files[1].allocated + reports.files[2].allocated)
        #expect(scan.reclaimable == reports.reclaimable + films.reclaimable)
        #expect(scan.filesSeen == 9)
        #expect(scan.bytesRead > 0)
        #expect(scan.unreadable.isEmpty)
    }

    @Test func leavesOutWhatIsNotTheUsersToTidyByHand() async throws {
        let home = try Home()
        defer { home.remove() }
        try home.file("Documents/photo.jpg", fill: 0x01)
        try home.file("Pictures/photo.jpg", fill: 0x01)
        // Each of these pairs would be a group if its folder were looked into.
        let leftOut = [
            "Library/Application Support/Maker/data.bin", "Library/Containers/Maker/data.bin",
            "Documents/.hidden/a.bin", "Documents/.hidden/b.bin",
            "Code/project/assets/logo.png", "Code/project/build/logo.png",
            "Documents/site/node_modules/pkg/a.js", "Documents/site/node_modules/pkg/b.js",
            "Documents/Tool.app/Contents/Resources/a.png", "Documents/Tool.app/Contents/Resources/b.png",
            "Music/Music/Media/song.m4a", "Music/Music/Media/song 2.m4a",
            "Documents/.secret one.bin", "Documents/.secret two.bin",
            // A project without a repository, the data folder of a database, and pieces with no type in their name.
            "Documents/Site/public/hero.png", "Documents/Site/dist/hero.png",
            "Documents/Database/data/base/1/table.csv", "Documents/Database/data copy/base/1/table.csv",
            "Documents/Backups/monday/17368", "Documents/Backups/tuesday/17368",
            "Documents/Store/a/part.1", "Documents/Store/b/part.1",
            // A toolchain's programs, an app's cache in a folder anyone can see, and a program's small data files.
            "Tools/sdk/bin/engine.zip", "Tools/sdk/bin/engine old.zip",
            "Movies/Editor/User Data/Cache/effect/a.png", "Movies/Editor/User Data/Cache/effect/b.png",
            "Documents/Readings/monday.dat", "Documents/Readings/tuesday.dat",
            // A repository directly in the home folder is a repository all the same.
            "sdk/packages/tool/icon.png", "sdk/examples/icon.png",
        ]
        for (index, path) in leftOut.enumerated() {
            try home.file(path, fill: UInt8(0x10 + index / 2))
        }
        try FileManager.default.createDirectory(at: home.root.appending(path: "Code/project/.git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: home.root.appending(path: "sdk/.git"), withIntermediateDirectories: true)
        try home.file("Documents/Site/package.json", fill: 0x7B, kilobytes: 1)
        try home.file("Documents/Database/data/PG_VERSION", fill: 0x31, kilobytes: 1)
        try home.file("Documents/Database/data copy/PG_VERSION", fill: 0x31, kilobytes: 1)
        // A stray project file in Documents itself does not make all of Documents a project.
        try home.file("Documents/requirements.txt", fill: 0x23, kilobytes: 1)

        let scan = try await home.scan()
        #expect(scan.groups.count == 1)
        #expect(names(scan.groups.first) == ["photo.jpg", "photo.jpg"])
        #expect(scan.groups.first?.kind == .images)

        // A folder the user points at is looked into whatever it is; what it holds still goes by the rules.
        let project = try await home.scan(["Code/project"])
        #expect(names(project.groups.first) == ["logo.png", "logo.png"])
        let library = try await home.scan(["Library/Containers", "Library"])
        #expect(library.groups.count == 1)
        // A file of no known kind is some program's data unless it is large.
        let readings = [home.root.appending(path: "Documents/Readings")]
        #expect(try #require(await DuplicateScanner.scan(roots: readings, home: home.root, safety: home.safety)).groups.isEmpty)
        let large = try #require(await DuplicateScanner.scan(roots: readings, home: home.root, safety: home.safety, minimumUnknownSize: 200_000))
        #expect(names(large.groups.first) == ["monday.dat", "tuesday.dat"])
        #expect(large.groups.first?.kind == .other)
    }

    /// Finder makes a clone when it duplicates a file. The disk says the two are alike, so neither is
    /// read, and removing one of them gives nothing back while the other points at the same data.
    @Test func aCloneIsFoundWithoutBeingReadAndGivesNothingBack() async throws {
        let home = try Home()
        defer { home.remove() }
        let original = try home.file("Documents/Clones/plan.key", fill: 0x21, kilobytes: 1_000)
        let clone = home.root.appending(path: "Documents/Clones/plan copy.key")
        try FileManager.default.copyItem(at: original, to: clone)
        guard let storage = FileStorage.read(clone.path), storage.cloneCount == 2 else {
            // The disk under the temporary folder does not make clones, so there is nothing to check.
            return
        }
        #expect(FileStorage.read(original.path)?.cloneID == storage.cloneID)
        #expect(storage.privateSize == 0)

        let scan = try await home.scan(["Documents/Clones"])
        let group = try #require(scan.groups.first)
        #expect(names(group) == ["plan.key", "plan copy.key"])
        #expect(group.id.hasPrefix("clones-"))
        #expect(group.files.allSatisfy { $0.sharesSpace })
        #expect(scan.bytesRead == 0)
        #expect(group.reclaimable == 0)
        #expect(group.freed(removing: [clone.path]) == 0)
        // Only with both gone would the data go.
        #expect(group.freed(removing: [clone.path, original.path]) == group.files[0].allocated)

        // A separate copy beside them takes space of its own. Keeping a clone and removing it gives that back.
        try home.file("Documents/Clones/plan from mail.key", fill: 0x21, kilobytes: 1_000)
        let wider = try #require(try await home.scan(["Documents/Clones"]).groups.first)
        #expect(wider.files.count == 3)
        #expect(wider.reclaimable == wider.files[0].allocated)
        #expect(wider.id.hasPrefix("1000000-"))
        // A clone that has been changed is a clone no longer, and no longer alike.
        let handle = try FileHandle(forWritingTo: clone)
        try handle.seek(toOffset: 100)
        try handle.write(contentsOf: Data([0xFF]))
        try handle.close()
        let after = try #require(try await home.scan(["Documents/Clones"]).groups.first)
        #expect(names(after) == ["plan.key", "plan from mail.key"])
    }

    @Test func aSecondNameForAFileIsNotACopyOfIt() async throws {
        let home = try Home()
        defer { home.remove() }
        let first = try home.file("Documents/ledger.numbers", fill: 0x31)
        try FileManager.default.linkItem(at: first, to: home.root.appending(path: "Documents/ledger link.numbers"))
        // On their own the two names are one file, and one file is no duplicate.
        #expect(try await home.scan().groups.isEmpty)

        try home.file("Downloads/ledger.numbers", fill: 0x31)
        let group = try #require(try await home.scan().groups.first)
        #expect(group.files.count == 2)
        // The file with two names stays: taking one name away would free nothing.
        #expect(group.files[0].isLocked)
        #expect(group.files[0].lockedReason?.contains("second name") == true)
        #expect(group.extras.map(\.url.path) == [home.root.appending(path: "Downloads/ledger.numbers").path])
        #expect(group.reclaimable == group.files[1].allocated)
    }

    @Test func aCopyTheGuardWouldRefuseIsListedAsOneThatStays() async throws {
        let home = try Home()
        defer { home.remove() }
        let kept = try home.file("Documents/Taxes/return.pdf", fill: 0x41)
        try home.file("Downloads/return.pdf", fill: 0x41)
        // Directly in the home folder, where the guard lets nothing be removed.
        try home.file("return.pdf", fill: 0x41)
        try home.file("Documents/Taxes/receipt.pdf", fill: 0x42)
        try home.file("Documents/Taxes/receipt copy.pdf", fill: 0x42)
        let safety = SafetyGuard(root: home.root, neverSuggest: [kept.deletingLastPathComponent().path])

        let scan = try await home.scan(safety: safety)
        // Both receipts are on the Never Suggest list, so there is nothing to offer and no group.
        #expect(scan.groups.count == 1)
        let group = try #require(scan.groups.first)
        #expect(group.files.map(\.isLocked) == [true, true, false])
        #expect(Set(group.files.prefix(2).compactMap(\.lockedReason)) == [
            "It is on your Never Suggest list", "It sits directly in your home folder, which this app leaves as it is",
        ])
        // With a copy that has to stay, every other copy may go.
        #expect(group.extras.map(\.url.lastPathComponent) == ["return.pdf"])
        #expect(group.extras.first?.url.path.contains("Downloads") == true)
    }

    @Test func foldersInsideOneAnotherAreWalkedOnce() throws {
        let home = try Home()
        defer { home.remove() }
        let documents = home.root.appending(path: "Documents")
        let inner = documents.appending(path: "Work")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        #expect(DuplicateScanner.distinct([inner, documents, documents]).map(\.path) == [documents.path])
        #expect(DuplicateScanner.distinct([inner, home.root.appending(path: "Downloads")]).count == 2)
    }

    @Test func tellsACopysNameAndWhatKindOfFileItIs() {
        for name in ["Report copy", "Report copy 2", "Report (1)", "Report 2", "report COPY"] {
            #expect(DuplicateScanner.looksLikeCopy(name), "\(name)")
        }
        for name in ["Report", "Copybook", "Report 2026", "IMG_0002", "Report (final)"] {
            #expect(!DuplicateScanner.looksLikeCopy(name), "\(name)")
        }
        #expect(DuplicateKind(fileExtension: "jpg") == .images)
        #expect(DuplicateKind(fileExtension: "mov") == .videos)
        #expect(DuplicateKind(fileExtension: "mp3") == .music)
        #expect(DuplicateKind(fileExtension: "pdf") == .documents)
        #expect(DuplicateKind(fileExtension: "txt") == .documents)
        #expect(DuplicateKind(fileExtension: "zip") == .archives)
        #expect(DuplicateKind(fileExtension: "dmg") == .archives)
        #expect(DuplicateKind(fileExtension: "") == .other)
        #expect(DuplicateKind(fileExtension: "qqqzzz") == .other)
        for name in ["photo.jpg", "archive.tar.gz", "model.gguf", "Report 2.PDF", "clip.mp4"] {
            #expect(DuplicateScanner.hasType(name), "\(name)")
        }
        for name in ["17368", "part.1", "journal.0000000002", "Makefile", "e878ccec-13c0-4543", "notes.", "odd.na me"] {
            #expect(!DuplicateScanner.hasType(name), "\(name)")
        }
    }
}

struct DuplicateGroupTests {
    private func group(_ files: [DuplicateFile]) -> DuplicateGroup {
        DuplicateGroup(id: "g", kind: .documents, size: 1_000, files: files)
    }

    @Test func separateCopiesEachGiveTheirSpaceBack() {
        let files = [copy("a", clone: 1), copy("b", clone: 2), copy("c", clone: 3)]
        let group = group(files)
        #expect(group.extras.map(\.url.lastPathComponent) == ["b", "c"])
        #expect(group.reclaimable == 8_192)
        #expect(group.freed(removing: [files[1].id]) == 4_096)
        #expect(group.freed(removing: []) == 0)
        #expect(group.shares(removing: [files[1], files[2]]) == [files[1].id: 4_096, files[2].id: 4_096])
    }

    @Test func clonesGiveTheirSpaceBackOnlyWhenTheLastOneGoes() {
        // Two clones of each other and one separate copy.
        let files = [copy("a", clone: 1, clones: 2), copy("a copy", clone: 1, clones: 2), copy("b", clone: 2)]
        let group = group(files)
        #expect(group.freed(removing: [files[1].id]) == 0)
        #expect(group.freed(removing: [files[0].id, files[1].id]) == 4_096)
        #expect(group.freed(removing: [files[1].id, files[2].id]) == 4_096)
        #expect(group.reclaimable == 4_096)
        // The shares add up to what the removal gives back, with a pair of clones counted once.
        let shares = group.shares(removing: [files[0], files[1]])
        #expect(shares.values.reduce(0, +) == 4_096)
        #expect(shares.count == 2)
    }

    @Test func aCloneOfSomethingOutsideTheGroupGivesBackOnlyWhatIsItsOwn() {
        // The disk knows three files with this data; only two were found. Removing both still leaves the third.
        let files = [copy("a", clone: 1, clones: 3, own: 0), copy("a copy", clone: 1, clones: 3, own: 512)]
        let group = group(files)
        #expect(group.freed(removing: [files[0].id, files[1].id]) == 512)
        #expect(group.reclaimable == 512)
    }

    @Test func aCopyThatHasToStayIsTheOneKept() {
        let files = [copy("kept", clone: 1, locked: true), copy("b", clone: 2), copy("c", clone: 3)]
        #expect(group(files).extras.map(\.url.lastPathComponent) == ["b", "c"])
        #expect(group(files).reclaimable == 8_192)
    }

    /// The copy whose data would stay on the disk anyway is the better one to keep, whatever it is called.
    @Test func keepsTheCopyThatWouldGiveNothingBack() {
        let downloads = "/Users/demo/Downloads/"
        let sharedElsewhere = copy("Report copy", clone: 1, clones: 2)
        let separate = copy("Report", clone: 2)
        let first = DuplicateScanner.keepingOrder(sharedElsewhere, clonesHere: 1, downloads: downloads)
        let second = DuplicateScanner.keepingOrder(separate, clonesHere: 1, downloads: downloads)
        #expect(first < second)
        // With nothing to choose between them on that score, the one not named as a copy is kept.
        let named = DuplicateScanner.keepingOrder(copy("Report copy", clone: 3), clonesHere: 1, downloads: downloads)
        #expect(second < named)
    }
}

struct DuplicatePlanTests {
    @Test func oneCopyStaysEvenWhenEveryCopyIsTicked() {
        let files = [copy("a.pdf", clone: 1), copy("b.pdf", clone: 2), copy("c.pdf", clone: 3)]
        let documents = DuplicateGroup(id: "d", kind: .documents, size: 1_000, files: files)
        let images = DuplicateGroup(id: "i", kind: .images, size: 1_000,
                                    files: [copy("x.jpg", clone: 4, locked: true), copy("y.jpg", clone: 5)])
        let everything = Set((documents.files + images.files).map(\.id))

        let checked = DuplicatePlan.make(groups: [documents, images], selection: everything)
        #expect(checked.leftOut.isEmpty)
        // In the order the kinds are listed, whatever order the groups came in.
        #expect(checked.plan.steps.map(\.id) == [DuplicatePlan.stepID(for: .images), DuplicatePlan.stepID(for: .documents)])
        let step = checked.plan.steps[1]
        #expect(step.operations.map(\.kind) == [.trash(files[1].url), .trash(files[2].url)])
        #expect(step.size == 8_192)
        #expect(step.method == .trash)
        #expect(step.summary == "Move 2 duplicates to the Trash. A copy of each stays")
        // A copy that has to stay is never in a plan, ticked or not.
        #expect(checked.plan.steps[0].operations.map(\.kind) == [.trash(images.files[1].url)])
        #expect(DuplicatePlan.make(groups: [documents], selection: []).plan.isEmpty)
        #expect(DuplicatePlan.going(from: documents, selection: [files[0].id]).map(\.id) == [files[0].id])
    }

    @Test func aFileChangedSinceItWasComparedIsLeftAloneAndSoIsAGroupWhoseKeptCopyIsGone() async throws {
        let home = try Home()
        defer { home.remove() }
        let report = try home.file("Documents/report.pdf", fill: 0x51)
        let reportCopy = try home.file("Downloads/report.pdf", fill: 0x51)
        let changed = try home.file("Downloads/report (1).pdf", fill: 0x51)
        let photo = try home.file("Pictures/Trip/photo.jpg", fill: 0x52)
        let photoCopy = try home.file("Downloads/photo.jpg", fill: 0x52)
        let scan = try await home.scan()
        #expect(scan.groups.count == 2)
        let selection: Set<String> = [reportCopy.path, changed.path, photoCopy.path]

        // Written to after the comparison, and the photo that was to stay thrown away meanwhile.
        try Data(repeating: 0x51, count: 300_001).write(to: changed)
        try FileManager.default.removeItem(at: photo)

        let unchecked = DuplicatePlan.make(groups: scan.groups, selection: selection)
        #expect(unchecked.plan.steps.flatMap(\.operations).count == 3)
        let checked = DuplicatePlan.make(groups: scan.groups, selection: selection, verifying: true)
        #expect(checked.leftOut == [changed.path: DuplicatePlan.changedReason, photoCopy.path: DuplicatePlan.keeperReason])
        #expect(checked.plan.steps.map(\.id) == [DuplicatePlan.stepID(for: .documents)])
        #expect(checked.plan.steps[0].operations.map(\.kind) == [.trash(reportCopy)])

        let outcome = await Cleaner.run(plan: checked.plan, safety: home.safety) { _ in }
        defer { outcome.trashed.forEach { try? FileManager.default.removeItem(at: $0.inTrash) } }
        #expect(outcome.failureCount == 0)
        #expect(outcome.cleanedItemIDs == [reportCopy.path])
        #expect(!Files.exists(reportCopy))
        #expect(Files.exists(report) && Files.exists(changed) && Files.exists(photoCopy))

        // The receipt accounts for what was left out, in a step of its own where none ran.
        let recorded = DuplicatePlan.recording(checked.leftOut, in: outcome, groups: scan.groups)
        #expect(recorded.steps.map(\.id) == [DuplicatePlan.stepID(for: .documents), DuplicatePlan.stepID(for: .images)])
        #expect(recorded.steps[0].skippedItems == [changed.path: DuplicatePlan.changedReason])
        #expect(recorded.steps[1].skippedItems == [photoCopy.path: DuplicatePlan.keeperReason])
        #expect(recorded.steps[1].cleanedItemIDs.isEmpty)
    }
}

@MainActor
struct DuplicatesModelTests {
    /// Settings kept apart from the user's own, so a test's Never Suggest entry never reaches them.
    private func settings() throws -> (AppSettings, () -> Void) {
        let name = "DuplicatesTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        return (AppSettings(defaults: defaults), { defaults.removePersistentDomain(forName: name) })
    }

    private func demo() throws -> (DuplicatesModel, () -> Void) {
        let (settings, forget) = try settings()
        let model = DuplicatesModel(home: URL(fileURLWithPath: "/Users/demo", isDirectory: true), settings: settings)
        model.showDemo("results")
        return (model, forget)
    }

    @Test func theLastCopyLeftUntickedCannotBeTicked() throws {
        let (model, forget) = try demo()
        defer { forget() }
        let group = try #require(model.groups.first { $0.name == "Harbour timelapse.mov" })
        #expect(model.selectedCount == 0)
        #expect(group.files.allSatisfy { model.canToggle($0, in: group) })

        model.binding(for: group.files[1], in: group).wrappedValue = true
        model.binding(for: group.files[2], in: group).wrappedValue = true
        #expect(model.staying(in: group) == 1)
        // The one that is left stays, however it is asked.
        #expect(!model.canToggle(group.files[0], in: group))
        model.binding(for: group.files[0], in: group).wrappedValue = true
        #expect(!model.isSelected(group.files[0]))
        #expect(model.selectedCount == 2)
        #expect(model.selectedSize == group.reclaimable)
        // Unticking another copy frees this one to go instead.
        model.binding(for: group.files[2], in: group).wrappedValue = false
        #expect(model.canToggle(group.files[0], in: group))
    }

    @Test func aCopyThatHasToStayCannotBeTickedAndTheOthersMayAllGo() throws {
        let (model, forget) = try demo()
        defer { forget() }
        let group = try #require(model.groups.first { $0.name == "2025 return.pdf" })
        #expect(group.files[0].isLocked)
        #expect(!model.canToggle(group.files[0], in: group))
        for file in group.files { model.binding(for: file, in: group).wrappedValue = true }
        #expect(group.files.map(model.isSelected) == [false, true, true])
    }

    @Test func tickingAGroupsHeadingTicksItsExtraCopiesAndNothingElse() throws {
        let (model, forget) = try demo()
        defer { forget() }
        let group = try #require(model.groups.first { $0.name == "Harbour timelapse.mov" })
        // The copy most worth keeping was ticked by hand, and another left alone.
        model.binding(for: group.files[0], in: group).wrappedValue = true
        for binding in model.bindings(forExtrasOf: group) { binding.wrappedValue = true }
        #expect(group.files.map(model.isSelected) == [false, true, true])
        for binding in model.bindings(forExtrasOf: group) { binding.wrappedValue = false }
        #expect(model.selectedCount == 0)
    }

    @Test func selectingExtraCopiesKeepsOneOfEachAndCountsSharedSpaceOnce() throws {
        let (model, forget) = try demo()
        defer { forget() }
        model.selectExtras()
        #expect(model.groups.allSatisfy { model.staying(in: $0) >= 1 })
        #expect(model.selectedCount == model.groups.reduce(0) { $0 + $1.extras.count })
        #expect(model.selectedSize == model.reclaimable)
        // Two of the ticked copies are clones of a copy that stays: they tidy up and give nothing back.
        #expect(model.selectedSharing == 2)
        #expect(model.plan.totalSize == model.reclaimable)
        #expect(model.plan.steps.map(\.title) == ["Images", "Videos", "Music", "Documents", "Archives"])

        // Narrowed to one kind, only that kind's groups are ticked.
        model.selectNone()
        model.kind = .images
        #expect(model.visibleGroups.allSatisfy { $0.kind == .images })
        model.selectExtras()
        #expect(model.plan.steps.map(\.title) == ["Images"])
        model.kind = nil
        model.search = "Talks"
        #expect(model.visibleGroups.map(\.name) == ["Autumn review.key"])
        model.search = ""
        model.sort = .name
        #expect(model.visibleGroups.map(\.name) == model.groups.map(\.name).sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    @Test func aFinishedRemovalDropsTheGroupsThatAreDownToOneCopy() throws {
        let (model, forget) = try demo()
        defer { forget() }
        var reported: CleanOutcome?
        model.didRemove = { reported = $0 }
        let before = model.groups.count
        let gain = model.reclaimable
        // Everything but one group is tidied up.
        model.selectExtras()
        let kept = try #require(model.groups.first { $0.name == "panorama.tiff" })
        for file in kept.files { model.binding(for: file, in: kept).wrappedValue = false }
        model.finishDemoRemoval()
        #expect(model.phase == .done)
        #expect(model.groups.map(\.name) == ["panorama.tiff"])
        #expect(model.removal.files == 11)
        #expect(model.removal.size == gain - kept.reclaimable)
        #expect(model.removal.leftOut == 0)
        #expect(model.selectedCount == 0)
        #expect(reported?.trashed.count == 11)
        #expect(before == 8)
        model.showResults()
        #expect(model.phase == .results)
    }

    @Test func neverSuggestingAFolderMakesItsCopiesOnesThatStay() throws {
        let (model, forget) = try demo()
        defer { forget() }
        let reports = try #require(model.groups.first { $0.name == "Harbour timelapse.mov" })
        let inDownloads = try #require(reports.files.first { $0.url.path.contains("/Downloads/") })
        model.selectExtras()
        #expect(model.isSelected(inDownloads))

        model.neverSuggest(folderOf: inDownloads)
        #expect(model.settings.neverSuggest.map(\.path) == ["/Users/demo/Downloads"])
        // Every copy in Downloads now stays, is listed first, and is no longer ticked.
        let after = try #require(model.groups.first { $0.name.hasPrefix("Harbour timelapse") })
        #expect(after.files.first?.url.path.contains("/Downloads/") == true)
        #expect(after.files.first?.lockedReason == "It is on your Never Suggest list")
        #expect(!model.isSelected(inDownloads))
        #expect(model.groups.flatMap(\.files).filter { $0.url.path.contains("/Downloads/") }.allSatisfy { $0.isLocked })
        // A group whose only other copy was in Downloads still has one that may go; none is left with nothing to offer.
        #expect(model.groups.allSatisfy { group in group.files.contains { !$0.isLocked } })
    }

    /// The whole way through on real files: scan a folder, tick the extra copies, remove them.
    @Test func scansAFolderAndMovesTheExtraCopiesToTheTrash() async throws {
        let home = try Home()
        defer { home.remove() }
        let (settings, forget) = try settings()
        defer { forget() }
        let original = try home.file("Documents/Trip/photo.jpg", fill: 0x61)
        let second = try home.file("Downloads/photo.jpg", fill: 0x61)
        let third = try home.file("Downloads/photo (1).jpg", fill: 0x61)
        try home.file("Documents/Trip/other.jpg", fill: 0x62)
        let model = DuplicatesModel(home: home.root, settings: settings)
        var reported: CleanOutcome?
        model.didRemove = { reported = $0 }

        model.start()
        #expect(model.phase == .scanning)
        for _ in 0..<200 where model.phase == .scanning { try await Task.sleep(for: .milliseconds(25)) }
        #expect(model.phase == .results)
        #expect(model.groups.count == 1)
        #expect(model.scan.filesSeen == 4)

        model.selectExtras()
        #expect(model.selected == [second.path, third.path])
        model.remove()
        for _ in 0..<200 where model.phase == .removing { try await Task.sleep(for: .milliseconds(25)) }
        defer { reported?.trashed.forEach { try? FileManager.default.removeItem(at: $0.inTrash) } }
        #expect(model.phase == .done)
        #expect(model.removal.files == 2)
        #expect(model.removal.leftOut == 0)
        #expect(Files.exists(original))
        #expect(!Files.exists(second) && !Files.exists(third))
        #expect(reported?.trashed.map(\.original.path).sorted() == [third.path, second.path].sorted())
        // With one copy left there is no group, so there is nothing more to show.
        #expect(model.groups.isEmpty)
        model.showResults()
        #expect(model.phase == .idle)
    }
}
