//
//  VitalsTests.swift
//  SwiftMacCleanerTests
//
//  The menu bar's readings: how the kernel's counts become a load, a pressure and a charge, what
//  each tile says about them, which apps the lists name, and when the Mac is asked at all. The Mac
//  itself is never asked here: every count and every app is made up, and no app is quit.
//

import CoreGraphics
import Foundation
import Testing
@testable import SwiftMacCleaner

private let gigabyte: Int64 = 1_073_741_824
private let megabyte: Int64 = 1_048_576

struct VitalFormatTests {
    @Test func writesSharesAndMemoryTheWayMacOSStatesThem() {
        #expect(VitalFormat.percent(0.384) == "38%")
        #expect(VitalFormat.percent(0.096, decimals: 1) == "9.6%")
        #expect(VitalFormat.percent(-0.2) == "0%")
        // Memory is counted in binary units under the everyday names.
        #expect(VitalFormat.memory(Int64(6.92 * Double(gigabyte))) == "6.9 GB")
        #expect(VitalFormat.memory(Int64(3.96 * Double(gigabyte)), decimals: 2) == "3.96 GB")
        #expect(VitalFormat.memory(940 * megabyte) == "940 MB")
        #expect(VitalFormat.memory(1023 * megabyte) == "1,023 MB")
        #expect(VitalFormat.memory(512 * 1024) == "512 KB")
        #expect(VitalFormat.installedMemory(24 * gigabyte) == "24 GB")
        #expect(VitalFormat.installedMemory(Int64(1.5 * Double(gigabyte))) == "1.5 GB")
        #expect(VitalFormat.memoryShare(16 * gigabyte, of: 24 * gigabyte) == "16.0 of 24 GB")
    }

    @Test func writesTimesAndCounts() {
        #expect(VitalFormat.clock(minutes: 310) == "5:10")
        #expect(VitalFormat.clock(minutes: 48) == "0:48")
        #expect(VitalFormat.clock(minutes: 65) == "1:05")
        #expect(VitalFormat.span(6 * 86_400 + 5_400) == "6 days")
        #expect(VitalFormat.span(86_400) == "1 day")
        #expect(VitalFormat.span(5 * 3_600 + 59) == "5 hours")
        #expect(VitalFormat.span(3_600) == "1 hour")
        #expect(VitalFormat.span(40 * 60) == "40 minutes")
        #expect(VitalFormat.span(61) == "1 minute")
        #expect(VitalFormat.count(1000) == "1,000")
        #expect(VitalFormat.count(310) == "310")
    }
}

struct CPUReadingTests {
    private func reading(user: Double = 0.1, system: Double = 0.05, loadAverage: Double = 2, heat: Heat = .normal, cores: Int = 4) -> CPUReading {
        CPUReading(chip: "Test Chip", cores: (0..<cores).map { CPUCore(id: $0, kind: .plain, load: user + system) },
                   user: user, system: system, loadAverage: loadAverage, heat: heat, startedAt: nil)
    }

    @Test func aLoadIsTheDifferenceBetweenTwoCounts() throws {
        let earlier = [CPUTicks(user: 1_000, system: 500, idle: 8_500), CPUTicks(user: 2_000, system: 100, idle: 7_900)]
        let later = [CPUTicks(user: 1_030, system: 520, idle: 8_550), CPUTicks(user: 2_000, system: 100, idle: 8_000)]
        let shares = try #require(CPUReading.shares(from: earlier, to: later))
        // The first core spent 50 of its 100 ticks at work; the second sat idle.
        #expect(shares.cores == [0.5, 0])
        #expect(shares.user == 30.0 / 200)
        #expect(shares.system == 20.0 / 200)
    }

