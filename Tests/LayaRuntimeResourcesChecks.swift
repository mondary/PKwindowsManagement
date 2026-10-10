import Foundation

@main
struct LayaRuntimeResourcesChecks {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        // Both SwiftPM layouts must work after relocation, without build-machine paths.
        for nested in [false, true] {
            let bundleURL = root.appendingPathComponent("\(nested).bundle")
            let resources = nested ? bundleURL.appendingPathComponent("LayaServer") : bundleURL
            try fm.createDirectory(at: resources, withIntermediateDirectories: true)
            for filename in LayaRuntimeResources.filenames {
                try Data(filename.utf8).write(to: resources.appendingPathComponent(filename))
            }
            let bundle = Bundle(url: bundleURL)!
            let sources = try LayaRuntimeResources.sources(in: bundle)
            assert(sources.count == 5)
            for source in sources {
                let contents = try String(contentsOf: source, encoding: .utf8)
                assert(contents == source.lastPathComponent)
            }
        }

        // Partial/missing resources must throw an actionable error, never trap or
        // silently install an incomplete runtime.
        let missingURL = root.appendingPathComponent("missing.bundle")
        try fm.createDirectory(at: missingURL, withIntermediateDirectories: true)
        do {
            _ = try LayaRuntimeResources.sources(in: Bundle(url: missingURL)!)
            fatalError("Missing scripts should fail")
        } catch {
            assert(error.localizedDescription.contains("server.py"))
        }

        // Pass a packaged bundle path to verify actual release resources too.
        if CommandLine.arguments.count > 1 {
            let bundle = Bundle(path: CommandLine.arguments[1])!
            for source in try LayaRuntimeResources.sources(in: bundle) {
                let data = try Data(contentsOf: source)
                assert(!data.isEmpty)
            }
        }
        print("Laya resources: relocated flat/nested bundles, missing scripts and packaged resources passed")
    }
}
