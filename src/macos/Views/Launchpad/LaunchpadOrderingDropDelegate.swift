import SwiftUI
import UniformTypeIdentifiers

struct LaunchpadAppDropDelegate: DropDelegate {
    let targetBundleID: String
    let settings: AppSettings
    let fallbackOrder: [String]
    @Binding var draggingBundleID: String?

    func validateDrop(info: DropInfo) -> Bool {
        settings.launchpadAppSortMode == .custom
            && draggingBundleID != nil
            && draggingBundleID != targetBundleID
    }

    func dropEntered(info: DropInfo) {
        guard settings.launchpadAppSortMode == .custom,
              let draggingBundleID,
              draggingBundleID != targetBundleID
        else { return }
        settings.moveLaunchpadApp(draggingBundleID, toward: targetBundleID, fallbackOrder: fallbackOrder)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { draggingBundleID = nil }
        return settings.launchpadAppSortMode == .custom
    }
}

struct LaunchpadCategoryDropDelegate: DropDelegate {
    let targetGroup: LaunchpadGroup
    let settings: AppSettings
    @Binding var draggingGroup: LaunchpadGroup?

    func validateDrop(info: DropInfo) -> Bool {
        settings.launchpadCategorySortMode == .custom
            && draggingGroup != nil
            && draggingGroup != targetGroup
    }

    func dropEntered(info: DropInfo) {
        guard settings.launchpadCategorySortMode == .custom,
              let draggingGroup,
              draggingGroup != targetGroup
        else { return }
        settings.moveLaunchpadCategory(draggingGroup, toward: targetGroup)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { draggingGroup = nil }
        return settings.launchpadCategorySortMode == .custom
    }
}