    @Test func aCounterThatStartedAgainIsAllowedFor() throws {
        let earlier = [CPUTicks(user: .max - 9, system: 0, idle: .max - 29)]
        let later = [CPUTicks(user: 20, system: 0, idle: 40)]
        let shares = try #require(CPUReading.shares(from: earlier, to: later))
        #expect(shares.cores == [0.3])
        #expect(shares.user == 0.3)
    }

    @Test func countsThatDoNotBelongTogetherGiveNoReading() {
        let one = [CPUTicks(user: 1, system: 1, idle: 1)]
        #expect(CPUReading.shares(from: [], to: one) == nil)
        #expect(CPUReading.shares(from: one, to: []) == nil)
        // No time has passed between the two looks.
        #expect(CPUReading.shares(from: one, to: one) == nil)
    }

    @Test func busyMeansAMinuteOfItNotAMoment() {
        // Four cores, all of them wanted for the last minute.
        let busy = reading(user: 0.5, system: 0.25, loadAverage: 3.4)
        #expect(busy.isBusy)
        #expect(busy.level == .raised)
        // The same load just now, on a Mac that was idle a moment ago.
        let burst = reading(user: 0.5, system: 0.25, loadAverage: 0.9)
        #expect(!burst.isBusy)
        #expect(burst.level == .normal)
        // Many threads waiting, and the processor hardly working: not busy either.
        #expect(!reading(user: 0.1, system: 0.05, loadAverage: 6).isBusy)
        #expect(busy.summary == VitalSummary(fraction: 0.75, line: "Heat: normal", level: .raised))
        #expect(busy.summary.figure == "75%")
    }

    @Test func heatComesBeforeLoad() {
        let hot = reading(user: 0.2, system: 0.1, heat: .serious)
        #expect(hot.level == .high)
        #expect(hot.summary.line == "Running hot")
        #expect(reading(heat: .raised).level == .normal)
        #expect(reading(heat: .raised).summary.line == "Heat: raised")
        #expect(reading(heat: .critical).summary.line == "Overheating")
        #expect(Heat(.nominal) == .normal)
        #expect(Heat(.fair) == .raised)
        #expect(Heat(.serious) == .serious)
        #expect(Heat(.critical) == .critical)
    }

    @Test func aLoadNeverReadsOverTheWhole() {
        let over = reading(user: 0.8, system: 0.3)
        #expect(over.load == 1)
        #expect(over.idle == 0)
    }

    @Test func theFastCoresComeFirst() {
        // The kernel counts the frugal cores first.
        let kinds = CoreLayout.assumed(count: 6, efficiency: 2)
        #expect(kinds == [.efficiency, .efficiency, .performance, .performance, .performance, .performance])
        var reading = reading()
        reading.cores = kinds.enumerated().map { CPUCore(id: $0.offset, kind: $0.element, load: Double($0.offset) / 10) }
        let groups = reading.coreGroups
        #expect(groups.map(\.kind) == [.performance, .efficiency])
        #expect(groups.map(\.caption) == ["4 performance cores", "2 efficiency"])
        #expect(groups[0].cores.map(\.id) == [2, 3, 4, 5])
        #expect(groups[0].busiest == 0.5)
        #expect(groups[1].average == 0.05)
    }

    @Test func aMacWithOneKindOfCoreHasPlainOnes() {
        #expect(CoreLayout.assumed(count: 8, efficiency: 0) == Array(repeating: .plain, count: 8))
        // A count that makes no sense is not believed.
        #expect(CoreLayout.assumed(count: 4, efficiency: 4) == Array(repeating: .plain, count: 4))
        let groups = reading(cores: 8).coreGroups
        #expect(groups.map(\.caption) == ["8 cores"])
        #expect(CPUCore.Kind.plain.caption(count: 1) == "1 core")
    }

    @Test func theFactsAreHeatAndHowLongTheMacHasBeenOn() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var reading = reading()
        #expect(reading.facts(now: now).map(\.title) == ["Heat"])
        reading.startedAt = now.addingTimeInterval(-6 * 86_400 - 5_400)
        let facts = reading.facts(now: now)
        #expect(facts.map(\.title) == ["Heat", "Uptime"])
        #expect(facts[0].value == "Normal")
        #expect(facts[1].value == "6 days")
        #expect(facts[1].detail.hasPrefix("Running since "))
    }
}

