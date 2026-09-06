import SwiftUI

// MARK: - Steps

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case howItWorks
    case requirements
    case appleHome
    case homeAssistant
    case ready

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: return "Keep both homes in sync"
        case .howItWorks: return "How the bridge works"
        case .requirements: return "Before you start"
        case .appleHome: return "Connect Apple Home"
        case .homeAssistant: return "Connect Home Assistant"
        case .ready: return "You’re ready"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome: return "What this app does, in one screen."
        case .howItWorks: return "How devices are matched, and when anything is written."
        case .requirements: return "One Home Assistant setting decides whether syncing can work."
        case .appleHome: return "Allow the app to read and update your Apple Home."
        case .homeAssistant: return "Enter the address and access token for your Home Assistant."
        case .ready: return "Here’s what is set up, and where to go next."
        }
    }
}

/// Result of the "Test connection" button on the credentials step.
enum OnboardingConnectionState: Equatable {
    case idle
    case testing
    case succeeded
    case failed(String)
}

// MARK: - Connected view

struct OnboardingView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var syncEngine: SyncEngine

    @AppStorage("haURL") private var haURL = ""
    @AppStorage("haToken") private var haToken = ""
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    @State private var step: OnboardingStep = .welcome
    @State private var connectionState: OnboardingConnectionState = .idle

    var body: some View {
        OnboardingContent(
            step: step,
            homeKitAuthorized: homeKitManager.isAuthorized,
            homeNames: homeKitManager.homes.map(\.name),
            haURL: $haURL,
            haToken: $haToken,
            connectionState: connectionState,
            onRequestHomeKitAccess: { homeKitManager.requestAccess() },
            onTestConnection: testConnection,
            onBack: { move(by: -1) },
            onNext: { move(by: 1) },
            onFinish: { onboardingComplete = true }
        )
        .onChange(of: haURL) { _, _ in connectionState = .idle }
        .onChange(of: haToken) { _, _ in connectionState = .idle }
    }

    private func move(by offset: Int) {
        let steps = OnboardingStep.allCases
        guard let index = steps.firstIndex(of: step) else { return }
        let next = index + offset
        guard steps.indices.contains(next) else { return }
        step = steps[next]
    }

    private func testConnection() {
        connectionState = .testing
        Task {
            let ok = await syncEngine.testHAConnection()
            connectionState = ok ? .succeeded : .failed(errorMessage)
        }
    }

    private var errorMessage: String {
        "Could not connect. Check the address and token, then try again."
    }
}

// MARK: - Content

/// The onboarding flow with every input passed in, so each step can be previewed
/// and snapshot tested without HomeKit or a Home Assistant server.
struct OnboardingContent: View {
    let step: OnboardingStep
    let homeKitAuthorized: Bool
    let homeNames: [String]
    @Binding var haURL: String
    @Binding var haToken: String
    let connectionState: OnboardingConnectionState
    var animatesBackground = true
    let onRequestHomeKitAccess: () -> Void
    let onTestConnection: () -> Void
    let onBack: () -> Void
    let onNext: () -> Void
    let onFinish: () -> Void

    private var stepNumber: Int { step.rawValue + 1 }
    private var stepCount: Int { OnboardingStep.allCases.count }

