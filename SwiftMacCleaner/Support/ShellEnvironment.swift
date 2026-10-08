//
//  ShellEnvironment.swift
//  SwiftMacCleaner
//

import Foundation

/// What the user's login shell knows and an app opened from Finder does not: the PATH their tools
/// are on, and the variables those tools read their folders from.
nonisolated struct ShellEnvironment: Sendable {
    var variables: [String: String] = [:]
    /// Install locations looked in after the shell's PATH. Tests empty this to keep the Mac's real tools out.
    var usualDirectories = Shell.searchDirectories

    /// Shells that take `-ilc` and read the same files a terminal window does.
    static let knownShells: Set<String> = ["zsh", "bash", "fish"]

    /// Set for every tool that is asked something, so none of them goes online or stops to ask back.
    static let quiet: [String: String] = [
        "COREPACK_ENABLE_NETWORK": "0", "COREPACK_ENABLE_DOWNLOAD_PROMPT": "0",
        "NO_UPDATE_NOTIFIER": "1", "npm_config_update_notifier": "false",
        "HOMEBREW_NO_AUTO_UPDATE": "1", "PIP_DISABLE_PIP_VERSION_CHECK": "1",
    ]

    /// The app's own environment, for when the shell cannot be asked.
    static var inherited: ShellEnvironment { ShellEnvironment(variables: ProcessInfo.processInfo.environment) }

    /// Starts asking the login shell, so a scan can carry the answer to every scanner that wants it.
    static func loading() -> Task<ShellEnvironment, Never> {
        Task { await load() }
    }

    /// Asks the login shell for its environment, the way a new terminal window would get it.
    /// A shell that is not one of the known ones, or takes longer than `timeout` seconds, is not waited for.
    @concurrent
    static func load(timeout: TimeInterval = 10) async -> ShellEnvironment {
        guard let shell = loginShell(), knownShells.contains((shell as NSString).lastPathComponent) else { return inherited }
        let marker = "mdc-\(UUID().uuidString)"
        // Interactive as well as login: most people export from the file their terminal reads, such as .zshrc.
        let script = "printf %s \(marker); /usr/bin/env -0; printf %s \(marker)"
        guard let output = Shell.run(shell, ["-ilc", script], timeout: timeout),
              let variables = variables(in: output.stdout, between: marker) else { return inherited }
        return ShellEnvironment(variables: variables)
    }

    /// The shell in the user's account record, which is the one Terminal opens.
    static func loginShell() -> String? {
        guard let entry = getpwuid(getuid()), let shell = entry.pointee.pw_shell else { return nil }
        let path = String(cString: shell)
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }

    /// The variables `env -0` printed between two copies of `marker`. Whatever the shell's own
    /// start-up files printed around them is ignored. Nil when the output is not of that shape.
    static func variables(in output: String, between marker: String) -> [String: String]? {
        let parts = output.components(separatedBy: marker)
        guard parts.count == 3 else { return nil }
        var variables: [String: String] = [:]
        for entry in parts[1].split(separator: "\0") {
            guard let equals = entry.firstIndex(of: "=") else { continue }
            variables[String(entry[..<equals])] = String(entry[entry.index(after: equals)...])
        }
        return variables.isEmpty ? nil : variables
    }

    /// Where tools are looked for: the shell's PATH first, then the usual install locations.
    var searchDirectories: [String] {
        var seen = Set<String>()
        let fromShell = (variables["PATH"] ?? "").split(separator: ":").map(String.init)
        return (fromShell + usualDirectories).filter { $0.hasPrefix("/") && seen.insert($0).inserted }
    }

    func which(_ name: String) -> String? {
        searchDirectories.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// The folder a variable names, when it is set to a full path.
    func folder(named variable: String) -> URL? {
        guard let value = variables[variable]?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        let expanded = (value as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
    }

    /// Runs a tool that prints a folder and returns that folder: the last line it wrote that is a full path.
    /// The tool gets the shell's variables, so it answers as it would in a terminal.
    func folder(printedBy tool: String, _ arguments: [String], startingIn directory: URL, timeout: TimeInterval = 15) -> URL? {
        // Apple's stand-ins in /usr/bin, such as pip3, can raise a prompt to install the developer tools.
        let candidates = searchDirectories.filter { $0 != "/usr/bin" }.map { "\($0)/\(tool)" }
        guard let executable = candidates.first(where: FileManager.default.isExecutableFile(atPath:)) else { return nil }
        var environment = variables.merging(Self.quiet) { _, quiet in quiet }
        environment["PATH"] = searchDirectories.joined(separator: ":")
        guard let output = Shell.run(executable, arguments, timeout: timeout, environment: environment, directory: directory),
              output.succeeded else { return nil }
        let lines = output.stdout.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let path = lines.last(where: { $0.hasPrefix("/") }) else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }
}
