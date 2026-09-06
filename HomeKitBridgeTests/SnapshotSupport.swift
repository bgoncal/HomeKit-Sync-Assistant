import SnapshotTesting
import SwiftUI
import XCTest
@testable import HomeKitBridge

/// Screen sizes the snapshots are recorded at. iPhone snapshots use a portrait
/// phone viewport; Mac snapshots use a typical Catalyst window.
enum SnapshotScreen {
    #if targetEnvironment(macCatalyst)
    static let platformName = "mac"
    static let size = CGSize(width: 1_000, height: 760)
    /// Catalyst has no device configuration, so it renders at a window-sized frame.
    static let layout = SwiftUISnapshotLayout.fixed(width: size.width, height: size.height)
    #else
    static let platformName = "iPhone"
    static let size = CGSize(width: 390, height: 844)
    /// A real device layout, so the references carry the status bar and home
    /// indicator insets the app actually gets.
    static let layout = SwiftUISnapshotLayout.device(config: .iPhone13Pro)
    #endif

    /// Where reference images are read from and written to.
    ///
    /// On iOS they live next to the test file, in the repository. A Mac Catalyst
    /// app is always sandboxed and cannot touch the repository, so there they live
    /// in the app container and `Scripts/snapshot-tests.sh mac` copies them in and
    /// out around the test run.
    static func referenceDirectory(forTestFile filePath: StaticString) -> String? {
        #if targetEnvironment(macCatalyst)
        let fileName = URL(fileURLWithPath: "\(filePath)").deletingPathExtension().lastPathComponent
        return NSHomeDirectory() + "/Documents/__Snapshots__/" + fileName
        #else
        return nil
        #endif
    }
}

/// Base class that pins everything a snapshot could otherwise drift with:
/// time zone, animations, and the recording mode.
class SnapshotTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        NSTimeZone.default = TimeZone(identifier: "UTC") ?? .current
        UIView.setAnimationsEnabled(false)
    }

    override func tearDown() {
        UIView.setAnimationsEnabled(true)
        super.tearDown()
    }
}

@MainActor
extension SnapshotTestCase {
    /// Renders a screen at the platform's reference size and compares it with the
    /// stored reference image. References are per platform, so the same test file
    /// covers both iPhone and Mac.
    func assertScreen(
        _ view: some View,
        named name: String,
        size: CGSize = SnapshotScreen.size,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        let layout = SnapshotScreen.layout
        let screen = view
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.colorScheme, .light)
            .frame(width: size.width, height: size.height)
            .background(Color(uiColor: .systemBackground))

        let failure = verifySnapshot(
            of: screen,
            as: .image(
                precision: 0.99,
                perceptualPrecision: 0.98,
                layout: layout,
                traits: UITraitCollection(traitsFrom: [
                    UITraitCollection(userInterfaceStyle: .light),
                    UITraitCollection(displayScale: 2),
                    UITraitCollection(preferredContentSizeCategory: .large),
                    UITraitCollection(layoutDirection: .leftToRight)
                ])
            ),
            named: "\(name).\(SnapshotScreen.platformName)",
            snapshotDirectory: SnapshotScreen.referenceDirectory(forTestFile: file),
            file: file,
            testName: testName,
            line: line
        )

        if let failure {
            XCTFail(failure, file: file, line: line)
        }
    }
}
