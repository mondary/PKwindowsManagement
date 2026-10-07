import AppKit
import Combine
import Foundation

@MainActor
final class LocalAIModelManager: ObservableObject {
    static let shared = LocalAIModelManager()

    static let modelRepository = "convaiinnovations/laya"
    static let serverURL = URL(string: "http://127.0.0.1:8770")!

    @Published private(set) var modelInstalled = false
    @Published private(set) var modelSize: Int64 = 0
    @Published private(set) var serverReady = false
    @Published private(set) var serverLoading = false
    @Published private(set) var isBusy = false
    @Published private(set) var errorMessage: String?

    private let fileManager = FileManager.default
    private let supportDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/PK/LayaServer", isDirectory: true)
    private let cacheDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".cache/huggingface/hub/models--convaiinnovations--laya", isDirectory: true)

    private init() {
        installRuntimeFiles()
        refresh()
    }

    /// Small service code ships inside the app, then lives in the shared
    /// Application Support directory. Model weights never ship with the app.
    private func installRuntimeFiles() {
        do {
            try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            let files: [(String, String)] = [
                ("server", "py"), ("run", "sh"), ("install-model", "sh"),
                ("start-server", "sh"), ("stop-server", "sh")
            ]
            for (name, ext) in files {
                guard let source = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "LayaServer") else { continue }
                let destination = supportDirectory.appendingPathComponent("\(name).\(ext)")
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: source, to: destination)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() {
        let blobs = cacheDirectory.appendingPathComponent("blobs", isDirectory: true)
        var bytes: Int64 = 0
        var completeCount = 0
        if let enumerator = fileManager.enumerator(at: blobs, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                guard let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                      size > 50 * 1024 * 1024
                else { continue }
                bytes += Int64(size)
                completeCount += 1
            }
        }
        modelSize = bytes
        // The repository currently includes three large checkpoint blobs.
        // Treat partial downloads as not installed so the UI still offers
        // the download/repair action.
        modelInstalled = completeCount >= 3
        Task { await refreshServerStatus() }
    }

    func downloadModel() {
        runScript("install-model.sh") { [weak self] success, output in
            guard let self else { return }
            self.isBusy = false
            if !success { self.errorMessage = output }
            self.refresh()
        }
    }

    func startServer() {
        runScript("start-server.sh") { [weak self] success, output in
            guard let self else { return }
            self.isBusy = false
            if !success { self.errorMessage = output }
            Task { await self.refreshServerStatus() }
        }
    }

    func stopServer() {
        runScript("stop-server.sh") { [weak self] success, output in
            guard let self else { return }
            self.isBusy = false
            if !success { self.errorMessage = output }
            Task { await self.refreshServerStatus() }
        }
    }

    func deleteModel() {
        runScript("stop-server.sh") { [weak self] success, output in
            guard let self else { return }
            self.isBusy = false
            if !success {
                self.errorMessage = output
                return
            }
            do {
                if self.fileManager.fileExists(atPath: self.cacheDirectory.path) {
                    try self.fileManager.removeItem(at: self.cacheDirectory)
                }
                self.errorMessage = nil
                self.refresh()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func refreshServerStatus() async {
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.serverURL.appendingPathComponent("health"))
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                serverReady = false
                serverLoading = false
                return
            }
            serverReady = json["ready"] as? Bool == true
            serverLoading = json["loading"] as? Bool == true
        } catch {
            serverReady = false
            serverLoading = false
        }
    }

    private func runScript(_ name: String, completion: @escaping (Bool, String) -> Void) {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        let script = supportDirectory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: script.path) else {
            isBusy = false
            errorMessage = "Missing shared service script: \(script.path)"
            return
        }

        let process = Process()
        let logURL = supportDirectory.appendingPathComponent("\(name).log")
        try? fileManager.removeItem(at: logURL)
        fileManager.createFile(atPath: logURL.path, contents: nil)
        guard let logHandle = try? FileHandle(forWritingTo: logURL) else {
            isBusy = false
            errorMessage = "Unable to open operation log."
            return
        }
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        process.standardOutput = logHandle
        process.standardError = logHandle
        process.terminationHandler = { process in
            try? logHandle.close()
            let data = try? Data(contentsOf: logURL)
            let text = String(data: data ?? Data(), encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                completion(process.terminationStatus == 0, text)
            }
        }
        do {
            try process.run()
        } catch {
            isBusy = false
            errorMessage = error.localizedDescription
        }
    }

    var modelSizeLabel: String {
        ByteCountFormatter.string(fromByteCount: modelSize, countStyle: .file)
    }
}