struct MemoryReadingTests {
    private func reading(freePercent: Int = 62, kernelLevel: Int = 1) -> MemoryReading {
        // Pages of 16 KB, as on Apple's chips: 65,536 of them to the gigabyte.
        let pages = MemoryReading.Pages(active: 7 * 65_536, wired: 3 * 65_536, compressor: 6 * 65_536, fileBacked: 5 * 65_536)
        return MemoryReading(pages: pages, pageSize: 16_384, total: 24 * gigabyte, swap: 2 * gigabyte, freePercent: freePercent, kernelLevel: kernelLevel)
    }

    @Test func thePartsAddUpToWhatIsInUse() {
        let reading = reading()
        #expect(reading.active == 7 * gigabyte)
        #expect(reading.wired == 3 * gigabyte)
        #expect(reading.compressed == 6 * gigabyte)
        #expect(reading.cached == 5 * gigabyte)
        #expect(reading.used == 16 * gigabyte)
        #expect(reading.available == 8 * gigabyte)
        #expect(reading.facts == [
            VitalFact(title: "Swap", value: "2.0 GB", detail: "Disk space standing in for memory."),
            VitalFact(title: "Cached", value: "5.0 GB", detail: "Files kept for speed. Counts as available."),
        ])
    }

    @Test func pressureIsWhatIsLeftOfTheKernelsFreeFigure() {
        #expect(reading(freePercent: 62).pressure == 0.38)
        #expect(reading(freePercent: 120).pressure == 0)
        #expect(reading(freePercent: -5).pressure == 1)
        #expect(reading().summary == VitalSummary(fraction: 0.38, line: "16.0 of 24 GB", level: .normal))
    }

    @Test func theKernelSaysWhenMemoryIsAStruggle() {
        #expect(reading(kernelLevel: 1).state == .normal)
        #expect(reading(kernelLevel: 2).state == .warning)
        #expect(reading(kernelLevel: 4).state == .critical)
        // A full-looking Mac is not under pressure until the kernel says so.
        #expect(reading(freePercent: 8, kernelLevel: 1).level == .normal)
        #expect(reading(kernelLevel: 2).level == .raised)
        #expect(reading(kernelLevel: 4).level == .high)
        #expect(MemoryReading.Pressure.warning.title == "Tight")
        #expect(MemoryReading.Pressure.critical.title == "Critical")
    }

    @Test func moreInUseThanThereIsLeavesNothingOverNotLessThanNothing() {
        var reading = reading()
        reading.active = 30 * gigabyte
        #expect(reading.used == 24 * gigabyte)
        #expect(reading.available == 0)
    }
}

struct BatteryReadingTests {
    /// What macOS says about the built-in battery, with the keys it uses.
    private func source(charge: Int = 100, plugged: Bool = true, charging: Bool = false, charged: Bool = false,
                        toEmpty: Int = 0, toFull: Int = 0, type: String = "InternalBattery") -> [String: Any] {
        [
            "Type": type, "Current Capacity": charge, "Max Capacity": 100,
            "Power Source State": plugged ? "AC Power" : "Battery Power",
            "Is Charging": charging, "Is Charged": charged, "Time to Empty": toEmpty, "Time to Full Charge": toFull,
        ]
    }

    private let registry: [String: Any] = [
        "CycleCount": 310, "DesignCycleCount9C": 1000,
        "BatteryData": ["NominalChargeCapacity": 7548, "DesignCapacity": 8579] as [String: Any],
    ]

