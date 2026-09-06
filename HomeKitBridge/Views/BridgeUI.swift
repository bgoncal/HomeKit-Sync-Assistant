import SwiftUI

/// Shared pieces every screen is built from. Everything here sits inside a
/// standard `List`/`Form`, so the app looks like the built-in iOS apps: grouped
/// sections, explanatory footers, and system colours.

// MARK: - Rows

/// A list row that states how one side of the bridge is doing: glyph, name, and
/// one line saying what that means.
struct BridgeStatusRow: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Icon, title, and one explaining line — the row Apple's own welcome screens use.
struct BridgeFeatureRow: View {
    let systemImage: String
    let title: String
    let message: String
    var tint: Color = .accentColor

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title.weight(.medium))
                .foregroundStyle(tint)
                .frame(width: 44)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pills

/// A word and its glyph in a tinted pill, for a status at a glance.
struct BridgePill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .imageScale(.small)
            Text(title)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.15), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

/// Which side is read and which side is written, as two pills and an arrow.
/// Shown anywhere an operation is named, so the direction is never implied.
struct BridgeDirectionBadge: View {
    let direction: SyncDirection

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                pill(for: direction.source)
                arrow("arrow.right")
                pill(for: direction.destination)
            }
            VStack(alignment: .leading, spacing: 4) {
                pill(for: direction.source)
                arrow("arrow.down")
                pill(for: direction.destination)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("From \(direction.source.name) to \(direction.destination.name)")
    }

    private func pill(for platform: SyncPlatform) -> some View {
        BridgePill(title: platform.name, systemImage: platform.symbolName, tint: platform.tint)
    }

    private func arrow(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
    }
}

extension SyncPlatform {
    var tint: Color {
        switch self {
        case .appleHome: return .orange
        case .homeAssistant: return .blue
        }
    }
}

// MARK: - Code

/// JSON and other machine text, in the one place the app uses a mono font.
struct BridgeCodeBlock: View {
    let content: String

    var body: some View {
        ScrollView(.horizontal) {
            Text(content)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
