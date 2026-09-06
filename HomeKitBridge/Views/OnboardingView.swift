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
        case .welcome: return "Welcome to Home Sync Assistant"
        case .howItWorks: return "How It Works"
        case .requirements: return "Before You Start"
        case .appleHome: return "Connect Apple Home"
        case .homeAssistant: return "Connect Home Assistant"
        case .ready: return "You’re Ready"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome: return "Keep Apple Home and Home Assistant telling the same story."
        case .howItWorks: return "How devices are paired, and when anything is written."
        case .requirements: return "One Home Assistant setting decides whether syncing can work."
        case .appleHome: return "Allow the app to read and update your Apple Home."
        case .homeAssistant: return "Enter the address and access token for your Home Assistant."
        case .ready: return "Here’s what is set up, and where to go next."
        }
    }

    var symbolName: String {
        switch self {
        case .welcome: return "arrow.left.arrow.right.circle.fill"
        case .howItWorks: return "link.circle.fill"
        case .requirements: return "exclamationmark.triangle.fill"
        case .appleHome: return "house.fill"
        case .homeAssistant: return "server.rack"
        case .ready: return "checkmark.circle.fill"
        }
    }
}

/// Result of the "Test Connection" button, on setup and in Settings.
enum ConnectionTestState: Equatable {
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
    @State private var connectionState: ConnectionTestState = .idle

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
        withAnimation { step = steps[next] }
    }

    private func testConnection() {
        connectionState = .testing
        Task {
            let ok = await syncEngine.testHAConnection()
            connectionState = ok
                ? .succeeded
                : .failed("Could not connect. Check the address and token, then try again.")
        }
    }
}

// MARK: - Content

/// Setup, in the shape of Apple's own welcome screens: an icon, a title, a few
/// rows explaining the app, and one clear action at the bottom.
struct OnboardingContent: View {
    let step: OnboardingStep
    let homeKitAuthorized: Bool
    let homeNames: [String]
    @Binding var haURL: String
    @Binding var haToken: String
    let connectionState: ConnectionTestState
    let onRequestHomeKitAccess: () -> Void
    let onTestConnection: () -> Void
    let onBack: () -> Void
    let onNext: () -> Void
    let onFinish: () -> Void