    @Test func fullOnTheAdapter() throws {
        let reading = try #require(BatteryReading(source: source(charged: true), adapter: ["Watts": 140], registry: registry))
        #expect(reading.charge == 1)
        #expect(reading.state == .charged)
        #expect(reading.title == "Fully charged")
        #expect(reading.detail == "Running on the power adapter.")
        #expect(reading.summary == VitalSummary(fraction: 1, line: "Fully charged", level: .normal))
        #expect(reading.facts == [
            // 7,548 of 8,579 is 87.98%, which System Information states as 87%.
            VitalFact(title: "Health", value: "87%", detail: "Of the charge it held when new."),
            VitalFact(title: "Cycles", value: "310", detail: "Built for 1,000."),
            VitalFact(title: "Holds", value: "7,548 mAh", detail: "8,579 mAh when new."),
            VitalFact(title: "Adapter", value: "140 W", detail: "What it can deliver at most."),
        ])
    }

    @Test func chargingSaysHowLongOnceMacOSKnows() throws {
        let known = try #require(BatteryReading(source: source(charge: 62, charging: true, toFull: 48), adapter: nil, registry: [:]))
        #expect(known.state == .charging)
        #expect(known.summary.line == "0:48 to full")
        #expect(known.detail == "0:48 until full.")
        // macOS answers -1 while it is still working the time out.
        let unknown = try #require(BatteryReading(source: source(charge: 62, charging: true, toFull: -1), adapter: nil, registry: [:]))
        #expect(unknown.minutesToFull == nil)
        #expect(unknown.summary.line == "Charging")
        #expect(unknown.detail == "Working out how long it will take.")
        // Nothing is known about the battery's shape, and the adapter did not say what it delivers.
        #expect(unknown.facts == [VitalFact(title: "Adapter", value: "Connected", detail: "What it can deliver at most.")])
    }

    @Test func onTheBatteryItCountsDownAndRunsLowAtAFifth() throws {
        let fine = try #require(BatteryReading(source: source(charge: 74, plugged: false, toEmpty: 310), adapter: ["Watts": 140], registry: registry))
        #expect(fine.state == .onBattery)
        #expect(fine.summary == VitalSummary(fraction: 0.74, line: "5:10 left", level: .normal))
        #expect(fine.detail == "About 5:10 left.")
        // An adapter macOS still remembers is not one that is connected.
        #expect(fine.adapterWatts == nil)
        #expect(fine.facts.last == VitalFact(title: "Adapter", value: "None", detail: "Running on the battery alone."))

        let low = try #require(BatteryReading(source: source(charge: 20, plugged: false, toEmpty: -1), adapter: nil, registry: registry))
        #expect(low.isLow)
        #expect(low.level == .high)
        #expect(low.summary.line == "On battery")
        #expect(low.detail == "Working out how long is left.")
        let justOver = try #require(BatteryReading(source: source(charge: 21, plugged: false), adapter: nil, registry: registry))
        #expect(!justOver.isLow)
    }

    @Test func pluggedInAndHoldingIsNeitherChargingNorLow() throws {
        let holding = try #require(BatteryReading(source: source(charge: 80), adapter: ["Watts": 96], registry: registry))
        #expect(holding.state == .notCharging)
        #expect(holding.summary.line == "Not charging")
        // Low is about running out, which a plugged-in Mac is not doing.
        let lowButPlugged = try #require(BatteryReading(source: source(charge: 5, charging: true), adapter: nil, registry: registry))
        #expect(!lowButPlugged.isLow)
        #expect(lowButPlugged.level == .normal)
    }

    @Test func onlyTheBuiltInBatteryCounts() {
        #expect(BatteryReading(source: source(type: "UPS"), adapter: nil, registry: registry) == nil)
        #expect(BatteryReading(source: [:], adapter: nil, registry: registry) == nil)
    }

    @Test func olderSystemsKeepTheCapacitiesAtTheTop() throws {
        let flat: [String: Any] = ["CycleCount": 12, "AppleRawMaxCapacity": 5000, "DesignCapacity": 5000]
        let reading = try #require(BatteryReading(source: source(charged: true), adapter: nil, registry: flat))
        #expect(reading.health == 1)
        #expect(reading.facts.map(\.value) == ["100%", "12", "5,000 mAh", "Connected"])
        #expect(reading.facts[1].detail == "Full charges so far.")
    }
}

