import SwiftUI
import XCTest
@testable import HomeKitBridge

/// Writes store-ready screenshots instead of comparing them.
///
/// These render the same screens the snapshot tests do, at 6.7" and 3x, straight
/// into `Screenshots/` in the repository. Skipped on Mac Catalyst, where the
/// sandbox rules out writing there.
@MainActor
final class ScreenshotCaptureTests: SnapshotTestCase {
    /// 6.7" portrait — 430 × 932 points at 3x, the size App Store Connect expects.
    private let size = CGSize(width: 430, height: 932)
    private let scale: CGFloat = 3

    /// 12.9" iPad portrait — 1024 × 1366 at 2x, which is the 2048 × 2732 the store wants.
    private let padSize = CGSize(width: 1024, height: 1366)
    private let padScale: CGFloat = 2

    func testCaptureHomeScreen() throws {
        try captureIsEnabled()

        try capture(
            NavigationStack {
                HomeContent(
                    homes: [Fixtures.home, Fixtures.secondHome],
                    isHomeKitAuthorized: true,
                    connections: Fixtures.connections,
                    isServerRunning: true,
                    serverPort: 8400,
                    supportsScheduledActions: false,
                    tipProduct: Fixtures.tipProduct
                )
            },
            named: "01-home"
        )
    }

    func testCaptureSyncScreen() throws {
        try captureIsEnabled()

        try capture(
            NavigationStack {
                SyncContent(
                    homes: [Fixtures.home, Fixtures.secondHome],
                    servers: [Fixtures.houseServer, Fixtures.beachServer],
                    homeId: .constant(Fixtures.home.id),
                    serverId: .constant(Fixtures.houseServer.id),
                    direction: .constant(.homeAssistantToAppleHome),
                    subject: .constant(.placement),
                    dryRunResult: Fixtures.placementPreview,
                    progress: nil,
                    errorMessage: nil,
                    isWorking: false
                )
            },
            named: "02-sync"
        )
    }

    func testCaptureEntitiesScreen() throws {
        try captureIsEnabled()

        try capture(
            NavigationStack {
                EntitiesContent(
                    serverName: Fixtures.houseServer.name,
                    serverId: Fixtures.houseServer.id,
                    areas: Fixtures.entityAreas,
                    search: .constant("")
                )
            },
            named: "03-entities"
        )
    }

    func testCaptureDevicesScreen() throws {
        try captureIsEnabled()

        try capture(
            NavigationStack {
                HomeDevicesContent(home: Fixtures.home, search: .constant(""))
            },
            named: "04-devices"
        )
    }

    // MARK: - iPad

    func testCaptureHomeScreenOnPad() throws {
        try captureIsEnabled()

        try capture(
            NavigationStack {
                HomeContent(
                    homes: [Fixtures.home, Fixtures.secondHome],
                    isHomeKitAuthorized: true,
                    connections: Fixtures.connections,
                    isServerRunning: true,
                    serverPort: 8400,
                    supportsScheduledActions: false,
                    tipProduct: Fixtures.tipProduct
                )
            },
            named: "pad-01-home",
            size: padSize,
            scale: padScale
        )
    }

    func testCaptureSyncScreenOnPad() throws {
        try captureIsEnabled()

        try capture(
            NavigationStack {
                SyncContent(
                    homes: [Fixtures.home, Fixtures.secondHome],
                    servers: [Fixtures.houseServer, Fixtures.beachServer],
                    homeId: .constant(Fixtures.home.id),
                    serverId: .constant(Fixtures.houseServer.id),
                    direction: .constant(.homeAssistantToAppleHome),
                    subject: .constant(.placement),
                    dryRunResult: Fixtures.placementPreview,
                    progress: nil,
                    errorMessage: nil,
                    isWorking: false
                )
            },
            named: "pad-02-sync",
            size: padSize,
            scale: padScale
        )
    }

    func testCaptureEntitiesScreenOnPad() throws {
        try captureIsEnabled()

        try capture(
            NavigationStack {
                EntitiesContent(
                    serverName: Fixtures.houseServer.name,
                    serverId: Fixtures.houseServer.id,
                    areas: Fixtures.entityAreas,
                    search: .constant("")
                )
            },
            named: "pad-03-entities",
            size: padSize,
            scale: padScale
        )
    }

    func testCaptureDevicesScreenOnPad() throws {
        try captureIsEnabled()

        try capture(
            NavigationStack {
                HomeDevicesContent(home: Fixtures.home, search: .constant(""))
            },
            named: "pad-04-devices",
            size: padSize,
            scale: padScale
        )
    }

    // MARK: - Plumbing

    private func captureIsEnabled() throws {
        #if targetEnvironment(macCatalyst)
        throw XCTSkip("A sandboxed Catalyst app cannot write into the repository")
        #endif
    }

    private func capture(
        _ view: some View,
        named name: String,
        size: CGSize? = nil,
        scale: CGFloat? = nil
    ) throws {
        let size = size ?? self.size
        let scale = scale ?? self.scale
        let controller = UIHostingController(
            rootView: view
                .environment(\.locale, Locale(identifier: "en_US"))
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height)
        )
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .systemGroupedBackground

        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }

        let data = try XCTUnwrap(image.pngData())
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // HomeKitBridgeTests
            .deletingLastPathComponent()   // the repository
            .appendingPathComponent("Screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).png")
        try data.write(to: url)

        print("SCREENSHOT \(Int(size.width * scale))x\(Int(size.height * scale)) \(url.path)")
    }
}
