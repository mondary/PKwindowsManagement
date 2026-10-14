import SwiftUI

struct WindowSwitcherView: View {
    @ObservedObject var model: WindowSwitcherModel
    let onActivate: (WindowSwitcherID) -> Void
    let onClose: () -> Void
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !model.accessibilityGranted {
                permissionView
            } else {
                if !model.previewsGranted { previewPermissionBanner }
                if !model.message.isEmpty {
                    Text(model.message).font(.callout).foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                }
                if model.isLoading {
                    ProgressView(localizedString("Loading windows…"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.filteredItems.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "macwindow").font(.system(size: 32)).foregroundStyle(.secondary)
                        Text(localizedString(model.query.isEmpty ? "No windows available" : "No matching windows"))
                        Button(localizedString("Refresh")) { model.prepare(resetSearch: false) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    windowGrid
                }
            }
            Divider()
            HStack(spacing: 16) {
                Text("⇥  " + localizedString("Browse"))
                Text("↵  " + localizedString("Open"))
                Text("⌘1–9  " + localizedString("Quick select"))
                Spacer(minLength: 0)
                Text("esc  " + localizedString("Close"))
            }
            .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear { searchFocused = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(localizedString("Window previews"), systemImage: "rectangle.on.rectangle")
                    .font(.headline)
                if !model.isLoading, model.accessibilityGranted {
                    Text("\(model.filteredItems.count)").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.prepare(resetSearch: false) } label: { Image(systemName: "arrow.clockwise") }
                    .help(localizedString("Refresh") + " (⌘R)")
                    .accessibilityLabel(localizedString("Refresh"))
                Button(action: onClose) { Image(systemName: "xmark") }
                    .help(localizedString("Close"))
                    .accessibilityLabel(localizedString("Close"))
            }
            .buttonStyle(.plain)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(localizedString("Search by app or window title"), text: $model.query)
                    .textFieldStyle(.plain).font(.system(size: 17)).focused($searchFocused)
                    .accessibilityLabel(localizedString("Search by app or window title"))
                if !model.query.isEmpty {
                    Button { model.query = ""; searchFocused = true } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel(localizedString("Clear"))
                }
            }
        }
        .padding(20)
    }

    private var windowGrid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: model.columns), spacing: 12) {
                    ForEach(Array(model.filteredItems.enumerated()), id: \.element.id) { rank, item in
                        WindowSwitcherCard(item: item, icon: model.icons[item.id.pid], image: model.images[item.id],
                            isSelected: model.selectedID == item.id, rank: rank,
                            isLoadingPreview: model.previewsGranted && !model.completedPreviews.contains(item.id),
                            onActivate: { onActivate(item.id) })
                            .id(item.id)
                            .onAppear { model.requestPreview(item.id) }
                    }
                }
                .padding(16)
            }
            .id(model.generation)
            .onChange(of: model.selectedID) { id in
                if let id { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private var previewPermissionBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "photo").foregroundStyle(.secondary)
            Text(localizedString("Enable Screen Recording to show thumbnails. Reopen the picker after granting access; macOS may ask you to restart the app."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(localizedString("Enable previews…")) { model.requestPreviews() }
        }
        .padding(14).background(.primary.opacity(0.035))
    }

    private var permissionView: some View {
        VStack(spacing: 14) {
            Image(systemName: "hand.raised").font(.system(size: 34)).foregroundStyle(.secondary)
            Text(localizedString("Allow Accessibility to list and activate your windows."))
                .multilineTextAlignment(.center)
            Button(localizedString("Open Accessibility Settings")) { model.requestAccessibility() }
            Button(localizedString("Refresh")) { model.prepare(resetSearch: false) }
        }
        .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WindowSwitcherCard: View {
    let item: WindowSwitcherItem
    let icon: NSImage?
    let image: NSImage?
    let isSelected: Bool
    let rank: Int
    var isLoadingPreview = false
    let onActivate: () -> Void

    var body: some View {
        Button(action: onActivate) {
            VStack(alignment: .leading, spacing: 10) {
                thumbnail
                caption
                if let status {
                    Text(localizedString(status)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 12))
            .overlay(selectionBorder)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .help(item.appName + " — " + item.displayTitle)
        .accessibilityLabel(item.appName + ", " + item.displayTitle)
        .accessibilityValue(isSelected ? localizedString("Selected") : "")
        .accessibilityHint(localizedString("Activate this window"))
    }

    private var backgroundColor: Color {
        isSelected ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor).opacity(0.75)
    }

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: 12).strokeBorder(
            isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.045))
            if let image {
                Image(nsImage: image).renderingMode(.original).resizable().scaledToFit().padding(4)
            } else {
                VStack(spacing: 8) {
                    appIcon.frame(width: 44, height: 44)
                    if isLoadingPreview {
                        ProgressView().controlSize(.small).accessibilityLabel(localizedString("Loading windows…"))
                    } else {
                        Text(localizedString("Preview unavailable")).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 132)
        .clipped()
    }

    private var caption: some View {
        HStack(spacing: 8) {
            appIcon.frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.appName).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(item.displayTitle).font(.system(size: 12, weight: .medium)).lineLimit(1)
            }
            Spacer(minLength: 0)
            if rank < 9 {
                Text("⌘\(rank + 1)").font(.caption.monospaced()).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var appIcon: some View {
        if let icon { Image(nsImage: icon).resizable().scaledToFit() }
        else { Image(systemName: "macwindow").resizable().scaledToFit().foregroundStyle(.secondary) }
    }

    private var status: String? {
        if item.isMinimized { return "Minimized" }
        if item.isHidden { return "Hidden app" }
        if item.isFullScreen { return "Fullscreen" }
        if !item.isOnScreen { return "Off screen" }
        return nil
    }
}
