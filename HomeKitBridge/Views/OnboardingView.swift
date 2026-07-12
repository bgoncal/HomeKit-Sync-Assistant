import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var syncEngine: SyncEngine

    @AppStorage("haURL") private var haURL = ""
    @AppStorage("haToken") private var haToken = ""
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    @State private var step = 0
    @State private var haConnectionOK: Bool?
    @State private var isTestingHA = false

    private let stepsCount = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("HomeKit Bridge Setup")
                    .font(.largeTitle.bold())
                Spacer()
                Text("Step \(step + 1) of \(stepsCount)")
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(step + 1), total: Double(stepsCount))

            Group {
                switch step {
                case 0: welcomeStep
                case 1: homeKitStep
                case 2: homeAssistantStep
                case 3: importantNoteStep
                default: doneStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                }
                Spacer()
                if step < stepsCount - 1 {
                    Button("Next") { step += 1 }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canContinue)
                } else {
                    Button("Start Using App") {
                        onboardingComplete = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 520)
    }

    private var canContinue: Bool {
        switch step {
        case 2:
            return !haURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !haToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return true
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome 👋")
                .font(.title2.bold())
            Text("HomeKit Bridge keeps room names and device names aligned between Apple Home and Home Assistant.")
            Text("You’ll configure Home Assistant access, then run dry-run syncs before any changes are applied.")
                .foregroundStyle(.secondary)
        }
    }

    private var homeKitStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HomeKit Access")
                .font(.title2.bold())
            Text("The app needs permission to read and update your Apple Home data.")

            HStack {
                Label(homeKitManager.isAuthorized ? "Connected" : "Waiting for access", systemImage: homeKitManager.isAuthorized ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                    .foregroundStyle(homeKitManager.isAuthorized ? .green : .orange)
                Spacer()
                Button("Request Access") {
                    homeKitManager.requestAccess()
                }
            }

            Text("Tip: if no prompt appears, open Apple Home once and return.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var homeAssistantStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Home Assistant Setup")
                .font(.title2.bold())

            TextField("Home Assistant URL (e.g. http://homeassistant.local:8123)", text: $haURL)
                .textFieldStyle(.roundedBorder)

            SecureField("Long-Lived Access Token", text: $haToken)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button {
                    Task {
                        isTestingHA = true
                        haConnectionOK = await syncEngine.testHAConnection()
                        isTestingHA = false
                    }
                } label: {
                    if isTestingHA {
                        ProgressView()
                    } else {
                        Text("Test Connection")
                    }
                }
                .disabled(isTestingHA)

                if let haConnectionOK {
                    Label(haConnectionOK ? "Connected" : "Failed", systemImage: haConnectionOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(haConnectionOK ? .green : .red)
                }
            }

            Link("How to create a Long-Lived Access Token", destination: URL(string: "https://www.home-assistant.io/docs/authentication/")!)
        }
    }

    private var importantNoteStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Important Note")
                .font(.title2.bold())
            Text("Devices **must** be exposed to Apple Home via Home Assistant’s **HomeKit Bridge** integration.")
            Text("Why: this workflow matches each HomeKit accessory to Home Assistant using the HomeKit serial number, which must equal the HA entity_id.")
                .foregroundStyle(.secondary)
            Text("If devices come from another source, matching can fail and sync results will be incomplete.")
                .foregroundStyle(.secondary)
        }
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You’re all set ✅")
                .font(.title2.bold())
            Text("Open the Dashboard to confirm status, then use Sync with dry-run previews before applying changes.")
        }
    }
}
