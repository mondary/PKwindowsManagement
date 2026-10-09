import Foundation

@main
enum UpdateInstallScriptChecks {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
            .appendingPathComponent("installer-checks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for scenario in ["success", "rollback", "timeout"] {
            try check(scenario, root: root)
        }
        print("Installer: waits for process exit, replaces/relaunches, rolls back on open failure, preserves installed bundle on timeout")
    }

    private static func quote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private static func check(_ scenario: String, root: URL) throws {
        let directory = root.appendingPathComponent("\(scenario) with space and ' quote")
        let installed = directory.appendingPathComponent("Installed.app")
        let staged = directory.appendingPathComponent("Staged.app")
        let backup = directory.appendingPathComponent("Backup.app")
        let work = directory.appendingPathComponent("work")
        for folder in [installed, staged, work] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        try "old".write(to: installed.appendingPathComponent("version"), atomically: true, encoding: .utf8)
        try "new".write(to: staged.appendingPathComponent("version"), atomically: true, encoding: .utf8)
        let openLog = directory.appendingPathComponent("open.log")
        let opener = directory.appendingPathComponent("fake-open.sh")
        try """
        #!/bin/bash
        version=$(/bin/cat "$1/version")
        echo "$version" >> \(quote(openLog.path))
        if [ \(quote(scenario)) = rollback ] && [ "$version" = new ]; then exit 1; fi
        exit 0
        """.write(to: opener, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: opener.path)

        let oldProcess = Process()
        oldProcess.executableURL = URL(fileURLWithPath: "/bin/sleep")
        oldProcess.arguments = ["20"]
        try oldProcess.run()
        defer { if oldProcess.isRunning { oldProcess.terminate(); oldProcess.waitUntilExit() } }
        // Stub only the external launch, so no actual application is opened.
        var script = UpdateInstallScript.make(installed: installed, staged: staged, backup: backup, work: work,
                                             processID: oldProcess.processIdentifier)
            .replacingOccurrences(of: "/usr/bin/open", with: quote(opener.path))
        if scenario == "timeout" { script = script.replacingOccurrences(of: "-ge 600", with: "-ge 3") }
        let scriptURL = directory.appendingPathComponent("install.sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        let installer = Process()
        installer.executableURL = URL(fileURLWithPath: "/bin/bash")
        installer.arguments = [scriptURL.path]
        try installer.run()
        Thread.sleep(forTimeInterval: 0.3)
        let beforeExit = try String(contentsOf: installed.appendingPathComponent("version"), encoding: .utf8)
        precondition(beforeExit == "old")
        precondition(!FileManager.default.fileExists(atPath: openLog.path))
        if scenario != "timeout" { oldProcess.terminate(); oldProcess.waitUntilExit() }
        installer.waitUntilExit()
        precondition(installer.terminationStatus == (scenario == "success" ? 0 : 1))
        let expected = scenario == "success" ? "new" : "old"
        let afterExit = try String(contentsOf: installed.appendingPathComponent("version"), encoding: .utf8)
        precondition(afterExit == expected)
        if scenario == "timeout" {
            precondition(oldProcess.isRunning && !FileManager.default.fileExists(atPath: backup.path))
        } else {
            let opens = try String(contentsOf: openLog, encoding: .utf8)
            precondition(opens == (scenario == "success" ? "new\n" : "new\nold\n"))
        }
    }
}
