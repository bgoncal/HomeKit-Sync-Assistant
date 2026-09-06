import SwiftUI
import XCTest
@testable import HomeKitBridge

@MainActor
final class OnboardingSnapshotTests: SnapshotTestCase {
    func testWelcomeStep() {
        assertScreen(onboarding(step: .welcome), named: "onboarding-welcome")
    }

    func testHowItWorksStep() {
        assertScreen(onboarding(step: .howItWorks), named: "onboarding-how-it-works")
    }

    func testRequirementsStep() {
        assertScreen(onboarding(step: .requirements), named: "onboarding-requirements")
    }

    func testAppleHomeStepWaitingForAccess() {
        assertScreen(
            onboarding(step: .appleHome, homeKitAuthorized: false, homeNames: []),
            named: "onboarding-apple-home-waiting"
        )
    }

    func testAppleHomeStepAuthorized() {
        assertScreen(onboarding(step: .appleHome), named: "onboarding-apple-home-connected")
    }

    func testHomeAssistantStepEmpty() {
        assertScreen(
            onboarding(step: .homeAssistant, url: "", token: ""),
            named: "onboarding-home-assistant-empty"
        )
    }

    func testHomeAssistantStepConnected() {
        assertScreen(
            onboarding(step: .homeAssistant, connectionState: .succeeded),
            named: "onboarding-home-assistant-connected"
        )
    }

    func testHomeAssistantStepRejected() {
        assertScreen(
            onboarding(
                step: .homeAssistant,
                token: "short-token",
                connectionState: .failed("Could not connect. Check the address and token, then try again.")
            ),
            named: "onboarding-home-assistant-failed"
        )
    }

    func testReadyStep() {
        assertScreen(
            onboarding(step: .ready, connectionState: .succeeded),
            named: "onboarding-ready"
        )
    }

    private func onboarding(
        step: OnboardingStep,
        homeKitAuthorized: Bool = true,
        homeNames: [String] = ["Casa"],
        url: String = "http://homeassistant.local:8123",
        token: String = Fixtures.token,
        connectionState: OnboardingConnectionState = .idle
    ) -> some View {
        OnboardingContent(
            step: step,
            homeKitAuthorized: homeKitAuthorized,
            homeNames: homeNames,
            haURL: .constant(url),
            haToken: .constant(token),
            connectionState: connectionState,
            animatesBackground: false,
            onRequestHomeKitAccess: {},
            onTestConnection: {},
            onBack: {},
            onNext: {},
            onFinish: {}
        )
    }
}