    var body: some View {
        ZStack {
            AmbientGlow(animates: animatesBackground)

            VStack(alignment: .leading, spacing: 0) {
                header

                ScrollView {
                    stepBody
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 20)
                }

                footer
            }
            .padding(24)
            .frame(maxWidth: 720)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(uiColor: .systemBackground).opacity(0.92))
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .accentColor.opacity(0.28), radius: 30, x: 0, y: 12)
            .padding(16)
        }
    }

    // MARK: Chrome

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Setup")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Step \(stepNumber) of \(stepCount)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ProgressView(value: Double(stepNumber), total: Double(stepCount))

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.largeTitle.bold())
                Text(step.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
    }

    private var footer: some View {
        HStack {
            if step != .welcome {
                Button("Back", action: onBack)
                    .buttonStyle(.bordered)
            }

            Spacer()

            if step == .ready {
                Button("Start Using the Bridge", action: onFinish)
                    .buttonStyle(.borderedProminent)
                    .glow(.accentColor)
            } else {
                Button(nextButtonTitle, action: onNext)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canContinue)
                    .glow(canContinue ? .accentColor : .clear)
            }
        }
    }

    private var nextButtonTitle: String {
        switch step {
        case .appleHome where !homeKitAuthorized: return "Continue Anyway"
        case .homeAssistant: return "Save and Continue"
        default: return "Continue"
        }
    }

    private var canContinue: Bool {
        guard step == .homeAssistant else { return true }
        return HAConfiguration.urlProblem(haURL) == nil && HAConfiguration.tokenProblem(haToken) == nil
    }

    // MARK: Steps

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case .welcome: welcomeStep
        case .howItWorks: howItWorksStep
        case .requirements: requirementsStep
        case .appleHome: appleHomeStep
        case .homeAssistant: homeAssistantStep
        case .ready: readyStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Apple Home and Home Assistant each keep their own room names, device names, and device placement. This app compares the two and copies your choice from one side to the other.")
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 16) {
                BridgeBulletRow(
                    systemImage: SyncSubject.rooms.symbolName,
                    title: SyncSubject.rooms.title,
                    message: "Create the rooms or areas that only exist on one side.",
                    tint: .blue
                )
                BridgeBulletRow(
                    systemImage: SyncSubject.placement.symbolName,
                    title: SyncSubject.placement.title,
                    message: "Put each device in the same room on both sides.",
                    tint: .purple
                )
                BridgeBulletRow(
                    systemImage: SyncSubject.names.symbolName,
                    title: SyncSubject.names.title,
                    message: "Give each device the same name on both sides.",
                    tint: .teal
                )
            }

            BridgeCard {
                BridgeStatusHeader(
                    title: "You pick the direction every time",
                    message: "Each sync runs one way only. The side you copy from is never modified.",
                    systemImage: "arrow.left.arrow.right.circle.fill",
                    tint: .accentColor
                )
                BridgeDirectionBadge(direction: .homeAssistantToAppleHome, showsExplanation: true)
                BridgeDirectionBadge(direction: .appleHomeToHomeAssistant, showsExplanation: true)
            }
        }
    }

    private var howItWorksStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 16) {
                BridgeBulletRow(
                    systemImage: "number",
                    title: "Devices are matched by entity ID",
                    message: "Home Assistant writes each entity ID (like light.kitchen) into the serial number of the device it exposes to Apple Home. That serial number is how the two sides are paired.",
                    tint: .blue
                )
                BridgeBulletRow(
                    systemImage: "list.bullet.clipboard",
                    title: "Nothing is written until you preview",
                    message: "Every sync starts as a preview that lists each change. You apply it only when the list looks right.",
                    tint: .orange
                )
                BridgeBulletRow(
                    systemImage: "clock.arrow.circlepath",
                    title: "Repeat it on a schedule",
                    message: "Once a direction works for you, Actions can run the same sync daily at a set time.",
                    tint: .green
                )
                BridgeBulletRow(
                    systemImage: "point.3.connected.trianglepath.dotted",
                    title: "Drive Apple Home from your own tools",
                    message: "The bridge can also serve a small local API on this device, for scripts and automations on your network.",
                    tint: .purple
                )
            }
        }
    }

    private var requirementsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            BridgeCard {
                BridgeStatusHeader(
                    title: "Expose your devices with the HomeKit Bridge integration",
                    message: "In Home Assistant, add the HomeKit Bridge integration and let it expose the devices you want to keep in sync.",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                )

                Text("Devices that reach Apple Home another way — a native HomeKit accessory, or a different bridge — carry a real hardware serial number instead of an entity ID, so this app cannot pair them and will skip them.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 16) {
                BridgeBulletRow(
                    systemImage: "checkmark.circle",
                    title: "Works",
                    message: "Devices bridged from Home Assistant into Apple Home.",
                    tint: .green
                )
                BridgeBulletRow(
                    systemImage: "minus.circle",
                    title: "Skipped",
                    message: "Native HomeKit accessories and devices from other bridges. They stay untouched.",
                    tint: .secondary
                )
            }
        }
    }

    private var appleHomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            BridgeCard {
                BridgeStatusHeader(
                    title: homeKitAuthorized ? "Apple Home is connected" : "Apple Home access needed",
                    message: homeKitAuthorized
                        ? homeSummaryMessage
                        : "The app reads your rooms and devices, and updates them only when you apply a sync.",
                    systemImage: homeKitAuthorized ? "checkmark.circle.fill" : "house.circle",
                    tint: homeKitAuthorized ? .green : .orange
                )

                if !homeKitAuthorized {
                    Button(action: onRequestHomeKitAccess) {
                        Label("Allow Access to Apple Home", systemImage: "lock.open")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            BridgeBulletRow(
                systemImage: "lightbulb",
                title: "No permission prompt?",
                message: "Open the Apple Home app once on this device, then come back and tap the button again.",
                tint: .yellow
            )
        }
    }

    private var homeSummaryMessage: String {
        switch homeNames.count {
        case 0: return "No homes found yet. They appear here once Apple Home finishes loading."
        case 1: return "Found “\(homeNames[0])”. You can switch homes later on the Sync screen."
        default: return "Found \(homeNames.count) homes: \(homeNames.joined(separator: ", ")). You pick which one to sync later."
        }
    }

    private var homeAssistantStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            BridgeCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Address")
                        .font(.headline)
                    Text("The same address you type in a browser to open Home Assistant.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("http://homeassistant.local:8123", text: $haURL)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    fieldNote(problem: HAConfiguration.urlProblem(haURL), okMessage: connectsToMessage)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Long-lived access token")
                        .font(.headline)
                    Text("Home Assistant → your profile → Security → Long-lived access tokens → Create token.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    SecureField("Paste the token", text: $haToken)
                        .textFieldStyle(.roundedBorder)
                    fieldNote(problem: HAConfiguration.tokenProblem(haToken), okMessage: "Token saved on this device only.")
                }

                Divider()

                HStack(spacing: 12) {
                    Button(action: onTestConnection) {
                        Label("Test Connection", systemImage: "network")
                    }
                    .buttonStyle(.bordered)
                    .disabled(connectionState == .testing || !canContinue)

                    connectionStatus
                }
            }

            Link(destination: URL(string: "https://www.home-assistant.io/docs/authentication/")!) {
                Label("How to create a long-lived access token", systemImage: "questionmark.circle")
            }
            .font(.callout)
        }
    }

    private var connectsToMessage: String? {
        guard let url = HAConfiguration.webSocketURL(for: haURL) else { return nil }
        return "Will connect to \(url.absoluteString)"
    }

    @ViewBuilder
    private func fieldNote(problem: String?, okMessage: String?) -> some View {
        if let problem {
            Label(problem, systemImage: "exclamationmark.circle")
                .font(.footnote)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        } else if let okMessage {
            Text(okMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var connectionStatus: some View {
        switch connectionState {
        case .idle:
            EmptyView()
        case .testing:
            Text("Connecting…")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .succeeded:
            Label("Connected to Home Assistant", systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            BridgeCard {
                BridgeInfoRow(label: "Apple Home", value: homeKitAuthorized ? "Connected" : "Not connected yet")
                BridgeInfoRow(label: "Home Assistant", value: connectionState == .succeeded ? "Connected" : "Saved, not tested")
                BridgeInfoRow(label: "Address", value: HAConfiguration.normalizedURL(haURL).isEmpty ? "Not set" : HAConfiguration.normalizedURL(haURL), selectable: true)
            }

            VStack(alignment: .leading, spacing: 16) {
                BridgeBulletRow(
                    systemImage: "house",
                    title: "Start on Dashboard",
                    message: "It shows at a glance whether Apple Home, Home Assistant, and the local API are ready.",
                    tint: .blue
                )
                BridgeBulletRow(
                    systemImage: "arrow.triangle.2.circlepath",
                    title: "Then open Sync",
                    message: "Pick a direction, preview the changes, and apply them when the list looks right.",
                    tint: .green
                )
                BridgeBulletRow(
                    systemImage: "gearshape",
                    title: "Setup lives in Settings",
                    message: "You can change the address, the token, and run this guide again at any time.",
                    tint: .secondary
                )
            }
        }
    }
}

// MARK: - Backdrop

/// A soft, slowly breathing multi-color glow used as an onboarding backdrop.
private struct AmbientGlow: View {
    var animates = true

    @State private var animate = false

    var body: some View {
        ZStack {
            glowCircle(.accentColor, size: 380, opacity: 0.22)
                .offset(x: animate ? -150 : -80, y: animate ? -150 : -90)
            glowCircle(.purple, size: 340, opacity: 0.18)
                .offset(x: animate ? 160 : 100, y: animate ? 130 : 70)
            glowCircle(.teal, size: 300, opacity: 0.16)
                .offset(x: animate ? 70 : 20, y: animate ? -70 : 130)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            guard animates else { return }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }

    private func glowCircle(_ color: Color, size: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 120)
            .opacity(opacity)
    }
}

private extension View {
    /// Adds a soft colored halo around a view (used for prominent buttons).
    func glow(_ color: Color, radius: CGFloat = 12) -> some View {
        shadow(color: color.opacity(0.55), radius: radius, x: 0, y: 3)
    }
}