struct ConsumerTests {
    private let chrome = RunningApp(path: "/Applications/Google Chrome.app", bundleID: "com.google.Chrome", name: "Google Chrome", isRegular: true)
    private let xcode = RunningApp(path: "/Applications/Xcode.app", bundleID: "com.apple.dt.Xcode", name: "Xcode", isRegular: true)
    private let simulator = RunningApp(path: "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app",
                                       bundleID: "com.apple.iphonesimulator", name: "Simulator", isRegular: true)
    private let finder = RunningApp(path: "/System/Library/CoreServices/Finder.app", bundleID: "com.apple.finder", name: "Finder", isRegular: true)
    private let safari = RunningApp(path: "/System/Applications/Safari.app", bundleID: "com.apple.Safari", name: "Safari", isRegular: true)
    private let dock = RunningApp(path: "/System/Library/CoreServices/Dock.app", bundleID: "com.apple.dock", name: "Dock", isRegular: false)
    private let menuBarTool = RunningApp(path: "/Applications/Tally.app", bundleID: "com.example.Tally", name: "Tally", isRegular: false)

    private func usage(_ pid: pid_t, _ path: String, cpu: UInt64 = 0, megabytes: Int64 = 100, started: UInt64 = 1) -> ProcessUsage {
        ProcessUsage(pid: pid, path: path, cpuTime: cpu, memory: megabytes * megabyte, startedAt: started)
    }

