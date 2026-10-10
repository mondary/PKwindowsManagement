import Foundation

/// SwiftPM `.process` flattens scripts; `.copy` bundles can preserve their folder.
/// Resolve both layouts without invoking the fatal generated Bundle.module accessor.
enum LayaRuntimeResources {
    static let filenames = ["server.py", "run.sh", "install-model.sh", "start-server.sh", "stop-server.sh"]

    static func sources(in bundle: Bundle) throws -> [URL] {
        try filenames.map { filename in
            guard let url = bundle.url(forResource: filename, withExtension: nil, subdirectory: "LayaServer")
                ?? bundle.url(forResource: filename, withExtension: nil) else {
                throw MissingResource(filename: filename)
            }
            return url
        }
    }

    private struct MissingResource: LocalizedError {
        let filename: String
        var errorDescription: String? {
            localizedFormat("Missing bundled AI script: %@. Reinstall the app to repair its resources.", filename)
        }
    }
}
