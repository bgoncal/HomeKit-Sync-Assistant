import SwiftUI
import XCTest
@testable import HomeKitBridge

/// Writes raw store captures instead of comparing them.
///
/// These render the same screens the snapshot tests do, at the native size App Store
/// Connect wants for the largest phone and the largest tablet, straight into
/// `Docs/app-store/<device>/` in the repository. `Scripts/capture-screenshots.sh`
/// runs one class per simulator; Vitrine frames the result and derives every other
/// size. Skipped on Mac Catalyst, where the sandbox rules out writing there.
///
/// The screens are shared by both classes so the two sets tell the same story in
/// the same order.
enum StoreScreens {
    struct Screen {
        let name: String
        let view: AnyView
    }

    @MainActor
    static var all: [Screen] {
        [
            Screen(name: "01-home", view: AnyView(NavigationStack {
                HomeContent(
                    homes: [Fixtures.home, Fixtures.secondHome],
                    isHomeKitAuthorized: true,
                    connections: Fixtures.connections,
                    isServerRunning: true,
                    serverPort: 8400,
                    supportsScheduledActions: false,
                    tipProduct: Fixtures.tipProduct
                )
            })),
            Screen(name: "02-sync", view: AnyView(NavigationStack {
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
            })),
            Screen(name: "03-devices", view: AnyView(NavigationStack {
                HomeDevicesContent(home: Fixtures.home, search: .constant(""))
            })),
            Screen(name: "04-entities", view: AnyView(NavigationStack {
                EntitiesContent(
                    serverName: Fixtures.houseServer.name,
                    serverId: Fixtures.houseServer.id,
                    areas: Fixtures.entityAreas,
                    search: .constant("")
                )
            })),
            Screen(name: "05-device", view: AnyView(NavigationStack {
                DeviceDetailContent(
                    accessory: Fixtures.kitchenLight,
                    matchState: .matched(Fixtures.homeAssistantMatch),
                    serverName: Fixtures.houseServer.name
                )
            })),
            Screen(name: "06-activity", view: AnyView(NavigationStack {
                LogsContent(
                    entries: Fixtures.logEntries,
                    search: .constant(""),
                    selectedCategory: .constant(.all)
                )
            })),
        ]
    }
}

/// 6.9" phone — 440 × 956 points at 3x, the 1320 × 2868 App Store Connect wants.
@MainActor
final class PhoneScreenshotCaptureTests: SnapshotTestCase {
    func testCaptureEveryScreen() throws {
        try StoreCapture.captureIsEnabled()
        for screen in StoreScreens.all {
            try StoreCapture.capture(
                screen.view,
                named: screen.name,
                device: "iphone",
                size: CGSize(width: 440, height: 956),
                scale: 3
            )
        }
    }
}

/// 13" tablet — 1032 × 1376 points at 2x, the 2064 × 2752 App Store Connect wants.
@MainActor
final class PadScreenshotCaptureTests: SnapshotTestCase {
    func testCaptureEveryScreen() throws {
        try StoreCapture.captureIsEnabled()
        for screen in StoreScreens.all {
            try StoreCapture.capture(
                screen.view,
                named: screen.name,
                device: "ipad",
                size: CGSize(width: 1032, height: 1376),
                scale: 2
            )
        }
    }
}

// MARK: - Plumbing

@MainActor
enum StoreCapture {
    static func captureIsEnabled() throws {
        #if targetEnvironment(macCatalyst)
        throw XCTSkip("A sandboxed Catalyst app cannot write into the repository")
        #endif
    }

    static func capture(
        _ view: some View,
        named name: String,
        device: String,
        size: CGSize,
        scale: CGFloat
    ) throws {
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
            .appendingPathComponent("Docs/app-store", isDirectory: true)
            .appendingPathComponent(device, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).png")
        try data.write(to: url)

        print("SCREENSHOT \(Int(size.width * scale))x\(Int(size.height * scale)) \(url.path)")
    }
}
