//
//  Shell.swift
//  SwiftMacCleaner
//

import Foundation

nonisolated enum Shell {
    struct Output: Sendable {
        var status: Int32
        var stdout: String
        var stderr: String
        var timedOut: Bool

        var succeeded: Bool { status == 0 && !timedOut }
    }

    /// Apps launched from Finder get a bare PATH, so the usual install locations are searched by hand.
    static var searchDirectories: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "/usr/bin", "/bin", "/usr/sbin", "/sbin", "/usr/local/bin", "/opt/homebrew/bin",
            "\(home)/.docker/bin", "\(home)/.orbstack/bin", "/Applications/Docker.app/Contents/Resources/bin",
        ]
    }

    static func which(_ name: String) -> String? {
        searchDirectories.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Runs a command as root through macOS's own password prompt. Only `tmutil` needs this.
    /// Cancelling the prompt makes `osascript` fail with error -128, which the caller reads as "skipped".
    static func runAsAdministrator(_ command: [String], timeout: TimeInterval = 600) -> Output? {
        let quoted = command.map { "'" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'" }.joined(separator: " ")
        let escaped = quoted.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        return run("/usr/bin/osascript", ["-e", script], timeout: timeout)
    }

    /// Runs a tool and waits for it, giving up after `timeout` seconds.
    ///
    /// Output goes to temporary files rather than pipes: a tool such as `docker` can leave helper
    /// processes holding a pipe open, which would keep a reader waiting long after the tool is gone.
    /// `environment` replaces the app's own, PATH included; `directory` is where the tool starts.
    static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 30,
                    environment: [String: String]? = nil, directory: URL? = nil) -> Output? {
        let fileManager = FileManager.default
        let scratch = fileManager.temporaryDirectory.appending(path: "mdc-\(UUID().uuidString)")
        let outURL = scratch.appendingPathExtension("out")
        let errURL = scratch.appendingPathExtension("err")
        fileManager.createFile(atPath: outURL.path, contents: nil)
        fileManager.createFile(atPath: errURL.path, contents: nil)
        defer {
            try? fileManager.removeItem(at: outURL)
            try? fileManager.removeItem(at: errURL)
        }
        guard let outHandle = try? FileHandle(forWritingTo: outURL),
              let errHandle = try? FileHandle(forWritingTo: errURL) else { return nil }
        defer {
            try? outHandle.close()
            try? errHandle.close()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outHandle
        process.standardError = errHandle
        if let environment {
            process.environment = environment
        } else {
            var inherited = ProcessInfo.processInfo.environment
            inherited["PATH"] = searchDirectories.joined(separator: ":")
            process.environment = inherited
        }
        if let directory { process.currentDirectoryURL = directory }

        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do { try process.run() } catch { return nil }

        var timedOut = false
        if exited.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            process.terminate()
            if exited.wait(timeout: .now() + 2) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = exited.wait(timeout: .now() + 2)
            }
        }

        return Output(
            status: timedOut || process.isRunning ? -1 : process.terminationStatus,
            stdout: (try? String(contentsOf: outURL, encoding: .utf8)) ?? "",
            stderr: (try? String(contentsOf: errURL, encoding: .utf8)) ?? "",
            timedOut: timedOut
        )
    }
}