    private var stepNumber: Int { step.rawValue + 1 }
    private var stepCount: Int { OnboardingStep.allCases.count }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .welcome: welcomeStep
            case .howItWorks: howItWorksStep
            case .requirements: requirementsStep
            case .appleHome: appleHomeStep
            case .homeAssistant: homeAssistantStep
            case .ready: readyStep
            }

            actions
        }
    }

    // MARK: Page scaffolding

    private func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                VStack(alignment: .leading, spacing: 28) {
                    content()
                }
                .padding(.top, 36)
            }
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(uiColor: .systemBackground))
    }

    private var header: some View {
        VStack(spacing: 16) {
            icon
                .padding(.top, 44)
            Text(step.title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(step.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var icon: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 88, height: 88)
            .overlay {
                Image(systemName: step.symbolName)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Text("Step \(stepNumber) of \(stepCount)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            if step == .ready {
                Button(action: onFinish) {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button(action: onNext) {
                    Text(nextButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canContinue)
            }

            if step != .welcome {
                Button("Back", action: onBack)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .top) { Divider() }
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

    private var welcomeStep: some View {
        page {
            BridgeFeatureRow(
                systemImage: SyncSubject.rooms.symbolName,
                title: SyncSubject.rooms.title,
                message: "Create the rooms or areas that only exist on one side.",
                tint: .blue
            )
            BridgeFeatureRow(
                systemImage: SyncSubject.placement.symbolName,
                title: SyncSubject.placement.title,
                message: "Put each device in the same room on both sides.",
                tint: .purple
            )
            BridgeFeatureRow(
                systemImage: SyncSubject.names.symbolName,
                title: SyncSubject.names.title,
                message: "Give each device the same name on both sides.",
                tint: .teal
            )
            BridgeFeatureRow(
                systemImage: "arrow.left.arrow.right",
                title: "You Pick the Direction",
                message: "Every sync runs one way. The side you copy from is never modified.",
                tint: .orange
            )
        }
    }

    private var howItWorksStep: some View {
        page {
            BridgeFeatureRow(
                systemImage: "number",
                title: "Paired by Entity ID",
                message: "Home Assistant writes each entity ID, like light.kitchen, into the serial number of the device it exposes to Apple Home. That is how the two sides are matched.",
                tint: .blue
            )
            BridgeFeatureRow(
                systemImage: "list.bullet.clipboard",
                title: "Preview, Then Apply",
                message: "Every sync starts as a list of the exact changes. Nothing is written until you apply it.",
                tint: .orange
            )
            BridgeFeatureRow(
                systemImage: "clock.arrow.circlepath",
                title: "Repeat on a Schedule",
                message: "Once a direction works for you, Actions can run it daily at a set time.",
                tint: .green
            )
            BridgeFeatureRow(
                systemImage: "point.3.connected.trianglepath.dotted",
                title: "Your Own Tools",
                message: "A small local API can read and change Apple Home from scripts on your network.",
                tint: .purple
            )
        }
    }

    private var requirementsStep: some View {
        page {
            BridgeFeatureRow(
                systemImage: "app.connected.to.app.below.fill",
                title: "Use the HomeKit Bridge Integration",
                message: "In Home Assistant, add the HomeKit Bridge integration and let it expose the devices you want to keep in sync.",
                tint: .orange
            )
            BridgeFeatureRow(
                systemImage: "checkmark.circle",
                title: "Works",
                message: "Devices bridged from Home Assistant into Apple Home.",
                tint: .green
            )
            BridgeFeatureRow(
                systemImage: "minus.circle",
                title: "Skipped",
                message: "Native HomeKit accessories and devices from other bridges. They carry a real hardware serial number, so they cannot be paired — and they stay untouched.",
                tint: .secondary
            )
        }
    }

    private var appleHomeStep: some View {
        page {
            BridgeStatusRow(
                title: homeKitAuthorized ? "Connected" : "Access Needed",
                message: homeKitAuthorized ? homeSummaryMessage : "The app reads your rooms and devices, and updates them only when you apply a sync.",
                systemImage: homeKitAuthorized ? "checkmark.circle.fill" : "lock.circle.fill",
                tint: homeKitAuthorized ? .green : .orange
            )

            if !homeKitAuthorized {
                Button(action: onRequestHomeKitAccess) {
                    Text("Allow Access to Apple Home")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            BridgeFeatureRow(
                systemImage: "lightbulb",
                title: "No Prompt?",
                message: "Open the Apple Home app once on this device, then come back and try again.",
                tint: .yellow
            )
        }
    }

    private var homeSummaryMessage: String {
        switch homeNames.count {
        case 0: return "No homes have loaded yet. They appear once Apple Home finishes syncing."
        case 1: return "Found “\(homeNames[0])”."
        default: return "Found \(homeNames.count) homes: \(homeNames.joined(separator: ", ")). You choose which one to sync later."
        }
    }

    private var homeAssistantStep: some View {
        Form {
            Section {
                header
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                TextField("homeassistant.local:8123", text: $haURL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
            } header: {
                Text("Address")
            } footer: {
                if haURL.isEmpty {
                    Text("The same address you type in a browser to open Home Assistant.")
                } else if let problem = HAConfiguration.urlProblem(haURL) {
                    Text(problem).foregroundStyle(.orange)
                } else if let url = HAConfiguration.webSocketURL(for: haURL) {
                    Text("Will connect to \(url.absoluteString)")
                }
            }

            Section {
                SecureField("Paste the token", text: $haToken)
            } header: {
                Text("Long-Lived Access Token")
            } footer: {
                if !haToken.isEmpty, let problem = HAConfiguration.tokenProblem(haToken) {
                    Text(problem).foregroundStyle(.orange)
                } else {
                    Text("In Home Assistant: your profile → Security → Long-lived access tokens → Create token. The token is stored on this device.")
                }
            }

            Section {
                Button(action: onTestConnection) {
                    HStack {
                        Text("Test Connection")
                        if connectionState == .testing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(connectionState == .testing || !canContinue)

                if let result = connectionResult {
                    BridgeStatusRow(
                        title: result.title,
                        message: result.message,
                        systemImage: result.systemImage,
                        tint: result.tint
                    )
                }

                Link(destination: URL(string: "https://www.home-assistant.io/docs/authentication/")!) {
                    Label("How to Create a Token", systemImage: "arrow.up.right.square")
                }
            }
        }
    }

    private var connectionResult: (title: String, message: String, systemImage: String, tint: Color)? {
        switch connectionState {
        case .idle, .testing:
            return nil
        case .succeeded:
            return ("Connected", "Home Assistant answered and accepted the token.", "checkmark.circle.fill", .green)
        case .failed(let message):
            return ("Not Connected", message, "exclamationmark.circle.fill", .red)
        }
    }

    private var readyStep: some View {
        Form {
            Section {
                header
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                LabeledContent(SyncPlatform.appleHome.name, value: homeKitAuthorized ? "Connected" : "Not connected")
                LabeledContent(SyncPlatform.homeAssistant.name, value: connectionState == .succeeded ? "Connected" : "Saved, not tested")
                LabeledContent("Address", value: HAConfiguration.normalizedURL(haURL).isEmpty ? "Not set" : HAConfiguration.normalizedURL(haURL))
                    .lineLimit(1)
                    .truncationMode(.middle)
            } header: {
                Text("Setup")
            }

            Section {
                BridgeFeatureRow(
                    systemImage: "square.grid.2x2",
                    title: "Start on Dashboard",
                    message: "It shows whether both sides and the local API are ready.",
                    tint: .blue
                )
                BridgeFeatureRow(
                    systemImage: "arrow.triangle.2.circlepath",
                    title: "Then Open Sync",
                    message: "Pick a direction, preview the changes, and apply them when the list looks right.",
                    tint: .green
                )
                BridgeFeatureRow(
                    systemImage: "gearshape",
                    title: "Setup Lives in Settings",
                    message: "Change the address or token, or run this guide again, at any time.",
                    tint: .secondary
                )
            }
        }
    }
}
