import Foundation

enum DesktopOrder {
    /// Insertion, not a swap: other Spaces (including fullscreen) keep their
    /// relative order and identity.
    static func moving(_ ids: [UInt64], from source: Int, to destination: Int) -> [UInt64]? {
        guard ids.indices.contains(source), ids.indices.contains(destination),
              Set(ids).count == ids.count else { return nil }
        var result = ids
        let id = result.remove(at: source)
        result.insert(id, at: destination)
        return result
    }
}
