import SwiftUI

struct PickerView: View {
    let url: URL?
    let browsers: [Browser]
    let onOpen: (Browser, Profile?) -> Void
    let onSetDefault: (@escaping (Bool) -> Void) -> Void

    @State private var expanded: Browser.ID?
    @State private var defaultStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(spacing: 6) {
                ForEach(browsers) { browser in
                    browserBlock(browser)
                }
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

    @ViewBuilder
    private func browserBlock(_ browser: Browser) -> some View {
        VStack(spacing: 4) {
            RowButton(
                icon: Image(nsImage: browser.icon),
                title: browser.name,
                trailing: browser.supportsProfiles
                    ? Image(systemName: expanded == browser.id ? "chevron.down" : "chevron.right")
                    : nil
            ) {
                if browser.supportsProfiles {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        expanded = (expanded == browser.id) ? nil : browser.id
                    }
                } else {
                    onOpen(browser, nil)
                }
            }

            if expanded == browser.id {
                VStack(spacing: 2) {
                    ForEach(browser.profiles) { profile in
                        RowButton(
                            icon: Image(systemName: "person.crop.circle"),
                            title: profile.name,
                            indent: true
                        ) {
                            onOpen(browser, profile)
                        }
                    }
                }
            }
        }
    }
}

/// A clickable row with hover highlight.
private struct RowButton: View {
    let icon: Image
    let title: String
    var trailing: Image? = nil
    var indent: Bool = false
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
                    .fill(hovering ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
