import Foundation

func localizedString(_ key: String) -> String {
    key.replacingOccurrences(of: "_", with: " ").capitalized
}