    @Test func findsTheBundlesOnTheWayToAProgram() {
        let helper = "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)"
        #expect(Consumer.bundles(in: helper) == [
            "/Applications/Google Chrome.app",
            "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper (Renderer).app",
        ])
        #expect(Consumer.bundles(in: "/usr/libexec/mdworker") == [])
        #expect(Consumer.fileName(of: "/Applications/Tally.app") == "Tally")
        // A program's name may have dots of its own.
        #expect(Consumer.fileName(of: "/System/Library/XPCServices/com.apple.Virtualization.VirtualMachine") == "com.apple.Virtualization.VirtualMachine")
    }

    @Test func helpersAreCountedWithTheAppTheyBelongTo() throws {
        let usages = [
            usage(10, "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", megabytes: 300),
            usage(11, "/Applications/Google Chrome.app/Contents/Frameworks/X.framework/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)", megabytes: 500),
            usage(12, "/Applications/Google Chrome.app/Contents/Frameworks/X.framework/Helpers/Google Chrome Helper (GPU).app/Contents/MacOS/Google Chrome Helper (GPU)", megabytes: 200),
        ]
        let consumers = Consumer.grouped(usages, apps: [chrome])
        let only = try #require(consumers.first)
        #expect(consumers.count == 1)
        #expect(only.id == "/Applications/Google Chrome.app")
        #expect(only.name == "Google Chrome")
        #expect(only.memory == 1000 * megabyte)
        #expect(only.bundleID == "com.google.Chrome")
        #expect(only.canQuit)
        #expect(only.text(for: .memory) == "1,000 MB")
    }

    @Test func anAppInsideAnotherAppIsItsOwn() {
        let usages = [
            usage(20, "/Applications/Xcode.app/Contents/MacOS/Xcode"),
            usage(21, "/Applications/Xcode.app/Contents/Developer/usr/bin/sourcekit-lsp"),
            usage(22, "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app/Contents/MacOS/Simulator"),
        ]
        let consumers = Consumer.grouped(usages, apps: [xcode, simulator]).sorted { $0.name < $1.name }
        #expect(consumers.map(\.name) == ["Simulator", "Xcode"])
        #expect(consumers.map(\.memory) == [100 * megabyte, 200 * megabyte])
    }

    @Test func aProgramOutsideAnyAppStandsAlone() throws {
        let service = "/System/Library/Frameworks/Virtualization.framework/Versions/A/XPCServices/com.apple.Virtualization.VirtualMachine.xpc/Contents/MacOS/com.apple.Virtualization.VirtualMachine"
        let usages = [usage(30, "/Users/someone/.nvm/versions/node/v22/bin/node"), usage(31, service), usage(32, "/Applications/Old.app/Contents/MacOS/Old")]
        let consumers = Consumer.grouped(usages, apps: []) { path in path == service ? "Virtual Machine Service" : nil }
        let node = try #require(consumers.first { $0.name == "node" })
        #expect(!node.canQuit)
        #expect(!node.isSystem)
        let machine = try #require(consumers.first { $0.name == "Virtual Machine Service" })
        #expect(machine.isSystem)
        #expect(!machine.canQuit)
        // A bundle that is not among the running apps is named after its folder and gets no Quit button.
        let old = try #require(consumers.first { $0.id == "/Applications/Old.app" })
        #expect(old.name == "Old")
        #expect(!old.canQuit)
    }

    @Test func onlyAppsTheUserCouldQuitGetTheButton() {
        let usages = [
            usage(40, finder.path + "/Contents/MacOS/Finder"),
            usage(41, safari.path + "/Contents/MacOS/Safari"),
            usage(42, dock.path + "/Contents/MacOS/Dock"),
            usage(43, menuBarTool.path + "/Contents/MacOS/Tally"),
            usage(44, "/Applications/Mine.app/Contents/MacOS/Mine"),
        ]
        let mine = RunningApp(path: "/Applications/Mine.app", bundleID: "com.example.Mine", name: "Mine", isRegular: true)
        let consumers = Consumer.grouped(usages, apps: [finder, safari, dock, menuBarTool, mine], own: "com.example.Mine")
        func consumer(_ name: String) -> Consumer? { consumers.first { $0.name == name } }
        // Finder is never quit, and says it is part of macOS.
        #expect(consumer("Finder")?.canQuit == false)
        #expect(consumer("Finder")?.isSystem == true)
        // Apple's own apps are apps like any other.
        #expect(consumer("Safari")?.canQuit == true)
        #expect(consumer("Safari")?.isSystem == false)
        // What macOS runs without a place in the Dock is not the user's to quit.
        #expect(consumer("Dock")?.canQuit == false)
        #expect(consumer("Dock")?.isSystem == true)
        // Somebody else's menu bar app is.
        #expect(consumer("Tally")?.canQuit == true)
        // This app does not offer to quit itself.
        #expect(consumer("Mine")?.canQuit == false)
        #expect(consumer("Mine")?.isSystem == false)
    }

    @Test func processorTimeIsMeasuredBetweenTwoCounts() throws {
        let path = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        let earlier: [pid_t: ProcessUsage] = [10: usage(10, path, cpu: 1_000_000_000), 11: usage(11, path, cpu: 500_000_000), 12: usage(12, path, cpu: 9_000_000_000, started: 7)]
        let later = [
            // Half a second of work in two seconds: a quarter of a core.
            usage(10, path, cpu: 1_500_000_000),
            // And a whole core beside it.
            usage(11, path, cpu: 2_500_000_000),
            // The same number, but a program that started since: nothing to measure it against yet.
            usage(12, path, cpu: 100_000_000, started: 8),
        ]
        let chromeNow = try #require(Consumer.grouped(later, since: earlier, elapsed: 2, apps: [chrome]).first)
        #expect(chromeNow.cpu == 125)
        #expect(chromeNow.text(for: .cpu) == "125.0%")
        // Without an earlier count there is no figure at all.
        let first = try #require(Consumer.grouped(later, apps: [chrome]).first)
        #expect(first.cpu == nil)
    }

    @Test func theListsNameTheFewThatUseTheMost() {
        let consumers = (1...8).map { number in
            Consumer(id: "/Applications/App\(number).app", name: "App\(number)", cpu: Double(number), memory: Int64(9 - number) * megabyte, isSystem: false)
        } + [
            Consumer(id: "/usr/bin/idle", name: "idle", cpu: 0.01, memory: 0, isSystem: true),
            Consumer(id: "/usr/bin/new", name: "new", cpu: nil, memory: megabyte / 2, isSystem: true),
        ]
        #expect(consumers.top(by: .cpu).map(\.name) == ["App8", "App7", "App6", "App5", "App4"])
        #expect(consumers.top(by: .memory).map(\.name) == ["App1", "App2", "App3", "App4", "App5"])
        // What uses next to nothing, or has not been measured, is not listed even when there is room.
        #expect(Array(consumers.suffix(2)).top(by: .cpu).isEmpty)
        #expect(Array(consumers.suffix(2)).top(by: .memory).map(\.name) == ["new"])
    }
}

