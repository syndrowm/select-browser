import SwiftUI

struct PickerView: View {
    let url: URL?
    let browsers: [Browser]
    let savedRule: DomainRule?
    let onOpen: (Browser, Profile?) -> Void
    let onSetDefault: (@escaping (Bool) -> Void) -> Void
    /// Reports the content's laid-out size so AppKit can size the window
    /// explicitly (instead of via constraint-driven auto-sizing, which can
    /// crash when the height changes during a layout pass).
    var onContentSize: (CGSize) -> Void = { _ in }

    @State private var expanded: Browser.ID?
    @State private var defaultStatus: String?

    private var host: String? { url?.host }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(spacing: 6) {
                ForEach(browsers) { browser in
                    browserBlock(browser)
                }
            }

            if host != nil {
                Text("Your choice is remembered for this site.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            HStack(spacing: 10) {
                Button("Set as Default Browser") {
                    defaultStatus = "Waiting for confirmation…"
                    onSetDefault { ok in
                        defaultStatus = ok
                            ? "✓ Set as default browser"
                            : "Couldn't set — confirm in System Settings"
                    }
                }
                if let defaultStatus {
                    Text(defaultStatus)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ContentSizeKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(ContentSizeKey.self) { size in
            onContentSize(size)
        }
        .onAppear(perform: preselectSavedChoice)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Open link in…")
                .font(.headline)
            if let url {
                Text(url.absoluteString)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                Text("No URL — app was launched directly")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Auto-expand the browser that holds the remembered profile.
    private func preselectSavedChoice() {
        guard let saved = savedRule,
              let browser = browsers.first(where: { $0.id == saved.bundleID }),
              browser.supportsProfiles else { return }
        expanded = browser.id
    }

    private func isSaved(_ browser: Browser, profile: Profile?) -> Bool {
        guard let saved = savedRule else { return false }
        return saved.bundleID == browser.bundleID
            && saved.profileDirectory == profile?.directory
    }

    @ViewBuilder
    private func browserBlock(_ browser: Browser) -> some View {
        VStack(spacing: 4) {
            RowButton(
                icon: Image(nsImage: browser.icon),
                title: browser.name,
                trailing: browser.supportsProfiles
                    ? Image(systemName: expanded == browser.id ? "chevron.down" : "chevron.right")
                    : nil,
                // A profile-less browser (e.g. Safari) can itself be the default.
                isPreferred: !browser.supportsProfiles && isSaved(browser, profile: nil)
            ) {
                if browser.supportsProfiles {
                    expanded = (expanded == browser.id) ? nil : browser.id
                } else {
                    choose(browser, nil)
                }
            }

            if expanded == browser.id {
                VStack(spacing: 2) {
                    ForEach(browser.profiles) { profile in
                        RowButton(
                            icon: Image(systemName: "person.crop.circle"),
                            title: profile.name,
                            indent: true,
                            isPreferred: isSaved(browser, profile: profile)
                        ) {
                            choose(browser, profile)
                        }
                    }
                }
            }
        }
    }

    private func choose(_ browser: Browser, _ profile: Profile?) {
        onOpen(browser, profile)
    }
}

/// Carries the picker's laid-out size up to AppKit for explicit window sizing.
private struct ContentSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// A clickable row with hover highlight. The "preferred" row (the remembered
/// choice) is tinted, badged, and bound to the Return key.
private struct RowButton: View {
    let icon: Image
    let title: String
    var trailing: Image? = nil
    var indent: Bool = false
    var isPreferred: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: indent ? 16 : 22, height: indent ? 16 : 22)
                Text(title)
                    .font(indent ? .callout : .body)
                if isPreferred {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption2)
                }
                Spacer()
                if let trailing {
                    trailing.foregroundStyle(.secondary).font(.caption)
                }
            }
            .padding(.vertical, 6)
            .padding(.leading, indent ? 28 : 10)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(backgroundColor)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(isPreferred ? .defaultAction : nil)
        .onHover { hovering = $0 }
    }

    private var backgroundColor: Color {
        if hovering { return Color.accentColor.opacity(0.18) }
        if isPreferred { return Color.accentColor.opacity(0.10) }
        return .clear
    }
}
