import SwiftUI

struct BridgePage<Content: View>: View {
    let title: String
    let subtitle: String?
    let showsHeader: Bool
    private let content: Content

    init(title: String, subtitle: String? = nil, showsHeader: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.showsHeader = showsHeader
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if showsHeader {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.largeTitle.bold())
                        if let subtitle {
                            Text(subtitle)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                content
            }
            .padding(20)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        // The in-page header already names the screen; keep the bar slim so the
        // title is not printed twice inside a navigation stack.
        .navigationTitle(showsHeader ? "" : title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BridgeCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // An opaque fill rather than a material: it reads the same on iPhone and
        // Mac, in light and dark, and over any page background.
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct BridgeStatusHeader: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

struct BridgeInfoRow: View {
    let label: String
    let value: String
    var selectable = false

    var body: some View {
        LabeledContent {
            if selectable {
                Text(value)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
            } else {
                Text(value)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
            }
        } label: {
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

struct BridgeCodeBlock: View {
    let content: String

    var body: some View {
        ScrollView(.horizontal) {
            Text(content)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.black.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Shows which side is read and which side is written for a sync operation.
/// Used anywhere an operation is named, so the direction is never implied.
struct BridgeDirectionBadge: View {
    let direction: SyncDirection
    var showsExplanation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    platform(direction.source)
                    arrow(.right)
                    platform(direction.destination)
                }
                VStack(alignment: .leading, spacing: 4) {
                    platform(direction.source)
                    arrow(.down)
                    platform(direction.destination)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("From \(direction.source.name) to \(direction.destination.name)")

            if showsExplanation {
                Text(direction.explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private enum ArrowDirection: String {
        case right = "arrow.right"
        case down = "arrow.down"
    }

    private func arrow(_ arrowDirection: ArrowDirection) -> some View {
        Image(systemName: arrowDirection.rawValue)
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
    }

    private func platform(_ platform: SyncPlatform) -> some View {
        HStack(spacing: 4) {
            Image(systemName: platform.symbolName)
                .imageScale(.small)
            Text(platform.name)
                .lineLimit(1)
                .fixedSize()
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint(for: platform).opacity(0.15))
        .foregroundStyle(tint(for: platform))
        .clipShape(Capsule())
    }

    private func tint(for platform: SyncPlatform) -> Color {
        switch platform {
        case .appleHome: return .orange
        case .homeAssistant: return .blue
        }
    }
}

/// Icon + title + explanation, for the "how this works" lists in onboarding and
/// the empty states.
struct BridgeBulletRow: View {
    let systemImage: String
    let title: String
    let message: String
    var tint: Color = .accentColor

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