@MainActor
struct VitalsModelTests {
    private func model() -> VitalsModel {
        VitalsModel(settings: AppSettings(defaults: MemoryDefaults()))
    }

    @Test func nothingIsReadWhileNobodyCanSeeIt() {
        let model = model()
        #expect(model.wantedPace == nil)
        // A reading beside the icon is read for as long as the icon is there.
        model.settings.showsCPUBesideIcon = true
        #expect(model.wantedPace == .icon)
        model.settings.showsMenuBarItem = false
        #expect(model.wantedPace == nil)
        model.settings.showsMenuBarItem = true
        model.settings.showsCPUBesideIcon = false
        model.settings.showsMemoryBesideIcon = true
        #expect(model.wantedPace == .icon)
        #expect(VitalsModel.Pace.menu.interval < VitalsModel.Pace.icon.interval)
    }

    @Test func madeUpReadingsStandInForTheMacs() {
        let model = model()
        model.settings.showsCPUBesideIcon = true
        let standIn = VitalsDemoData.vitals()
        model.standIn = standIn
        #expect(model.wantedPace == nil)
        model.menuOpened()
        #expect(model.isMenuOpen)
        #expect(model.wantedPace == nil)
        #expect(model.readings == standIn)
        // Closing the menu forgets the processor's part of real readings only.
        model.menuClosed()
        #expect(model.readings == standIn)
    }

    @Test func theSettingsDecideWhatStandsBesideTheIcon() {
        let model = model()
        model.standIn = VitalsDemoData.vitals()
        #expect(model.iconReadings == nil)
        model.settings.showsCPUBesideIcon = true
        #expect(model.iconReadings == "CPU 16%")
        model.settings.showsMemoryBesideIcon = true
        #expect(model.iconReadings == "CPU 16%  RAM 38%")
        model.settings.showsCPUBesideIcon = false
        #expect(model.iconReadings == "RAM 38%")
        // Before anything has been read there is nothing to write.
        model.standIn = Vitals()
        #expect(model.iconReadings == nil)
    }

    @Test func aMacWithoutABatteryHasTwoTiles() {
        let model = model()
        model.standIn = VitalsDemoData.vitals()
        #expect(model.kinds == [.cpu, .memory, .battery])
        model.standIn = VitalsDemoData.vitals("desktop")
        #expect(model.kinds == [.cpu, .memory])
        #expect(model.readings.summary(of: .battery) == nil)
        #expect(model.readings.summary(of: .memory)?.line == "16.0 of 24 GB")
    }

    @Test func aTileOpensItsDetailsAndClosesThemAgain() {
        let model = model()
        model.standIn = VitalsDemoData.vitals()
        model.menuOpened()
        model.toggle(.cpu)
        #expect(model.detail == .cpu)
        model.toggle(.memory)
        #expect(model.detail == .memory)
        model.toggle(.memory)
        #expect(model.detail == nil)
        // The details go with the menu.
        model.toggle(.battery)
        model.menuClosed()
        #expect(model.detail == nil)
        #expect(!model.isMenuOpen)
    }

    @Test func quittingAStandInOnlyTakesItOffTheLists() throws {
        let model = model()
        model.standIn = VitalsDemoData.vitals()
        let warp = try #require(model.readings.byCPU.first { $0.name == "Warp" })
        model.quit(warp)
        #expect(!model.readings.byCPU.contains { $0.name == "Warp" })
        #expect(!model.readings.byMemory.contains { $0.name == "Warp" })
        // A part of macOS has no Quit button, and asking does nothing.
        let finder = try #require(model.readings.byCPU.first { $0.name == "Finder" })
        model.quit(finder)
        #expect(model.readings.byCPU.contains { $0.name == "Finder" })
    }

    @Test func theDemoStatesShowWhatAQuietAfternoonDoesNot() {
        #expect(VitalsDemoData.vitals("busy").cpu?.level == .raised)
        #expect(VitalsDemoData.vitals("hot").cpu?.level == .high)
        #expect(VitalsDemoData.vitals("tight").memory?.level == .raised)
        #expect(VitalsDemoData.vitals("full").memory?.level == .high)
        #expect(VitalsDemoData.vitals("low").battery?.level == .high)
        #expect(VitalsDemoData.vitals("charging").battery?.summary.line == "0:48 to full")
        #expect(VitalsDemoData.vitals("battery").battery?.summary.line == "5:10 left")
        #expect(VitalsDemoData.vitals().cpu?.summary.figure == "16%")
        #expect(VitalsDemoData.vitals().cpu?.level == .normal)
    }
}

@MainActor
struct FreeUpMemoryTests {
    @Test func theMenusButtonLeadsToTheOneTaskAndItsConfirmation() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "mdc-vitals-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(home: root, settings: AppSettings(defaults: MemoryDefaults()))
        // The made-up scan, which ticks what it recommends.
        model.performance.showDemo("summary")
        model.freeUpMemory()
        #expect(model.sidebarSelection == .performance)
        #expect(model.performance.phase == .managing)
        #expect(model.performance.section == .maintenance)
        #expect(model.performance.plan.steps.count == 1)
        #expect(model.performance.showingReview == (model.performance.check(for: .freeMemory)?.isAvailable == true))
        #expect(model.performance.showingReview)
    }
}

struct VitalsPanelPlacementTests {
    private let screen = CGRect(x: 0, y: 0, width: 1728, height: 1084)

    @Test func theDetailsStandLeftOfThePopoverWithTheirTopsLevel() {
        let popover = CGRect(x: 1000, y: 600, width: 360, height: 440)
        let frame = VitalsPanelPlacement.frame(for: CGSize(width: 360, height: 580), beside: popover, on: screen, gap: 10)
        #expect(frame == CGRect(x: 630, y: 460, width: 360, height: 580))
        #expect(frame.maxY == popover.maxY)
    }

    @Test func withNoRoomOnTheLeftTheyGoToTheRight() {
        let popover = CGRect(x: 200, y: 600, width: 360, height: 440)
        let frame = VitalsPanelPlacement.frame(for: CGSize(width: 360, height: 380), beside: popover, on: screen, gap: 10)
        #expect(frame.minX == 570)
        #expect(frame.maxY == popover.maxY)
        // On a second screen to the right, the left edge of that screen is what counts.
        let second = CGRect(x: 1728, y: 0, width: 2560, height: 1440)
        let near = CGRect(x: 1900, y: 900, width: 360, height: 440)
        #expect(VitalsPanelPlacement.frame(for: CGSize(width: 360, height: 380), beside: near, on: second, gap: 10).minX == 2270)
    }
}
